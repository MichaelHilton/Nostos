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
        m.registerMigration("v2") { db in
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS photos_taken_at_camera_model ON photos(taken_at, camera_model)")
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
            try photo.upsert(db)
        }
    }

    func updatePhoto(_ photo: Photo) throws {
        try dbWriter.write { db in try photo.update(db) }
    }

    func fetchPhotos(filter: PhotoFilter) throws -> [Photo] {
        try dbWriter.read { db in
            var query = Photo.all()
            if !filter.status.isEmpty {
                let values = filter.status.map { $0.rawValue }
                let placeholders = Array(repeating: "?", count: values.count).joined(separator: ",")
                query = query.filter(sql: "status IN (\(placeholders))", arguments: StatementArguments(values))
            }
            if !filter.cameraModels.isEmpty || filter.includeNoCamera {
                let hasModels = !filter.cameraModels.isEmpty
                if hasModels && filter.includeNoCamera {
                    let values = Array(filter.cameraModels)
                    let placeholders = Array(repeating: "?", count: values.count).joined(separator: ",")
                    query = query.filter(sql: "(camera_model IN (\(placeholders)) OR camera_model IS NULL)", arguments: StatementArguments(values))
                } else if hasModels {
                    let values = Array(filter.cameraModels)
                    let placeholders = Array(repeating: "?", count: values.count).joined(separator: ",")
                    query = query.filter(sql: "camera_model IN (\(placeholders))", arguments: StatementArguments(values))
                } else {
                    // only include photos with no camera metadata
                    query = query.filter(sql: "camera_model IS NULL")
                }
            }

            // Year range filtering (taken_at year)
            if let from = filter.yearFrom, let to = filter.yearTo {
                // Both bounds provided. Support numeric (unix epoch) and text datetime.
                query = query.filter(sql: "CAST((CASE WHEN typeof(taken_at) IN ('integer','real') THEN strftime('%Y', taken_at, 'unixepoch') ELSE strftime('%Y', taken_at) END) AS INTEGER) BETWEEN ? AND ?", arguments: StatementArguments([from, to]))
            } else if let from = filter.yearFrom {
                query = query.filter(sql: "CAST((CASE WHEN typeof(taken_at) IN ('integer','real') THEN strftime('%Y', taken_at, 'unixepoch') ELSE strftime('%Y', taken_at) END) AS INTEGER) >= ?", arguments: StatementArguments([from]))
            } else if let to = filter.yearTo {
                query = query.filter(sql: "CAST((CASE WHEN typeof(taken_at) IN ('integer','real') THEN strftime('%Y', taken_at, 'unixepoch') ELSE strftime('%Y', taken_at) END) AS INTEGER) <= ?", arguments: StatementArguments([to]))
            }
            if let from = filter.dateFrom {
                query = query.filter(Column("taken_at") >= from)
            }
            if let to = filter.dateTo {
                query = query.filter(Column("taken_at") <= to)
            }
            if !filter.hasDuplicates.isEmpty {
                let set = filter.hasDuplicates
                let wantsWith = set.contains(true)
                let wantsWithout = set.contains(false)
                if wantsWith && !wantsWithout {
                    query = query.filter(Column("duplicate_group_id") != nil)
                } else if wantsWithout && !wantsWith {
                    query = query.filter(Column("duplicate_group_id") == nil)
                }
                // if both or neither are selected -> no extra filter (any)
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

    func fetchAllPaths() throws -> Set<String> {
        try dbWriter.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT path FROM photos")
            return Set(rows.compactMap { $0["path"] as? String })
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

    func fetchDistinctYears() throws -> [Int] {
        try dbWriter.read { db in
            let sql = "SELECT DISTINCT CAST((CASE WHEN typeof(taken_at) IN ('integer','real') THEN strftime('%Y', taken_at, 'unixepoch') ELSE strftime('%Y', taken_at) END) AS INTEGER) AS year FROM photos WHERE taken_at IS NOT NULL ORDER BY year DESC"
            let rows = try Row.fetchAll(db, sql: sql)
            return rows.compactMap { (row) -> Int? in
                if let i64 = row["year"] as? Int64 { return Int(i64) }
                if let i = row["year"] as? Int { return i }
                return nil
            }
        }
    }

    func photoCount() throws -> Int {
        try dbWriter.read { db in try Photo.fetchCount(db) }
    }

    func fetchAllPhotos() throws -> [Photo] {
        try dbWriter.read { db in try Photo.fetchAll(db) }
    }

    /// Streams all photos through a closure without loading them all into memory at once.
    func enumerateAllPhotos(_ body: (Photo) throws -> Void) throws {
        try dbWriter.read { db in
            let cursor = try Photo.fetchCursor(db)
            while let photo = try cursor.next() {
                try body(photo)
            }
        }
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
            guard !groups.isEmpty else { return [] }

            // Fetch all photos for all groups in one query, then group in memory
            let groupIds = groups.compactMap { $0.id }
            let placeholders = groupIds.map { _ in "?" }.joined(separator: ",")
            let photos = try Photo
                .filter(sql: "duplicate_group_id IN (\(placeholders))",
                        arguments: StatementArguments(groupIds))
                .order(Column("taken_at").asc)
                .fetchAll(db)

            var photosByGroupId: [Int64: [Photo]] = [:]
            for photo in photos {
                guard let gid = photo.duplicateGroupId else { continue }
                photosByGroupId[gid, default: []].append(photo)
            }

            return groups.map { group in
                DuplicateGroupWithPhotos(group: group, photos: photosByGroupId[group.id ?? -1] ?? [])
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
