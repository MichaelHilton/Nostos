import Foundation
import XCTest

#if os(macOS) && !SWIFT_PACKAGE

// MARK: - Read-only tests — one shared app launch for the entire class
//
// These tests navigate and inspect state but never mutate the database. Sharing
// a single cold-start across 13 tests avoids ~60s of repeated boot overhead.

final class NostosUITests: XCTestCase {

    private static var sharedApp: XCUIApplication!
    private static var sharedVaultRootPath: String!
    private static var sharedSourceDirPath: String!

    private var app: XCUIApplication { Self.sharedApp }

    override class func setUp() {
        super.setUp()

        sharedVaultRootPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("nostos-ui-shared-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            atPath: sharedVaultRootPath,
            withIntermediateDirectories: true
        )

        sharedSourceDirPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("nostos-ui-shared-src-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            atPath: sharedSourceDirPath,
            withIntermediateDirectories: true
        )

        sharedApp = XCUIApplication()
        sharedApp.launchEnvironment["UI_TESTING_SEED_DATA"] = "1"
        sharedApp.launchEnvironment["UI_TESTING_VAULT_ROOT"] = sharedVaultRootPath
        sharedApp.launchEnvironment["UI_TESTING_VAULT_DIRECTORY_TO_PICK"] = sharedVaultRootPath
        sharedApp.launchEnvironment["UI_TESTING_SOURCE_DIRECTORY_TO_PICK"] = sharedSourceDirPath
        sharedApp.launchEnvironment["UI_TESTING"] = "1"
        sharedApp.launch()

        let tabButton = sharedApp.buttons.matching(identifier: "scannerTabButton").firstMatch
        if !tabButton.waitForExistence(timeout: 20) {
            let chooseVaultButton = sharedApp.buttons["chooseVaultButton"].firstMatch
            if chooseVaultButton.waitForExistence(timeout: 5) {
                chooseVaultButton.click()
            }
        }
        _ = tabButton.waitForExistence(timeout: 25)
    }

    override class func tearDown() {
        sharedApp.terminate()
        if let path = sharedVaultRootPath { try? FileManager.default.removeItem(atPath: path) }
        if let path = sharedSourceDirPath { try? FileManager.default.removeItem(atPath: path) }
        super.tearDown()
    }

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Waits for an element to exist, fails the test if it doesn't, then returns it.
    /// Defaults to `.button` (the most common element type) for a faster tree query;
    /// pass `.any` for tiles or other non-button elements.
    @discardableResult
    private func el(_ id: String, type: XCUIElement.ElementType = .button, timeout: TimeInterval = 5) -> XCUIElement {
        let match = app.descendants(matching: type).matching(identifier: id).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: timeout), "'\(id)' not found within \(timeout)s")
        return match
    }

    private func notPresent(_ id: String, type: XCUIElement.ElementType = .button, within timeout: TimeInterval = 2) {
        let match = app.descendants(matching: type).matching(identifier: id).firstMatch
        XCTAssertFalse(
            match.waitForExistence(timeout: timeout),
            "'\(id)' was still present after \(timeout)s"
        )
    }

    private func goToTab(_ id: String) {
        el(id).click()
    }

    // MARK: - Tab Navigation

    func testTabNavigation() {
        el("galleryPhotoTile", type: .any)

        goToTab("scannerTabButton")
        el("scannerStartScanButton")

        goToTab("duplicatesTabButton")
        el("duplicatesKeepFirstButton")

        goToTab("vaultTabButton")
        el("vaultChangeVaultButton")

        goToTab("galleryTabButton")
        el("galleryPhotoTile", type: .any)
    }

    // MARK: - Scanner Tab

    func testScannerChooseSourceDirectory() {
        goToTab("scannerTabButton")

        let scanButton = el("scannerStartScanButton")
        XCTAssertFalse(scanButton.isEnabled)

        let chooseButton = app.buttons["Choose…"].firstMatch
        XCTAssertTrue(chooseButton.waitForExistence(timeout: 3), "'Choose…' button not found within 3s")
        chooseButton.click()

        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: scanButton)
        waitForExpectations(timeout: 3)
    }

    func testScannerViewScanRuns() {
        goToTab("scannerTabButton")

        let recentScans = app.staticTexts["Recent Scans"]
        XCTAssertTrue(recentScans.waitForExistence(timeout: 3), "Recent Scans section not found")

        let seededScanPath = app.staticTexts["/tmp/ui-test-source"].firstMatch
        XCTAssertTrue(seededScanPath.waitForExistence(timeout: 3), "Seeded scan run row not found")
    }

    // MARK: - Gallery Tab

    func testGalleryPhotoSelectionAndDismiss() {
        goToTab("galleryTabButton")

        el("galleryPhotoTile", type: .any).click()
        el("galleryClearSelectionButton").click()
        notPresent("galleryClearSelectionButton")
    }

    func testGallerySidebarDuplicateFilters() {
        goToTab("galleryTabButton")

        el("galleryFilterWithDuplicates").click()
        el("galleryFilterNoDuplicates").click()
        el("galleryRemoveAllFiltersButton").click()
    }

    func testGallerySidebarStatusFilters() {
        goToTab("galleryTabButton")

        el("galleryFilterStatus_new").click()
        el("galleryFilterStatus_copied").click()
        el("galleryFilterStatus_skipped_duplicate").click()
        el("galleryRemoveAllFiltersButton").click()
    }

    func testGallerySidebarNoCameraInfoFilter() {
        goToTab("galleryTabButton")

        el("galleryFilterNoCameraInfo").click()
        el("galleryRemoveAllFiltersButton").click()
    }

    func testGallerySidebarCameraModelFilter() {
        goToTab("galleryTabButton")

        let cameraModelButton = app.buttons["Canon EOS R5"].firstMatch
        XCTAssertTrue(cameraModelButton.waitForExistence(timeout: 10), "Camera model filter not found")
        cameraModelButton.click()

        el("galleryRemoveAllFiltersButton").click()
    }

    func testGalleryYearRangeSlider() {
        goToTab("galleryTabButton")

        XCTAssertEqual(el("galleryFilterYearSummary", type: .any).label, "All years")
        notPresent("galleryFilterYearClear")

        let yearButton = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'galleryFilterYear_'")
        ).firstMatch
        XCTAssertTrue(yearButton.waitForExistence(timeout: 5), "No year labels found in year range slider")
        yearButton.click()

        XCTAssertNotEqual(el("galleryFilterYearSummary", type: .any).label, "All years")

        el("galleryFilterYearClear").click()
        XCTAssertEqual(el("galleryFilterYearSummary", type: .any).label, "All years")
        notPresent("galleryFilterYearClear")
    }

    // MARK: - Vault Tab

    func testVaultDryRunToggle() {
        goToTab("vaultTabButton")

        el("vaultPreviewButton")

        el("vaultDryRunToggle").click()
        el("vaultSaveButton")

        el("vaultDryRunToggle").click()
        el("vaultPreviewButton")
    }

    func testVaultToggleDetails() {
        goToTab("vaultTabButton")

        el("vaultToggleDetailsButton").click()
        el("vaultToggleDetailsButton").click()
    }

    func testVaultChangeVaultCancelPath() {
        goToTab("vaultTabButton")

        el("vaultChangeVaultButton").click()

        let cancelBtn = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelBtn.waitForExistence(timeout: 5), "Cancel button not found in vault-change dialog")
        cancelBtn.click()

        el("vaultChangeVaultButton")
    }

    func testErrorAlertOKButton() {
        goToTab("vaultTabButton")

        let errorOKBtn = app.buttons.matching(identifier: "errorAlertOKButton").firstMatch
        if errorOKBtn.waitForExistence(timeout: 2) {
            errorOKBtn.click()
            XCTAssertFalse(
                errorOKBtn.waitForExistence(timeout: 2),
                "Error alert should be dismissed after clicking OK"
            )
        }
    }
}

// MARK: - Mutating tests — isolated app launch per test
//
// These tests write to the database (backup, resolve duplicates, start scans).
// Each needs a clean app launch to avoid state bleed between tests.

final class NostosUIMutatingTests: XCTestCase {

    private var app: XCUIApplication!
    private var vaultRootPath: String!
    private var sourceDirectoryPath: String?

    override func setUpWithError() throws {
        continueAfterFailure = false

        vaultRootPath = (NSTemporaryDirectory() as NSString)
            .appendingPathComponent("nostos-ui-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            atPath: vaultRootPath,
            withIntermediateDirectories: true
        )

        if name.contains("testScannerStartScan") || name.contains("testScannerCancelScan") {
            let sourcePath = (NSTemporaryDirectory() as NSString)
                .appendingPathComponent("nostos-ui-source-\(UUID().uuidString)")
            try FileManager.default.createDirectory(
                atPath: sourcePath,
                withIntermediateDirectories: true
            )
            let imageData = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2m8ZkAAAAASUVORK5CYII=")!
            try imageData.write(to: URL(fileURLWithPath: sourcePath).appendingPathComponent("scan-test.png"))
            sourceDirectoryPath = sourcePath
        }

        app = XCUIApplication()
        app.launchEnvironment["UI_TESTING_SEED_DATA"] = "1"
        app.launchEnvironment["UI_TESTING_VAULT_ROOT"] = vaultRootPath
        app.launchEnvironment["UI_TESTING_VAULT_DIRECTORY_TO_PICK"] = vaultRootPath
        if name.contains("testScannerCancelScan") {
            app.launchEnvironment["UI_TESTING_SLOW_SCAN"] = "1"
        }
        app.launchEnvironment["UI_TESTING"] = "1"
        if let sourceDirectoryPath {
            app.launchEnvironment["UI_TESTING_SOURCE_DIRECTORY_TO_PICK"] = sourceDirectoryPath
        }
        app.launch()

        let tabButton = app.buttons.matching(identifier: "scannerTabButton").firstMatch
        if !tabButton.waitForExistence(timeout: 20) {
            let chooseVaultButton = app.buttons["chooseVaultButton"].firstMatch
            if chooseVaultButton.waitForExistence(timeout: 5) {
                chooseVaultButton.click()
            }
        }
        XCTAssertTrue(tabButton.waitForExistence(timeout: 25), "App failed to initialize within 45s")
    }

    override func tearDownWithError() throws {
        app.terminate()
        try? FileManager.default.removeItem(atPath: vaultRootPath)
        if let sourceDirectoryPath {
            try? FileManager.default.removeItem(atPath: sourceDirectoryPath)
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func el(_ id: String, type: XCUIElement.ElementType = .button, timeout: TimeInterval = 5) -> XCUIElement {
        let match = app.descendants(matching: type).matching(identifier: id).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: timeout), "'\(id)' not found within \(timeout)s")
        return match
    }

    private func notPresent(_ id: String, type: XCUIElement.ElementType = .button, within timeout: TimeInterval = 2) {
        let match = app.descendants(matching: type).matching(identifier: id).firstMatch
        XCTAssertFalse(
            match.waitForExistence(timeout: timeout),
            "'\(id)' was still present after \(timeout)s"
        )
    }

    private func goToTab(_ id: String) {
        el(id).click()
    }

    // MARK: - Scanner Tab

    func testScannerStartScan() {
        goToTab("scannerTabButton")

        let chooseButton = app.buttons["Choose…"].firstMatch
        XCTAssertTrue(chooseButton.waitForExistence(timeout: 3), "Choose… button not found within 3s")
        chooseButton.click()

        let scanButton = el("scannerStartScanButton")
        XCTAssertTrue(scanButton.isEnabled, "Scan button should be enabled after choosing a source folder")
        scanButton.click()

        let progressSection = app.staticTexts["Progress"].firstMatch
        XCTAssertTrue(progressSection.waitForExistence(timeout: 10), "Progress section not found after starting scan")

        let filesFound = app.staticTexts["Files Found"].firstMatch
        XCTAssertTrue(filesFound.waitForExistence(timeout: 10), "Progress metrics not shown after starting scan")
    }

    func testScannerCancelScan() {
        goToTab("scannerTabButton")

        let chooseButton = app.buttons["Choose…"].firstMatch
        XCTAssertTrue(chooseButton.waitForExistence(timeout: 3), "Choose… button not found")
        chooseButton.click()

        let scanButton = el("scannerStartScanButton")
        XCTAssertTrue(scanButton.isEnabled, "Scan button should be enabled after choosing a source folder")
        scanButton.click()

        let cancelButton = el("scannerCancelButton", timeout: 10)
        cancelButton.click()

        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: scanButton)
        waitForExpectations(timeout: 5)

        notPresent("scannerCancelButton")
    }

    // MARK: - Gallery Tab

    func testGalleryBackupToVault() {
        goToTab("galleryTabButton")

        el("galleryPhotoTile", type: .any)
        el("galleryBackUpToVaultButton").click()
        el("galleryBackUpAgainButton")
    }

    func testGalleryPhotoShowsVaultBadgeAfterBackup() {
        goToTab("galleryTabButton")

        el("galleryBackUpToVaultButton").click()
        el("galleryBackUpAgainButton", timeout: 20)

        let vaultBadge = app.staticTexts["IN VAULT"].firstMatch
        XCTAssertTrue(vaultBadge.waitForExistence(timeout: 10), "IN VAULT badge not found after backup")

        el("galleryPhotoTile", type: .any).click()
        el("galleryClearSelectionButton").click()
        notPresent("galleryClearSelectionButton")
    }

    // MARK: - Duplicates Tab

    func testDuplicatesGroupInteraction() {
        goToTab("duplicatesTabButton")

        el("duplicatePhotoTile", type: .any).click()
        el("duplicatesClearSelectionsButton").click()
        el("duplicatesKeepFirstButton").click()
    }

    func testDuplicatesKeepAllInAllGroups() {
        goToTab("duplicatesTabButton")

        el("duplicatesKeepAllButton").click()

        let resolvedBadge = app.staticTexts["Resolved"].firstMatch
        XCTAssertTrue(resolvedBadge.waitForExistence(timeout: 5), "Resolved badge not found after Keep All")
    }

    func testDuplicateGroupCardKeepFirstButton() {
        goToTab("duplicatesTabButton")

        el("duplicateKeepFirstButton").click()

        let resolvedBadge = app.staticTexts["Resolved"].firstMatch
        XCTAssertTrue(resolvedBadge.waitForExistence(timeout: 5), "Resolved badge not found after Keep First")
    }
}
#endif
