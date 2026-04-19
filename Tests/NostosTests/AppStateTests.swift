import XCTest
@testable import Nostos

@MainActor
final class AppStateTests: XCTestCase {

    func testLoadInitialDataPopulatesPhotosAndCounts() async throws {
        let db = try AppDatabase.makeInMemory()

        var p1 = Photo(id: nil,
                       path: "/tmp/test/photo1.jpg",
                       hash: "h1",
                       fileSize: 100,
                       width: 100,
                       height: 100,
                       takenAt: Date(),
                       cameraMake: "Canon",
                       cameraModel: "EOS",
                       gpsLat: nil,
                       gpsLon: nil,
                       thumbnailPath: nil,
                       duplicateGroupId: nil,
                       isKept: false,
                       status: .new,
                       scannedAt: Date(),
                       scanRunId: nil)

        var p2 = p1
        p2.path = "/tmp/test/photo2.jpg"
        p2.hash = "h2"

        try db.insertPhoto(&p1)
        try db.insertPhoto(&p2)

        let appState = AppState(db: db)

        await appState.loadInitialData()

        XCTAssertEqual(appState.photos.count, 2)
        XCTAssertEqual(appState.totalPhotoCount, 2)
    }

    func testCountPhotosForBackupUsesDB() throws {
        let db = try AppDatabase.makeInMemory()

        var p = Photo(id: nil,
                      path: "/tmp/test/photo.jpg",
                      hash: nil,
                      fileSize: 50,
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

        try db.insertPhoto(&p)

        let appState = AppState(db: db)

        let filter = PhotoFilter()
        let count = appState.countPhotosForBackup(filter: filter)

        XCTAssertEqual(count, 1)
    }
}
