import XCTest
@testable import Nostos

final class ScannerEdgeCasesTests: XCTestCase {

    func testScannerSkipsUnsupportedExtensions() async throws {
        let db = try AppDatabase.makeInMemory()

        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_scan_edge1")
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let txt = root.appendingPathComponent("file.txt")
        try "not an image".data(using: .utf8)!.write(to: txt)

        let scanner = Scanner(db: db) { _ in }
        let run = try await scanner.scan(rootURL: root)

        XCTAssertEqual(run.photosFound, 0)
        let photos = try db.fetchPhotos(filter: PhotoFilter(limit: 100, offset: 0))
        XCTAssertEqual(photos.count, 0)

        try? FileManager.default.removeItem(at: root)
    }

    func testScannerSkipsAlreadyScannedPath() async throws {
        let db = try AppDatabase.makeInMemory()

        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_scan_edge2")
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let img = root.appendingPathComponent("photo.jpg")
        try "data".data(using: .utf8)!.write(to: img)

        var existing = Photo(id: nil,
                             path: img.path,
                             hash: nil,
                             fileSize: 4,
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
        try db.insertPhoto(&existing)

        let scanner = Scanner(db: db) { _ in }
        let run = try await scanner.scan(rootURL: root)

        // scanner should not remove the existing record; ensure the path exists afterwards
        let fetched = try db.fetchPhoto(path: img.path)
        XCTAssertNotNil(fetched)
        let photos = try db.fetchPhotos(filter: PhotoFilter(limit: 100, offset: 0))
        XCTAssertGreaterThanOrEqual(photos.count, 1)

        try? FileManager.default.removeItem(at: root)
    }
}
