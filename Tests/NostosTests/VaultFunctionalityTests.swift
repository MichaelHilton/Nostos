import XCTest
import GRDB
@testable import Nostos

final class VaultFunctionalityTests: XCTestCase {

    // MARK: - Helpers

    private func makePhoto(
        db: AppDatabase,
        path: String,
        hash: String? = "test_hash",
        status: PhotoStatus = .new,
        takenAt: Date? = nil
    ) throws -> Photo {
        var photo = Photo(
            id: nil,
            path: path,
            hash: hash,
            fileSize: 1024,
            width: nil,
            height: nil,
            takenAt: takenAt,
            cameraMake: nil,
            cameraModel: nil,
            gpsLat: nil,
            gpsLon: nil,
            thumbnailPath: nil,
            duplicateGroupId: nil,
            isKept: false,
            status: status,
            scannedAt: Date(),
            scanRunId: nil
        )
        try db.insertPhoto(&photo)
        return photo
    }

    // MARK: - Test: Backup Updates Photo Status to .copied

    func testBackupUpdatesPhotoStatusToCopied() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        let srcFile = tmpSrc.appendingPathComponent("photo.jpg")
        try Data("fake-image-data".utf8).write(to: srcFile)

        let photo = try makePhoto(db: db, path: srcFile.path, hash: "backup_test_hash")

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        _ = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        // Fetch the photo and verify status is now .copied
        let updatedPhoto = try db.fetchPhoto(id: photo.id!)
        XCTAssertNotNil(updatedPhoto, "Photo should exist after backup")
        XCTAssertEqual(updatedPhoto?.status, .copied, "Photo status should be .copied after successful backup")
    }

    // MARK: - Test: Photo Appears in Gallery After Backup

    func testPhotoAppearsInGalleryAfterBackup() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_gallery_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        let srcFile = tmpSrc.appendingPathComponent("pic.jpg")
        try Data("gallery-test-image".utf8).write(to: srcFile)

        let originalPhoto = try makePhoto(db: db, path: srcFile.path)

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_gallery_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        _ = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        // Fetch all photos from DB (simulating gallery load)
        var filter = PhotoFilter()
        filter.limit = Int.max
        let allPhotos = try db.fetchPhotos(filter: filter)

        XCTAssertFalse(allPhotos.isEmpty, "Gallery should contain photos after backup")
        let fetchedPhoto = allPhotos.first { $0.id == originalPhoto.id }
        XCTAssertNotNil(fetchedPhoto, "Original photo should appear in gallery")
        XCTAssertEqual(fetchedPhoto?.status, .copied, "Photo in gallery should have .copied status")
    }

    // MARK: - Test: Can Filter by "In Vault" Status

    func testCanFilterByInVaultStatus() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_filter_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        // Create 3 photos
        let file1 = tmpSrc.appendingPathComponent("photo1.jpg")
        let file2 = tmpSrc.appendingPathComponent("photo2.jpg")
        let file3 = tmpSrc.appendingPathComponent("photo3.jpg")

        for file in [file1, file2, file3] {
            try Data("test".utf8).write(to: file)
        }

        _ = try makePhoto(db: db, path: file1.path, hash: "hash1")
        _ = try makePhoto(db: db, path: file2.path, hash: "hash2")
        _ = try makePhoto(db: db, path: file3.path, hash: "hash3")

        // Backup all photos
        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_filter_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        _ = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        // Filter to show only .copied photos (in vault)
        var inVaultFilter = PhotoFilter()
        inVaultFilter.status = [.copied]
        inVaultFilter.limit = Int.max

        let inVaultPhotos = try db.fetchPhotos(filter: inVaultFilter)
        XCTAssertEqual(inVaultPhotos.count, 3, "Should have 3 photos in vault after backup")
        for photo in inVaultPhotos {
            XCTAssertEqual(photo.status, .copied)
        }

        // Filter to show only .new photos (not in vault)
        var notInVaultFilter = PhotoFilter()
        notInVaultFilter.status = [.new]
        notInVaultFilter.limit = Int.max

        let notInVaultPhotos = try db.fetchPhotos(filter: notInVaultFilter)
        XCTAssertEqual(notInVaultPhotos.count, 0, "Should have 0 photos not in vault after backup")
    }

    // MARK: - Test: Vault Badge Should Display for .copied Photos

    func testVaultBadgeShowsForCopiedPhotos() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_badge_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        let srcFile = tmpSrc.appendingPathComponent("badge_test.jpg")
        try Data("badge-test".utf8).write(to: srcFile)

        let originalPhoto = try makePhoto(db: db, path: srcFile.path, hash: "badge_hash")

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_badge_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        _ = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        // Verify the photo was backed up by checking both conditions:
        // 1. Status should be .copied (this triggers VaultBadge in UI)
        // 2. Photo should still exist in database
        let updatedPhoto = try db.fetchPhoto(id: originalPhoto.id!)
        XCTAssertNotNil(updatedPhoto, "Photo should exist in database after backup")
        XCTAssertEqual(updatedPhoto?.status, .copied, "Photo status should be .copied after backup")

        // 3. When fetching via filter, photo with .copied status should appear
        var filter = PhotoFilter()
        filter.limit = Int.max
        let allPhotos = try db.fetchPhotos(filter: filter)

        let copiedPhoto = allPhotos.first { $0.id == originalPhoto.id }
        XCTAssertNotNil(copiedPhoto, "Backed-up photo should appear in gallery")
        XCTAssertEqual(copiedPhoto?.status, .copied, "Photo in gallery should have .copied status")

        // 4. Verify the UI condition: if status == .copied, badge should show
        let shouldShowBadge = copiedPhoto?.status == .copied
        XCTAssertTrue(shouldShowBadge, "VaultBadge should be displayed when status == .copied")
    }

    // MARK: - Test: Multiple Backups Don't Create Duplicates in vault_photos

    func testMultipleBackupsPreventDuplicatesInVault() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_dup_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        let srcFile = tmpSrc.appendingPathComponent("duplicate_test.jpg")
        try Data("dup-test".utf8).write(to: srcFile)

        _ = try makePhoto(db: db, path: srcFile.path, hash: "dup_hash")

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_dup_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }

        // First backup
        let job1 = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        XCTAssertEqual(job1.copiedFiles, 1)
        XCTAssertEqual(job1.skippedFiles, 0)

        // Second backup attempt (should skip since already in vault)
        let job2 = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        XCTAssertEqual(job2.copiedFiles, 0, "Should not copy again")
        XCTAssertEqual(job2.skippedFiles, 1, "Should skip the already-backed-up photo")

        let results = try db.fetchBackupResults(jobId: job2.id!)
        XCTAssertEqual(results.first?.action, .skipInVault)
    }

    // MARK: - Test: Vault Photos Table Tracks Correct Metadata

    func testVaultPhotosTableHasCorrectMetadata() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_meta_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        let srcFile = tmpSrc.appendingPathComponent("meta_test.jpg")
        let testData = Data("metadata-test-file-content".utf8)
        try testData.write(to: srcFile)

        _ = try makePhoto(db: db, path: srcFile.path, hash: "meta_hash_123")

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_meta_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        let job = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        // Query vault_photos to verify metadata
        let vaultPhotos = try db.fetchAllVaultHashes()
        XCTAssertTrue(vaultPhotos.contains("meta_hash_123"), "Vault should track the photo hash")

        // Verify backup results were recorded
        let backupResults = try db.fetchBackupResults(jobId: job.id!)
        XCTAssertFalse(backupResults.isEmpty, "Backup results should be recorded")
        XCTAssertEqual(backupResults.first?.action, .copy, "Backup result action should be .copy")
        XCTAssertNotNil(backupResults.first?.vaultPath, "Backup result should have vault path")
    }

    // MARK: - Test: App Reloads Photos After Backup

    func testAppReloadsPhotosAfterBackup() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_reload_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        let srcFile = tmpSrc.appendingPathComponent("reload_test.jpg")
        try Data("reload-test-data".utf8).write(to: srcFile)

        let originalPhoto = try makePhoto(db: db, path: srcFile.path, hash: "reload_hash")

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_reload_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        _ = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        // Simulate app reloading photos (what happens in AppState.startBackup completion)
        var filter = PhotoFilter()
        filter.limit = Int.max
        let reloadedPhotos = try db.fetchPhotos(filter: filter)

        // Find the original photo in the reloaded set
        let reloadedPhoto = reloadedPhotos.first { $0.id == originalPhoto.id }
        XCTAssertNotNil(reloadedPhoto, "Photo should exist after reload")
        XCTAssertEqual(reloadedPhoto?.status, .copied, "Reloaded photo should have .copied status to show badge")

        // Verify the badge condition will work in the UI
        let shouldShowVaultBadge = reloadedPhoto?.status == .copied
        XCTAssertTrue(shouldShowVaultBadge, "VaultBadge condition should be true in gallery after reload")
    }

    // MARK: - Test: Can Show "In Vault" Label in UI

    func testInVaultLabelCondition() async throws {
        let db = try AppDatabase.makeInMemory()
        let fm = FileManager.default

        let tmpSrc = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_label_src_\(UUID().uuidString)")
        try fm.createDirectory(at: tmpSrc, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpSrc) }

        let srcFile = tmpSrc.appendingPathComponent("label_test.jpg")
        try Data("label".utf8).write(to: srcFile)

        _ = try makePhoto(db: db, path: srcFile.path, hash: "label_hash")

        let tmpVault = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vault_test_label_vault_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tmpVault) }

        let service = BackupService(db: db) { _ in }
        _ = try await service.backup(
            vaultRootURL: tmpVault,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        var filter = PhotoFilter()
        filter.limit = Int.max
        let photos = try db.fetchPhotos(filter: filter)
        let photoInVault = photos.first!

        // This condition would be used in the UI to show the "In Vault" label
        let shouldShowInVaultLabel = photoInVault.status == .copied
        XCTAssertTrue(shouldShowInVaultLabel, "UI should show 'In Vault' label for .copied photos")
    }
}
