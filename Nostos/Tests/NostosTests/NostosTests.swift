import XCTest
import AppKit
import ImageIO
import CoreGraphics
import ViewInspector
@testable import Nostos

final class NostosTests: XCTestCase {
    private var db: AppDatabase!

    override func setUpWithError() throws {
        db = try AppDatabase.makeInMemory()
    }

    func testDuplicateDetectorGroupsHashAndExifDuplicates() throws {
        let now = Date()

        var photo1 = makePhoto(
            path: "/tmp/photo1.jpg",
            hash: "hash1",
            takenAt: now,
            cameraModel: "Canon"
        )
        var photo2 = makePhoto(
            path: "/tmp/photo2.jpg",
            hash: "hash1",
            takenAt: now.addingTimeInterval(60),
            cameraModel: "Nikon"
        )
        var photo3 = makePhoto(
            path: "/tmp/photo3.jpg",
            hash: "hash2",
            takenAt: now,
            cameraModel: "Sony"
        )
        var photo4 = makePhoto(
            path: "/tmp/photo4.jpg",
            hash: "hash3",
            takenAt: now,
            cameraModel: "Sony"
        )

        try db.insertPhoto(&photo1)
        try db.insertPhoto(&photo2)
        try db.insertPhoto(&photo3)
        try db.insertPhoto(&photo4)

        let detector = DuplicateDetector(db: db)
        let createdGroups = try detector.detect()

        XCTAssertEqual(createdGroups, 2)

        let groups = try db.fetchDuplicateGroupsWithPhotos()
        XCTAssertEqual(groups.count, 2)

        XCTAssertTrue(groups.contains { groupWithPhotos in
            groupWithPhotos.group.reason == .hashMatch &&
            groupWithPhotos.photos.map(\.path).contains("/tmp/photo1.jpg") &&
            groupWithPhotos.photos.map(\.path).contains("/tmp/photo2.jpg")
        })

        XCTAssertTrue(groups.contains { groupWithPhotos in
            groupWithPhotos.group.reason == .exifMatch &&
            groupWithPhotos.photos.map(\.path).contains("/tmp/photo3.jpg") &&
            groupWithPhotos.photos.map(\.path).contains("/tmp/photo4.jpg")
        })
    }

    func testAppDatabasePhotoFiltersAndDistinctCameraModels() async throws {
        let date1 = Date(timeIntervalSince1970: 1_700_000_000)
        let date2 = date1.addingTimeInterval(86400)

        var photoA = makePhoto(
            path: "/tmp/a.jpg",
            hash: "h1",
            takenAt: date1,
            cameraModel: "Canon",
            status: .new
        )
        var photoB = makePhoto(
            path: "/tmp/b.jpg",
            hash: "h2",
            takenAt: date2,
            cameraModel: "Nikon",
            status: .copied
        )
        var group = DuplicateGroup(reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)

        var photoC = makePhoto(
            path: "/tmp/c.jpg",
            hash: "h3",
            takenAt: date2,
            cameraModel: "Canon",
            duplicateGroupId: group.id,
            status: .new
        )

        try db.insertPhoto(&photoA)
        try db.insertPhoto(&photoB)
        try db.insertPhoto(&photoC)

        let newPhotos = try db.fetchPhotos(filter: PhotoFilter(status: .new))
        XCTAssertEqual(newPhotos.count, 2)

        let nikonPhotos = try db.fetchPhotos(filter: PhotoFilter(cameraModel: "Nikon"))
        XCTAssertEqual(nikonPhotos.count, 1)
        XCTAssertEqual(nikonPhotos.first?.path, "/tmp/b.jpg")

        let dateRangePhotos = try db.fetchPhotos(filter: PhotoFilter(dateFrom: date1, dateTo: date1))
        XCTAssertEqual(dateRangePhotos.count, 1)

        let duplicated = try db.fetchPhotos(filter: PhotoFilter(hasDuplicates: true))
        XCTAssertEqual(duplicated.count, 1)

        let nonDuplicated = try db.fetchPhotos(filter: PhotoFilter(hasDuplicates: false))
        XCTAssertEqual(nonDuplicated.count, 2)

        let models = try db.fetchDistinctCameraModels()
        XCTAssertEqual(models, ["Canon", "Nikon"])
    }

    func testAppDatabaseSetKeptPhotoUpdatesGroupAndPhotos() async throws {
        var group = DuplicateGroup(reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)

        var firstPhoto = makePhoto(
            path: "/tmp/keep.jpg",
            hash: "h1",
            takenAt: Date(),
            cameraModel: "Canon",
            duplicateGroupId: group.id,
            isKept: false
        )
        var secondPhoto = makePhoto(
            path: "/tmp/skip.jpg",
            hash: "h1",
            takenAt: Date(),
            cameraModel: "Canon",
            duplicateGroupId: group.id,
            isKept: false
        )

        try db.insertPhoto(&firstPhoto)
        try db.insertPhoto(&secondPhoto)

        let groupId = group.id!
        let firstPhotoId = firstPhoto.id!
        let secondPhotoId = secondPhoto.id!

        try db.setKeptPhoto(groupId: groupId, photoId: firstPhotoId)

        let reloadedGroup = try await db.dbWriter.read { db in
            try DuplicateGroup.fetchOne(db, key: groupId)
        }
        XCTAssertEqual(reloadedGroup?.keptPhotoId, firstPhotoId)

        let reloadedFirst = try await db.dbWriter.read { db in
            try Photo.fetchOne(db, key: firstPhotoId)
        }
        let reloadedSecond = try await db.dbWriter.read { db in
            try Photo.fetchOne(db, key: secondPhotoId)
        }

        XCTAssertEqual(reloadedFirst?.isKept, true)
        XCTAssertEqual(reloadedSecond?.isKept, false)
    }

    func testEXIFReaderReadsMetadataFromImage() throws {
        let tempDir = try createTempDirectory()
        let imageURL = tempDir.appendingPathComponent("exif.jpg")

        let metadata: [String: Any] = [
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2024:01:02 03:04:05",
                kCGImagePropertyExifDateTimeDigitized as String: "2024:01:02 03:04:05"
            ],
            kCGImagePropertyTIFFDictionary as String: [
                kCGImagePropertyTIFFMake as String: "Canon",
                kCGImagePropertyTIFFModel as String: "EOS",
                kCGImagePropertyTIFFDateTime as String: "2024:01:02 03:04:05"
            ],
            kCGImagePropertyGPSDictionary as String: [
                kCGImagePropertyGPSLatitude as String: 12.34,
                kCGImagePropertyGPSLatitudeRef as String: "N",
                kCGImagePropertyGPSLongitude as String: 56.78,
                kCGImagePropertyGPSLongitudeRef as String: "E"
            ]
        ]

        try createJPEGFile(at: imageURL, metadata: metadata)

        let data = EXIFReader.read(from: imageURL)

        XCTAssertEqual(data.cameraMake, "Canon")
        XCTAssertEqual(data.cameraModel, "EOS")
        XCTAssertEqual(data.gpsLat, 12.34)
        XCTAssertEqual(data.gpsLon, 56.78)
        XCTAssertEqual(data.width, 16)
        XCTAssertEqual(data.height, 16)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(data.takenAt, formatter.date(from: "2024:01:02 03:04:05"))
    }

    func testThumbnailServiceGeneratesAndLoadsCachedThumbnail() throws {
        let tempDir = try createTempDirectory()
        let sourceURL = tempDir.appendingPathComponent("thumb.jpg")
        try createJPEGFile(at: sourceURL, metadata: nil)

        let thumbnailPath = ThumbnailService.thumbnail(for: 42, sourceURL: sourceURL)
        XCTAssertNotNil(thumbnailPath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailPath!))

        let image = ThumbnailService.loadImage(path: thumbnailPath!)
        XCTAssertNotNil(image)

        let cachedPath = ThumbnailService.thumbnail(for: 42, sourceURL: sourceURL)
        XCTAssertEqual(cachedPath, thumbnailPath)
    }

    func testScannerScanInsertsPhotosAndGeneratesThumbnails() async throws {
        let sourceDir = try createTempDirectory()
        let sourceURL = sourceDir.appendingPathComponent("scan.jpg")
        try createJPEGFile(at: sourceURL, metadata: nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))

        let supportedExtensions: Set<String> = [
            "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif",
            "cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2", "pef"
        ]
        let fm = FileManager.default
        let enumerator = fm.enumerator(
            at: sourceDir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        var foundPaths: [URL] = []
        if let enumerator = enumerator {
            while let url = enumerator.nextObject() as? URL {
                if let attrs = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                   attrs.isRegularFile == true,
                   supportedExtensions.contains(url.pathExtension.lowercased()) {
                    foundPaths.append(url)
                }
            }
        }
        XCTAssertEqual(foundPaths.count, 1)

        let lastProgressBox = ActorBox(ScanProgress())
        let scanner = Scanner(db: db) { progress in
            await lastProgressBox.set(progress)
        }

        let run = try await scanner.scan(rootURL: sourceDir)

        XCTAssertEqual(run.status, .completed)
        XCTAssertEqual(run.photosFound, 1)
        XCTAssertEqual(run.duplicatesFound, 0)
        let lastProgress = await lastProgressBox.value
        XCTAssertFalse(lastProgress.isScanning)
        XCTAssertEqual(lastProgress.processed, 1)

    }

    @MainActor
    func testAppStateLoadsAndAppliesFilterAndSetKeptPhoto() async throws {
        let state = AppState(db: db)

        var scanRun = ScanRun(
            rootPath: "/tmp",
            startedAt: Date(),
            photosFound: 0,
            duplicatesFound: 0,
            status: .running
        )
        try db.insertScanRun(&scanRun)

        var group = DuplicateGroup(reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)

        var photo1 = makePhoto(
            path: "/tmp/a.jpg",
            hash: "h1",
            takenAt: Date(),
            cameraModel: "Canon",
            duplicateGroupId: group.id,
            isKept: false
        )
        var photo2 = makePhoto(
            path: "/tmp/b.jpg",
            hash: "h2",
            takenAt: Date(),
            cameraModel: "Nikon",
            duplicateGroupId: group.id,
            isKept: false
        )
        try db.insertPhoto(&photo1)
        try db.insertPhoto(&photo2)

        var job = OrganizeJob(
            destinationRoot: "/tmp/dest",
            folderFormat: "YYYY/MM/DD",
            dryRun: true,
            startedAt: Date(),
            status: .running,
            totalFiles: 0,
            copiedFiles: 0,
            skippedFiles: 0
        )
        try db.insertOrganizeJob(&job)

        await state.loadInitialData()

        let scanRunsCount = await state.scanRuns.count
        let photosCount = await state.photos.count
        let cameraModels = await state.cameraModels
        let duplicateGroupsCount = await state.duplicateGroups.count
        let organizeJobsCount = await state.organizeJobs.count

        XCTAssertEqual(scanRunsCount, 1)
        XCTAssertEqual(photosCount, 2)
        XCTAssertEqual(cameraModels, ["Canon", "Nikon"])
        XCTAssertEqual(duplicateGroupsCount, 1)
        XCTAssertEqual(organizeJobsCount, 1)

        await state.applyFilter(PhotoFilter(status: .new))
        try await Task.sleep(nanoseconds: 100_000_000)
        let photoFilterStatus = await state.photoFilter.status
        XCTAssertEqual(photoFilterStatus, .new)

        let groupId = group.id!
        let photo1Id = photo1.id!
        await state.setKeptPhoto(groupId: groupId, photoId: photo1Id)
        try await Task.sleep(nanoseconds: 100_000_000)
        let keptPhotoId = await state.duplicateGroups.first?.group.keptPhotoId
        XCTAssertEqual(keptPhotoId, photo1Id)
    }

    func testDuplicateDetectorSkipsAlreadyGroupedAndIncompleteExifPhotos() throws {
        let now = Date()
        var group = DuplicateGroup(reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)
        var photo1 = makePhoto(
            path: "/tmp/skip1.jpg",
            hash: nil,
            takenAt: now,
            cameraModel: "Canon",
            duplicateGroupId: group.id
        )
        var photo2 = makePhoto(
            path: "/tmp/skip2.jpg",
            hash: "h1",
            takenAt: nil,
            cameraModel: nil
        )

        try db.insertPhoto(&photo1)
        try db.insertPhoto(&photo2)

        let detector = DuplicateDetector(db: db)
        let createdGroups = try detector.detect()

        XCTAssertEqual(createdGroups, 0)
        let groups = try db.fetchDuplicateGroupsWithPhotos()
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.photos.count, 1)
    }

    @MainActor
    func testViewInspectorCoversDuplicateAndGalleryViews() throws {
        let state = AppState(db: db)
        let duplicatesView = DuplicatesView().environmentObject(state)
        XCTAssertNoThrow(try duplicatesView.inspect().find(text: "No Duplicates Found"))

        let galleryView = GalleryView().environmentObject(state)
        XCTAssertNoThrow(try galleryView.inspect().find(text: "No Photos"))
    }

    @MainActor
    func testOrganizerViewButtonIsDisabledWhenNoDestination() throws {
        let state = AppState(db: db)
        let view = OrganizerView().environmentObject(state)
        let button = try view.inspect().find(ViewType.Button.self)
        XCTAssertTrue(try button.isDisabled())
        XCTAssertNoThrow(try button.labelView().find(text: "Preview"))
    }

    @MainActor
    func testScannerViewButtonIsDisabledWhenNoSelectedPath() throws {
        let state = AppState(db: db)
        let view = ScannerView().environmentObject(state)
        let button = try view.inspect().find(ViewType.Button.self)
        XCTAssertTrue(try button.isDisabled())
        XCTAssertNoThrow(try button.labelView().find(text: "Start Scan"))
    }

    // MARK: - Helpers

    private func makePhoto(
        path: String,
        hash: String? = nil,
        takenAt: Date? = nil,
        cameraModel: String? = nil,
        duplicateGroupId: Int64? = nil,
        isKept: Bool = true,
        status: PhotoStatus = .new,
        scannedAt: Date = Date()
    ) -> Photo {
        Photo(
            id: nil,
            path: path,
            hash: hash,
            fileSize: 1,
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
            status: status,
            scannedAt: scannedAt,
            scanRunId: nil
        )
    }

    private func createTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func createJPEGFile(at url: URL, metadata: [String: Any]?) throws {
        let width = 16
        let height = 16
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }

        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = context.makeImage() else {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }

        var properties: [String: Any] = [
            kCGImagePropertyPixelWidth as String: width,
            kCGImagePropertyPixelHeight as String: height,
        ]
        if let metadata = metadata {
            properties.merge(metadata) { current, _ in current }
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "Test", code: 1, userInfo: nil)
        }
    }
}

actor ActorBox<Value> {
    private var boxed: Value

    init(_ value: Value) {
        self.boxed = value
    }

    func set(_ value: Value) {
        boxed = value
    }

    var value: Value {
        boxed
    }
}

