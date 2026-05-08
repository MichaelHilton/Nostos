import XCTest
import SwiftUI
import ViewInspector
@testable import Nostos

extension PageHeaderView: Inspectable {}
extension SectionLabel: Inspectable {}
extension DiamondAccent: Inspectable {}
extension Stat: Inspectable {}

@MainActor
final class NostosComponentsTests: XCTestCase {

    // MARK: - PageHeaderView

    func testPageHeaderViewRendersTitle() throws {
        let view = PageHeaderView(title: "Scanner")
        XCTAssertNotNil(try view.inspect().find(text: "Scanner"))
    }

    func testPageHeaderViewRendersSubtitle() throws {
        let view = PageHeaderView(title: "Scanner", subtitle: "Scan your photos")
        XCTAssertNotNil(try view.inspect().find(text: "Scan your photos"))
    }

    func testPageHeaderViewRendersActions() throws {
        let view = PageHeaderView(
            title: "Scanner",
            actions: [AnyView(Text("Export"))]
        )
        XCTAssertNotNil(try view.inspect().find(text: "Export"))
    }

    func testPageHeaderViewRendersMultipleActions() throws {
        let view = PageHeaderView(
            title: "Scanner",
            actions: [AnyView(Text("Export")), AnyView(Text("Import"))]
        )
        XCTAssertNotNil(try view.inspect().find(text: "Export"))
        XCTAssertNotNil(try view.inspect().find(text: "Import"))
    }

    // MARK: - SectionLabel

    func testSectionLabelRendersText() throws {
        let view = SectionLabel("Source Folder")
        XCTAssertNotNil(try view.inspect().find(text: "Source Folder"))
    }

    func testSectionLabelWithDiamondRendersAccent() throws {
        let view = SectionLabel("Progress", diamond: true)
        XCTAssertNotNil(try view.inspect().find(DiamondAccent.self))
    }

    func testSectionLabelWithoutDiamondHasNoDiamondAccent() throws {
        let view = SectionLabel("Progress", diamond: false)
        XCTAssertThrowsError(try view.inspect().find(DiamondAccent.self))
    }

    // MARK: - Stat

    func testStatRendersLabelAndValue() throws {
        let view = Stat("Files Found", value: "42")
        XCTAssertNotNil(try view.inspect().find(text: "Files Found"))
        XCTAssertNotNil(try view.inspect().find(text: "42"))
    }

    func testStatWithCustomColor() throws {
        let view = Stat("Errors", value: "3", color: .red)
        XCTAssertNotNil(try view.inspect().find(text: "Errors"))
        XCTAssertNotNil(try view.inspect().find(text: "3"))
    }
}
