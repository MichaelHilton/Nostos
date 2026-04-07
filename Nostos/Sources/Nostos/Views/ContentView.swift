import SwiftUI

enum Tab {
    case scanner, gallery, duplicates, organizer
}

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab: Tab = .scanner

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("Scanner", systemImage: "magnifyingglass")
                    .tag(Tab.scanner)
                Label("Gallery", systemImage: "photo.on.rectangle.angled")
                    .tag(Tab.gallery)
                Label("Duplicates", systemImage: "doc.on.doc")
                    .tag(Tab.duplicates)
                Label("Organizer", systemImage: "folder.badge.gearshape")
                    .tag(Tab.organizer)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .navigationTitle("Nostos")
        } detail: {
            switch selectedTab {
            case .scanner:    ScannerView()
            case .gallery:    GalleryView()
            case .duplicates: DuplicatesView()
            case .organizer:  OrganizerView()
            }
        }
        .alert("Error", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("OK") { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
    }
}
