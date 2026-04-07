import Foundation
import GRDB

final class AppDatabase {
    let dbWriter: DatabaseWriter

    private init(_ dbWriter: DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    static func makeShared() throws -> AppDatabase {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Nostos", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dbURL = dir.appendingPathComponent("nostos.db")
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let pool = try DatabasePool(path: dbURL.path, configuration: config)
        return try AppDatabase(pool)
    }

    static func makeInMemory() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            try db.execute(sql: """
                CREATE TABLE scan_runs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    root_path TEXT NOT NULL,
                    started_at DATETIME NOT NULL,
                    finished_at DATETIME,
                    photos_found INTEGER NOT NULL DEFAULT 0,
                    duplicates_found INTEGER NOT NULL DEFAULT 0,
                    status TEXT NOT NULL DEFAULT 'running'
                )
            """)

            try db.execute(sql: """
                CREATE TABLE duplicate_groups (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    reason TEXT NOT NULL,
                    kept_photo_id INTEGER
                )
            """)

            try db.execute(sql: """
                CREATE TABLE photos (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    path TEXT NOT NULL UNIQUE,
                    hash TEXT,
                    file_size INTEGER NOT NULL,
                    width INTEGER,
                    height INTEGER,
                    taken_at DATETIME,
                    camera_make TEXT,
                    camera_model TEXT,
                    gps_lat REAL,
                    gps_lon REAL,
                    thumbnail_path TEXT,
                    duplicate_group_id INTEGER REFERENCES duplicate_groups(id),
                    is_kept INTEGER NOT NULL DEFAULT 0,
                    status TEXT NOT NULL DEFAULT 'new',
                    scanned_at DATETIME NOT NULL,
                    scan_run_id INTEGER REFERENCES scan_runs(id)
                )
            """)
            try db.execute(sql: "CREATE INDEX photos_hash ON photos(hash)")
            try db.execute(sql: "CREATE INDEX photos_status ON photos(status)")
            try db.execute(sql: "CREATE INDEX photos_taken_at ON photos(taken_at)")
            try db.execute(sql: "CREATE INDEX photos_dup_group ON photos(duplicate_group_id)")

            try db.execute(sql: """
                CREATE TABLE organize_jobs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    destination_root TEXT NOT NULL,
                    folder_format TEXT NOT NULL,
                    dry_run INTEGER NOT NULL DEFAULT 0,
                    started_at DATETIME NOT NULL,
                    finished_at DATETIME,
                    status TEXT NOT NULL DEFAULT 'running',
                    total_files INTEGER NOT NULL DEFAULT 0,
                    copied_files INTEGER NOT NULL DEFAULT 0,
                    skipped_files INTEGER NOT NULL DEFAULT 0
                )
            """)

            try db.execute(sql: """
                CREATE TABLE organize_results (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    job_id INTEGER NOT NULL REFERENCES organize_jobs(id),
                    photo_id INTEGER NOT NULL REFERENCES photos(id),
                    source TEXT NOT NULL,
                    destination TEXT,
                    action TEXT NOT NULL,
                    reason TEXT
                )
            """)
        }
        return m
    }
}

// MARK: - ScanRun queries
extension AppDatabase {
    func insertScanRun(_ run: inout ScanRun) throws {
        try dbWriter.write { db in try run.insert(db) }
    }

    func updateScanRun(_ run: ScanRun) throws {
        try dbWriter.write { db in try run.update(db) }
    }

    func fetchAllScanRuns() throws -> [ScanRun] {
        try dbWriter.read { db in
            try ScanRun.order(Column("started_at").desc).fetchAll(db)
        }
    }
}

// MARK: - Photo queries
extension AppDatabase {
    func insertPhoto(_ photo: inout Photo) throws {
        try dbWriter.write { db in try photo.insert(db) }
    }

    func upsertPhoto(_ photo: inout Photo) throws {
        try dbWriter.write { db in
            if let existing = try Photo.filter(Column("path") == photo.path).fetchOne(db) {
                photo.id = existing.id
                try photo.update(db)
            } else {
                try photo.insert(db)
            }
        }
    }

    func updatePhoto(_ photo: Photo) throws {
        try dbWriter.write { db in try photo.update(db) }
    }

    func fetchPhotos(filter: PhotoFilter) throws -> [Photo] {
        try dbWriter.read { db in
            var query = Photo.all()
            if let status = filter.status {
                query = query.filter(Column("status") == status.rawValue)
            }
            if let model = filter.cameraModel {
                query = query.filter(Column("camera_model") == model)
            }
            if let from = filter.dateFrom {
                query = query.filter(Column("taken_at") >= from)
            }
            if let to = filter.dateTo {
                query = query.filter(Column("taken_at") <= to)
            }
            if let hasDups = filter.hasDuplicates {
                if hasDups {
                    query = query.filter(Column("duplicate_group_id") != nil)
                } else {
                    query = query.filter(Column("duplicate_group_id") == nil)
                }
            }
            return try query
                .order(Column("taken_at").desc)
                .limit(filter.limit, offset: filter.offset)
                .fetchAll(db)
        }
    }

    func fetchPhoto(id: Int64) throws -> Photo? {
        try dbWriter.read { db in try Photo.fetchOne(db, key: id) }
    }

    func fetchPhoto(path: String) throws -> Photo? {
        try dbWriter.read { db in
            try Photo.filter(Column("path") == path).fetchOne(db)
        }
    }

    func fetchAllHashes() throws -> [String: Int64] {
        try dbWriter.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT id, hash FROM photos WHERE hash IS NOT NULL")
            var result: [String: Int64] = [:]
            for row in rows {
                let hash: String = row["hash"]
                let id: Int64 = row["id"]
                result[hash] = id
            }
            return result
        }
    }

    func fetchDistinctCameraModels() throws -> [String] {
        try dbWriter.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT DISTINCT camera_model FROM photos WHERE camera_model IS NOT NULL ORDER BY camera_model")
            return rows.compactMap { $0["camera_model"] as? String }
        }
    }

    func photoCount() throws -> Int {
        try dbWriter.read { db in try Photo.fetchCount(db) }
    }
}

// MARK: - DuplicateGroup queries
extension AppDatabase {
    func insertDuplicateGroup(_ group: inout DuplicateGroup) throws {
        try dbWriter.write { db in try group.insert(db) }
    }

    func updateDuplicateGroup(_ group: DuplicateGroup) throws {
        try dbWriter.write { db in try group.update(db) }
    }

    func fetchDuplicateGroupsWithPhotos() throws -> [DuplicateGroupWithPhotos] {
        try dbWriter.read { db in
            let groups = try DuplicateGroup.fetchAll(db)
            return try groups.map { group in
                let photos = try Photo
                    .filter(Column("duplicate_group_id") == group.id)
                    .order(Column("taken_at").asc)
                    .fetchAll(db)
                return DuplicateGroupWithPhotos(group: group, photos: photos)
            }
        }
    }

    func setKeptPhoto(groupId: Int64, photoId: Int64) throws {
        try dbWriter.write { db in
            // Clear is_kept for all photos in group
            try db.execute(sql: "UPDATE photos SET is_kept = 0 WHERE duplicate_group_id = ?", arguments: [groupId])
            // Set is_kept for chosen photo
            try db.execute(sql: "UPDATE photos SET is_kept = 1 WHERE id = ?", arguments: [photoId])
            // Update group's kept_photo_id
            try db.execute(sql: "UPDATE duplicate_groups SET kept_photo_id = ? WHERE id = ?", arguments: [photoId, groupId])
        }
    }
}

// MARK: - OrganizeJob queries
extension AppDatabase {
    func insertOrganizeJob(_ job: inout OrganizeJob) throws {
        try dbWriter.write { db in try job.insert(db) }
    }

    func updateOrganizeJob(_ job: OrganizeJob) throws {
        try dbWriter.write { db in try job.update(db) }
    }

    func insertOrganizeResult(_ result: inout OrganizeResult) throws {
        try dbWriter.write { db in try result.insert(db) }
    }

    func fetchOrganizeJob(id: Int64) throws -> OrganizeJob? {
        try dbWriter.read { db in try OrganizeJob.fetchOne(db, key: id) }
    }

    func fetchOrganizeResults(jobId: Int64) throws -> [OrganizeResult] {
        try dbWriter.read { db in
            try OrganizeResult.filter(Column("job_id") == jobId).fetchAll(db)
        }
    }

    func fetchAllOrganizeJobs() throws -> [OrganizeJob] {
        try dbWriter.read { db in
            try OrganizeJob.order(Column("started_at").desc).fetchAll(db)
        }
    }
}
