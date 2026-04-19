import XCTest
@testable import Nostos

@MainActor
final class AppStateMoreTests: XCTestCase {

    override func tearDown() {
        // Clean up any env vars we set
        unsetenv("UI_TESTING_SOURCE_DIRECTORY_TO_PICK")
        unsetenv("UI_TESTING_VAULT_DIRECTORY_TO_PICK")
        unsetenv("UI_TESTING_SEED_DATA")
        super.tearDown()
    }

    func testPickDirectoryUsesEnvVar() {
        let tmp = NSTemporaryDirectory() + "pick-src"
        setenv("UI_TESTING_SOURCE_DIRECTORY_TO_PICK", tmp, 1)
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        let picked = appState.pickDirectory()

        XCTAssertNotNil(picked)
        XCTAssertEqual(picked?.path, tmp)
    }

    func testPickVaultDirectoryUsesEnvVar() {
        let tmp = NSTemporaryDirectory() + "pick-vault"
        setenv("UI_TESTING_VAULT_DIRECTORY_TO_PICK", tmp, 1)
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        let picked = appState.pickVaultDirectory()

        XCTAssertNotNil(picked)
        XCTAssertEqual(picked?.path, tmp)
    }

    func testStartVaultWithoutVaultSetsError() {
        let db = try! AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        appState.startVault(folderFormat: "YYYY", dryRun: true)

        XCTAssertEqual(appState.errorMessage, "Select a vault before organizing files.")
    }

    func testChangeVaultRootCreatesDBAndSeedsWhenUIEnvSet() async throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.removeItem(at: tmpDir)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

        setenv("UI_TESTING_SEED_DATA", "1", 1)

        let db = try AppDatabase.makeInMemory()
        let appState = AppState(db: db)

        appState.changeVaultRoot(to: tmpDir)

        // loadInitialData was scheduled; run it to ensure state is updated
        await appState.loadInitialData()

        XCTAssertNotNil(appState.vaultRootURL)
        XCTAssertEqual(appState.vaultRootURL?.path, tmpDir.path)
        XCTAssertFalse(appState.scanRuns.isEmpty, "Expected seed to create scan runs")
        XCTAssertFalse(appState.organizeJobs.isEmpty, "Expected seed to create organize jobs")

        // cleanup
        try? FileManager.default.removeItem(at: tmpDir)
    }
}
