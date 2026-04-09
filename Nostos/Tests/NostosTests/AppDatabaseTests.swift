import XCTest
@testable import Nostos

final class AppDatabaseTests: XCTestCase {

    func testInsertAndFetchScanRun() throws {
        let db = try AppDatabase.makeInMemory()

        var run = ScanRun(id: nil,
                          rootPath: "/tmp/test",
                          startedAt: Date(),
                          finishedAt: nil,
                          photosFound: 0,
                          duplicatesFound: 0,
                          status: .running)

        try db.insertScanRun(&run)
        XCTAssertNotNil(run.id)

        let all = try db.fetchAllScanRuns()
        XCTAssertGreaterThanOrEqual(all.count, 1)
        XCTAssertEqual(all.first?.rootPath, "/tmp/test")
    }

    func testInsertUpsertAndFetchPhoto() throws {
        let db = try AppDatabase.makeInMemory()

        var run = ScanRun(id: nil,
                          rootPath: "/tmp/photos",
                          startedAt: Date(),
                          finishedAt: nil,
                          photosFound: 0,
                          duplicatesFound: 0,
                          status: .running)
        try db.insertScanRun(&run)

        var p = Photo(id: nil,
                      path: "/tmp/photos/1.jpg",
                      hash: "abcdef",
                      fileSize: 123,
                      width: 100,
                      height: 200,
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
                      scanRunId: run.id)

        try db.insertPhoto(&p)
        XCTAssertNotNil(p.id)

        // upsert with same path should update existing row
        p.fileSize = 456
        try db.upsertPhoto(&p)

        let fetched = try db.fetchPhoto(path: "/tmp/photos/1.jpg")
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.fileSize, 456)

        let count = try db.photoCount()
        XCTAssertEqual(count, 1)

        let hashes = try db.fetchAllHashes()
        XCTAssertEqual(hashes["abcdef"], fetched?.id)
    }
}
