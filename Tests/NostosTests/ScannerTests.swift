import XCTest
@testable import Nostos

final class ScannerTests: XCTestCase {

    actor ProgressCollector {
        var snaps: [ScanProgress] = []
        func append(_ s: ScanProgress) { snaps.append(s) }
        func last() -> ScanProgress? { snaps.last }
    }

    func testScanFindsPhotosAndGeneratesThumbnails() async throws {
        let db = try AppDatabase.makeInMemory()

        // create temp dir with files
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_scan_test")
        try? FileManager.default.removeItem(at: tmp)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        let f1 = tmp.appendingPathComponent("a.jpg")
        let f2 = tmp.appendingPathComponent("b.jpg")
        try "one".data(using: .utf8)!.write(to: f1)
        try "two".data(using: .utf8)!.write(to: f2)

        let collector = ProgressCollector()

        let scanner = Scanner(db: db) { progress in
            await collector.append(progress)
        }

        let run = try await scanner.scan(rootURL: tmp)

        XCTAssertEqual(run.photosFound, 2)

        let photos = try db.fetchPhotos(filter: PhotoFilter())
        XCTAssertEqual(photos.count, 2)

        for p in photos {
            if let tp = p.thumbnailPath {
                XCTAssertTrue(FileManager.default.fileExists(atPath: tp))
            }
        }

        // cleanup
        try? FileManager.default.removeItem(at: tmp)
    }
}
