import XCTest
import CryptoKit
@testable import Nostos

final class OrganizerConflictTests: XCTestCase {

    func testOrganizeSkipsIdenticalDestination() async throws {
        let db = try AppDatabase.makeInMemory()

        // create a source file
        let srcDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_org_conf_src")
        try? FileManager.default.removeItem(at: srcDir)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        let srcFile = srcDir.appendingPathComponent("photo.jpg")
        try "identical".data(using: .utf8)!.write(to: srcFile)

        // create destination root and a file at the would-be destination
        let destRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_org_conf_dest")
        try? FileManager.default.removeItem(at: destRoot)
        try FileManager.default.createDirectory(at: destRoot, withIntermediateDirectories: true)
        let folder = "2026/01/01"
        let destDir = destRoot.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destFile = destDir.appendingPathComponent("photo.jpg")
        try "identical".data(using: .utf8)!.write(to: destFile)

        // compute hash for source and set on photo so Organizer considers them identical
        let hash = try XCTUnwrap(CryptoKit.SHA256.hash(data: Data("identical".utf8)).compactMap { String(format: "%02x", $0) }.joined())

        var photo = Photo(id: nil,
                          path: srcFile.path,
                          hash: hash,
                          fileSize: 9,
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

        let organizer = Organizer(db: db) { _ in }
        let job = try await organizer.organize(destination: destRoot, folderFormat: folder, dryRun: false)

        XCTAssertEqual(job.totalFiles, 1)
        XCTAssertEqual(job.copiedFiles, 0)
        XCTAssertEqual(job.skippedFiles, 1)

        let results = try db.fetchOrganizeResults(jobId: job.id!)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].action, .skipExists)
        XCTAssertEqual(results[0].destination, destFile.path)

        try? FileManager.default.removeItem(at: srcDir)
        try? FileManager.default.removeItem(at: destRoot)
    }

    func testOrganizeRenamesOnConflict() async throws {
        let db = try AppDatabase.makeInMemory()

        // create a source file
        let srcDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_org_conf_src2")
        try? FileManager.default.removeItem(at: srcDir)
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        let srcFile = srcDir.appendingPathComponent("photo.jpg")
        try "original".data(using: .utf8)!.write(to: srcFile)

        // create destination file with different contents to force rename
        let destRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_org_conf_dest2")
        try? FileManager.default.removeItem(at: destRoot)
        try FileManager.default.createDirectory(at: destRoot, withIntermediateDirectories: true)
        let folder = "2026/01/01"
        let destDir = destRoot.appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let destFile = destDir.appendingPathComponent("photo.jpg")
        try "different".data(using: .utf8)!.write(to: destFile)

        var photo = Photo(id: nil,
                          path: srcFile.path,
                          hash: nil,
                          fileSize: 8,
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

        let organizer = Organizer(db: db) { _ in }
        let job = try await organizer.organize(destination: destRoot, folderFormat: folder, dryRun: false)

        XCTAssertEqual(job.totalFiles, 1)
        XCTAssertEqual(job.copiedFiles, 0)
        XCTAssertEqual(job.skippedFiles, 1)

        let results = try db.fetchOrganizeResults(jobId: job.id!)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].action, .renameConflict)
        XCTAssertTrue(results[0].destination?.contains("_1") == true)

        try? FileManager.default.removeItem(at: srcDir)
        try? FileManager.default.removeItem(at: destRoot)
    }
}
