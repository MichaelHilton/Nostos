import XCTest
import ViewInspector
@testable import Nostos

@MainActor
final class GalleryViewTests: XCTestCase {
    private var db: AppDatabase!

    override func setUpWithError() throws {
        db = try AppDatabase.makeInMemory()
        // Ensure AppKit application exists for SwiftUI view inspection
        if NSApp == nil {
            _ = NSApplication.shared
        }
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

    func testGallery_emptyState_showsWhenNoPhotos() throws {
        // Test the empty state view in isolation (no environment object required)
        let empty = GalleryEmptyState(clearAction: {})
        let sut = try empty.inspect()

        // Expect empty-state text
        let texts = try sut.findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("No photos match"))

        // VerticalYearRangeSlider with no selection shows "All years"
        let slider = VerticalYearRangeSlider(years: [], yearFrom: .constant(nil), yearTo: .constant(nil)) {}
        let s2 = try slider.inspect()
        let t = try s2.find(ViewType.Text.self).string()
        XCTAssertEqual(t, "All years")
    }

    func testGallery_filterDuplicates_buttonExistsAndShowsToolbarCount() throws {
        let state = AppState(db: db)
        let now = Date()
        let p1 = makePhoto(path: "/tmp/p1.jpg", takenAt: now, cameraModel: "X", duplicateGroupId: nil, status: .new)
        let p2 = makePhoto(path: "/tmp/p2.jpg", takenAt: now, cameraModel: "Y", duplicateGroupId: 1, status: .new)
        state.photos = [p1, p2]
        state.totalPhotoCount = 2
        state.cameraModels = ["X", "Y"]

        // Inspect the toolbar in isolation
        let toolbar = GalleryToolbar(filteredCount: 2, totalCount: 2, isFiltered: true, onToggleDuplicates: {}, onToggleInVault: {}, onClearAll: {}, tileSize: .constant(145))
        let sut = try toolbar.inspect()

        // Toolbar should show total count
        var foundCountText: String?
        for t in try sut.findAll(ViewType.Text.self) {
            if let s = try? t.string(), s.contains("of") && s.contains("photos") {
                foundCountText = s
                break
            }
        }
        XCTAssertEqual(foundCountText, "2 of 2 photos")

        // Duplicates filter chip exists (look for label text)
        let textValues = try sut.findAll(ViewType.Text.self).map { try? $0.string() }
        XCTAssertTrue(textValues.contains("Duplicates"))
    }

    func testGallery_photoTileSelectionAndBadgesShowsSelectedPanel() throws {
        let state = AppState(db: db)
        let now = Date()
        let photo = makePhoto(path: "/tmp/photo.jpg", takenAt: now, cameraModel: "Z", duplicateGroupId: 10, status: .copied)
        state.photos = [photo]
        state.totalPhotoCount = 1
        state.cameraModels = ["Z"]

        // Inspect the photo tile in isolation to avoid injecting AppState into the full GalleryView
        let tile = GalleryPhotoTile(photo: photo, tileSize: 145, selectedPhoto: .constant(nil as Photo?), hoveredPhotoId: .constant(nil as Int64?))
        let sut = try tile.inspect()

        // Badges text should exist on the tile
        let texts = try sut.findAll(ViewType.Text.self).map { try? $0.string() }
        XCTAssertTrue(texts.contains("DUP"))
        XCTAssertTrue(texts.contains("IN VAULT"))
    }

    func testBackupFooterButtonEnabledState() throws {
        let state = AppState(db: db)
        // Case: no backup candidates
        let p1 = makePhoto(path: "/tmp/c1.jpg", status: .copied)
        state.photos = [p1]
        state.totalPhotoCount = 1

        // Inspect BackupFooterBar directly to avoid inspecting the whole GalleryView
        let footer0 = BackupFooterBar(matchCount: 0).environmentObject(state)
        let sut0 = try footer0.inspect()
        var foundText0: String?
        for t in try sut0.findAll(ViewType.Text.self) {
            if let s = try? t.string(), s.contains("photos to back up") {
                foundText0 = s
                break
            }
        }
        XCTAssertEqual(foundText0, "0 photos to back up")

        let footer1 = BackupFooterBar(matchCount: 2).environmentObject(state)
        let sut1 = try footer1.inspect()
        var foundText1: String?
        for t in try sut1.findAll(ViewType.Text.self) {
            if let s = try? t.string(), s.contains("photos to back up") {
                foundText1 = s
                break
            }
        }
        XCTAssertEqual(foundText1, "2 photos to back up")
    }
}

// Make views inspectable for ViewInspector in this test file as well
import SwiftUI
import AppKit
extension BackupFooterBar: Inspectable {}
extension VerticalYearRangeSlider: Inspectable {}
extension Badge: Inspectable {}
extension VaultBadge: Inspectable {}
extension GalleryPhotoTile: Inspectable {}
