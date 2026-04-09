import XCTest
@testable import Nostos

final class DuplicateDetectorTests: XCTestCase {

    func testDetectHashDuplicates() throws {
        let db = try AppDatabase.makeInMemory()

        var p1 = Photo(id: nil,
                       path: "/tmp/dup/hash1.jpg",
                       hash: "h1",
                       fileSize: 100,
                       width: nil,
                       height: nil,
                       takenAt: nil,
                       cameraMake: nil,
                       cameraModel: nil,
                       gpsLat: nil,
                       gpsLon: nil,
                       thumbnailPath: nil,
                       duplicateGroupId: nil,
                       isKept: false,
                       status: .new,
                       scannedAt: Date(),
                       scanRunId: nil)

        var p2 = Photo(id: nil,
                       path: "/tmp/dup/hash2.jpg",
                       hash: "h1",
                       fileSize: 120,
                       width: nil,
                       height: nil,
                       takenAt: nil,
                       cameraMake: nil,
                       cameraModel: nil,
                       gpsLat: nil,
                       gpsLon: nil,
                       thumbnailPath: nil,
                       duplicateGroupId: nil,
                       isKept: false,
                       status: .new,
                       scannedAt: Date(),
                       scanRunId: nil)

        try db.insertPhoto(&p1)
        try db.insertPhoto(&p2)

        let detector = DuplicateDetector(db: db)
        let created = try detector.detect()

        XCTAssertEqual(created, 1)

        let groups = try db.fetchDuplicateGroupsWithPhotos()
        XCTAssertEqual(groups.count, 1)
        let group = groups[0]
        XCTAssertEqual(group.group.reason, .hashMatch)
        XCTAssertEqual(group.photos.count, 2)
        // one should be marked kept
        XCTAssertTrue(group.photos.contains(where: { $0.isKept }))
    }

    func testDetectExifDuplicates() throws {
        let db = try AppDatabase.makeInMemory()
        let now = Date()

        var p1 = Photo(id: nil,
                       path: "/tmp/dup/exif1.jpg",
                       hash: nil,
                       fileSize: 200,
                       width: nil,
                       height: nil,
                       takenAt: now,
                       cameraMake: "Make",
                       cameraModel: "ModelX",
                       gpsLat: nil,
                       gpsLon: nil,
                       thumbnailPath: nil,
                       duplicateGroupId: nil,
                       isKept: false,
                       status: .new,
                       scannedAt: Date(),
                       scanRunId: nil)

        var p2 = Photo(id: nil,
                       path: "/tmp/dup/exif2.jpg",
                       hash: nil,
                       fileSize: 210,
                       width: nil,
                       height: nil,
                       takenAt: now,
                       cameraMake: "Make",
                       cameraModel: "ModelX",
                       gpsLat: nil,
                       gpsLon: nil,
                       thumbnailPath: nil,
                       duplicateGroupId: nil,
                       isKept: false,
                       status: .new,
                       scannedAt: Date(),
                       scanRunId: nil)

        try db.insertPhoto(&p1)
        try db.insertPhoto(&p2)

        let detector = DuplicateDetector(db: db)
        let created = try detector.detect()

        XCTAssertEqual(created, 1)

        let groups = try db.fetchDuplicateGroupsWithPhotos()
        XCTAssertEqual(groups.count, 1)
        let group = groups[0]
        XCTAssertEqual(group.group.reason, .exifMatch)
        XCTAssertEqual(group.photos.count, 2)
    }
}
