import SwiftUI
import AppKit

struct GalleryView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedPhoto: Photo?

    // Filter controls (local state, applied on demand)
    @State private var filterStatus: Set<PhotoStatus> = []
    @State private var filterCameraModels: Set<String> = []
    @State private var filterDateFrom: Date?
    @State private var filterDateTo: Date?
    @State private var filterHasDuplicates: Set<Bool> = []
    @State private var filterIncludeNoCamera: Bool = false
    @State private var filterYearFrom: Int?
    @State private var filterYearTo: Int?

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 8)]

    var body: some View {
        HSplitView {
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

            // Filter sidebar (always visible on the right)
            filterPanel
                .frame(minWidth: 200, maxWidth: 240)
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo)
        }
        .navigationTitle("Gallery")
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("\(state.photos.count) photos")
                .foregroundColor(.secondary)

            // Pagination controls
            let limit = state.photoFilter.limit
            let offset = state.photoFilter.offset
            if limit > 0 && limit < Int.max {
                let page = (offset / max(1, limit)) + 1
                HStack(spacing: 8) {
                    Button("Prev") {
                        var f = state.photoFilter
                        f.offset = max(0, f.offset - f.limit)
                        state.applyFilter(f)
                    }
                    .disabled(state.photoFilter.offset == 0)

                    Text("Page \(page)")

                    Button("Next") {
                        var f = state.photoFilter
                        f.offset += f.limit
                        state.applyFilter(f)
                    }
                    .disabled(state.photos.count < state.photoFilter.limit)
                }
            } else {
                Text("All pages")
                    .foregroundColor(.secondary)
            }

            Spacer()
            Menu {
                Button("25") { var f = state.photoFilter; f.limit = 25; f.offset = 0; state.applyFilter(f) }
                Button("50") { var f = state.photoFilter; f.limit = 50; f.offset = 0; state.applyFilter(f) }
                Button("100") { var f = state.photoFilter; f.limit = 100; f.offset = 0; state.applyFilter(f) }
                Button("200") { var f = state.photoFilter; f.limit = 200; f.offset = 0; state.applyFilter(f) }
                Button("All") { var f = state.photoFilter; f.limit = Int.max; f.offset = 0; state.applyFilter(f) }
            } label: {
                Label("Per Page", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)

            // Filters are always visible on the right
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var filterPanel: some View {
        Form {
            Section("Status") {
                ForEach(PhotoStatus.allCases, id: \ .self) { s in
                    Toggle(s.rawValue.capitalized, isOn: Binding(
                        get: { filterStatus.contains(s) },
                        set: { on in
                            if on { filterStatus.insert(s) } else { filterStatus.remove(s) }
                            applyLocalFilters()
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
            }

            Section("Camera") {
                if state.cameraModels.isEmpty {
                    Text("No camera models").foregroundColor(.secondary)
                }
                ForEach(state.cameraModels, id: \.self) { model in
                    Toggle(model, isOn: Binding(
                        get: { filterCameraModels.contains(model) },
                        set: { on in
                            if on { filterCameraModels.insert(model) } else { filterCameraModels.remove(model) }
                            applyLocalFilters()
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
                // Checkbox for images without camera metadata
                Toggle("No camera", isOn: Binding(
                    get: { filterIncludeNoCamera },
                    set: { on in filterIncludeNoCamera = on; applyLocalFilters() }
                ))
                .toggleStyle(.checkbox)
            }

            Section("Duplicates") {
                Toggle("With duplicates", isOn: Binding(
                    get: { filterHasDuplicates.contains(true) },
                    set: { on in if on { filterHasDuplicates.insert(true) } else { filterHasDuplicates.remove(true) }; applyLocalFilters() }
                ))
                .toggleStyle(.checkbox)
                Toggle("No duplicates", isOn: Binding(
                    get: { filterHasDuplicates.contains(false) },
                    set: { on in if on { filterHasDuplicates.insert(false) } else { filterHasDuplicates.remove(false) }; applyLocalFilters() }
                ))
                .toggleStyle(.checkbox)
            }

            Section("Years") {
                if state.years.isEmpty {
                    Text("No year data").foregroundColor(.secondary)
                } else {
                    HStack {
                        Picker("From", selection: Binding(get: { filterYearFrom ?? -1 }, set: { v in
                            let newFrom = v == -1 ? nil : v
                            filterYearFrom = newFrom
                            // Auto-clamp: if from > to, set to = from
                            if let f = filterYearFrom, let t = filterYearTo, f > t {
                                filterYearTo = f
                            }
                            applyLocalFilters()
                        })) {
                            Text("Any").tag(-1)
                            ForEach(state.years, id: \ .self) { y in Text(String(y)).tag(y) }
                        }
                        .labelsHidden()

                        Picker("To", selection: Binding(get: { filterYearTo ?? -1 }, set: { v in
                            let newTo = v == -1 ? nil : v
                            filterYearTo = newTo
                            // Auto-clamp: if to < from, set from = to
                            if let f = filterYearFrom, let t = filterYearTo, t < f {
                                filterYearFrom = t
                            }
                            applyLocalFilters()
                        })) {
                            Text("Any").tag(-1)
                            ForEach(state.years, id: \ .self) { y in Text(String(y)).tag(y) }
                        }
                        .labelsHidden()
                    }

                    // Validation / summary
                    let yearRangeValid: Bool = {
                        if let f = filterYearFrom, let t = filterYearTo { return f <= t }
                        return true
                    }()

                    if filterYearFrom == nil && filterYearTo == nil {
                        Text("Range: Any").foregroundColor(.secondary).font(.caption)
                    } else if yearRangeValid {
                        let fromText = filterYearFrom.map(String.init) ?? "Any"
                        let toText = filterYearTo.map(String.init) ?? "Any"
                        Text("Range: \(fromText) — \(toText)").foregroundColor(.secondary).font(.caption)
                    } else {
                        Text("Invalid range").foregroundColor(.red).font(.caption)
                    }
                }
            }

            HStack {
                Spacer()

                Button("Remove All") {
                    // Clear local selections and remove filters
                    filterStatus.removeAll()
                    filterCameraModels.removeAll()
                    filterHasDuplicates.removeAll()
                    filterIncludeNoCamera = false
                    filterYearFrom = nil
                    filterYearTo = nil
                    state.applyFilter(PhotoFilter())
                }
                .foregroundColor(.red)
            }
        }
        .padding(8)
        .ifAvailableFormStyleGrouped()
        .onAppear { }
    }

    // Apply the local filter selections to the global state
    private func applyLocalFilters() {
        state.applyFilter(PhotoFilter(
            status: filterStatus,
            cameraModels: filterCameraModels,
            dateFrom: filterDateFrom,
            dateTo: filterDateTo,
            yearFrom: filterYearFrom,
            yearTo: filterYearTo,
            hasDuplicates: filterHasDuplicates,
            includeNoCamera: filterIncludeNoCamera
        ))
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
        // Capture only Sendable values for the detached task
        let localThumbnailPath = photo.thumbnailPath
        let localPath = photo.path
        let localId = photo.id

        Task.detached(priority: .userInitiated) {
            // Compute thumbnail path on background thread using Sendable values
            let thumbPath: String? = {
                if let p = localThumbnailPath { return p }
                if let id = localId {
                    return ThumbnailService.thumbnail(for: id, sourceURL: URL(fileURLWithPath: localPath))
                }
                return nil
            }()

            await MainActor.run {
                if let p = thumbPath {
                    image = ThumbnailService.loadImage(path: p)
                }
            }
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
