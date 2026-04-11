import SwiftUI

enum Tab {
    case scanner, gallery, duplicates, vault
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab: Tab = .scanner

    var body: some View {
        Group {
            if #available(macOS 13, *) {
                NavigationSplitView {
                    List(selection: $selectedTab) {
                        Label("Scanner", systemImage: "magnifyingglass")
                            .tag(Tab.scanner)
                        Label("Gallery", systemImage: "photo.on.rectangle.angled")
                            .tag(Tab.gallery)
                        Label("Duplicates", systemImage: "doc.on.doc")
                            .tag(Tab.duplicates)
                        Label("Vault", systemImage: "archivebox")
                            .tag(Tab.vault)
                    }
                    .navigationTitle("Nostos")
                } detail: {
                    switch selectedTab {
                    case .scanner:    ScannerView()
                    case .gallery:    GalleryView()
                    case .duplicates: DuplicatesView()
                    case .vault:      VaultView()
                    }
                }
            } else {
                NavigationView {
                    List {
                        Button(action: { selectedTab = .scanner }) { Label("Scanner", systemImage: "magnifyingglass") }
                        Button(action: { selectedTab = .gallery }) { Label("Gallery", systemImage: "photo.on.rectangle.angled") }
                        Button(action: { selectedTab = .duplicates }) { Label("Duplicates", systemImage: "doc.on.doc") }
                        Button(action: { selectedTab = .vault }) { Label("Vault", systemImage: "archivebox") }
                    }
                    .listStyle(SidebarListStyle())
                    .frame(minWidth: 160)

                    switch selectedTab {
                    case .scanner:    ScannerView()
                    case .gallery:    GalleryView()
                    case .duplicates: DuplicatesView()
                    case .vault:      VaultView()
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
