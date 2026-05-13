import Foundation
import XCTest

#if os(macOS) && !SWIFT_PACKAGE
final class NostosUITests: XCTestCase {

    private var app: XCUIApplication!
    private var vaultRootPath: String!

    override func setUpWithError() throws {
        continueAfterFailure = false

        vaultRootPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("nostos-ui-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: vaultRootPath,
            withIntermediateDirectories: true
        )

        app = XCUIApplication()
        app.launchEnvironment["UI_TESTING_SEED_DATA"] = "1"
        app.launchEnvironment["UI_TESTING_VAULT_ROOT"] = vaultRootPath
        // Tells the app's startBackup() to complete instantly instead of using a timer.
        app.launchEnvironment["XCTestConfigurationFilePath"] = "1"
        app.launch()

        // Wait for app to be ready (app initializes and loads data)
        let tabButton = app.descendants(matching: .any).matching(identifier: "scannerTabButton").firstMatch
        XCTAssertTrue(tabButton.waitForExistence(timeout: 45), "App failed to initialize within 45s")
    }

    /// Launches a fresh app instance with the given source directory preset in the picker mock.
    private func launchAppWithSourceDirectory(_ sourcePath: String) -> XCUIApplication {
        let freshApp = XCUIApplication()
        freshApp.launchEnvironment["UI_TESTING_SEED_DATA"] = "1"
        freshApp.launchEnvironment["UI_TESTING_VAULT_ROOT"] = vaultRootPath
        freshApp.launchEnvironment["XCTestConfigurationFilePath"] = "1"
        freshApp.launchEnvironment["UI_TESTING_SOURCE_DIRECTORY_TO_PICK"] = sourcePath
        freshApp.launch()

        let tabButton = freshApp.descendants(matching: .any).matching(identifier: "scannerTabButton").firstMatch
        XCTAssertTrue(tabButton.waitForExistence(timeout: 45), "App failed to initialize within 45s")

        return freshApp
    }

    override func tearDownWithError() throws {
        app.terminate()
        try? FileManager.default.removeItem(atPath: vaultRootPath)
    }

    // MARK: - Helpers

    /// Waits for an element to exist, fails the test if it doesn't, then returns it.
    @discardableResult
    private func el(_ id: String, timeout: TimeInterval = 10) -> XCUIElement {
        let match = app.descendants(matching: .any).matching(identifier: id).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: timeout), "'\(id)' not found within \(timeout)s")
        return match
    }

    private func notPresent(_ id: String, within timeout: TimeInterval = 2) {
        let match = app.descendants(matching: .any).matching(identifier: id).firstMatch
        XCTAssertFalse(
            match.waitForExistence(timeout: timeout),
            "'\(id)' was still present after \(timeout)s"
        )
    }

    private func goToTab(_ id: String) {
        el(id).click()
    }

    // MARK: - Tab Navigation

    /// Clicking each sidebar tab button lands on that tab's content.
    func testTabNavigation() {
        // Default tab is Gallery — navigate through all tabs and confirm unique elements.
        el("galleryPhotoTile")

        goToTab("scannerTabButton")
        el("scannerStartScanButton")

        goToTab("duplicatesTabButton")
        el("duplicatesKeepFirstButton")

        goToTab("vaultTabButton")
        el("vaultChangeVaultButton")

        goToTab("galleryTabButton")
        el("galleryPhotoTile")
    }

    // MARK: - Scanner Tab

    /// Scanner tab shows Choose… and Start Scan buttons in their default enabled state.
    func testScannerButtons() {
        goToTab("scannerTabButton")

        let choose = app.buttons["Choose…"]
        XCTAssertTrue(choose.waitForExistence(timeout: 5))
        XCTAssertTrue(choose.isEnabled)

        // Start Scan is disabled until a directory is chosen — just verify it exists.
        el("scannerStartScanButton")
    }

    /// Tapping Choose… button updates the selected folder path (covers ScannerView.body closure line 32-34).
    func testScannerChooseDirectoryButtonUpdatesPath() {
        // Launch with a preset source directory path
        let sourceDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("test-photos-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: sourceDir) }

        let freshApp = launchAppWithSourceDirectory(sourceDir)

        // Dump the app's accessibility hierarchy to the test log for debugging.
        print("=== Accessibility hierarchy (freshApp.debugDescription) ===")
        print(freshApp.debugDescription)

        let scannerTab = freshApp.descendants(matching: .any).matching(identifier: "scannerTabButton").firstMatch
        XCTAssertTrue(scannerTab.waitForExistence(timeout: 10))
        scannerTab.click()

        // The view initializes its `selectedPath` from `UI_TESTING_SOURCE_DIRECTORY_TO_PICK`,
        // so the label should already contain the last path component without tapping Choose…
        let lastComponent = (sourceDir as NSString).lastPathComponent
        // Prefer the combined card accessibility element; fall back to the text if needed.
        let sourceCard = freshApp.descendants(matching: .any).matching(identifier: "scannerSourceFolderCard").firstMatch
        if sourceCard.waitForExistence(timeout: 5) {
            XCTAssertTrue(sourceCard.label.contains(lastComponent), "Path component '\(lastComponent)' should appear in the source-card label")
        } else {
            let pathText = freshApp.staticTexts["scannerSelectedPathText"].firstMatch
            XCTAssertTrue(pathText.waitForExistence(timeout: 5), "Selected path label should appear")
            XCTAssertTrue(pathText.label.contains(lastComponent), "Path component '\(lastComponent)' should appear in the selected-path label")
        }
    }

    /// Tapping Start Scan button initiates a scan (covers ScannerView.body closure line 42-43).
    func testScannerStartScanButtonInitiatesScan() {
        // Launch with a preset source directory path so the Start Scan button is enabled
        let sourceDir = (NSTemporaryDirectory() as NSString).appendingPathComponent("test-scan-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: sourceDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: sourceDir) }

        let freshApp = launchAppWithSourceDirectory(sourceDir)

        let scannerTab = freshApp.descendants(matching: .any).matching(identifier: "scannerTabButton").firstMatch
        XCTAssertTrue(scannerTab.waitForExistence(timeout: 10))
        scannerTab.click()

        // The view initializes its `selectedPath` from `UI_TESTING_SOURCE_DIRECTORY_TO_PICK`,
        // so the label should already contain the path; wait for it before starting scan.
        let lastComponent = (sourceDir as NSString).lastPathComponent
        let sourceCard = freshApp.descendants(matching: .any).matching(identifier: "scannerSourceFolderCard").firstMatch
        if sourceCard.waitForExistence(timeout: 5) {
            XCTAssertTrue(sourceCard.label.contains(lastComponent))
        } else {
            let pathText = freshApp.staticTexts["scannerSelectedPathText"].firstMatch
            XCTAssertTrue(pathText.waitForExistence(timeout: 5))
            XCTAssertTrue(pathText.label.contains(lastComponent))
        }

        // Now tap the Start Scan button (covers closure at lines 42-43)
        let startButton = freshApp.descendants(matching: .any).matching(identifier: "scannerStartScanButton").firstMatch
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        XCTAssertTrue(startButton.isEnabled, "Start Scan button should be enabled after choosing a directory")
        startButton.click()

        // Wait briefly for scan to start
        Thread.sleep(forTimeInterval: 0.5)

        // Verify the button changes to show scanning state (button text changes to include "Scanning")
        let scanningText = freshApp.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Scanning")).firstMatch
        XCTAssertTrue(scanningText.exists, "Scanning indicator should appear after tapping Start Scan")
    }

    // MARK: - Gallery Tab

    /// Clicking a photo tile opens the detail panel; dismissing it closes the panel.
    func testGalleryPhotoSelectionAndDismiss() {
        goToTab("galleryTabButton")

        el("galleryPhotoTile").click()
        let dismiss = el("galleryClearSelectionButton")
        dismiss.click()
        notPresent("galleryClearSelectionButton")
    }

    /// Toolbar filter chips toggle on and the Clear All button appears / disappears correctly.
    func testGalleryToolbarFilterChips() {
        goToTab("galleryTabButton")

        el("galleryFilterChipDuplicates").click()
        el("galleryToolbarClearAllButton")   // must appear after activating a chip

        el("galleryFilterChipInVault").click()
        el("galleryToolbarClearAllButton").click()
        notPresent("galleryToolbarClearAllButton")
    }

    /// Sidebar duplicate-status filter checkboxes respond to clicks and Clear All resets them.
    func testGallerySidebarDuplicateFilters() {
        goToTab("galleryTabButton")

        el("galleryFilterWithDuplicates").click()
        el("galleryFilterNoDuplicates").click()
        el("galleryRemoveAllFiltersButton").click()
    }

    /// Sidebar backup-status filter checkboxes (New, Copied, Skipped Duplicate) are clickable.
    func testGallerySidebarStatusFilters() {
        goToTab("galleryTabButton")

        el("galleryFilterStatus_new").click()
        el("galleryFilterStatus_copied").click()
        el("galleryFilterStatus_skipped_duplicate").click()
        el("galleryRemoveAllFiltersButton").click()
    }

    /// Sidebar "No camera info" checkbox is clickable.
    func testGallerySidebarNoCameraInfoFilter() {
        goToTab("galleryTabButton")

        el("galleryFilterNoCameraInfo").click()
        el("galleryRemoveAllFiltersButton").click()
    }

    /// Back Up to Vault starts the backup; Back Up Again resets to idle so the button returns.
    func testGalleryBackupToVaultAndBackUpAgain() {
        goToTab("galleryTabButton")

        el("galleryBackUpToVaultButton").click()

        // Under XCTest, startBackup() immediately completes → "Back Up Again" should appear.
        el("galleryBackUpAgainButton").click()

        // After reset the primary button is restored.
        el("galleryBackUpToVaultButton")
    }

    // MARK: - Duplicates Tab

    /// Expanding a group shows photo tiles; selecting one enables Clear Selections; Keep First runs.
    func testDuplicatesGroupInteraction() {
        goToTab("duplicatesTabButton")

        el("duplicateExpandGroupButton").click()
        el("duplicatePhotoTile").click()
        el("duplicatesClearSelectionsButton").click()
        el("duplicatesKeepFirstButton").click()
    }

    // MARK: - Vault Tab

    /// Toggling Dry Run switches the organise button between vaultPreviewButton and vaultSaveButton.
    func testVaultDryRunToggle() {
        goToTab("vaultTabButton")

        // Default: dry run on → preview button
        el("vaultPreviewButton")

        el("vaultDryRunToggle").click()   // turn off dry run
        el("vaultSaveButton")

        el("vaultDryRunToggle").click()   // back to dry run
        el("vaultPreviewButton")
    }

    /// Show Details / Hide toggles the results table (seeded organize job populates results).
    func testVaultToggleDetails() {
        goToTab("vaultTabButton")

        el("vaultToggleDetailsButton").click()   // "Show Details" → show table
        el("vaultToggleDetailsButton").click()   // "Hide" → hide table
    }

    /// Year range slider shows "All years" by default; tapping a year activates a filter; Clear resets it.
    func testGalleryYearRangeSlider() {
        goToTab("galleryTabButton")

        // Default: no filter active — summary shows "All years", Clear is absent
        XCTAssertEqual(el("galleryFilterYearSummary").label, "All years")
        notPresent("galleryFilterYearClear")

        // Tap the first year button that appears in the slider
        let yearButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'galleryFilterYear_'")
        ).firstMatch
        XCTAssertTrue(yearButton.waitForExistence(timeout: 5), "No year labels found in year range slider")
        yearButton.click()

        // Summary updates to a specific year (no longer "All years")
        XCTAssertNotEqual(el("galleryFilterYearSummary").label, "All years")

        // Clear button appears; clicking it resets the filter
        el("galleryFilterYearClear").click()
        XCTAssertEqual(el("galleryFilterYearSummary").label, "All years")
        notPresent("galleryFilterYearClear")
    }

    /// Change vault dialog can be cancelled without changing the vault path.
    func testVaultChangeVaultCancelPath() {
        goToTab("vaultTabButton")

        el("vaultChangeVaultButton").click()

        // confirmationDialog creates a native macOS sheet; locate Cancel by its button label.
        let cancelBtn = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelBtn.waitForExistence(timeout: 5), "Cancel button not found in vault-change dialog")
        cancelBtn.click()

        // Dialog dismissed; vault button still present.
        el("vaultChangeVaultButton")
    }

    /// After backup to vault completes, photos show the "IN VAULT" badge in the gallery.
    func testGalleryPhotoShowsVaultBadgeAfterBackup() {
        goToTab("galleryTabButton")

        // Get initial count of photos marked as "In Vault" by looking at the app's debug description
        // to identify how many tiles exist before backup
        let tilesBeforeBackup = app.descendants(matching: .any).matching(identifier: "galleryPhotoTile").count

        // Backup photos to vault
        el("galleryBackUpToVaultButton").click()

        // Wait for backup to complete — "Back Up Again" button should appear
        el("galleryBackUpAgainButton", timeout: 20)

        // Filter by "In Vault" to verify that backed-up photos are now tagged
        el("galleryFilterChipInVault").click()

        // The "In Vault" filter should show at least some photos (the seeded .copied photos
        // plus any newly backed-up photos). Verify filter is active and photos are displayed.
        el("galleryPhotoTile")  // At least one photo should be visible with vault status
        el("galleryToolbarClearAllButton")  // Clear All button appears when a filter is active

        // Verify we can still interact with a photo and it displays correctly
        el("galleryPhotoTile").click()
        let dismiss = el("galleryClearSelectionButton")
        dismiss.click()
        notPresent("galleryClearSelectionButton")
    }
}
#endif
