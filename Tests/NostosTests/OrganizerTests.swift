import XCTest
@testable import Nostos

final class OrganizerTests: XCTestCase {

    actor ProgressCollector {
        var progresses: [OrganizeProgress] = []
        func append(_ p: OrganizeProgress) { progresses.append(p) }
        func count() -> Int { progresses.count }
    }

    func testOrganizeDryRunCountsCopiedAndSkipped() async throws {
        let db = try AppDatabase.makeInMemory()

        // Photo that should be copied
        var p1 = Photo(id: nil,
                       path: "/tmp/org/src1.jpg",
                       hash: nil,
                       fileSize: 10,
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

        // Photo that should be skipped because not kept duplicate
        var p2 = Photo(id: nil,
                   path: "/tmp/org/src2.jpg",
                   hash: nil,
                   fileSize: 20,
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

        // insert a duplicate group and attach p2 to it (but not kept)
        var group = DuplicateGroup(id: nil, reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)
        p2.duplicateGroupId = group.id

        try db.insertPhoto(&p1)
        try db.insertPhoto(&p2)

        let collector = ProgressCollector()
        let tmpDest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_test_dest_dryrun")
        try? FileManager.default.removeItem(at: tmpDest)

        let organizer = Organizer(db: db) { progress in
            Task { await collector.append(progress) }
        }

        let job = try await organizer.organize(destination: tmpDest, folderFormat: "YYYY/MM/DD", dryRun: true)

        XCTAssertEqual(job.totalFiles, 2)
        XCTAssertEqual(job.copiedFiles, 1)
        XCTAssertEqual(job.skippedFiles, 1)

        let results = try db.fetchOrganizeResults(jobId: job.id!)
        XCTAssertEqual(results.count, 2)

        // progress updates were emitted (at least start and end)
        let progressCount = await collector.count()
        XCTAssertGreaterThanOrEqual(progressCount, 2)
    }

    func testOrganizePerformsCopyAndUpdatesPhotoStatus() async throws {
        let db = try AppDatabase.makeInMemory()

        // Create a temporary source file
        let srcDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_test_src")
        try? FileManager.default.removeItem(at: srcDir)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)

        let srcFile = srcDir.appendingPathComponent("photo.jpg")
        try "hello".data(using: .utf8)!.write(to: srcFile)

        var photo = Photo(id: nil,
                          path: srcFile.path,
                          hash: nil,
                          fileSize: 5,
                          width: nil,
                          height: nil,
                          takenAt: Date(),
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

        try db.insertPhoto(&photo)

        let tmpDest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_test_dest_copy")
        try? FileManager.default.removeItem(at: tmpDest)

        let organizer = Organizer(db: db) { _ in }
        let job = try await organizer.organize(destination: tmpDest, folderFormat: "YYYY/MM/DD", dryRun: false)

        XCTAssertEqual(job.totalFiles, 1)
        XCTAssertEqual(job.copiedFiles, 1)
        XCTAssertEqual(job.skippedFiles, 0)

        let results = try db.fetchOrganizeResults(jobId: job.id!)
        XCTAssertEqual(results.count, 1)

        let res = results[0]
        XCTAssertEqual(res.action, .copy)
        XCTAssertNotNil(res.destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: res.destination!))

        let fetched = try db.fetchPhoto(id: photo.id!)
        XCTAssertEqual(fetched?.status, .copied)

        // cleanup
        try? FileManager.default.removeItem(at: tmpDest)
        try? FileManager.default.removeItem(at: srcDir)
    }
}
