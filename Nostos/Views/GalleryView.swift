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

    private var orderedYears: [Int] {
        state.years.sorted()
    }

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
                .frame(minWidth: 240, maxWidth: 300)
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var filterPanel: some View {
        Form {
            Section("Status") {
                ForEach(PhotoStatus.allCases, id: \.self) { s in
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
                if orderedYears.isEmpty {
                    Text("No year data").foregroundColor(.secondary)
                } else {
                    YearRangeSlider(
                        years: orderedYears,
                        lowerYear: filterYearFrom,
                        upperYear: filterYearTo,
                        onChange: { lower, upper in
                            updateYearRange(lower: lower, upper: upper)
                        }
                    )
                    .frame(height: max(CGFloat(orderedYears.count) * 30, 160))

                    Text(yearRangeSummary)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            HStack {
                Spacer()

                Button("Remove All") {
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

    private var yearRangeSummary: String {
        if filterYearFrom == nil && filterYearTo == nil {
            return "Range: Any"
        }

        let fromText = filterYearFrom.map(String.init) ?? "Any"
        let toText = filterYearTo.map(String.init) ?? "Any"
        return "Range: \(fromText) — \(toText)"
    }

    private func updateYearRange(lower: Int?, upper: Int?) {
        let normalized = normalizeYearRange(lower: lower, upper: upper)
        filterYearFrom = normalized.lower
        filterYearTo = normalized.upper
        applyLocalFilters()
    }

    private func normalizeYearRange(lower: Int?, upper: Int?) -> (lower: Int?, upper: Int?) {
        guard let minYear = orderedYears.first, let maxYear = orderedYears.last else {
            return (lower, upper)
        }

        var normalizedLower = lower
        var normalizedUpper = upper

        if let lowerValue = normalizedLower, let upperValue = normalizedUpper, lowerValue > upperValue {
            normalizedLower = upperValue
            normalizedUpper = lowerValue
        }

        if normalizedLower == minYear {
            normalizedLower = nil
        }
        if normalizedUpper == maxYear {
            normalizedUpper = nil
        }

        return (normalizedLower, normalizedUpper)
    }
}

private struct YearRangeSlider: View {
    enum Handle {
        case lower
        case upper
    }

    let years: [Int]
    let lowerYear: Int?
    let upperYear: Int?
    let onChange: (_ lowerYear: Int?, _ upperYear: Int?) -> Void

    @State private var activeHandle: Handle?

    private let rowHeight: CGFloat = 30
    private let railWidth: CGFloat = 2
    private let railInset: CGFloat = 14
    private let dotSize: CGFloat = 8
    private let handleSize: CGFloat = 18

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Older")
                Spacer()
                Text("Newer")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            ZStack(alignment: .topLeading) {
                if years.count > 1 {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: railWidth, height: CGFloat(years.count - 1) * rowHeight)
                        .padding(.leading, railInset + (handleSize - railWidth) / 2)
                        .padding(.top, rowHeight / 2)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(years.indices, id: \.self) { index in
                        yearRow(for: index)
                            .frame(height: rowHeight)
                    }
                }
            }
            .coordinateSpace(name: "year-range-slider")
            .contentShape(Rectangle())
            .gesture(dragGesture)
        }
    }

    private var lowerIndex: Int {
        index(for: lowerYear, fallback: 0)
    }

    private var upperIndex: Int {
        index(for: upperYear, fallback: max(0, years.count - 1))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("year-range-slider"))
            .onChanged { value in
                guard !years.isEmpty else { return }
                if activeHandle == nil {
                    activeHandle = handle(for: value.startLocation.y)
                }

                guard let activeHandle else { return }
                let index = index(forLocation: value.location.y)
                switch activeHandle {
                case .lower:
                    setLowerIndex(index)
                case .upper:
                    setUpperIndex(index)
                }
            }
            .onEnded { _ in
                activeHandle = nil
            }
    }

    @ViewBuilder
    private func yearRow(for index: Int) -> some View {
        let isInRange = index >= lowerIndex && index <= upperIndex
        let isLower = index == lowerIndex
        let isUpper = index == upperIndex

        HStack(spacing: 10) {
            ZStack {
                if isInRange {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.08))
                        .frame(width: 34, height: 24)
                }

                Circle()
                    .fill(isInRange ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.18))
                    .frame(width: dotSize, height: dotSize)

                if isLower && isUpper {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: handleSize, height: handleSize)
                        .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 2))
                } else if isLower {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: handleSize, height: handleSize)
                        .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 2))
                } else if isUpper {
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .frame(width: handleSize, height: handleSize)
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                }
            }
            .frame(width: 34, height: rowHeight)

            Text(String(years[index]))
                .font(.system(.body, design: .rounded).monospacedDigit())
                .foregroundColor(isInRange ? .primary : .secondary)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            moveNearestHandle(to: index)
        }
    }

    private func moveNearestHandle(to index: Int) {
        let lowerDistance = abs(index - lowerIndex)
        let upperDistance = abs(index - upperIndex)

        if lowerDistance <= upperDistance {
            setLowerIndex(index)
        } else {
            setUpperIndex(index)
        }
    }

    private func handle(for locationY: CGFloat) -> Handle {
        let lowerY = CGFloat(lowerIndex) * rowHeight + rowHeight / 2
        let upperY = CGFloat(upperIndex) * rowHeight + rowHeight / 2
        return abs(locationY - lowerY) <= abs(locationY - upperY) ? .lower : .upper
    }

    private func index(forLocation locationY: CGFloat) -> Int {
        guard !years.isEmpty else { return 0 }
        let rawIndex = Int(locationY / rowHeight)
        return min(max(0, rawIndex), years.count - 1)
    }

    private func index(for year: Int?, fallback: Int) -> Int {
        guard let year, let index = years.firstIndex(of: year) else {
            return fallback
        }
        return index
    }

    private func setLowerIndex(_ index: Int) {
        guard !years.isEmpty else { return }
        let clampedIndex = min(max(0, index), upperIndex)
        let newLowerYear = clampedIndex == 0 ? nil : years[clampedIndex]
        onChange(newLowerYear, upperYear)
    }

    private func setUpperIndex(_ index: Int) {
        guard !years.isEmpty else { return }
        let clampedIndex = max(min(index, years.count - 1), lowerIndex)
        let newUpperYear = clampedIndex == years.count - 1 ? nil : years[clampedIndex]
        onChange(lowerYear, newUpperYear)
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
