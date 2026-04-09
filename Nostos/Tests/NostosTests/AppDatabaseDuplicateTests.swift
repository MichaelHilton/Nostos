import XCTest
@testable import Nostos

final class AppDatabaseDuplicateTests: XCTestCase {

    func testFetchDuplicateGroupsWithPhotosOrdering() throws {
        let db = try AppDatabase.makeInMemory()

        var run = ScanRun(id: nil,
                          rootPath: "/tmp/dups",
                          startedAt: Date(),
                          finishedAt: nil,
                          photosFound: 0,
                          duplicatesFound: 0,
                          status: .running)
        try db.insertScanRun(&run)

        var group = DuplicateGroup(id: nil, reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)
        XCTAssertNotNil(group.id)

        // Insert two photos with different takenAt dates
        let older = Date(timeIntervalSince1970: 1_600_000_000)
        let newer = Date(timeIntervalSince1970: 1_700_000_000)

        var p1 = Photo(id: nil,
                       path: "/tmp/dups/old.jpg",
                       hash: "h1",
                       fileSize: 100,
                       width: 10,
                       height: 10,
                       takenAt: older,
                       cameraMake: nil,
                       cameraModel: nil,
                       gpsLat: nil,
                       gpsLon: nil,
                       thumbnailPath: nil,
                       duplicateGroupId: group.id,
                       isKept: false,
                       status: .new,
                       scannedAt: Date(),
                       scanRunId: run.id)

        var p2 = Photo(id: nil,
                       path: "/tmp/dups/new.jpg",
                       hash: "h2",
                       fileSize: 200,
                       width: 20,
                       height: 20,
                       takenAt: newer,
                       cameraMake: nil,
                       cameraModel: nil,
                       gpsLat: nil,
                       gpsLon: nil,
                       thumbnailPath: nil,
                       duplicateGroupId: group.id,
                       isKept: false,
                       status: .new,
                       scannedAt: Date(),
                       scanRunId: run.id)

        try db.insertPhoto(&p1)
        try db.insertPhoto(&p2)

        let groups = try db.fetchDuplicateGroupsWithPhotos()
        guard let found = groups.first(where: { $0.group.id == group.id }) else {
            XCTFail("Expected duplicate group to be returned")
            return
        }

        XCTAssertEqual(found.photos.count, 2)
        // photos are ordered ascending by taken_at
        XCTAssertLessThanOrEqual(found.photos[0].takenAt ?? Date.distantPast,
                                 found.photos[1].takenAt ?? Date.distantFuture)
    }

    func testSetKeptPhotoUpdatesGroupAndPhotos() throws {
        let db = try AppDatabase.makeInMemory()

        var run = ScanRun(id: nil,
                          rootPath: "/tmp/dups",
                          startedAt: Date(),
                          finishedAt: nil,
                          photosFound: 0,
                          duplicatesFound: 0,
                          status: .running)
        try db.insertScanRun(&run)

        var group = DuplicateGroup(id: nil, reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)

        var p1 = Photo(id: nil,
                       path: "/tmp/dups/a.jpg",
                       hash: "ha",
                       fileSize: 10,
                       width: nil,
                       height: nil,
                       takenAt: nil,
                       cameraMake: nil,
                       cameraModel: nil,
                       gpsLat: nil,
                       gpsLon: nil,
                       thumbnailPath: nil,
                       duplicateGroupId: group.id,
                       isKept: false,
                       status: .new,
                       scannedAt: Date(),
                       scanRunId: run.id)

        var p2 = Photo(id: nil,
                       path: "/tmp/dups/b.jpg",
                       hash: "hb",
                       fileSize: 20,
                       width: nil,
                       height: nil,
                       takenAt: nil,
                       cameraMake: nil,
                       cameraModel: nil,
                       gpsLat: nil,
                       gpsLon: nil,
                       thumbnailPath: nil,
                       duplicateGroupId: group.id,
                       isKept: false,
                       status: .new,
                       scannedAt: Date(),
                       scanRunId: run.id)

        try db.insertPhoto(&p1)
        try db.insertPhoto(&p2)

        // Set p2 as kept
        try db.setKeptPhoto(groupId: group.id!, photoId: p2.id!)

        // Re-fetch groups to observe updates
        let groups = try db.fetchDuplicateGroupsWithPhotos()
        guard let found = groups.first(where: { $0.group.id == group.id }) else {
            XCTFail("Expected duplicate group to be returned")
            return
        }

        XCTAssertEqual(found.group.keptPhotoId, p2.id)
        // Ensure only the chosen photo has isKept == true
        let kept = found.photos.filter { $0.isKept }
        XCTAssertEqual(kept.count, 1)
        XCTAssertEqual(kept.first?.id, p2.id)
    }
}
