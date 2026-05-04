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

        let removeAllFiltersButton = app.buttons["galleryRemoveAllFiltersButton"]
        XCTAssertTrue(removeAllFiltersButton.waitForExistence(timeout: 5))
        click(removeAllFiltersButton, label: "galleryRemoveAllFiltersButton")

        let duplicatesTabButton = app.buttons["duplicatesTabButton"]
        XCTAssertTrue(duplicatesTabButton.waitForExistence(timeout: 10))
        click(duplicatesTabButton, label: "duplicatesTabButton")

        let expandGroupButton = app.buttons["duplicateExpandGroupButton"].firstMatch
        XCTAssertTrue(expandGroupButton.waitForExistence(timeout: 5))
        click(expandGroupButton, label: "duplicateExpandGroupButton")

        let duplicatePhotoTiles = app.descendants(matching: .any).matching(identifier: "duplicatePhotoTile")
        XCTAssertGreaterThan(duplicatePhotoTiles.count, 0)
        for index in 0..<duplicatePhotoTiles.count {
            let tile = duplicatePhotoTiles.element(boundBy: index)
            if tile.waitForExistence(timeout: 5), tile.isHittable {
                click(tile, label: "duplicatePhotoTile[\(index)]")
            }
        }

        let keepFirstButton = app.buttons["duplicatesKeepFirstButton"]
        XCTAssertTrue(keepFirstButton.waitForExistence(timeout: 5))
        click(keepFirstButton, label: "duplicatesKeepFirstButton")

        let clearSelectionsButton = app.buttons["duplicatesClearSelectionsButton"]
        XCTAssertTrue(clearSelectionsButton.waitForExistence(timeout: 5))
        click(clearSelectionsButton, label: "duplicatesClearSelectionsButton")

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

    func testGalleryFilterAndBackupButtons() throws {
        let fileManager = FileManager.default
        let uniqueSuffix = UUID().uuidString
        let vaultRoot = fileManager.temporaryDirectory.appendingPathComponent("nostos-ui-gallery-\(uniqueSuffix)")
        try fileManager.createDirectory(at: vaultRoot, withIntermediateDirectories: true)

        let app = XCUIApplication(bundleIdentifier: "com.github.michaelhilton.Nostos")
        app.launchEnvironment = [
            "UI_TESTING_VAULT_ROOT": vaultRoot.path,
            "UI_TESTING_SEED_DATA": "1"
        ]
        app.launch()

        let galleryTabButton = app.buttons["galleryTabButton"]
        XCTAssertTrue(galleryTabButton.waitForExistence(timeout: 10))
        click(galleryTabButton, label: "galleryTabButton")

        // Filter chip: Duplicates — activates filter, making toolbar Clear all visible
        let filterChipDuplicates = app.buttons["galleryFilterChipDuplicates"]
        XCTAssertTrue(filterChipDuplicates.waitForExistence(timeout: 5))
        click(filterChipDuplicates, label: "galleryFilterChipDuplicates")

        let toolbarClearAllButton = app.buttons["galleryToolbarClearAllButton"]
        XCTAssertTrue(toolbarClearAllButton.waitForExistence(timeout: 5))
        click(toolbarClearAllButton, label: "galleryToolbarClearAllButton")

        // Filter chip: In Vault
        let filterChipInVault = app.buttons["galleryFilterChipInVault"]
        XCTAssertTrue(filterChipInVault.waitForExistence(timeout: 5))
        click(filterChipInVault, label: "galleryFilterChipInVault")

        // Clear toolbar again (now visible because In Vault filter is active)
        XCTAssertTrue(toolbarClearAllButton.waitForExistence(timeout: 5))
        click(toolbarClearAllButton, label: "galleryToolbarClearAllButton (clear after In Vault)")

        // Sidebar: With duplicates checkbox
        let filterWithDuplicates = app.buttons["galleryFilterWithDuplicates"]
        XCTAssertTrue(filterWithDuplicates.waitForExistence(timeout: 5))
        click(filterWithDuplicates, label: "galleryFilterWithDuplicates")
        click(filterWithDuplicates, label: "galleryFilterWithDuplicates (deactivate)")

        // Sidebar: No duplicates checkbox
        let filterNoDuplicates = app.buttons["galleryFilterNoDuplicates"]
        XCTAssertTrue(filterNoDuplicates.waitForExistence(timeout: 5))
        click(filterNoDuplicates, label: "galleryFilterNoDuplicates")
        click(filterNoDuplicates, label: "galleryFilterNoDuplicates (deactivate)")

        // Backup footer: Back Up to Vault (enabled because seeded photos include non-copied status)
        let backUpToVaultButton = app.buttons["galleryBackUpToVaultButton"]
        XCTAssertTrue(backUpToVaultButton.waitForExistence(timeout: 5))
        XCTAssertTrue(backUpToVaultButton.isEnabled)
        click(backUpToVaultButton, label: "galleryBackUpToVaultButton")

        // Pause/resume button appears immediately when backup starts
        let pauseResumeButton = app.buttons["galleryBackupPauseResumeButton"]
        XCTAssertTrue(pauseResumeButton.waitForExistence(timeout: 5))
        click(pauseResumeButton, label: "galleryBackupPauseResumeButton (pause)")

        print("UI test click log: \(clickedControls.joined(separator: " -> "))")
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

        print("UI test click log: \(clickedControls.joined(separator: " -> "))")
    }
}
#endif
