import XCTest
import AppKit
@testable import Nostos

final class ThumbnailServiceTests: XCTestCase {

    func testThumbnailGenerationCreatesFileAndLoadsImage() throws {
        // create a small NSImage and write it as JPEG to a temp file
        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nostos_thumb_test")
        try? FileManager.default.removeItem(at: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        let src = tmpDir.appendingPathComponent("src.jpg")
        let image = NSImage(size: NSSize(width: 16, height: 16))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 16, height: 16).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpg = rep.representation(using: .jpeg, properties: [:]) else {
            XCTFail("failed to create test image")
            return
        }
        try jpg.write(to: src)

        // call thumbnail service
        let dest = ThumbnailService.thumbnail(for: 12345, sourceURL: src)
        XCTAssertNotNil(dest)
        if let path = dest {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path))
            XCTAssertNotNil(ThumbnailService.loadImage(path: path))
        }

        try? FileManager.default.removeItem(at: tmpDir)
    }
}
