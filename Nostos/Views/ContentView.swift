import SwiftUI

enum Tab {
    case scanner, gallery, duplicates, vault
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    let vaultRootChangeHandler: (URL) -> Void
    @State private var selectedTab: Tab = .scanner

    var body: some View {
        Group {
            if #available(macOS 13, *) {
                NavigationSplitView {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { selectedTab = .scanner }) {
                            Label("Scanner", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("scannerTabButton")

                        Button(action: { selectedTab = .gallery }) {
                            Label("Gallery", systemImage: "photo.on.rectangle.angled")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("galleryTabButton")

                        Button(action: { selectedTab = .duplicates }) {
                            Label("Duplicates", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("duplicatesTabButton")

                        Button(action: { selectedTab = .vault }) {
                            Label("Vault", systemImage: "archivebox")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("vaultTabButton")

                        Spacer()
                    }
                    .padding(16)
                    .frame(minWidth: 180, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .navigationTitle("")
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            HStack(spacing: 10) {
                                AppLogoView()
                                    .frame(width: 24, height: 24)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                Text("Nostos")
                                    .font(.headline)
                            }
                        }
                    }
                } detail: {
                    switch selectedTab {
                    case .scanner:    ScannerView()
                    case .gallery:    GalleryView()
                    case .duplicates: DuplicatesView()
                    case .vault:      VaultView(onVaultRootChange: vaultRootChangeHandler)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NavigationView {
                    List {
                        Button(action: { selectedTab = .scanner }) { Label("Scanner", systemImage: "magnifyingglass") }
                            .accessibilityIdentifier("scannerTabButton")
                        Button(action: { selectedTab = .gallery }) { Label("Gallery", systemImage: "photo.on.rectangle.angled") }
                            .accessibilityIdentifier("galleryTabButton")
                        Button(action: { selectedTab = .duplicates }) { Label("Duplicates", systemImage: "doc.on.doc") }
                            .accessibilityIdentifier("duplicatesTabButton")
                        Button(action: { selectedTab = .vault }) { Label("Vault", systemImage: "archivebox") }
                            .accessibilityIdentifier("vaultTabButton")
                    }
                    .listStyle(SidebarListStyle())
                    .frame(minWidth: 160)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            HStack(spacing: 10) {
                                AppLogoView()
                                    .frame(width: 24, height: 24)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                Text("Nostos")
                                    .font(.headline)
                            }
                        }
                    }

                    switch selectedTab {
                    case .scanner:    ScannerView()
                    case .gallery:    GalleryView()
                    case .duplicates: DuplicatesView()
                    case .vault:      VaultView(onVaultRootChange: vaultRootChangeHandler)
                    }
                }
                .navigationTitle("Nostos")
            }
        }
        .modifier(ErrorAlert(state: state))
    }
}

fileprivate struct ErrorAlert: ViewModifier {
    @ObservedObject var state: AppState

    func body(content: Content) -> some View {
        if #available(macOS 13, *) {
            content.alert("Error", isPresented: Binding(
                get: { state.errorMessage != nil },
                set: { if !$0 { state.errorMessage = nil } }
            )) {
                Button("OK") { state.errorMessage = nil }
                    .accessibilityIdentifier("errorAlertOKButton")
            } message: {
                Text(state.errorMessage ?? "")
            }
        } else {
            content.alert(isPresented: Binding(
                get: { state.errorMessage != nil },
                set: { if !$0 { state.errorMessage = nil } }
            )) {
                Alert(title: Text("Error"), message: Text(state.errorMessage ?? ""), dismissButton: .default(Text("OK")) )
            }
        }
    }
}
