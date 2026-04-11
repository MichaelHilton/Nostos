import Foundation
import XCTest

#if os(macOS) && !SWIFT_PACKAGE
final class NostosUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func accessibleControl(in app: XCUIApplication, identifier: String) -> XCUIElement {
        let candidates = [
            app.buttons[identifier],
            app.popUpButtons[identifier],
            app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        ]

        for candidate in candidates where candidate.exists {
            return candidate
        }

        return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
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

        scannerTabButton.click()
        let scannerChooseButton = app.buttons["scannerChooseDirectoryButton"]
        XCTAssertTrue(scannerChooseButton.waitForExistence(timeout: 5))
        scannerChooseButton.click()

        let scannerStartButton = app.buttons["scannerStartScanButton"]
        XCTAssertTrue(scannerStartButton.waitForExistence(timeout: 5))
        XCTAssertTrue(scannerStartButton.isEnabled)
        scannerStartButton.click()

        let galleryTabButton = app.buttons["galleryTabButton"]
        XCTAssertTrue(galleryTabButton.waitForExistence(timeout: 10))
        galleryTabButton.click()

        let loadMoreButton = app.buttons["galleryLoadMoreButton"]
        XCTAssertTrue(loadMoreButton.waitForExistence(timeout: 5))
        loadMoreButton.click()

        let perPageMenuButton = accessibleControl(in: app, identifier: "galleryPerPageMenuButton")
        XCTAssertTrue(perPageMenuButton.waitForExistence(timeout: 5))
        perPageMenuButton.click()
        XCTAssertTrue(app.menuItems["25"].waitForExistence(timeout: 5))
        app.menuItems["25"].click()

        let nextPageButton = app.buttons["galleryNextPageButton"]
        XCTAssertTrue(nextPageButton.waitForExistence(timeout: 5))
        nextPageButton.click()

        let prevPageButton = app.buttons["galleryPrevPageButton"]
        XCTAssertTrue(prevPageButton.waitForExistence(timeout: 5))
        prevPageButton.click()

        let removeAllFiltersButton = app.buttons["galleryRemoveAllFiltersButton"]
        XCTAssertTrue(removeAllFiltersButton.waitForExistence(timeout: 5))
        removeAllFiltersButton.click()

        let duplicatesTabButton = app.buttons["duplicatesTabButton"]
        XCTAssertTrue(duplicatesTabButton.waitForExistence(timeout: 10))
        duplicatesTabButton.click()

        let duplicateKeepButtons = app.buttons.matching(identifier: "duplicateKeepButton")
        XCTAssertGreaterThan(duplicateKeepButtons.count, 0)
        for index in 0..<duplicateKeepButtons.count {
            let keepButton = duplicateKeepButtons.element(boundBy: index)
            if keepButton.waitForExistence(timeout: 5), keepButton.isHittable {
                keepButton.click()
            }
        }

        let vaultTabButton = app.buttons["vaultTabButton"]
        XCTAssertTrue(vaultTabButton.waitForExistence(timeout: 10))
        vaultTabButton.click()

        let toggleDetailsButton = accessibleControl(in: app, identifier: "vaultToggleDetailsButton")
        XCTAssertTrue(toggleDetailsButton.waitForExistence(timeout: 5))
        toggleDetailsButton.click()

        let previewButton = accessibleControl(in: app, identifier: "vaultPreviewButton")
        XCTAssertTrue(previewButton.waitForExistence(timeout: 5))
        previewButton.click()

        let changeVaultButton = accessibleControl(in: app, identifier: "vaultChangeVaultButton")
        XCTAssertTrue(changeVaultButton.waitForExistence(timeout: 5))
        changeVaultButton.click()

        let confirmChangeButton = accessibleControl(in: app, identifier: "vaultConfirmChangeButton")
        XCTAssertTrue(confirmChangeButton.waitForExistence(timeout: 5))
        confirmChangeButton.click()

        let scannerTabAfterChange = app.buttons["scannerTabButton"]
        XCTAssertTrue(scannerTabAfterChange.waitForExistence(timeout: 10))
        XCTAssertTrue(scannerTabAfterChange.isHittable)
    }
}
#endif
