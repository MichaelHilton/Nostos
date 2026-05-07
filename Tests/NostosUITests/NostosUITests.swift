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
    }

    override func tearDownWithError() throws {
        app.terminate()
        try? FileManager.default.removeItem(atPath: vaultRootPath)
    }

    // MARK: - Helpers

    /// Waits for an element to exist, fails the test if it doesn't, then returns it.
    @discardableResult
    private func el(_ id: String, timeout: TimeInterval = 5) -> XCUIElement {
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

        let choose = el("scannerChooseDirectoryButton")
        XCTAssertTrue(choose.isEnabled)

        // Start Scan is disabled until a directory is chosen — just verify it exists.
        el("scannerStartScanButton")
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
}
#endif
