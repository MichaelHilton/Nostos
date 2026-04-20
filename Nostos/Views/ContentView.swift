import SwiftUI

enum Tab {
    case scanner, gallery, duplicates, vault
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    let vaultRootChangeHandler: (URL) -> Void
    @State private var selectedTab: Tab = .gallery

    var body: some View {
        HStack(spacing: 0) {
            NostosSidebar(selectedTab: $selectedTab, vaultPath: state.vaultRootURL?.path)
            Rectangle()
                .fill(NostosTheme.sidebarBorder)
                .frame(width: 1)
            ZStack {
                NostosTheme.bg.ignoresSafeArea()
                switch selectedTab {
                case .scanner:    ScannerView()
                case .gallery:    GalleryView()
                case .duplicates: DuplicatesView()
                case .vault:      VaultView(onVaultRootChange: vaultRootChangeHandler)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NostosTheme.bg)
        .modifier(ErrorAlert(state: state))
    }
}

// MARK: - Sidebar

private struct NostosSidebar: View {
    @Binding var selectedTab: Tab
    let vaultPath: String?
    @State private var hoveredTab: Tab? = nil

    private let navItems: [(Tab, String, String)] = [
        (.scanner,    "Scanner",    "magnifyingglass"),
        (.gallery,    "Gallery",    "photo.on.rectangle.angled"),
        (.duplicates, "Duplicates", "doc.on.doc"),
        (.vault,      "Vault",      "archivebox"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Logo header
            HStack(spacing: 10) {
                WaveLensLogo(size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text("nostos")
                        .font(NostosTheme.displayFont(size: 17))
                        .foregroundColor(NostosTheme.fg1)
                        
                    Text("Photo Management")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(NostosTheme.fg3)
                        .textCase(.uppercase)
                        
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(NostosTheme.sidebar)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NostosTheme.sidebarBorder)
                    .frame(height: 1)
            }

            // Nav items
            VStack(spacing: 3) {
                ForEach(navItems, id: \.0.hashValue) { tab, label, icon in
                    navItem(tab: tab, label: label, icon: icon)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 12)

            Spacer()

            // Compass rose watermark
            CompassRoseWatermark()
                .frame(width: 120, height: 120)
                .opacity(0.13)
                .padding(.bottom, -28)

            // Vault path footer
            Text(vaultPath ?? "~/Pictures/Vault")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(NostosTheme.fg3)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NostosTheme.sidebar)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(NostosTheme.sidebarBorder)
                        .frame(height: 1)
                }
        }
        .frame(width: 196)
        .background(NostosTheme.sidebar)
    }

    @ViewBuilder
    private func navItem(tab: Tab, label: String, icon: String) -> some View {
        let isActive = selectedTab == tab
        let isHov    = hoveredTab == tab && !isActive

        Button {
            selectedTab = tab
        } label: {
            Label(label, systemImage: icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundColor(isActive ? .white : isHov ? NostosTheme.fg1 : NostosTheme.fg2)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? NostosTheme.accent : isHov ? NostosTheme.surface2 : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hoveredTab = $0 ? tab : nil }
        .accessibilityIdentifier(accessibilityId(tab))
    }

    private func accessibilityId(_ tab: Tab) -> String {
        switch tab {
        case .scanner:    return "scannerTabButton"
        case .gallery:    return "galleryTabButton"
        case .duplicates: return "duplicatesTabButton"
        case .vault:      return "vaultTabButton"
        }
    }
}

// MARK: - Error alert

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
                Alert(
                    title: Text("Error"),
                    message: Text(state.errorMessage ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}
