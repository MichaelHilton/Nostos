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

    func testClicksPrimaryButtonsAcrossTheApp() throws {
        let fileManager = FileManager.default
        let uniqueSuffix = UUID().uuidString
        let sourceRoot = fileManager.temporaryDirectory.appendingPathComponent("nostos-ui-source-\(uniqueSuffix)")
        let vaultRoot = fileManager.temporaryDirectory.appendingPathComponent("nostos-ui-vault-\(uniqueSuffix)")
        let secondVaultRoot = fileManager.temporaryDirectory.appendingPathComponent("nostos-ui-vault-2-\(uniqueSuffix)")

        try fileManager.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: vaultRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: secondVaultRoot, withIntermediateDirectories: true)

        let app = XCUIApplication(bundleIdentifier: "com.github.michaelhilton.Nostos")
        app.launchEnvironment = [
            "UI_TESTING_VAULT_ROOT": vaultRoot.path,
            "UI_TESTING_SEED_DATA": "1",
            "UI_TESTING_SOURCE_DIRECTORY_TO_PICK": sourceRoot.path,
            "UI_TESTING_VAULT_DIRECTORY_TO_PICK": vaultRoot.path
        ]
        app.launch()

        let scannerTabButton = app.buttons["scannerTabButton"]
        XCTAssertTrue(scannerTabButton.waitForExistence(timeout: 10))

        click(scannerTabButton, label: "scannerTabButton")
        let scannerChooseButton = app.buttons["scannerChooseDirectoryButton"]
        XCTAssertTrue(scannerChooseButton.waitForExistence(timeout: 5))
        click(scannerChooseButton, label: "scannerChooseDirectoryButton")

        let scannerStartButton = app.buttons["scannerStartScanButton"]
        XCTAssertTrue(scannerStartButton.waitForExistence(timeout: 5))
        XCTAssertTrue(scannerStartButton.isEnabled)
        click(scannerStartButton, label: "scannerStartScanButton")

        let galleryTabButton = app.buttons["galleryTabButton"]
        XCTAssertTrue(galleryTabButton.waitForExistence(timeout: 10))
        click(galleryTabButton, label: "galleryTabButton")

        let galleryPhotoTile = app.descendants(matching: .any).matching(identifier: "galleryPhotoTile").firstMatch
        XCTAssertTrue(galleryPhotoTile.waitForExistence(timeout: 5))
        click(galleryPhotoTile, label: "galleryPhotoTile")

        let clearSelectionButton = app.buttons["galleryClearSelectionButton"]
        XCTAssertTrue(clearSelectionButton.waitForExistence(timeout: 5))
        click(clearSelectionButton, label: "galleryClearSelectionButton")

        let loadMoreButton = app.buttons["galleryLoadMoreButton"]
        XCTAssertTrue(loadMoreButton.waitForExistence(timeout: 5))
        click(loadMoreButton, label: "galleryLoadMoreButton")

        let perPageMenuButton = accessibleControl(in: app, identifier: "galleryPerPageMenuButton")
        XCTAssertTrue(perPageMenuButton.waitForExistence(timeout: 5))
        for title in ["25", "50", "100", "200", "All"] {
            click(perPageMenuButton, label: "galleryPerPageMenuButton")
            XCTAssertTrue(menuItem(in: app, titled: title).waitForExistence(timeout: 5))
            click(menuItem(in: app, titled: title), label: "galleryPerPageMenuItem:\(title)")
        }

        let nextPageButton = app.buttons["galleryNextPageButton"]
        XCTAssertTrue(nextPageButton.waitForExistence(timeout: 5))
        click(nextPageButton, label: "galleryNextPageButton")

        let prevPageButton = app.buttons["galleryPrevPageButton"]
        XCTAssertTrue(prevPageButton.waitForExistence(timeout: 5))
        click(prevPageButton, label: "galleryPrevPageButton")

        let removeAllFiltersButton = app.buttons["galleryRemoveAllFiltersButton"]
        XCTAssertTrue(removeAllFiltersButton.waitForExistence(timeout: 5))
        click(removeAllFiltersButton, label: "galleryRemoveAllFiltersButton")

        let duplicatesTabButton = app.buttons["duplicatesTabButton"]
        XCTAssertTrue(duplicatesTabButton.waitForExistence(timeout: 10))
        click(duplicatesTabButton, label: "duplicatesTabButton")

        let duplicateKeepButtons = app.buttons.matching(identifier: "duplicateKeepButton")
        XCTAssertGreaterThan(duplicateKeepButtons.count, 0)
        for index in 0..<duplicateKeepButtons.count {
            let keepButton = duplicateKeepButtons.element(boundBy: index)
            if keepButton.waitForExistence(timeout: 5), keepButton.isHittable {
                click(keepButton, label: "duplicateKeepButton[\(index)]")
            }
        }

        let vaultTabButton = app.buttons["vaultTabButton"]
        XCTAssertTrue(vaultTabButton.waitForExistence(timeout: 10))
        click(vaultTabButton, label: "vaultTabButton")

        let toggleDetailsButton = accessibleControl(in: app, identifier: "vaultToggleDetailsButton")
        XCTAssertTrue(toggleDetailsButton.waitForExistence(timeout: 5))
        click(toggleDetailsButton, label: "vaultToggleDetailsButton")

        let previewButton = accessibleControl(in: app, identifier: "vaultPreviewButton")
        XCTAssertTrue(previewButton.waitForExistence(timeout: 5))
        click(previewButton, label: "vaultPreviewButton")

        let changeVaultButton = accessibleControl(in: app, identifier: "vaultChangeVaultButton")
        XCTAssertTrue(changeVaultButton.waitForExistence(timeout: 5))
        click(changeVaultButton, label: "vaultChangeVaultButton")

        let cancelChangeButton = accessibleControl(in: app, identifier: "vaultCancelChangeButton")
        XCTAssertTrue(cancelChangeButton.waitForExistence(timeout: 5))
        click(cancelChangeButton, label: "vaultCancelChangeButton")

        click(changeVaultButton, label: "vaultChangeVaultButton")

        let confirmChangeButton = accessibleControl(in: app, identifier: "vaultConfirmChangeButton")
        XCTAssertTrue(confirmChangeButton.waitForExistence(timeout: 5))
        click(confirmChangeButton, label: "vaultConfirmChangeButton")

        let dryRunToggle = app.checkBoxes["Dry Run (preview only, no files copied)"]
        XCTAssertTrue(dryRunToggle.waitForExistence(timeout: 5))
        click(dryRunToggle, label: "Dry Run (preview only, no files copied)")

        let saveButton = accessibleControl(in: app, identifier: "vaultSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        click(saveButton, label: "vaultSaveButton")

        print("UI test click log: \(clickedControls.joined(separator: " -> "))")

        let scannerTabAfterChange = app.buttons["scannerTabButton"]
        XCTAssertTrue(scannerTabAfterChange.waitForExistence(timeout: 10))
        XCTAssertTrue(scannerTabAfterChange.isHittable)
    }

    func testSetupScreenChooseVaultButton() throws {
        let fileManager = FileManager.default
        let uniqueSuffix = UUID().uuidString
        let vaultRoot = fileManager.temporaryDirectory.appendingPathComponent("nostos-ui-setup-vault-\(uniqueSuffix)")

        try fileManager.createDirectory(at: vaultRoot, withIntermediateDirectories: true)

        let app = XCUIApplication(bundleIdentifier: "com.github.michaelhilton.Nostos")
        app.launchEnvironment = [
            "UI_TESTING_FORCE_SETUP": "1",
            "UI_TESTING_VAULT_DIRECTORY_TO_PICK": vaultRoot.path
        ]
        app.launch()

        let chooseVaultButton = app.buttons["chooseVaultButton"]
        XCTAssertTrue(chooseVaultButton.waitForExistence(timeout: 10))
        click(chooseVaultButton, label: "chooseVaultButton")

        let scannerTabButton = app.buttons["scannerTabButton"]
        XCTAssertTrue(scannerTabButton.waitForExistence(timeout: 10))

        print("UI test click log: \(clickedControls.joined(separator: " -> "))")
    }
}
#endif
