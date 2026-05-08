import XCTest
import SwiftUI
@testable import Nostos

final class WaveLensLogoTests: XCTestCase {
    func assertRect(_ rect: CGRect, equals expected: CGRect, accuracy: CGFloat = 1.0, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(rect.origin.x, expected.origin.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(rect.origin.y, expected.origin.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(rect.size.width, expected.size.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(rect.size.height, expected.size.height, accuracy: accuracy, file: file, line: line)
    }

    func testMainElementsBounds() {
        let size = CGSize(width: 280, height: 280)
        let elements = WaveLensLogoRenderer.mainElements(for: size)

        let bgExpected = CGRect(origin: .zero, size: size)
        assertRect(elements.bgPath.boundingRect, equals: bgExpected, accuracy: 0.5)

        let outerExpected = CGRect(x: size.width * 0.13, y: size.height * 0.13, width: size.width * 0.74, height: size.height * 0.74)
        assertRect(elements.outerRing.boundingRect, equals: outerExpected, accuracy: 1.0)

        // Wave endpoints
        XCTAssertEqual(elements.wave.boundingRect.minX, size.width * 0.185, accuracy: 1.0)
        XCTAssertEqual(elements.wave.boundingRect.maxX, size.width * 0.87, accuracy: 1.0)

        // Needle positions
        XCTAssertEqual(elements.needle.boundingRect.midX, size.width * 0.5, accuracy: 0.5)
        XCTAssertEqual(elements.needle.boundingRect.minY, size.height * 0.097, accuracy: 1.0)
        XCTAssertEqual(elements.needle.boundingRect.maxY, size.height * 0.145, accuracy: 1.0)
    }

    func testWatermarkElements() {
        let size = CGSize(width: 200, height: 200)
        let elements = WaveLensLogoRenderer.watermarkElements(for: size)

        // Outer ring bounding box roughly the full size inset by 4%
        XCTAssertEqual(elements.outerRing.boundingRect.minX, size.width * 0.04, accuracy: 1.0)
        XCTAssertEqual(elements.middleRing.boundingRect.minX, size.width * 0.13, accuracy: 1.0)

        // Wave spans expected X range
        XCTAssertEqual(elements.wave.boundingRect.minX, size.width * 0.13, accuracy: 1.0)
        XCTAssertEqual(elements.wave.boundingRect.maxX, size.width * 0.87, accuracy: 1.0)

        // There are four cardinal ticks
        XCTAssertEqual(elements.ticks.count, 4)

        // Gold dot exists and has positive size
        XCTAssertGreaterThan(elements.goldDot.boundingRect.width, 0)
    }
}
