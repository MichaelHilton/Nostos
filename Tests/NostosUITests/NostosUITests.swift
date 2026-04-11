import Foundation
import XCTest

#if os(macOS)
final class NostosUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testClicksPrimaryButtonsAcrossTheApp() throws {
        try requireUITestHost()

        let fileManager = FileManager.default
        let uniqueSuffix = UUID().uuidString
        let sourceRoot = fileManager.temporaryDirectory.appendingPathComponent("nostos-ui-source-\(uniqueSuffix)")
        let vaultRoot = fileManager.temporaryDirectory.appendingPathComponent("nostos-ui-vault-\(uniqueSuffix)")
        let secondVaultRoot = fileManager.temporaryDirectory.appendingPathComponent("nostos-ui-vault-2-\(uniqueSuffix)")

        try fileManager.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: vaultRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: secondVaultRoot, withIntermediateDirectories: true)

        let app = XCUIApplication(url: try makeLaunchableAppBundle())
        app.launchEnvironment = [
            "UI_TESTING_FORCE_SETUP": "1",
            "UI_TESTING_SEED_DATA": "1",
            "UI_TESTING_SOURCE_DIRECTORY_TO_PICK": sourceRoot.path,
            "UI_TESTING_VAULT_DIRECTORY_TO_PICK": vaultRoot.path
        ]
        app.launch()

        let chooseVaultButton = app.buttons["chooseVaultButton"]
        XCTAssertTrue(chooseVaultButton.waitForExistence(timeout: 10))
        chooseVaultButton.click()

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

        let photoTile = app.otherElements.matching(identifier: "galleryPhotoTile").firstMatch
        XCTAssertTrue(photoTile.waitForExistence(timeout: 10))
        photoTile.click()

        let clearSelectionButton = app.buttons["galleryClearSelectionButton"]
        XCTAssertTrue(clearSelectionButton.waitForExistence(timeout: 5))
        clearSelectionButton.click()

        let loadMoreButton = app.buttons["galleryLoadMoreButton"]
        XCTAssertTrue(loadMoreButton.waitForExistence(timeout: 5))
        loadMoreButton.click()

        let perPageMenuButton = app.buttons["galleryPerPageMenuButton"]
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

        let toggleDetailsButton = app.buttons["vaultToggleDetailsButton"]
        XCTAssertTrue(toggleDetailsButton.waitForExistence(timeout: 5))
        toggleDetailsButton.click()

        let previewButton = app.buttons["vaultPreviewButton"]
        XCTAssertTrue(previewButton.waitForExistence(timeout: 5))
        previewButton.click()

        let changeVaultButton = app.buttons["vaultChangeVaultButton"]
        XCTAssertTrue(changeVaultButton.waitForExistence(timeout: 5))
        changeVaultButton.click()

        let confirmChangeButton = app.buttons["vaultConfirmChangeButton"]
        XCTAssertTrue(confirmChangeButton.waitForExistence(timeout: 5))
        confirmChangeButton.click()

        let scannerTabAfterChange = app.buttons["scannerTabButton"]
        XCTAssertTrue(scannerTabAfterChange.waitForExistence(timeout: 10))
        XCTAssertTrue(scannerTabAfterChange.isHittable)
    }

    private func requireUITestHost() throws {
        guard let configurationPath = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] else {
            throw XCTSkip("XCUITest requires an XCTest configuration with a target app path")
        }

        let configurationURL = URL(fileURLWithPath: configurationPath)
        let configurationData = try Data(contentsOf: configurationURL)
        let configuration = try PropertyListSerialization.propertyList(
            from: configurationData,
            options: [],
            format: nil
        ) as? [String: Any]

        guard let targetApplicationPath = configuration?["targetApplicationPath"] as? String,
              !targetApplicationPath.isEmpty else {
            throw XCTSkip("XCUITest requires a target application path")
        }
    }

    private func makeLaunchableAppBundle() throws -> URL {
        let fileManager = FileManager.default
        let testBundleURL = Bundle(for: type(of: self)).bundleURL
        let debugDirectory = testBundleURL.deletingLastPathComponent()
        let executableURL = debugDirectory.appendingPathComponent("Nostos")
        guard fileManager.fileExists(atPath: executableURL.path) else {
            throw XCTSkip("Could not locate the built Nostos executable at \(executableURL.path)")
        }

        let bundleURL = fileManager.temporaryDirectory.appendingPathComponent("NostosUITestHost-\(UUID().uuidString).app")
        let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        try fileManager.createDirectory(at: macOSURL, withIntermediateDirectories: true)

        let hostExecutableURL = macOSURL.appendingPathComponent("Nostos")
        if fileManager.fileExists(atPath: hostExecutableURL.path) {
            try fileManager.removeItem(at: hostExecutableURL)
        }
        try fileManager.copyItem(at: executableURL, to: hostExecutableURL)

        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        let infoPlist: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleExecutable": "Nostos",
            "CFBundleIdentifier": "com.github.michaelhilton.NostosUITestHost",
            "CFBundleName": "Nostos",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "12.0"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
        try data.write(to: infoPlistURL)

        return bundleURL
    }
}
#endif
