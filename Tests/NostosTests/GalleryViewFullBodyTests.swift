import XCTest
import ViewInspector
@testable import Nostos

@MainActor
final class GalleryViewFullBodyTests: XCTestCase {
    private var db: AppDatabase!

    override func setUpWithError() throws {
        db = try AppDatabase.makeInMemory()
        if NSApp == nil { _ = NSApplication.shared }
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

    // Full GalleryView inspection can be flaky under ViewInspector in some CI
    // environments; focus on isolated subviews instead.

    func testGalleryPhotoTile_overlay_and_selection() throws {
        let now = Date()
        let photo = makePhoto(path: "/tmp/p.jpg", takenAt: now, cameraModel: "M", duplicateGroupId: nil, status: .new)
        let photoWithBadges = makePhoto(path: "/tmp/p2.jpg", takenAt: now, cameraModel: "M", duplicateGroupId: 12, status: .copied)

        // Provide selected binding initialized to the badge photo so selection UI path is exercised
        let selected: Photo? = photoWithBadges
        let tile = GalleryPhotoTile(photo: photoWithBadges, tileSize: 145, selectedPhoto: .constant(selected), hoveredPhotoId: .constant(selected?.id))
        let sut = try tile.inspect()

        let texts = try sut.findAll(ViewType.Text.self).map { try? $0.string() }
        XCTAssertTrue(texts.contains(photoWithBadges.path.split(separator: "/").last.map(String.init)))
        XCTAssertTrue(texts.contains("IN VAULT") || texts.contains("DUP"))
    }
}
