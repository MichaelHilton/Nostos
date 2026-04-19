import XCTest
import ViewInspector
@testable import Nostos

@MainActor
final class ViewsTests: XCTestCase {
    private var db: AppDatabase!

    override func setUpWithError() throws {
        db = try AppDatabase.makeInMemory()
    }

    func makePhoto(
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

    func testGalleryShowsLoadMoreButtonWhenLimitReached() throws {
        let state = AppState(db: db)
        state.photoFilter.limit = 1

        var p1 = makePhoto(path: "/tmp/a.jpg")
        var p2 = makePhoto(path: "/tmp/b.jpg")
        state.photos = [p1, p2]

        let view = GalleryView().environmentObject(state)
        XCTAssertNoThrow(try view.inspect().find(text: "Load More"))
    }

    func testOrganizerShowsProgressAndStatsWhenRunning() throws {
        let state = AppState(vaultRootURL: URL(fileURLWithPath: NSTemporaryDirectory()))
        state.organizeProgress.isRunning = true
        state.organizeProgress.total = 10
        state.organizeProgress.copied = 2
        state.organizeProgress.skipped = 1

        let view = OrganizerView().environmentObject(state)
        XCTAssertNoThrow(try view.inspect().find(text: "Copied"))
        XCTAssertNoThrow(try view.inspect().find(text: "2"))
        XCTAssertNoThrow(try view.inspect().find(ViewType.ProgressView.self))
    }
}

// Make views inspectable for ViewInspector
import SwiftUI
import AppKit
extension GalleryView: Inspectable {}
extension OrganizerView: Inspectable {}
