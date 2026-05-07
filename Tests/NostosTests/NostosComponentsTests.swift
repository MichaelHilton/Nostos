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

    override func setUpWithError() throws {
        // Ensure AppKit application exists for SwiftUI view inspection
        if NSApp == nil {
            _ = NSApplication.shared
        }
    }

    func testPageHeaderView_withSubtitle_andActions() throws {
        let actionsArray: () -> [AnyView] = { return [AnyView(Button("Act1") {})] }
        let view = PageHeaderView(title: "My Title", subtitle: "My Subtitle", actions: actionsArray)

        let sut = try view.inspect()

        let texts = try sut.findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("My Title"))
        XCTAssertTrue(texts.contains("My Subtitle"))

        let buttons = try sut.findAll(ViewType.Button.self)
        XCTAssertEqual(buttons.count, 1)
        XCTAssertEqual(try buttons[0].labelView().text().string(), "Act1")
    }

    func testPageHeaderView_withoutSubtitle_noActions() throws {
        let view = PageHeaderView(title: "Only Title")
        let sut = try view.inspect()

        let texts = try sut.findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("Only Title"))

        let buttons = try sut.findAll(ViewType.Button.self)
        XCTAssertEqual(buttons.count, 0)
    }

    func testSectionLabel_withAndWithoutDiamond() throws {
        let withDiamond = SectionLabel("Section", diamond: true)
        let s1 = try withDiamond.inspect()
        XCTAssertNoThrow(try s1.find(DiamondAccent.self))

        let without = SectionLabel("Section", diamond: false)
        let s2 = try without.inspect()
        // Should not throw when looking for the label text
        let texts = try s2.findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("Section"))
    }

    func testNostosStatCard_and_Stat_views() throws {
        let statCard = NostosStatCard("Photos", value: "42", color: .red)
        let c = try statCard.inspect()
        let texts = try c.findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(texts.contains("Photos"))
        XCTAssertTrue(texts.contains("42"))

        let stat = Stat("Label", value: "99", color: .blue)
        let s = try stat.inspect()
        let st = try s.findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertTrue(st.contains("Label"))
        XCTAssertTrue(st.contains("99"))
    }

    func testProgressBar_and_shapeViews_build() throws {
        let p1 = NostosProgressBar(30, total: 100, color: .green)
        XCTAssertNoThrow(try p1.inspect())

        let p2 = NostosProgressBar(150, total: 100, color: .accentColor)
        XCTAssertNoThrow(try p2.inspect())
    }

    func testMeanderDivider_and_DiamondAccent_and_StarDotBackground_build() throws {
        XCTAssertNoThrow(try MeanderDivider().inspect())
        XCTAssertNoThrow(try DiamondAccent(size: 6).inspect())
        XCTAssertNoThrow(try StarDotBackground().inspect())
    }
}

// Make views inspectable for ViewInspector
import SwiftUI
import AppKit
extension PageHeaderView: Inspectable {}
extension SectionLabel: Inspectable {}
extension NostosStatCard: Inspectable {}
extension NostosProgressBar: Inspectable {}
extension MeanderDivider: Inspectable {}
extension DiamondAccent: Inspectable {}
extension Stat: Inspectable {}
