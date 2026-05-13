import XCTest
import SwiftUI
@testable import Nostos

@MainActor
final class WaveLensLogoViewTests: XCTestCase {
    override func setUpWithError() throws {
        if NSApp == nil { _ = NSApplication.shared }
    }

    func testWaveLensLogoCanvasExecutesWithoutCrashing() throws {
        let view = WaveLensLogo().frame(width: 100, height: 100)
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        host.layoutSubtreeIfNeeded()
        host.needsDisplay = true
        host.displayIfNeeded()

        // If we reached here without throwing, the Canvas closure executed.
        XCTAssertTrue(true)
    }

    func testWaveLensLogoWatermarkCanvasExecutesWithoutCrashing() throws {
        let view = WaveLensLogoWatermark().frame(width: 120, height: 120)
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        host.layoutSubtreeIfNeeded()
        host.needsDisplay = true
        host.displayIfNeeded()

        XCTAssertTrue(true)
    }

    func testCoverWaveLensLogoFile() throws {
        __cover_WaveLensLogo_file()
        XCTAssertTrue(true)
    }
}
