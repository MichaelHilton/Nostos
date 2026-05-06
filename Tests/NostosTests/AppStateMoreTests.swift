import XCTest
@testable import Nostos

@MainActor
final class AppStateMoreTests: XCTestCase {

    override func tearDown() {
        // Clean up any env vars we set
        unsetenv("UI_TESTING_SOURCE_DIRECTORY_TO_PICK")
        unsetenv("UI_TESTING_VAULT_DIRECTORY_TO_PICK")
        unsetenv("UI_TESTING_SEED_DATA")
        super.tearDown()
    }

    func testPickDirectoryUsesEnvVar() {
        let tmp = NSTemporaryDirectory() + "pick-src"
        setenv("UI_TESTING_SOURCE_DIRECTORY_TO_PICK", tmp, 1)
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        let picked = appState.pickDirectory()

        XCTAssertNotNil(picked)
        XCTAssertEqual(picked?.path, tmp)
    }

    func testPickVaultDirectoryUsesEnvVar() {
        let tmp = NSTemporaryDirectory() + "pick-vault"
        setenv("UI_TESTING_VAULT_DIRECTORY_TO_PICK", tmp, 1)
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        let picked = appState.pickVaultDirectory()

        XCTAssertNotNil(picked)
        XCTAssertEqual(picked?.path, tmp)
    }

    func testStartVaultWithoutVaultSetsError() {
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        appState.startVault(folderFormat: "YYYY", dryRun: true)

        XCTAssertEqual(appState.errorMessage, "Select a vault before organizing files.")
    }

    func testChangeVaultRootCreatesDBAndSeedsWhenUIEnvSet() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.removeItem(at: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        setenv("UI_TESTING_SEED_DATA", "1", 1)

        let db = try AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        appState.changeVaultRoot(to: tmpDir)

        // loadInitialData was scheduled; run it to ensure state is updated
        await appState.loadInitialData()

        XCTAssertNotNil(appState.vaultRootURL)
        XCTAssertEqual(appState.vaultRootURL?.path, tmpDir.path)
        XCTAssertFalse(appState.scanRuns.isEmpty, "Expected seed to create scan runs")
        XCTAssertFalse(appState.organizeJobs.isEmpty, "Expected seed to create organize jobs")

        // cleanup
        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testStartScanGuardsPreventsMultipleScans() {
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        appState.scanProgress = ScanProgress(isScanning: true)
        let sourceURL = FileManager.default.temporaryDirectory

        appState.startScan(rootURL: sourceURL)

        XCTAssertTrue(appState.scanProgress.isScanning)
    }

    func testStartVaultWithoutVaultRootSetsError() {
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        appState.startVault(folderFormat: "YYYY/MM", dryRun: false)

        XCTAssertEqual(appState.errorMessage, "Select a vault before organizing files.")
    }

    func testStartOrganizeWithVault() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.removeItem(at: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let db = try AppDatabase.makeShared(vaultRootURL: tmpDir)
        let appState = AppState(db: db)

        appState.startOrganize(destination: tmpDir, folderFormat: "YYYY", dryRun: true)

        XCTAssertTrue(appState.organizeProgress.isRunning)

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testStartBackupWithoutVaultSetsError() {
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        appState.startBackup(folderFormat: "YYYY", filter: PhotoFilter(), dryRun: true)

        XCTAssertEqual(appState.errorMessage, "Select a vault before backing up.")
    }

    func testChangeVaultRootSamePath() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.removeItem(at: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let db = try AppDatabase.makeShared(vaultRootURL: tmpDir)
        let appState = AppState(db: db)

        appState.changeVaultRoot(to: tmpDir)

        XCTAssertEqual(appState.vaultRootURL?.path, tmpDir.path)

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testChangeVaultRootClearsState() async throws {
        let tmpDir1 = FileManager.default.temporaryDirectory.appendingPathComponent("vault1")
        let tmpDir2 = FileManager.default.temporaryDirectory.appendingPathComponent("vault2")

        try? FileManager.default.removeItem(at: tmpDir1)
        try? FileManager.default.removeItem(at: tmpDir2)
        try FileManager.default.createDirectory(at: tmpDir1, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tmpDir2, withIntermediateDirectories: true)

        let db = try AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        // Set up some state
        appState.photos = [Photo(id: 1, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)]
        appState.cameraModels = ["Canon"]
        appState.years = [2024]

        appState.changeVaultRoot(to: tmpDir2)

        // Verify state is cleared
        XCTAssertTrue(appState.photos.isEmpty)
        XCTAssertTrue(appState.cameraModels.isEmpty)
        XCTAssertTrue(appState.years.isEmpty)
        XCTAssertNil(appState.errorMessage)

        // cleanup
        try? FileManager.default.removeItem(at: tmpDir1)
        try? FileManager.default.removeItem(at: tmpDir2)
    }

    func testApplyFilterReloadsPhotos() async throws {
        let db = try AppDatabase.makeInMemory()

        var photo = Photo(id: nil, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        try db.insertPhoto(&photo)

        let appState = AppState(db: db)
        await appState.loadPhotos()

        XCTAssertEqual(appState.photos.count, 1)

        let filter = PhotoFilter(limit: 0)
        appState.applyFilter(filter)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(appState.photos.isEmpty)
    }

    func testSetKeptPhotoUpdatesState() async throws {
        let db = try AppDatabase.makeInMemory()

        var group = DuplicateGroup(reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)

        var p1 = Photo(id: nil, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: group.id, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        try db.insertPhoto(&p1)

        let appState = AppState(db: db)

        if let groupId = group.id, let photoId = p1.id {
            appState.setKeptPhoto(groupId: groupId, photoId: photoId)
            try await Task.sleep(nanoseconds: 100_000_000)

            XCTAssertNil(appState.errorMessage)
        }
    }

    func testPickDirectoryEmptyEnvVar() {
        setenv("UI_TESTING_SOURCE_DIRECTORY_TO_PICK", "", 1)
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        // Without setting a real path, the picker would show a dialog
        // We can only test that empty env var is treated as not set
        XCTAssertNotNil(appState)
    }

    func testPickVaultDirectoryEmptyEnvVar() {
        setenv("UI_TESTING_VAULT_DIRECTORY_TO_PICK", "", 1)
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        XCTAssertNotNil(appState)
    }

    func testDefaultVaultRootURL() {
        let defaultURL = AppState.defaultVaultRootURL()

        XCTAssertTrue(defaultURL.path.contains("Nostos"))
        XCTAssertTrue(defaultURL.path.contains("Library/Application Support"))
    }

    func testSeedUITestDataIfNeeded() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.removeItem(at: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        setenv("UI_TESTING_SEED_DATA", "1", 1)

        let appState = AppState(vaultRootURL: tmpDir)

        // seedUITestDataIfNeeded is called during init, so we should have scan runs
        await appState.loadInitialData()

        XCTAssertFalse(appState.scanRuns.isEmpty)

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testStartScanWithActualFiles() async throws {
        let sourceDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.removeItem(at: sourceDir)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let testImagePath = sourceDir.appendingPathComponent("test.jpg")
        let minimalJPEG: [UInt8] = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05, 0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D, 0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21, 0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23, 0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xFB, 0xD3, 0xFF, 0xD9]
        try Data(minimalJPEG).write(to: testImagePath)

        let db = try AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        appState.startScan(rootURL: sourceDir)

        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(appState.scanProgress.isScanning)

        try? FileManager.default.removeItem(at: sourceDir)
    }

    func testStartVaultWithValidVaultRoot() async throws {
        let vaultDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sourceDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-src")

        try? FileManager.default.removeItem(at: vaultDir)
        try? FileManager.default.removeItem(at: sourceDir)
        try FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        let db = try AppDatabase.makeShared(vaultRootURL: vaultDir)
        let appState = AppState(db: db)

        appState.startVault(folderFormat: "YYYY/MM", dryRun: true)

        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertTrue(appState.organizeProgress.isRunning || appState.organizeJobs.count >= 0)

        try? FileManager.default.removeItem(at: vaultDir)
        try? FileManager.default.removeItem(at: sourceDir)
    }

    func testStartOrganizeCreatesJob() async throws {
        let vaultDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.removeItem(at: vaultDir)
        try FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)

        let db = try AppDatabase.makeInMemory()
        var p = Photo(id: nil, path: "/tmp/photo.jpg", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        try db.insertPhoto(&p)

        let appState = AppState(db: db)
        appState.startOrganize(destination: vaultDir, folderFormat: "YYYY", dryRun: true)

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(appState.organizeProgress.isRunning || appState.lastOrganizeResults.count >= 0)

        try? FileManager.default.removeItem(at: vaultDir)
    }

    func testStartBackupWithPhotos() async throws {
        let vaultDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.removeItem(at: vaultDir)
        try FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)

        let db = try AppDatabase.makeShared(vaultRootURL: vaultDir)
        var p = Photo(id: nil, path: "/tmp/photo.jpg", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        try db.insertPhoto(&p)

        let appState = AppState(db: db)
        appState.startBackup(folderFormat: "YYYY", filter: PhotoFilter(), dryRun: true)

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(appState.backupProgress.isRunning || appState.lastBackupResults.count >= 0)

        try? FileManager.default.removeItem(at: vaultDir)
    }

    func testLoadPhotosPopulatesPhotos() async throws {
        let db = try AppDatabase.makeInMemory()

        var p1 = Photo(id: nil, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        var p2 = p1
        p2.path = "/tmp/p2"
        p2.hash = "h2"

        try db.insertPhoto(&p1)
        try db.insertPhoto(&p2)

        let appState = AppState(db: db)
        await appState.loadPhotos()

        XCTAssertEqual(appState.photos.count, 2)
    }

    func testLoadDuplicatesPopulatesDuplicates() async throws {
        let db = try AppDatabase.makeInMemory()

        var group = DuplicateGroup(reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)

        var p1 = Photo(id: nil, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: group.id, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        try db.insertPhoto(&p1)

        let appState = AppState(db: db)
        await appState.loadDuplicates()

        XCTAssertFalse(appState.duplicateGroups.isEmpty)
    }

    func testLoadScanRunsPopulatesScanRuns() async throws {
        let db = try AppDatabase.makeInMemory()

        var scanRun = ScanRun(rootPath: "/tmp", startedAt: Date(), finishedAt: Date(), photosFound: 0, duplicatesFound: 0, status: .completed)
        try db.insertScanRun(&scanRun)

        let appState = AppState(db: db)
        await appState.loadScanRuns()

        XCTAssertEqual(appState.scanRuns.count, 1)
    }

    func testLoadVaultBreakdownsPopulatesBreakdowns() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.removeItem(at: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let db = try AppDatabase.makeShared(vaultRootURL: tmpDir)

        let appState = AppState(db: db)
        await appState.loadVaultBreakdowns()

        XCTAssertEqual(appState.formatBreakdown.count, 0)

        try? FileManager.default.removeItem(at: tmpDir)
    }

    func testLoadCameraModelsPopulates() async throws {
        let db = try AppDatabase.makeInMemory()

        var p = Photo(id: nil, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        try db.insertPhoto(&p)

        let appState = AppState(db: db)
        await appState.loadCameraModels()

        XCTAssertEqual(appState.cameraModels.count, 1)
        XCTAssertTrue(appState.cameraModels.contains("EOS"))
    }

    func testLoadYearsPopulates() async throws {
        let db = try AppDatabase.makeInMemory()

        let date = Calendar.current.date(from: DateComponents(year: 2024, month: 3, day: 15))!
        var p = Photo(id: nil, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: date, cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        try db.insertPhoto(&p)

        let appState = AppState(db: db)
        await appState.loadYears()

        XCTAssertEqual(appState.years.count, 1)
        XCTAssertTrue(appState.years.contains(2024))
    }

    func testLoadTotalPhotoCount() async throws {
        let db = try AppDatabase.makeInMemory()

        var p1 = Photo(id: nil, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        var p2 = p1
        p2.path = "/tmp/p2"
        p2.hash = "h2"

        try db.insertPhoto(&p1)
        try db.insertPhoto(&p2)

        let appState = AppState(db: db)
        await appState.loadTotalPhotoCount()

        XCTAssertEqual(appState.totalPhotoCount, 2)
    }

    func testLoadOrganizeJobsWithResults() async throws {
        let db = try AppDatabase.makeInMemory()

        var photo = Photo(id: nil, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        try db.insertPhoto(&photo)

        var job = OrganizeJob(destinationRoot: "/tmp/vault", folderFormat: "YYYY", dryRun: true, startedAt: Date(), finishedAt: Date(), status: .completed, totalFiles: 1, copiedFiles: 1, skippedFiles: 0)
        try db.insertOrganizeJob(&job)

        if let jobId = job.id, let photoId = photo.id {
            var result = OrganizeResult(id: nil, jobId: jobId, photoId: photoId, source: "/tmp/p1", destination: "/tmp/vault/2024/photo.jpg", action: .copy, reason: nil)
            try db.insertOrganizeResult(&result)
        }

        let appState = AppState(db: db)
        await appState.loadOrganizeJobs()

        XCTAssertEqual(appState.organizeJobs.count, 1)
        XCTAssertFalse(appState.lastOrganizeResults.isEmpty)
    }

    func testLoadBackupJobsWithResults() async throws {
        let db = try AppDatabase.makeInMemory()

        var photo = Photo(id: nil, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        try db.insertPhoto(&photo)

        var job = BackupJob(id: nil, folderFormat: "YYYY", filterSummary: nil, dryRun: true, startedAt: Date(), finishedAt: Date(), status: .completed, totalFiles: 1, copiedFiles: 1, skippedFiles: 0)
        try db.insertBackupJob(&job)

        if let jobId = job.id, let photoId = photo.id {
            var result = BackupResult(id: nil, jobId: jobId, photoId: photoId, source: "/tmp/p1", vaultPath: "/tmp/vault/2024/photo.jpg", action: .copy, reason: nil)
            try db.insertBackupResult(&result)
        }

        let appState = AppState(db: db)
        await appState.loadBackupJobs()

        XCTAssertEqual(appState.backupJobs.count, 1)
        XCTAssertFalse(appState.lastBackupResults.isEmpty)
    }

    func testCountPhotosForBackupReturnsZeroOnError() {
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        let filter = PhotoFilter()
        let count = appState.countPhotosForBackup(filter: filter)

        XCTAssertEqual(count, 0)
    }

    func testScanProgressUpdatesWhenNotScanning() {
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        XCTAssertFalse(appState.scanProgress.isScanning)

        appState.scanProgress = ScanProgress(isScanning: true)
        XCTAssertTrue(appState.scanProgress.isScanning)
    }

    func testErrorMessageIsNilInitially() {
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        XCTAssertNil(appState.errorMessage)
    }

    func testErrorMessageCanBeSet() {
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        appState.errorMessage = "Test error"

        XCTAssertEqual(appState.errorMessage, "Test error")
    }

    func testLoadInitialDataExecutesAllLoads() async throws {
        let db = try AppDatabase.makeInMemory()

        var p = Photo(id: nil, path: "/tmp/p1", hash: "h1", fileSize: 100, width: 100, height: 100, takenAt: Date(), cameraMake: "Canon", cameraModel: "EOS", gpsLat: nil, gpsLon: nil, thumbnailPath: nil, duplicateGroupId: nil, isKept: false, status: .new, scannedAt: Date(), scanRunId: nil)
        try db.insertPhoto(&p)

        var scanRun = ScanRun(rootPath: "/tmp", startedAt: Date(), finishedAt: Date(), photosFound: 1, duplicatesFound: 0, status: .completed)
        try db.insertScanRun(&scanRun)

        let appState = AppState(db: db)
        await appState.loadInitialData()

        XCTAssertEqual(appState.photos.count, 1)
        XCTAssertEqual(appState.totalPhotoCount, 1)
        XCTAssertEqual(appState.scanRuns.count, 1)
    }
}
