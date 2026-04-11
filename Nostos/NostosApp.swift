import SwiftUI

@main
struct NostosApp: App {
    @AppStorage("vaultRootPath") private var vaultRootPath: String = ""

    var body: some Scene {
        WindowGroup {
            if let vaultRootURL {
                MainAppView(vaultRootURL: vaultRootURL)
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
        guard !vaultRootPath.isEmpty else { return nil }
        return URL(fileURLWithPath: vaultRootPath)
    }
}

private struct MainAppView: View {
    @StateObject private var appState: AppState

    init(vaultRootURL: URL) {
        _appState = StateObject(wrappedValue: AppState(vaultRootURL: vaultRootURL))
    }

    var body: some View {
        ContentView()
            .environmentObject(appState)
            .frame(minWidth: 900, minHeight: 600)
    }
}

private struct VaultSetupView: View {
    let onChooseVault: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Vault")
                .font(.largeTitle).bold()

            Text("Choose a folder to store copied photos and Nostos metadata. The app will keep its database and thumbnails inside that vault.")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Choose Vault…") {
                if let url = pickVaultDirectory() {
                    onChooseVault(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func pickVaultDirectory() -> URL? {
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
