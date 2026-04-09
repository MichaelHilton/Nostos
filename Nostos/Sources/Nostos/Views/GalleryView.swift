import SwiftUI
import AppKit

struct GalleryView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedPhoto: Photo?
    @State private var showingFilters = false

    // Filter controls (local state, applied on demand)
    @State private var filterStatus: PhotoStatus?
    @State private var filterCameraModel: String?
    @State private var filterDateFrom: Date?
    @State private var filterDateTo: Date?
    @State private var filterHasDuplicates: Bool?

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 8)]

    var body: some View {
        HSplitView {
            // Filter sidebar
            if showingFilters {
                filterPanel
                    .frame(minWidth: 200, maxWidth: 240)
            }

            // Photo grid
            VStack(spacing: 0) {
                toolbar
                Divider()
                if state.photos.isEmpty {
                    EmptyStateView(
                        title: "No Photos",
                        systemImage: "photo.on.rectangle",
                        description: Text("Scan a folder to import photos.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(state.photos) { photo in
                                PhotoTile(photo: photo)
                                    .onTapGesture { selectedPhoto = photo }
                            }
                        }
                        .padding(12)

                        // Load more
                        if state.photos.count >= state.photoFilter.limit + state.photoFilter.offset {
                            Button("Load More") {
                                var f = state.photoFilter
                                f.offset += f.limit
                                state.applyFilter(f)
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
        .navigationTitle("Gallery")
    }

    private var toolbar: some View {
        HStack {
            Text("\(state.photos.count) photos")
                .foregroundColor(.secondary)
            Spacer()
            Button {
                showingFilters.toggle()
            } label: {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var filterPanel: some View {
        Form {
            Section("Status") {
                Picker("Status", selection: $filterStatus) {
                    Text("Any").tag(PhotoStatus?.none)
                    Text("New").tag(PhotoStatus?.some(.new))
                    Text("Copied").tag(PhotoStatus?.some(.copied))
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Section("Camera") {
                Picker("Camera Model", selection: $filterCameraModel) {
                    Text("Any").tag(String?.none)
                    ForEach(state.cameraModels, id: \.self) { model in
                        Text(model).tag(String?.some(model))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Section("Duplicates") {
                Picker("Duplicates", selection: $filterHasDuplicates) {
                    Text("Any").tag(Bool?.none)
                    Text("With duplicates").tag(Bool?.some(true))
                    Text("No duplicates").tag(Bool?.some(false))
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Button("Apply Filters") {
                state.applyFilter(PhotoFilter(
                    status: filterStatus,
                    cameraModel: filterCameraModel,
                    hasDuplicates: filterHasDuplicates
                ))
            }
            .buttonStyle(.borderedProminent)

            Button("Clear") {
                filterStatus = nil
                filterCameraModel = nil
                filterHasDuplicates = nil
                state.applyFilter(PhotoFilter())
            }
            .foregroundColor(.red)
        }
        .padding(8)
        .ifAvailableFormStyleGrouped()
    }
}

// MARK: - PhotoTile

struct PhotoTile: View {
    let photo: Photo
    @State private var image: NSImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let img = image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .overlay(ProgressView().scaleEffect(0.6))
                }
            }
            .frame(width: 160, height: 160)
            .clipped()
            .cornerRadius(6)

            // Badges
            HStack(spacing: 4) {
                if photo.duplicateGroupId != nil {
                    badge("DUP", color: .orange)
                }
                if photo.status == .copied {
                    badge("✓", color: .green)
                }
            }
            .padding(4)
        }
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        guard image == nil else { return }
        Task.detached(priority: .userInitiated) {
            let loaded: NSImage? = {
                if let path = photo.thumbnailPath {
                    return ThumbnailService.loadImage(path: path)
                }
                if let photoId = photo.id {
                    let path = ThumbnailService.thumbnail(
                        for: photoId,
                        sourceURL: URL(fileURLWithPath: photo.path)
                    )
                    return path.flatMap { ThumbnailService.loadImage(path: $0) }
                }
                return nil
            }()
            await MainActor.run { image = loaded }
        }
    }

    @ViewBuilder
    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(3)
    }
}

// MARK: - PhotoDetailView

struct PhotoDetailView: View {
    @Environment(\.dismiss) var dismiss
    let photo: Photo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Photo Detail")
                    .font(.title2).bold()
                Spacer()
                Button("Close") { dismiss() }
            }

            if let path = photo.thumbnailPath, let img = ThumbnailService.loadImage(path: path) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                    .frame(maxWidth: .infinity)
            }

            if #available(macOS 13, *) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    row("Path", photo.path)
                    row("Size", ByteCountFormatter.string(fromByteCount: photo.fileSize, countStyle: .file))
                    if let date = photo.takenAt {
                        row("Taken", date.formatted(date: .long, time: .standard))
                    }
                    if let make = photo.cameraMake { row("Make", make) }
                    if let model = photo.cameraModel { row("Model", model) }
                    if let w = photo.width, let h = photo.height {
                        row("Dimensions", "\(w) × \(h)")
                    }
                    row("Status", photo.status.rawValue)
                    if photo.duplicateGroupId != nil {
                        row("Duplicate", photo.isKept ? "Yes (kept)" : "Yes")
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    simpleRow("Path", photo.path)
                    simpleRow("Size", ByteCountFormatter.string(fromByteCount: photo.fileSize, countStyle: .file))
                    if let date = photo.takenAt { simpleRow("Taken", date.formatted(date: .long, time: .standard)) }
                    if let make = photo.cameraMake { simpleRow("Make", make) }
                    if let model = photo.cameraModel { simpleRow("Model", model) }
                    if let w = photo.width, let h = photo.height { simpleRow("Dimensions", "\(w) × \(h)") }
                    simpleRow("Status", photo.status.rawValue)
                    if photo.duplicateGroupId != nil { simpleRow("Duplicate", photo.isKept ? "Yes (kept)" : "Yes") }
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 480, minHeight: 400)
    }

    @available(macOS 13, *)
    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundColor(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func simpleRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

// small helper to conditionally apply macOS 13-only modifier
fileprivate extension View {
    @ViewBuilder
    func ifAvailableFormStyleGrouped() -> some View {
        if #available(macOS 13, *) {
            self.formStyle(.grouped)
        } else {
            self
        }
    }
}
