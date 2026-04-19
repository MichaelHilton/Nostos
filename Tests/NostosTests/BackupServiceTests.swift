import XCTest
@testable import Nostos

final class BackupServiceTests: XCTestCase {

    // Helper: create a minimal Photo, insert into DB, and optionally write a real file
    private func makePhoto(
        db: AppDatabase,
        path: String,
        hash: String? = "abc123",
        duplicateGroupId: Int64? = nil,
        isKept: Bool = false,
        cameraModel: String? = nil,
        takenAt: Date? = nil
    ) throws -> Photo {
        var photo = Photo(
            id: nil,
            path: path,
            hash: hash,
            fileSize: 10,
            width: nil,
            height: nil,
            takenAt: takenAt,
            cameraMake: nil,
            cameraModel: cameraModel,
            gpsLat: nil,
            gpsLon: nil,
            thumbnailPath: nil,
            duplicateGroupId: duplicateGroupId,
            isKept: isKept,
            status: .new,
            scannedAt: Date(),
            scanRunId: nil
        )
        try db.insertPhoto(&photo)
        return photo
    }

    // MARK: - Dry run

    func testDryRunCopiesAndSkips() async throws {
        let db = try AppDatabase.makeInMemory()

        // p1: eligible (no duplicate group)
        _ = try makePhoto(db: db, path: "/src/a.jpg", hash: "hash_a")

        // p2: in a duplicate group but NOT kept → should be skipped
        var group = DuplicateGroup(id: nil, reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)
        _ = try makePhoto(db: db, path: "/src/b.jpg", hash: "hash_b",
                          duplicateGroupId: group.id, isKept: false)

        // p3: in a duplicate group AND kept → eligible
        _ = try makePhoto(db: db, path: "/src/c.jpg", hash: "hash_c",
                          duplicateGroupId: group.id, isKept: true)

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nostos_backup_dry_\(UUID().uuidString)")

        let service = BackupService(db: db) { _ in }
        let job = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: true
        )

        // 2 eligible (a and c); b is a non-kept duplicate
        XCTAssertEqual(job.totalFiles, 2)
        XCTAssertEqual(job.copiedFiles, 2)
        XCTAssertEqual(job.skippedFiles, 0)
        XCTAssertEqual(job.status, .completed)

        // Dry run: no files written to disk
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmpVault.path))
    }

    // MARK: - Real copy

    func testRealCopyCopiesFileToVault() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nostos_backup_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        let srcFile = tmpSrc.appendingPathComponent("photo.jpg")
        try Data("fake-image".utf8).write(to: srcFile)

        _ = try makePhoto(db: db, path: srcFile.path, hash: "unique_hash_1")

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nostos_backup_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        let job = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        XCTAssertEqual(job.copiedFiles, 1)
        XCTAssertEqual(job.skippedFiles, 0)

        // The file should exist somewhere under the vault
        let enumerator = fm.enumerator(at: tmpVault, includingPropertiesForKeys: nil)
        var found = false
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == "photo.jpg" { found = true; break }
        }
        XCTAssertTrue(found, "Copied file should exist in vault")
    }

    // MARK: - Skip already in vault

    func testSkipsPhotoAlreadyInVault() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nostos_backup_skip_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        let srcFile = tmpSrc.appendingPathComponent("photo.jpg")
        try Data("fake".utf8).write(to: srcFile)

        _ = try makePhoto(db: db, path: srcFile.path, hash: "already_in_vault_hash")

        // Pre-seed the vault_photos table so it looks like this hash is already backed up
        var existing = VaultPhoto(
            id: nil,
            vaultPath: "2025/01/photo.jpg",
            hash: "already_in_vault_hash",
            fileSize: 4,
            sourcePath: srcFile.path,
            backedUpAt: Date(),
            backupJobId: nil
        )
        try db.insertVaultPhoto(&existing)

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nostos_backup_skip_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        let job = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        XCTAssertEqual(job.copiedFiles, 0)
        XCTAssertEqual(job.skippedFiles, 1)

        let results = try db.fetchBackupResults(jobId: job.id!)
        XCTAssertEqual(results.first?.action, .skipInVault)
    }

    // MARK: - Filter by camera model

    func testFilterByCameraModelOnlyBacksUpMatchingPhotos() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nostos_backup_cam_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        let file1 = tmpSrc.appendingPathComponent("nikon.jpg")
        let file2 = tmpSrc.appendingPathComponent("iphone.jpg")
        try Data("img1".utf8).write(to: file1)
        try Data("img2".utf8).write(to: file2)

        _ = try makePhoto(db: db, path: file1.path, hash: "hash_nikon", cameraModel: "Nikon D800")
        _ = try makePhoto(db: db, path: file2.path, hash: "hash_iphone", cameraModel: "iPhone 15 Pro")

        var filter = PhotoFilter()
        filter.cameraModels = ["Nikon D800"]
        filter.limit = Int.max

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nostos_backup_cam_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        let job = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: filter,
            dryRun: false
        )

        XCTAssertEqual(job.totalFiles, 1)
        XCTAssertEqual(job.copiedFiles, 1)
    }

    // MARK: - Filter by year

    func testFilterByYearRange() async throws {
        let db = try AppDatabase.makeInMemory()

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        let date2023 = cal.date(from: DateComponents(year: 2023, month: 6, day: 1))!
        let date2025 = cal.date(from: DateComponents(year: 2025, month: 6, day: 1))!

        _ = try makePhoto(db: db, path: "/src/old.jpg", hash: "hash_old", takenAt: date2023)
        _ = try makePhoto(db: db, path: "/src/new.jpg", hash: "hash_new", takenAt: date2025)

        var filter = PhotoFilter()
        filter.yearFrom = 2025
        filter.yearTo = 2025
        filter.limit = Int.max

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nostos_backup_year_vault_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        let job = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY",
            filter: filter,
            dryRun: true
        )

        XCTAssertEqual(job.totalFiles, 1, "Only the 2025 photo should match the year filter")
    }

    // MARK: - Progress callbacks

    func testProgressCallbacksAreEmitted() async throws {
        let db = try AppDatabase.makeInMemory()
        _ = try makePhoto(db: db, path: "/src/x.jpg", hash: "h1")
        _ = try makePhoto(db: db, path: "/src/y.jpg", hash: "h2")

        actor Collector {
            var items: [BackupProgress] = []
            func add(_ p: BackupProgress) { items.append(p) }
            var count: Int { items.count }
        }
        let collector = Collector()

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nostos_backup_progress_\(UUID().uuidString)")

        let service = BackupService(db: db) { p in
            Task { await collector.add(p) }
        }
        _ = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: true
        )

        let count = await collector.count
        XCTAssertGreaterThanOrEqual(count, 2, "At least start and end progress should be emitted")
    }
}
