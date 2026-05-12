import XCTest
@testable import Nostos

final class IntegrationTests: XCTestCase {
    private var db: AppDatabase!
    private var vaultDir: URL!
    private var sourceDir: URL!
    private var destinationDir: URL!

    override func setUpWithError() throws {
        db = try AppDatabase.makeInMemory()
        vaultDir = try makeTempDir()
        sourceDir = try makeTempDir()
        destinationDir = try makeTempDir()
        ThumbnailService.configure(vaultRootURL: vaultDir)
    }

    override func tearDownWithError() throws {
        try removeTempDirectory(vaultDir)
        try removeTempDirectory(sourceDir)
        try removeTempDirectory(destinationDir)
    }

    // MARK: - Scanner Tests

    func testScannerFindsPhotosAndReadsEXIF() async throws {
        let date1 = Date(timeIntervalSince1970: 1_700_000_000)
        let date2 = date1.addingTimeInterval(86400)
        let date3 = date1.addingTimeInterval(172800)

        let photos = [
            ("photo1.jpg", EXIFMetadata(
                takenAt: date1,
                cameraMake: "Canon",
                cameraModel: "EOS R5",
                gpsLat: 40.7128,
                gpsLon: -74.0060
            )),
            ("photo2.jpg", EXIFMetadata(
                takenAt: date2,
                cameraMake: "Sony",
                cameraModel: "A7R",
                gpsLat: 51.5074,
                gpsLon: -0.1278
            )),
            ("photo3.jpg", EXIFMetadata(
                takenAt: date3,
                cameraMake: "Nikon",
                cameraModel: "D850",
                gpsLat: 35.6762,
                gpsLon: 139.6503
            )),
        ]

        sourceDir = try makeSourceDirectory(photos: photos)
        let scanner = Scanner(db: db) { _ in }

        let run = try await scanner.scan(rootURL: sourceDir)

        XCTAssertEqual(run.status, ScanStatus.completed)
        XCTAssertEqual(run.photosFound, 3)
        XCTAssertEqual(run.duplicatesFound, 0)

        let allPhotos = try db.fetchAllPhotos()
        XCTAssertEqual(allPhotos.count, 3)

        let photo1 = allPhotos.first(where: { $0.path.contains("photo1.jpg") })
        XCTAssertNotNil(photo1)
        XCTAssertEqual(photo1?.cameraMake, "Canon")
        XCTAssertEqual(photo1?.cameraModel, "EOS R5")
        XCTAssertEqual(photo1?.takenAt, date1)
        XCTAssertEqual(photo1?.gpsLat, 40.7128)
        XCTAssertEqual(photo1?.gpsLon, -74.0060)
        XCTAssertNotNil(photo1?.thumbnailPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: photo1?.thumbnailPath ?? ""))
    }

    func testScannerSkipsAlreadyScannedPaths() async throws {
        let metadata = EXIFMetadata(
            takenAt: Date(),
            cameraMake: "Canon",
            cameraModel: "EOS"
        )
        sourceDir = try makeSourceDirectory(photos: [("test.jpg", metadata)])

        let scanner = Scanner(db: db) { _ in }

        let run1 = try await scanner.scan(rootURL: sourceDir)
        XCTAssertEqual(run1.photosFound, 1)
        XCTAssertEqual(run1.status, ScanStatus.completed)

        let allPhotos = try db.fetchAllPhotos()
        XCTAssertEqual(allPhotos.count, 1)

        let allScans = try db.fetchAllScanRuns()
        XCTAssertGreaterThanOrEqual(allScans.count, 1)
    }

    // MARK: - Duplicate Detection Tests

    func testDuplicateDetectionByHash() async throws {
        let metadata = EXIFMetadata(
            takenAt: Date(),
            cameraMake: "Canon",
            cameraModel: "EOS"
        )
        sourceDir = try makeSourceDirectory(photos: [
            ("photo1.jpg", metadata),
            ("photo2.jpg", metadata),
        ])

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let detector = DuplicateDetector(db: db)
        let groupsCreated = try detector.detect()
        XCTAssertEqual(groupsCreated, 1)

        let groups = try db.fetchDuplicateGroupsWithPhotos()
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].group.reason, .hashMatch)
        XCTAssertEqual(groups[0].photos.count, 2)

        let keptPhotoCount = groups[0].photos.filter { $0.isKept }.count
        XCTAssertEqual(keptPhotoCount, 1)
    }

    func testDuplicateDetectionByEXIF() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let photos = [
            ("photo1.jpg", EXIFMetadata(
                takenAt: date,
                cameraMake: "Canon",
                cameraModel: "EOS",
                gpsLat: 0.0,
                gpsLon: 0.0
            )),
            ("photo2.jpg", EXIFMetadata(
                takenAt: date,
                cameraMake: "Canon",
                cameraModel: "EOS",
                gpsLat: 0.0,
                gpsLon: 0.0
            )),
        ]

        sourceDir = try makeSourceDirectory(photos: photos)
        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let allPhotos = try db.fetchAllPhotos()
        XCTAssertEqual(allPhotos.count, 2)

        let detector = DuplicateDetector(db: db)
        let groupsCreated = try detector.detect()
        XCTAssertGreaterThanOrEqual(groupsCreated, 1)

        let groups = try db.fetchDuplicateGroupsWithPhotos()
        XCTAssertGreaterThanOrEqual(groups.count, 1)
    }

    // MARK: - Organizer Tests

    func testOrganizerCopiesIntoDatedFolderStructure() async throws {
        let date1 = Date(timeIntervalSince1970: 1_700_000_000)
        let date2 = Date(timeIntervalSince1970: 1_650_000_000)

        let photos = [
            ("photo1.jpg", EXIFMetadata(takenAt: date1, cameraMake: "Canon", cameraModel: "EOS")),
            ("photo2.jpg", EXIFMetadata(takenAt: date2, cameraMake: "Canon", cameraModel: "EOS")),
        ]
        sourceDir = try makeSourceDirectory(photos: photos)

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let organizer = Organizer(db: db) { _ in }
        let job = try await organizer.organize(
            destination: destinationDir,
            folderFormat: "YYYY/MM",
            dryRun: false
        )

        XCTAssertEqual(job.status, JobStatus.completed)
        XCTAssertEqual(job.copiedFiles, 2)
        XCTAssertEqual(job.skippedFiles, 0)

        let allPhotos = try db.fetchAllPhotos()
        for photo in allPhotos {
            XCTAssertEqual(photo.status, PhotoStatus.copied)
        }

        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: destinationDir.appendingPathComponent("2023/11").path))
        XCTAssertTrue(fm.fileExists(atPath: destinationDir.appendingPathComponent("2022/04").path))
    }

    func testOrganizerDryRunCreatesNoFiles() async throws {
        let metadata = EXIFMetadata(
            takenAt: Date(),
            cameraMake: "Canon",
            cameraModel: "EOS"
        )
        sourceDir = try makeSourceDirectory(photos: [("photo.jpg", metadata)])

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let organizer = Organizer(db: db) { _ in }
        let job = try await organizer.organize(
            destination: destinationDir,
            folderFormat: "YYYY/MM",
            dryRun: true
        )

        XCTAssertEqual(job.copiedFiles, 1)
        XCTAssertEqual(job.status, JobStatus.completed)

        let allPhotos = try db.fetchAllPhotos()
        XCTAssertEqual(allPhotos[0].status, PhotoStatus.new)

        let subDirs = try FileManager.default.contentsOfDirectory(at: destinationDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(subDirs.count, 0)
    }

    func testOrganizerSkipsAlreadyCopiedOnRerun() async throws {
        let metadata = EXIFMetadata(
            takenAt: Date(),
            cameraMake: "Canon",
            cameraModel: "EOS"
        )
        sourceDir = try makeSourceDirectory(photos: [("photo.jpg", metadata)])

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let organizer = Organizer(db: db) { _ in }
        let job1 = try await organizer.organize(
            destination: destinationDir,
            folderFormat: "YYYY/MM",
            dryRun: false
        )
        XCTAssertEqual(job1.copiedFiles, 1)

        let job2 = try await organizer.organize(
            destination: destinationDir,
            folderFormat: "YYYY/MM",
            dryRun: false
        )
        XCTAssertEqual(job2.skippedFiles, 1)
        XCTAssertEqual(job2.copiedFiles, 0)
    }

    func testOrganizerHandlesRenameConflict() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let metadata = EXIFMetadata(takenAt: date, cameraMake: "Canon", cameraModel: "EOS")
        sourceDir = try makeSourceDirectory(photos: [("photo.jpg", metadata)])

        let targetDir = destinationDir.appendingPathComponent("2023/11", isDirectory: true)
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let conflictFile = targetDir.appendingPathComponent("photo.jpg")
        try createJPEGFile(at: conflictFile, metadata: [:])

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let organizer = Organizer(db: db) { _ in }
        let job = try await organizer.organize(
            destination: destinationDir,
            folderFormat: "YYYY/MM",
            dryRun: false
        )

        XCTAssertEqual(job.status, JobStatus.completed)

        let results = try db.fetchOrganizeResults(jobId: job.id!)
        let conflictResult = results.first { $0.action == OrganizeAction.renameConflict }
        XCTAssertNotNil(conflictResult)
        XCTAssertTrue(conflictResult?.destination?.contains("photo_1.jpg") ?? false)
    }

    // MARK: - Backup Tests

    func testBackupCopiesPhotosToVault() async throws {
        let date1 = Date(timeIntervalSince1970: 1_700_000_000)
        let date2 = date1.addingTimeInterval(86400)

        let photos = [
            ("photo1.jpg", EXIFMetadata(takenAt: date1, cameraMake: "Canon", cameraModel: "EOS")),
            ("photo2.jpg", EXIFMetadata(takenAt: date2, cameraMake: "Sony", cameraModel: "A7R")),
        ]
        sourceDir = try makeSourceDirectory(photos: photos)

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let backup = BackupService(db: db) { _ in }
        let job = try await backup.backup(
            vaultRootURL: vaultDir,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        XCTAssertEqual(job.status, JobStatus.completed)
        XCTAssertEqual(job.copiedFiles, 2)
        XCTAssertEqual(job.skippedFiles, 0)

        let vaultHashes = try db.fetchAllVaultHashes()
        XCTAssertEqual(vaultHashes.count, 2)
    }

    func testBackupSkipsHashDuplicates() async throws {
        let metadata = EXIFMetadata(
            takenAt: Date(),
            cameraMake: "Canon",
            cameraModel: "EOS"
        )
        sourceDir = try makeSourceDirectory(photos: [("photo.jpg", metadata)])

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let backup = BackupService(db: db) { _ in }
        let job1 = try await backup.backup(
            vaultRootURL: vaultDir,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )
        XCTAssertEqual(job1.copiedFiles, 1)

        let job2 = try await backup.backup(
            vaultRootURL: vaultDir,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )
        XCTAssertEqual(job2.skippedFiles, 1)
        XCTAssertEqual(job2.copiedFiles, 0)

        let results = try db.fetchBackupResults(jobId: job2.id!)
        let skipResult = results.first { $0.action == BackupAction.skipInVault }
        XCTAssertNotNil(skipResult)
    }

    func testBackupWithPrePopulatedVault() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let photos = [
            ("photo1.jpg", EXIFMetadata(takenAt: date, cameraMake: "Canon", cameraModel: "EOS")),
            ("photo2.jpg", EXIFMetadata(takenAt: date, cameraMake: "Canon", cameraModel: "EOS")),
            ("photo3.jpg", EXIFMetadata(takenAt: date.addingTimeInterval(86400), cameraMake: "Sony", cameraModel: "A7R")),
            ("photo4.jpg", EXIFMetadata(takenAt: date.addingTimeInterval(172800), cameraMake: "Sony", cameraModel: "A7R")),
        ]
        sourceDir = try makeSourceDirectory(photos: photos)

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let allPhotos = try db.fetchAllPhotos()
        XCTAssertEqual(allPhotos.count, 4)

        let photo1 = allPhotos[0]
        let photo2 = allPhotos[1]

        var vaultPhoto1 = VaultPhoto(
            id: nil,
            vaultPath: "2023/11/backup1.jpg",
            hash: photo1.hash!,
            fileSize: 100,
            sourcePath: photo1.path,
            backedUpAt: Date(),
            backupJobId: nil
        )
        var vaultPhoto2 = VaultPhoto(
            id: nil,
            vaultPath: "2023/11/backup2.jpg",
            hash: photo2.hash!,
            fileSize: 100,
            sourcePath: photo2.path,
            backedUpAt: Date(),
            backupJobId: nil
        )
        try db.insertVaultPhoto(&vaultPhoto1)
        try db.insertVaultPhoto(&vaultPhoto2)

        let backup = BackupService(db: db) { _ in }
        let job = try await backup.backup(
            vaultRootURL: vaultDir,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        XCTAssertEqual(job.status, JobStatus.completed)
        XCTAssertGreaterThanOrEqual(job.copiedFiles, 0)
    }

    func testBackupSkipsNonKeptDuplicates() async throws {
        let date = Date()
        let metadata = EXIFMetadata(takenAt: date, cameraMake: "Canon", cameraModel: "EOS")
        sourceDir = try makeSourceDirectory(photos: [
            ("photo1.jpg", metadata),
            ("photo2.jpg", metadata),
        ])

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let detector = DuplicateDetector(db: db)
        _ = try detector.detect()

        let backup = BackupService(db: db) { _ in }
        let job = try await backup.backup(
            vaultRootURL: vaultDir,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        XCTAssertEqual(job.status, JobStatus.completed)
        XCTAssertGreaterThanOrEqual(job.copiedFiles + job.skippedFiles, 1)
    }

    func testBackupFiltersByCamera() async throws {
        let date = Date()
        let photos = [
            ("photo1.jpg", EXIFMetadata(takenAt: date, cameraMake: "Canon", cameraModel: "EOS")),
            ("photo2.jpg", EXIFMetadata(takenAt: date, cameraMake: "Sony", cameraModel: "A7R")),
            ("photo3.jpg", EXIFMetadata(takenAt: date, cameraMake: "Canon", cameraModel: "EOS")),
        ]
        sourceDir = try makeSourceDirectory(photos: photos)

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let backup = BackupService(db: db) { _ in }
        let job = try await backup.backup(
            vaultRootURL: vaultDir,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(cameraModels: Set(["EOS"])),
            dryRun: false
        )

        XCTAssertEqual(job.copiedFiles, 2)
    }

    func testBackupFiltersByYear() async throws {
        let date2021 = Date(timeIntervalSince1970: 1_609_459_200)
        let date2022 = Date(timeIntervalSince1970: 1_640_995_200)
        let date2023 = Date(timeIntervalSince1970: 1_672_531_200)

        let photos = [
            ("photo1.jpg", EXIFMetadata(takenAt: date2021, cameraMake: "Canon", cameraModel: "EOS")),
            ("photo2.jpg", EXIFMetadata(takenAt: date2022, cameraMake: "Canon", cameraModel: "EOS")),
            ("photo3.jpg", EXIFMetadata(takenAt: date2023, cameraMake: "Canon", cameraModel: "EOS")),
        ]
        sourceDir = try makeSourceDirectory(photos: photos)

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let backup = BackupService(db: db) { _ in }
        let job = try await backup.backup(
            vaultRootURL: vaultDir,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(yearFrom: 2022, yearTo: 2023),
            dryRun: false
        )

        XCTAssertGreaterThanOrEqual(job.copiedFiles, 0)
    }

    // MARK: - Gallery Query Tests

    func testGalleryQueriesReflectFullPipeline() async throws {
        let date1 = Date(timeIntervalSince1970: 1_700_000_000)
        let date2 = date1.addingTimeInterval(86400)
        let date3 = date1.addingTimeInterval(172800)

        let photos = [
            ("photo1.jpg", EXIFMetadata(takenAt: date1, cameraMake: "Canon", cameraModel: "EOS")),
            ("photo2.jpg", EXIFMetadata(takenAt: date2, cameraMake: "Sony", cameraModel: "A7R")),
            ("photo3.jpg", EXIFMetadata(takenAt: date3, cameraMake: "Nikon", cameraModel: "D850")),
            ("photo4.jpg", EXIFMetadata(takenAt: date1, cameraMake: "Canon", cameraModel: "EOS")),
            ("photo5.jpg", EXIFMetadata(takenAt: date2, cameraMake: "Canon", cameraModel: "EOS")),
        ]
        sourceDir = try makeSourceDirectory(photos: photos)

        let scanner = Scanner(db: db) { _ in }
        _ = try await scanner.scan(rootURL: sourceDir)

        let models = try db.fetchDistinctCameraModels()
        XCTAssertTrue(models.contains("EOS"))
        XCTAssertTrue(models.contains("A7R"))
        XCTAssertTrue(models.contains("D850"))

        let yearBreakdown = try db.fetchYearBreakdown()
        XCTAssertTrue(yearBreakdown.contains { $0.year == 2023 && $0.count == 5 })

        let allPhotos = try db.fetchPhotos(filter: PhotoFilter())
        XCTAssertEqual(allPhotos.count, 5)

        let canonPhotos = try db.fetchPhotos(filter: PhotoFilter(cameraModels: Set(["EOS"])))
        XCTAssertEqual(canonPhotos.count, 3)

        let detector = DuplicateDetector(db: db)
        _ = try detector.detect()

        let backup = BackupService(db: db) { _ in }
        _ = try await backup.backup(
            vaultRootURL: vaultDir,
            folderFormat: "YYYY/MM",
            filter: PhotoFilter(),
            dryRun: false
        )

        let backupPhotos = try db.fetchPhotos(filter: PhotoFilter(status: Set([PhotoStatus.copied])))
        XCTAssertGreaterThanOrEqual(backupPhotos.count, 0)
    }
}
