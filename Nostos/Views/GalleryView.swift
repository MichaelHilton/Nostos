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

    // Backup options (exposed in the filter sidebar)
    @State private var folderFormat: String = "YYYY/MM/DD"
    @State private var dryRun: Bool = true
    @State private var estimatedBackupCount: Int = 0

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
                                PhotoTile(photo: photo, isSelected: selectedPhoto?.id == photo.id)
                                    .onTapGesture {
                                        selectedPhoto = selectedPhoto?.id == photo.id ? nil : photo
                                    }
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
                            .accessibilityIdentifier("galleryLoadMoreButton")
                        }
                    }
                }
                selectedPhotoPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // Filter sidebar (always visible on the right)
            filterPanel
                .frame(minWidth: 240, maxWidth: 300)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Gallery")
        .onChange(of: filterCameraModels) { _ in refreshBackupCount() }
        .onChange(of: filterIncludeNoCamera) { _ in refreshBackupCount() }
        .onChange(of: filterYearFrom) { _ in refreshBackupCount() }
        .onChange(of: filterYearTo) { _ in refreshBackupCount() }
        .onChange(of: filterDateFrom) { _ in refreshBackupCount() }
        .onChange(of: filterDateTo) { _ in refreshBackupCount() }
        .onAppear { refreshBackupCount() }
    }

    @ViewBuilder
    private var selectedPhotoPanel: some View {
        if let photo = selectedPhoto {
            GroupBox {
                HStack(alignment: .top, spacing: 16) {
                    if let path = photo.thumbnailPath, let img = ThumbnailService.loadImage(path: path) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .frame(width: 96, height: 96)
                            .overlay(ProgressView().scaleEffect(0.7))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Selected Photo")
                                .font(.headline)
                            Spacer()
                            Button("Clear") {
                                selectedPhoto = nil
                            }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("galleryClearSelectionButton")
                        }

                        Text(photo.path)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .textSelection(.enabled)

                        VStack(alignment: .leading, spacing: 4) {
                            metadataRow("Size", ByteCountFormatter.string(fromByteCount: photo.fileSize, countStyle: .file))
                            if let date = photo.takenAt {
                                metadataRow("Taken", date.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let make = photo.cameraMake {
                                metadataRow("Make", make)
                            }
                            if let model = photo.cameraModel {
                                metadataRow("Model", model)
                            }
                            if let width = photo.width, let height = photo.height {
                                metadataRow("Dimensions", "\(width) × \(height)")
                            }
                            metadataRow("Status", photo.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                            if photo.duplicateGroupId != nil {
                                metadataRow("Duplicate", photo.isKept ? "Yes, kept" : "Yes")
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("\(state.photos.count) out of \(state.totalPhotoCount) photos")
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
                    .accessibilityIdentifier("galleryPrevPageButton")

                    Text("Page \(page)")

                    Button("Next") {
                        var f = state.photoFilter
                        f.offset += f.limit
                        state.applyFilter(f)
                    }
                    .disabled(state.photos.count < state.photoFilter.limit)
                    .accessibilityIdentifier("galleryNextPageButton")
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
                    .accessibilityIdentifier("galleryPerPageMenuButton")
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

            Section("Exact date range") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        DatePicker(
                            "From",
                            selection: Binding(
                                get: { filterDateFrom ?? Date() },
                                set: { filterDateFrom = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .opacity(filterDateFrom == nil ? 0.4 : 1)
                        .onTapGesture { if filterDateFrom == nil { filterDateFrom = Date() } }

                        Text("–").foregroundColor(.secondary)

                        DatePicker(
                            "To",
                            selection: Binding(
                                get: { filterDateTo ?? Date() },
                                set: { filterDateTo = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .opacity(filterDateTo == nil ? 0.4 : 1)
                        .onTapGesture { if filterDateTo == nil { filterDateTo = Date() } }

                        if filterDateFrom != nil || filterDateTo != nil {
                            Button("Clear") {
                                filterDateFrom = nil
                                filterDateTo = nil
                                applyLocalFilters()
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("Backup") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Folder Format")
                            .frame(width: 90, alignment: .trailing)
                        TextField("YYYY/MM/DD", text: $folderFormat)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                    }

                    Toggle("Dry Run (preview only)", isOn: $dryRun)

                    HStack {
                        Image(systemName: "photo.stack")
                            .foregroundColor(.secondary)
                        Text("**\(estimatedBackupCount)** photo\(estimatedBackupCount == 1 ? "" : "s") match current filter")
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    HStack {
                        Spacer()
                        Button(action: startBackup) {
                            Label(
                                state.backupProgress.isRunning
                                    ? "Backing up…"
                                    : (dryRun ? "Preview" : "Back Up Now"),
                                systemImage: state.backupProgress.isRunning ? "stop.circle" : "tray.and.arrow.down.fill"
                            )
                        }
                        .disabled(state.vaultRootURL == nil || state.backupProgress.isRunning || estimatedBackupCount == 0)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(dryRun ? "backupPreviewButton" : "backupRunButton")
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
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
                    // refresh backup count when clearing filters
                    refreshBackupCount()
                }
                .foregroundColor(.red)
                .accessibilityIdentifier("galleryRemoveAllFiltersButton")
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ifAvailableFormStyleGrouped()
    }

    // Keep the backup count in sync with local filter selections
    private func refreshBackupCount() {
        estimatedBackupCount = state.countPhotosForBackup(filter: currentBackupFilter)
    }

    private func startBackup() {
        state.startBackup(folderFormat: folderFormat, filter: currentBackupFilter, dryRun: dryRun)
    }

    private var currentBackupFilter: PhotoFilter {
        var f = PhotoFilter()
        f.cameraModels = filterCameraModels
        f.includeNoCamera = filterIncludeNoCamera
        f.yearFrom = filterYearFrom
        f.yearTo = filterYearTo
        f.dateFrom = filterDateFrom
        f.dateTo = filterDateTo
        f.limit = Int.max
        f.offset = 0
        return f
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
    private let tickWidth: CGFloat = 10
    private let tickHeight: CGFloat = 2
    private let handleWidth: CGFloat = 14
    private let handleHeight: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Year Range", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(selectionSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 0) {
                    Text("Older")
                    Spacer(minLength: 0)
                    Text("Newer")
                }
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundColor(.secondary)
                .frame(width: 40, height: CGFloat(years.count) * rowHeight - 4, alignment: .leading)
                .padding(.top, 2)

                ZStack(alignment: .topLeading) {
                    if years.count > 1 {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.secondary.opacity(0.10),
                                        Color.secondary.opacity(0.22),
                                        Color.secondary.opacity(0.10)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: railWidth, height: CGFloat(years.count - 1) * rowHeight)
                            .padding(.leading, railInset + (handleWidth - railWidth) / 2)
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
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.12))
            )
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

        HStack(spacing: 12) {
            ZStack {
                if index > 0 {
                    Capsule()
                        .fill(isInRange ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.14))
                        .frame(width: tickWidth, height: tickHeight)
                }

                if isLower || isUpper {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.96),
                                    Color.accentColor.opacity(0.82)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: handleWidth, height: handleHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.70), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.14), radius: 1.5, x: 0, y: 1)
                        .offset(x: -1)
                }
            }
            .frame(width: 36, height: rowHeight)

            Text(String(years[index]))
                .font(.system(size: 19, weight: isInRange ? .semibold : .medium, design: .rounded).monospacedDigit())
                .foregroundColor(isInRange ? .primary : Color.primary.opacity(0.58))
                .padding(.vertical, 2)
                .padding(.horizontal, 2)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isInRange ? Color.accentColor.opacity(0.08) : Color.clear)
                )

            Spacer()
        }
        .padding(.horizontal, 2)
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

    private var selectionSummary: String {
        let lowerText = lowerYear.map(String.init) ?? "Any"
        let upperText = upperYear.map(String.init) ?? "Any"
        return "\(lowerText) - \(upperText)"
    }
}

// MARK: - PhotoTile

struct PhotoTile: View {
    let photo: Photo
    let isSelected: Bool
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

            if isSelected {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.05),
                        Color.black.opacity(0.65)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: 160, height: 160)
                .cornerRadius(6)
            }

            // Badges
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    if photo.duplicateGroupId != nil {
                        badge("DUP", color: .orange)
                    }
                    if photo.status == .copied {
                        badge("✓", color: .green)
                    }
                    if isSelected {
                        badge("Selected", color: .blue)
                    }
                }

                if isSelected {
                    VStack(alignment: .leading, spacing: 2) {
                        if let model = photo.cameraModel {
                            Text(model)
                        }
                        if let date = photo.takenAt {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.65), radius: 1, x: 0, y: 1)
                }
            }
            .padding(4)
        }
        .onAppear { loadThumbnail() }
        .accessibilityIdentifier("galleryPhotoTile")
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

private extension GalleryView {
    @ViewBuilder
    func metadataRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
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
