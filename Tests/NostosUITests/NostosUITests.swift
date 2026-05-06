import Foundation
import XCTest

#if os(macOS) && !SWIFT_PACKAGE
final class NostosUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private var clickedControls: [String] = []

    private func logClick(_ label: String) {
        clickedControls.append(label)
        print("UI test clicked: \(label)")
    }

    private func click(_ element: XCUIElement, label: String) {
        logClick(label)
        element.click()
    }

    private func accessibleControl(in app: XCUIApplication, identifier: String) -> XCUIElement {
        let candidates = [
            app.buttons[identifier],
            app.popUpButtons[identifier],
            app.checkBoxes[identifier],
            app.otherElements[identifier],
            app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        ]

        for candidate in candidates where candidate.exists {
            return candidate
        }

        return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func menuItem(in app: XCUIApplication, titled title: String) -> XCUIElement {
        app.menuItems[title]
    }

}
#endif
