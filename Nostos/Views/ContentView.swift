import SwiftUI

enum Tab {
    case scanner, gallery, duplicates, vault
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    let vaultRootChangeHandler: (URL) -> Void
    @State private var selectedTab: Tab = .gallery

    var body: some View {
        Group {
            if #available(macOS 13, *) {
                NavigationSplitView {
                    NostosAppSidebar(selectedTab: $selectedTab, vaultPath: state.vaultRootURL?.path ?? "")
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

// MARK: - Sidebar
struct NostosAppSidebar: View {
    @Binding var selectedTab: Tab
    let vaultPath: String
    @State private var hoveredTab: Tab?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                WaveLensLogo()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("nostos")
                        .font(.nostosDisplay(size: 17, weight: .bold))
                        .foregroundColor(.nostosFg1)

                    Text("Photo Management")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.nostosFg3)
                        .textCase(.uppercase)
                }
                Spacer()
            }
            .padding(NostosSpacing.xl)
            .frame(height: 48)
            .borderBottom(width: 1, color: Color.nostosSidebarBorder)

            // Nav sections
            VStack(alignment: .leading, spacing: 0) {
                SidebarSection(title: "Catalogue", tabs: [.scanner, .gallery], selectedTab: $selectedTab, hoveredTab: $hoveredTab)
                SidebarSection(title: "Manage", tabs: [.duplicates, .vault], selectedTab: $selectedTab, hoveredTab: $hoveredTab)
            }
            .padding(NostosSpacing.sm)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            // Footer
            VStack(alignment: .leading, spacing: 4) {
                Text(vaultPath)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(.nostosFg3)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 5) {
                    Text("⌘K")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.nostosFg3)
                        .padding(.vertical, 1)
                        .padding(.horizontal, 4)
                        .border(Color.nostosSidebarBorder, width: 1)
                        .cornerRadius(3)

                    Text("Command palette")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundColor(.nostosFg3)
                }
                .opacity(0.5)
            }
            .padding(NostosSpacing.lg)
            .borderTop(width: 1, color: Color.nostosSidebarBorder)
        }
        .frame(width: 196)
        .background(Color.nostosSidebar)
    }
}

struct SidebarSection: View {
    let title: String
    let tabs: [Tab]
    @Binding var selectedTab: Tab
    @Binding var hoveredTab: Tab?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.nostosFg3)
                .textCase(.uppercase)
                .padding(.horizontal, NostosSpacing.lg)
                .padding(.bottom, NostosSpacing.xs)

            ForEach(tabs, id: \.self) { tab in
                SidebarTabButton(tab: tab, selected: selectedTab == tab, hovered: hoveredTab == tab, action: {
                    selectedTab = tab
                }, onHover: { isHovering in
                    hoveredTab = isHovering ? tab : nil
                })
            }
        }
        .padding(.vertical, NostosSpacing.sm)
    }
}

struct SidebarTabButton: View {
    let tab: Tab
    let selected: Bool
    let hovered: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void

    var tabLabel: String {
        switch tab {
        case .scanner: return "Scanner"
        case .gallery: return "Gallery"
        case .duplicates: return "Duplicates"
        case .vault: return "Vault"
        }
    }

    var tabIcon: AnyView {
        switch tab {
        case .scanner: return AnyView(ScannerIcon(active: selected))
        case .gallery: return AnyView(GalleryIcon(active: selected))
        case .duplicates: return AnyView(DuplicatesIcon(active: selected))
        case .vault: return AnyView(VaultIcon(active: selected))
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                tabIcon
                    .frame(width: 16, height: 16)
                Text(tabLabel)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                Spacer()
            }
            .foregroundColor(selected ? .white : (hovered ? .nostosFg1 : .nostosFg2))
            .padding(.horizontal, NostosSpacing.lg)
            .padding(.vertical, NostosSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.nostosAccent : (hovered ? Color.nostosSurface2 : Color.clear))
            .cornerRadius(NostosRadii.md)
            .padding(.horizontal, NostosSpacing.sm)
            .accessibilityIdentifier("\(tabLabel.lowercased())TabButton")
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
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

// MARK: - Helper extensions
extension View {
    func borderBottom(width: CGFloat, color: Color) -> some View {
        VStack(spacing: 0) {
            self
            Divider().frame(height: width).foregroundColor(color)
        }
    }

    func borderTop(width: CGFloat, color: Color) -> some View {
        VStack(spacing: 0) {
            Divider().frame(height: width).foregroundColor(color)
            self
        }
    }
}
