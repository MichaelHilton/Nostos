import XCTest
@testable import Nostos

final class EXIFReaderTests: XCTestCase {

    func testReadNonImageReturnsEmpty() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("not-an-image-")
        // Ensure file does not exist
        try? FileManager.default.removeItem(at: tmp)

        let data = EXIFReader.read(from: tmp)
        XCTAssertNil(data.takenAt)
        XCTAssertNil(data.cameraMake)
        XCTAssertNil(data.cameraModel)
        XCTAssertNil(data.gpsLat)
        XCTAssertNil(data.gpsLon)
        XCTAssertNil(data.width)
        XCTAssertNil(data.height)
    }
}
