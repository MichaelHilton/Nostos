import SwiftUI

@main
struct NostosApp: App {
    @AppStorage("vaultRootPath") private var vaultRootPath: String = ""

    private var launchVaultRootPath: String? {
        ProcessInfo.processInfo.environment["UI_TESTING_VAULT_ROOT"]
    }

    var body: some Scene {
        WindowGroup {
            if let vaultRootURL {
                MainAppView(vaultRootURL: vaultRootURL) { newVaultURL in
                    vaultRootPath = newVaultURL.path
                }
            } else {
                VaultSetupView { selectedURL in
                    vaultRootPath = selectedURL.path
                }
                .frame(minWidth: 900, minHeight: 600)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }

    private var vaultRootURL: URL? {
        if ProcessInfo.processInfo.environment["UI_TESTING_FORCE_SETUP"] == "1", vaultRootPath.isEmpty {
            return nil
        }

        if let launchVaultRootPath, !launchVaultRootPath.isEmpty {
            return URL(fileURLWithPath: launchVaultRootPath)
        }
        guard !vaultRootPath.isEmpty else { return nil }
        return URL(fileURLWithPath: vaultRootPath)
    }
}

private struct MainAppView: View {
    let onVaultRootChange: (URL) -> Void
    @StateObject private var appState: AppState

    init(vaultRootURL: URL, onVaultRootChange: @escaping (URL) -> Void) {
        self.onVaultRootChange = onVaultRootChange
        let rootURL = vaultRootURL
        _appState = StateObject(wrappedValue: AppState(vaultRootURL: rootURL))
    }

    var body: some View {
        ContentView(vaultRootChangeHandler: onVaultRootChange)
            .environmentObject(appState)
            .frame(minWidth: 900, minHeight: 600)
    }
}

struct AppLogoView: View {
    var body: some View {
        if let image = NSImage(contentsOfFile: Self.logoPath) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.secondary)
                }
        }
    }

    private static var logoPath: String {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return cwd.appendingPathComponent("logos/logo_square.png").path
    }
}

private struct VaultSetupView: View {
    let onChooseVault: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                AppLogoView()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Vault")
                    .font(.largeTitle).bold()
            }

            Text("Choose a folder to store copied photos and Nostos metadata. The app will keep its database and thumbnails inside that vault.")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Choose Vault…") {
                if let url = pickVaultDirectory() {
                    onChooseVault(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("chooseVaultButton")

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func pickVaultDirectory() -> URL? {
        if let uiTestingURL = ProcessInfo.processInfo.environment["UI_TESTING_VAULT_DIRECTORY_TO_PICK"], !uiTestingURL.isEmpty {
            return URL(fileURLWithPath: uiTestingURL)
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose a vault folder"
        panel.prompt = "Select"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
