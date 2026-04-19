import XCTest
@testable import Nostos
import CryptoKit

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

    func testOrganizeSkipsAlreadyCopied() async throws {
        let db = try AppDatabase.makeInMemory()

        var photo = Photo(id: nil,
                          path: "/tmp/nostos_already_copied.jpg",
                          hash: nil,
                          fileSize: 1,
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
                          status: .copied,
                          scannedAt: Date(),
                          scanRunId: nil)

        try db.insertPhoto(&photo)

        let tmpDest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_test_dest_already_copied")
        try? FileManager.default.removeItem(at: tmpDest)

        let organizer = Organizer(db: db) { _ in }
        let job = try await organizer.organize(destination: tmpDest, folderFormat: "YYYY/MM/DD", dryRun: false)

        XCTAssertEqual(job.totalFiles, 1)
        XCTAssertEqual(job.copiedFiles, 0)
        XCTAssertEqual(job.skippedFiles, 1)

        let results = try db.fetchOrganizeResults(jobId: job.id!)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].action, .skipExists)
        XCTAssertEqual(results[0].reason, "already copied")
    }

    func testOrganizeDetectsIdenticalDestinationAndRenameConflict() async throws {
        let db = try AppDatabase.makeInMemory()

        // create source file
        let srcDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_test_src2")
        try? FileManager.default.removeItem(at: srcDir)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        let srcFile = srcDir.appendingPathComponent("photo2.jpg")
        try "same".data(using: .utf8)!.write(to: srcFile)

        // destination root
        let tmpDest = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_test_dest_conflict")
        try? FileManager.default.removeItem(at: tmpDest)

        // compute folder like Organizer.formatFolder would
        let taken = Date()
        let cal = Calendar.current
        let year  = String(cal.component(.year,  from: taken))
        let month = String(format: "%02d", cal.component(.month, from: taken))
        let day   = String(format: "%02d", cal.component(.day,   from: taken))
        let folder = "YYYY/MM/DD".replacingOccurrences(of: "YYYY", with: year).replacingOccurrences(of: "MM", with: month).replacingOccurrences(of: "DD", with: day)

        let destDir = tmpDest.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        // create an existing file with identical contents
        let existing = destDir.appendingPathComponent(srcFile.lastPathComponent)
        try "same".data(using: .utf8)!.write(to: existing)

        // compute sha256 for the source/destination file
        func sha256Hex(of url: URL) throws -> String {
            let data = try Data(contentsOf: url)
            let digest = SHA256.hash(data: data)
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        }

        var photo1 = Photo(id: nil,
                           path: srcFile.path,
                           hash: try sha256Hex(of: srcFile),
                           fileSize: 4,
                           width: nil,
                           height: nil,
                           takenAt: taken,
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

        try db.insertPhoto(&photo1)

        // second photo that will conflict (same filename) but with different content
        let srcDir2 = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_test_src2b")
        try? FileManager.default.removeItem(at: srcDir2)
        try FileManager.default.createDirectory(at: srcDir2, withIntermediateDirectories: true)
        let srcFile2 = srcDir2.appendingPathComponent("photo2.jpg")
        try "other".data(using: .utf8)!.write(to: srcFile2)
        var photo2 = Photo(id: nil,
                           path: srcFile2.path,
                           hash: nil,
                           fileSize: 5,
                           width: nil,
                           height: nil,
                           takenAt: taken,
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

        try db.insertPhoto(&photo2)

        let organizer = Organizer(db: db) { _ in }
        let job = try await organizer.organize(destination: tmpDest, folderFormat: "YYYY/MM/DD", dryRun: false)

        XCTAssertEqual(job.totalFiles, 2)
        // photo1 should be skipped because identical exists, photo2 should trigger renameConflict
        XCTAssertEqual(job.skippedFiles, 2)

        let results = try db.fetchOrganizeResults(jobId: job.id!)
        XCTAssertEqual(results.count, 2)

        // find the result for photo1 (identical)
        let r1 = results.first { $0.photoId == photo1.id }
        XCTAssertEqual(r1?.action, .skipExists)
        XCTAssertEqual(r1?.reason, "identical file exists")

        // find the result for photo2 (rename)
        let r2 = results.first { $0.photoId == photo2.id }
        XCTAssertEqual(r2?.action, .renameConflict)
        XCTAssertTrue(r2?.destination?.contains("_1.") ?? false)

        // cleanup
        try? FileManager.default.removeItem(at: tmpDest)
        try? FileManager.default.removeItem(at: srcDir)
        try? FileManager.default.removeItem(at: srcDir2)
    }
}
