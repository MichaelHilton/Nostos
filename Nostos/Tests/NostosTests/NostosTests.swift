import XCTest
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

    func testOrganizerDryRunSkipsNonKeptDuplicateAndCopiesNewPhoto() async throws {
        let sourceDir = try createTempDirectory()
        let destinationRoot = try createTempDirectory()

        let keptPhotoURL = sourceDir.appendingPathComponent("kept.jpg")
        let duplicatePhotoURL = sourceDir.appendingPathComponent("duplicate.jpg")
        try "kept".write(to: keptPhotoURL, atomically: true, encoding: .utf8)
        try "duplicate".write(to: duplicatePhotoURL, atomically: true, encoding: .utf8)

        var group = DuplicateGroup(reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)

        var keptPhoto = makePhoto(
            path: keptPhotoURL.path,
            hash: "h1",
            takenAt: Date(),
            cameraModel: "Canon",
            duplicateGroupId: group.id,
            isKept: true
        )
        var duplicatePhoto = makePhoto(
            path: duplicatePhotoURL.path,
            hash: "h1",
            takenAt: Date(),
            cameraModel: "Canon",
            duplicateGroupId: group.id,
            isKept: false
        )

        try db.insertPhoto(&keptPhoto)
        try db.insertPhoto(&duplicatePhoto)

        let organizer = Organizer(db: db, onProgress: { _ in })
        let job = try await organizer.organize(
            destination: destinationRoot,
            folderFormat: "YYYY/MM/DD",
            dryRun: true
        )

        XCTAssertEqual(job.totalFiles, 2)
        XCTAssertEqual(job.copiedFiles, 1)
        XCTAssertEqual(job.skippedFiles, 1)
        XCTAssertEqual(job.status, .completed)

        let results = try await db.dbWriter.read { db in
            try OrganizeResult.fetchAll(db)
        }

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first { $0.source == keptPhoto.path }?.action, .copy)
        XCTAssertEqual(results.first { $0.source == duplicatePhoto.path }?.action, .skipDuplicate)
    }

    func testOrganizerRenameConflictCreatesRenamedDestination() async throws {
        let sourceDir = try createTempDirectory()
        let destinationRoot = try createTempDirectory()

        let sourceFile = sourceDir.appendingPathComponent("photo.jpg")
        try "source".write(to: sourceFile, atomically: true, encoding: .utf8)

        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let folder = "YYYY/MM/DD"
        let expectedFolder = "2023/11/14"
        let destinationFolder = destinationRoot.appendingPathComponent(expectedFolder, isDirectory: true)
        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        let existingDestination = destinationFolder.appendingPathComponent("photo.jpg")
        try "existing".write(to: existingDestination, atomically: true, encoding: .utf8)

        var photo = makePhoto(
            path: sourceFile.path,
            hash: "sourcehash",
            takenAt: date,
            cameraModel: "Canon"
        )
        try db.insertPhoto(&photo)

        let organizer = Organizer(db: db, onProgress: { _ in })
        let job = try await organizer.organize(
            destination: destinationRoot,
            folderFormat: folder,
            dryRun: false
        )

        XCTAssertEqual(job.copiedFiles, 0)
        XCTAssertEqual(job.skippedFiles, 1)
        XCTAssertEqual(job.status, .completed)

        let results = try await db.dbWriter.read { db in
            try OrganizeResult.fetchAll(db)
        }

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].action, .renameConflict)
        XCTAssertEqual(results[0].destination, destinationFolder.appendingPathComponent("photo_1.jpg").path)
    }

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
}
