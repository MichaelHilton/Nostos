import SwiftUI
import AppKit

// MARK: - Gallery helpers

private struct PhotoMonth: Identifiable {
    let id: String  // "2024-04"
    let year: Int
    let month: Int
    let photos: [Photo]

    static let monthNames = ["January", "February", "March", "April", "May", "June",
                              "July", "August", "September", "October", "November", "December"]
    static let monthShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    var fullName: String  { Self.monthNames[month] }
    var shortName: String { Self.monthShort[month] }
}

private func groupByMonth(_ photos: [Photo]) -> [PhotoMonth] {
    var dict: [String: (year: Int, month: Int, photos: [Photo])] = [:]
    for photo in photos {
        guard let date = photo.takenAt else { continue }
        let cal = Calendar.current
        let y = cal.component(.year,  from: date)
        let m = cal.component(.month, from: date) - 1  // 0-based
        let key = "\(y)-\(String(format: "%02d", m))"
        if dict[key] == nil { dict[key] = (y, m, []) }
        dict[key]!.photos.append(photo)
    }
    // Also include photos without a date under a generic group
    let undated = photos.filter { $0.takenAt == nil }
    return dict
        .sorted { $0.key > $1.key }
        .map { PhotoMonth(id: $0.key, year: $0.value.year, month: $0.value.month, photos: $0.value.photos) }
        + (undated.isEmpty ? [] : [PhotoMonth(id: "undated", year: 0, month: 0, photos: undated)])
}

// MARK: - GalleryView

struct GalleryView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedPhoto: Photo?

    @State private var filterStatus: Set<PhotoStatus> = []
    @State private var filterCameraModels: Set<String> = []
    @State private var filterDateFrom: Date?
    @State private var filterDateTo: Date?
    @State private var filterHasDuplicates: Set<Bool> = []
    @State private var filterIncludeNoCamera: Bool = false
    @State private var filterYearFrom: Int?
    @State private var filterYearTo: Int?

    @State private var folderFormat: String = "YYYY/MM/DD"
    @State private var dryRun: Bool = true
    @State private var estimatedBackupCount: Int = 0

    @State private var tileSize: CGFloat = 145

    private var orderedYears: [Int] { state.years.sorted() }

    private var yearPhotoCounts: [Int: Int] {
        var counts: [Int: Int] = [:]
        let cal = Calendar.current
        for photo in state.photos {
            guard let date = photo.takenAt else { continue }
            counts[cal.component(.year, from: date), default: 0] += 1
        }
        return counts
    }

    var body: some View {
        HSplitView {
            // Photo grid + selected panel
            VStack(spacing: 0) {
                galleryToolbar
                Rectangle()
                    .fill(NostosTheme.border)
                    .frame(height: 1)

                if state.photos.isEmpty {
                    EmptyStateView(
                        title: "No Photos",
                        systemImage: "photo.on.rectangle",
                        description: Text("Scan a folder to import photos.")
                    )
                    .background(NostosTheme.bg)
                } else {
                    scrollableGrid
                }

                selectedPhotoPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            filterPanel
                .frame(minWidth: 216, maxWidth: 240)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: filterCameraModels)    { _ in refreshBackupCount() }
        .onChange(of: filterIncludeNoCamera) { _ in refreshBackupCount() }
        .onChange(of: filterYearFrom)        { _ in refreshBackupCount() }
        .onChange(of: filterYearTo)          { _ in refreshBackupCount() }
        .onChange(of: filterDateFrom)        { _ in refreshBackupCount() }
        .onChange(of: filterDateTo)          { _ in refreshBackupCount() }
        .onAppear { refreshBackupCount() }
    }

    // MARK: Toolbar

    private var galleryToolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 0) {
                Text("\(state.photos.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(NostosTheme.fg1)
                Text(" of \(state.totalPhotoCount) photos")
                    .font(.system(size: 11))
                    .foregroundColor(NostosTheme.fg3)
            }

            Spacer()

            // Quick filter chips
            HStack(spacing: 6) {
                Text("Filter:")
                    .font(.system(size: 10))
                    .foregroundColor(NostosTheme.fg3)
                filterChip("Duplicates", on: filterHasDuplicates.contains(true)) {
                    if filterHasDuplicates.contains(true) { filterHasDuplicates.remove(true) }
                    else { filterHasDuplicates.insert(true) }
                    applyLocalFilters()
                }
                filterChip("In Vault", on: filterStatus.contains(.copied)) {
                    if filterStatus.contains(.copied) { filterStatus.remove(.copied) }
                    else { filterStatus.insert(.copied) }
                    applyLocalFilters()
                }
            }

            toolbarSeparator

            // Tile size slider
            HStack(spacing: 7) {
                Image(systemName: "square")
                    .font(.system(size: 10))
                    .foregroundColor(NostosTheme.fg3)
                tileSizeSlider
                Image(systemName: "square.fill")
                    .font(.system(size: 14))
                    .foregroundColor(NostosTheme.fg3)
            }

            toolbarSeparator

            // Per-page menu + Prev / Next
            HStack(spacing: 6) {
                Menu {
                    Button("25")  { setPage(25) }
                    Button("50")  { setPage(50) }
                    Button("100") { setPage(100) }
                    Button("200") { setPage(200) }
                    Button("All") { setPage(Int.max) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(NostosTheme.fg2)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
                .accessibilityIdentifier("galleryPerPageMenuButton")

                let limit = state.photoFilter.limit
                if limit > 0 && limit < Int.max {
                    Button("Prev") {
                        var f = state.photoFilter
                        f.offset = max(0, f.offset - f.limit)
                        state.applyFilter(f)
                    }
                    .buttonStyle(NostosButtonStyle(variant: .bordered))
                    .disabled(state.photoFilter.offset == 0)
                    .accessibilityIdentifier("galleryPrevPageButton")

                    Button("Next") {
                        var f = state.photoFilter
                        f.offset += f.limit
                        state.applyFilter(f)
                    }
                    .buttonStyle(NostosButtonStyle(variant: .bordered))
                    .disabled(state.photos.count < state.photoFilter.limit)
                    .accessibilityIdentifier("galleryNextPageButton")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(NostosTheme.surface)
    }

    private var toolbarSeparator: some View {
        Rectangle()
            .fill(NostosTheme.border)
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    @ViewBuilder
    private func filterChip(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .foregroundColor(on ? .white : NostosTheme.fg2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(on ? NostosTheme.accent : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(on ? NostosTheme.accent : NostosTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func backupStatCell(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(NostosTheme.fg3)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(NostosTheme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(NostosTheme.border, lineWidth: 1)
        )
    }

    private var tileSizeSlider: some View {
        GeometryReader { geo in
            let thumbD: CGFloat = 20
            let trackW = geo.size.width
            let fraction = (tileSize - 80) / (220 - 80)
            let thumbX = fraction * (trackW - thumbD)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(NostosTheme.border)
                    .frame(height: 3)
                Circle()
                    .fill(NostosTheme.accent)
                    .frame(width: thumbD, height: thumbD)
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1.5)
                    .offset(x: thumbX)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let raw = max(0, min(1, (val.location.x - thumbD / 2) / (trackW - thumbD)))
                        let stepped = (80 + raw * 140) / 10
                        tileSize = max(80, min(220, CGFloat(Int(stepped.rounded()) * 10)))
                    }
            )
        }
        .frame(width: 80, height: 20)
    }

    private func setPage(_ limit: Int) {
        var f = state.photoFilter; f.limit = limit; f.offset = 0; state.applyFilter(f)
    }

    // MARK: Scrollable month-grouped grid

    private var scrollableGrid: some View {
        let groups = groupByMonth(state.photos)
        let minCols = [GridItem(.adaptive(minimum: tileSize, maximum: tileSize + 60), spacing: 5)]

        return ScrollView {
            ZStack(alignment: .topLeading) {
                StarDotBackground()
                VStack(alignment: .leading, spacing: 0) {
                    if groups.isEmpty {
                        // Flat grid fallback (photos with no date)
                        LazyVGrid(columns: minCols, spacing: 5) {
                            ForEach(state.photos) { photo in
                                PhotoTile(photo: photo,
                                          isSelected: selectedPhoto?.id == photo.id,
                                          size: tileSize)
                                    .onTapGesture {
                                        selectedPhoto = selectedPhoto?.id == photo.id ? nil : photo
                                    }
                            }
                        }
                        .padding(14)
                    } else {
                        ForEach(groups) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                // Month / year header
                                HStack(alignment: .lastTextBaseline, spacing: 10) {
                                    Text(group.id == "undated" ? "Unknown Date" : group.fullName)
                                        .font(NostosTheme.displayFont(size: 22, weight: .semibold))
                                        .foregroundColor(NostosTheme.fg1)
                                        
                                    if group.id != "undated" {
                                        Text(String(group.year))
                                            .font(NostosTheme.displayFont(size: 16))
                                            .foregroundColor(NostosTheme.fg3)
                                            .italic()
                                    }
                                    Spacer()
                                    Text("\(group.photos.count)")
                                        .font(.system(size: 10))
                                        .foregroundColor(NostosTheme.fg3)
                                }

                                LazyVGrid(columns: minCols, spacing: 5) {
                                    ForEach(group.photos) { photo in
                                        PhotoTile(photo: photo,
                                                  isSelected: selectedPhoto?.id == photo.id,
                                                  size: tileSize)
                                            .onTapGesture {
                                                selectedPhoto = selectedPhoto?.id == photo.id ? nil : photo
                                            }
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .padding(.bottom, 8)
                        }

                        // Load more
                        if state.photos.count >= state.photoFilter.limit + state.photoFilter.offset {
                            Button("Load More") {
                                var f = state.photoFilter
                                f.offset += f.limit
                                state.applyFilter(f)
                            }
                            .buttonStyle(NostosButtonStyle(variant: .bordered))
                            .padding()
                            .accessibilityIdentifier("galleryLoadMoreButton")
                        }
                    }
                }
            }
        }
        .background(NostosTheme.bg)
    }

    // MARK: Selected photo panel

    @ViewBuilder
    private var selectedPhotoPanel: some View {
        if let photo = selectedPhoto {
            VStack(spacing: 0) {
                Rectangle().fill(NostosTheme.border).frame(height: 1)
                HStack(alignment: .top, spacing: 12) {
                    // Thumbnail
                    Group {
                        if let path = photo.thumbnailPath,
                           let img = ThumbnailService.loadImage(path: path) {
                            Image(nsImage: img)
                                .resizable().scaledToFill()
                        } else {
                            Rectangle()
                                .fill(NostosTheme.surface2)
                                .overlay(ProgressView().scaleEffect(0.7))
                        }
                    }
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(URL(fileURLWithPath: photo.path).lastPathComponent)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(NostosTheme.fg1)
                                .lineLimit(1)
                            Spacer()
                            Button("Dismiss") { selectedPhoto = nil }
                                .buttonStyle(NostosButtonStyle(variant: .plain))
                                .font(.system(size: 11))
                                .accessibilityIdentifier("galleryClearSelectionButton")
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            metaRow("Camera", photo.cameraModel ?? photo.cameraMake ?? "—")
                            metaRow("Date", photo.takenAt.map {
                                $0.formatted(date: .abbreviated, time: .omitted)
                            } ?? "—")
                            metaRow("Size", ByteCountFormatter.string(fromByteCount: photo.fileSize, countStyle: .file))
                            if let w = photo.width, let h = photo.height {
                                metaRow("Dims", "\(w) × \(h)")
                            }
                            metaRow("Status", photo.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                            metaRow("Format", URL(fileURLWithPath: photo.path).pathExtension.uppercased())
                        }
                        .font(.system(size: 11))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(NostosTheme.surface)
            }
        }
    }

    @ViewBuilder private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundColor(NostosTheme.fg3)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .foregroundColor(NostosTheme.fg1)
                .lineLimit(1)
        }
    }

    // MARK: Filter panel

    private var filterPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(NostosTheme.border).frame(height: 1)

                VStack(alignment: .leading, spacing: 0) {
                    filterSection("Status") {
                        ForEach(PhotoStatus.allCases, id: \.self) { s in
                            checkRow(s.rawValue == "copied" ? "In Vault" : s.rawValue.capitalized,
                                     on: filterStatus.contains(s)) {
                                if filterStatus.contains(s) { filterStatus.remove(s) }
                                else { filterStatus.insert(s) }
                                applyLocalFilters()
                            }
                        }
                    }

                    divider()

                    filterSection("Camera") {
                        if state.cameraModels.isEmpty {
                            Text("No camera models")
                                .font(.system(size: 11))
                                .foregroundColor(NostosTheme.fg3)
                        }
                        ForEach(state.cameraModels, id: \.self) { model in
                            checkRow(model, on: filterCameraModels.contains(model)) {
                                if filterCameraModels.contains(model) { filterCameraModels.remove(model) }
                                else { filterCameraModels.insert(model) }
                                applyLocalFilters()
                            }
                        }
                        checkRow("No camera", on: filterIncludeNoCamera) {
                            filterIncludeNoCamera.toggle()
                            applyLocalFilters()
                        }
                    }

                    divider()

                    filterSection("Duplicates") {
                        checkRow("With duplicates", on: filterHasDuplicates.contains(true)) {
                            if filterHasDuplicates.contains(true) { filterHasDuplicates.remove(true) }
                            else { filterHasDuplicates.insert(true) }
                            applyLocalFilters()
                        }
                        checkRow("No duplicates", on: filterHasDuplicates.contains(false)) {
                            if filterHasDuplicates.contains(false) { filterHasDuplicates.remove(false) }
                            else { filterHasDuplicates.insert(false) }
                            applyLocalFilters()
                        }
                    }

                    divider()

                    filterSection("Year Range") {
                        if orderedYears.isEmpty {
                            Text("No year data")
                                .font(.system(size: 11))
                                .foregroundColor(NostosTheme.fg3)
                        } else {
                            YearRangeSlider(
                                years: orderedYears,
                                lowerYear: filterYearFrom,
                                upperYear: filterYearTo,
                                onChange: { lower, upper in updateYearRange(lower: lower, upper: upper) },
                                photoCounts: yearPhotoCounts
                            )
                        }
                    }

                    divider()

                    filterSection("Back Up to Vault") {
                        HStack(spacing: 0) {
                            Text("\(estimatedBackupCount)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(NostosTheme.fg1)
                            Text(" photos to back up")
                                .font(.system(size: 13))
                                .foregroundColor(NostosTheme.fg2)
                        }

                        let bp = state.backupProgress
                        let backupDone = !bp.isRunning && bp.total > 0 && (bp.copied + bp.skipped >= bp.total)
                        if backupDone {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(NostosTheme.green)
                                Text("Backup complete")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(NostosTheme.green)
                            }

                            Button(action: startBackup) {
                                Text("Back Up Again")
                                    .font(.system(size: 13, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .foregroundColor(NostosTheme.fg1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(NostosTheme.surface2)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(NostosTheme.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(state.vaultRootURL == nil || estimatedBackupCount == 0)
                        } else if bp.isRunning || (bp.copied + bp.skipped > 0 && bp.total > 0) {
                            // Progress bar + pause/resume button
                            HStack(spacing: 8) {
                                NostosProgressBar(value: bp.fraction, color: NostosTheme.accent)
                                    .frame(height: 6)

                                Button {
                                    if bp.isPaused { state.resumeBackup() }
                                    else { state.pauseBackup() }
                                } label: {
                                    Image(systemName: bp.isPaused ? "play.fill" : "pause.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(NostosTheme.fg2)
                                        .frame(width: 32, height: 32)
                                        .background(NostosTheme.surface2)
                                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .stroke(NostosTheme.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            // Stat cells
                            HStack(spacing: 6) {
                                backupStatCell("Copied",  value: "\(bp.copied)",  color: NostosTheme.green)
                                backupStatCell("Skipped", value: "\(bp.skipped)", color: NostosTheme.orange)
                                backupStatCell("Total",   value: "\(bp.total)",   color: NostosTheme.fg1)
                            }

                            // Paused status
                            if bp.isPaused {
                                Text("Paused — \(Int(bp.fraction * 100))% complete")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(NostosTheme.orange)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        } else {
                            Button(action: startBackup) {
                                HStack(spacing: 7) {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Back Up to Vault")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(NostosTheme.accent)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(state.vaultRootURL == nil || estimatedBackupCount == 0)
                            .accessibilityIdentifier("backupRunButton")
                        }
                    }

                    divider()

                    HStack {
                        Spacer()
                        Button("Clear All Filters") {
                            filterStatus.removeAll()
                            filterCameraModels.removeAll()
                            filterHasDuplicates.removeAll()
                            filterIncludeNoCamera = false
                            filterYearFrom = nil; filterYearTo = nil
                            state.applyFilter(PhotoFilter())
                            refreshBackupCount()
                        }
                        .buttonStyle(NostosButtonStyle(variant: .danger))
                        .font(.system(size: 11))
                        .accessibilityIdentifier("galleryRemoveAllFiltersButton")
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .background(NostosTheme.surface)
    }

    @ViewBuilder
    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: title)
            content()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private func divider() -> some View {
        Rectangle()
            .fill(NostosTheme.border)
            .frame(height: 1)
    }

    @ViewBuilder
    private func checkRow(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .foregroundColor(on ? NostosTheme.accent : NostosTheme.fg3)
                    .font(.system(size: 13))
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(NostosTheme.fg2)
                    .lineLimit(1)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

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
        f.yearFrom = filterYearFrom; f.yearTo = filterYearTo
        f.dateFrom = filterDateFrom; f.dateTo = filterDateTo
        f.limit = Int.max; f.offset = 0
        return f
    }

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

    private func updateYearRange(lower: Int?, upper: Int?) {
        let normalized = normalizeYearRange(lower: lower, upper: upper)
        filterYearFrom = normalized.lower; filterYearTo = normalized.upper
        applyLocalFilters()
    }

    private func normalizeYearRange(lower: Int?, upper: Int?) -> (lower: Int?, upper: Int?) {
        guard let minYear = orderedYears.first, let maxYear = orderedYears.last else { return (lower, upper) }
        var lo = lower, hi = upper
        if let l = lo, let h = hi, l > h { lo = h; hi = l }
        if lo == minYear { lo = nil }
        if hi == maxYear { hi = nil }
        return (lo, hi)
    }
}

// MARK: - Year Range Slider

private struct YearRangeSlider: View {
    enum Handle { case lower, upper }

    let years: [Int]
    let lowerYear: Int?
    let upperYear: Int?
    let onChange: (_ lowerYear: Int?, _ upperYear: Int?) -> Void
    var photoCounts: [Int: Int] = [:]

    @State private var activeHandle: Handle?

    private let rowH: CGFloat = 44
    private let circleD: CGFloat = 20
    private let railW: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectionSummary)
                .font(.system(size: 12).italic())
                .foregroundColor(NostosTheme.fg3)

            VStack(spacing: 0) {
                ForEach(years.indices, id: \.self) { i in
                    yearRow(for: i)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(NostosTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(NostosTheme.border, lineWidth: 1)
            )
            .coordinateSpace(name: "year-range-slider")
            .contentShape(Rectangle())
            .gesture(dragGesture)
        }
    }

    private var lowerIndex: Int { index(for: lowerYear, fallback: 0) }
    private var upperIndex: Int { index(for: upperYear, fallback: max(0, years.count - 1)) }

    @ViewBuilder
    private func yearRow(for i: Int) -> some View {
        let isLower = i == lowerIndex
        let isUpper = i == upperIndex
        let inRange = i >= lowerIndex && i <= upperIndex

        HStack(spacing: 12) {
            ZStack {
                if inRange {
                    if isLower && !isUpper {
                        Rectangle()
                            .fill(NostosTheme.accent)
                            .frame(width: railW, height: rowH / 2)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    } else if isUpper && !isLower {
                        Rectangle()
                            .fill(NostosTheme.accent)
                            .frame(width: railW, height: rowH / 2)
                            .frame(maxHeight: .infinity, alignment: .top)
                    } else if !isLower && !isUpper {
                        Rectangle()
                            .fill(NostosTheme.accent)
                            .frame(width: railW, height: rowH)
                    }
                }
                if isLower || isUpper {
                    Circle()
                        .strokeBorder(NostosTheme.accent, lineWidth: 2.5)
                        .frame(width: circleD, height: circleD)
                        .background(Circle().fill(NostosTheme.surface))
                }
            }
            .frame(width: 32, height: rowH)

            HStack(spacing: 6) {
                Text(String(years[i]))
                    .font(.system(size: 15, weight: inRange ? .bold : .regular))
                    .foregroundColor(inRange ? NostosTheme.fg2 : NostosTheme.fg3)
                if let count = photoCounts[years[i]] {
                    Text("\(count) \(count == 1 ? "photo" : "photos")")
                        .font(.system(size: 11))
                        .foregroundColor(NostosTheme.fg3)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .frame(height: rowH)
        .contentShape(Rectangle())
        .onTapGesture { moveNearestHandle(to: i) }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("year-range-slider"))
            .onChanged { val in
                guard !years.isEmpty else { return }
                if activeHandle == nil { activeHandle = handle(for: val.startLocation.y) }
                guard let h = activeHandle else { return }
                let idx = index(forLocation: val.location.y)
                switch h {
                case .lower: setLowerIndex(idx)
                case .upper: setUpperIndex(idx)
                }
            }
            .onEnded { _ in activeHandle = nil }
    }

    private func handle(for y: CGFloat) -> Handle {
        let lY = CGFloat(lowerIndex) * rowH + rowH / 2
        let uY = CGFloat(upperIndex) * rowH + rowH / 2
        return abs(y - lY) <= abs(y - uY) ? .lower : .upper
    }

    private func index(forLocation y: CGFloat) -> Int {
        min(max(0, Int(y / rowH)), years.count - 1)
    }

    private func index(for year: Int?, fallback: Int) -> Int {
        guard let year, let i = years.firstIndex(of: year) else { return fallback }
        return i
    }

    private func moveNearestHandle(to i: Int) {
        if abs(i - lowerIndex) <= abs(i - upperIndex) { setLowerIndex(i) }
        else { setUpperIndex(i) }
    }

    private func setLowerIndex(_ i: Int) {
        guard !years.isEmpty else { return }
        let c = min(max(0, i), upperIndex)
        onChange(c == 0 ? nil : years[c], upperYear)
    }

    private func setUpperIndex(_ i: Int) {
        guard !years.isEmpty else { return }
        let c = max(min(i, years.count - 1), lowerIndex)
        onChange(lowerYear, c == years.count - 1 ? nil : years[c])
    }

    private var selectionSummary: String {
        if lowerYear == nil && upperYear == nil { return "All years" }
        return "\(lowerYear.map(String.init) ?? "Any") – \(upperYear.map(String.init) ?? "Any")"
    }
}

// MARK: - PhotoTile

struct PhotoTile: View {
    let photo: Photo
    let isSelected: Bool
    var size: CGFloat = 145
    @State private var image: NSImage?
    @State private var hovered = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let img = image {
                    Image(nsImage: img).resizable().scaledToFill()
                } else {
                    Rectangle()
                        .fill(NostosTheme.surface2)
                        .overlay(ProgressView().scaleEffect(0.6))
                }
            }
            .frame(width: size, height: size)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            // Hover/selection gradient overlay
            if hovered || isSelected {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.68)],
                    startPoint: .center, endPoint: .bottom
                )
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // File name + date
                VStack(alignment: .leading, spacing: 1) {
                    Text(URL(fileURLWithPath: photo.path).lastPathComponent)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(1)
                    if let date = photo.takenAt {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.65))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 5)
            }

            // Badges — top left
            if photo.duplicateGroupId != nil || photo.status == .copied {
                HStack(spacing: 3) {
                    if photo.duplicateGroupId != nil {
                        tileBadge("DUP", bg: NostosTheme.orange)
                    }
                    if photo.status == .copied {
                        inVaultBadge()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(4)
            }

            // Selection checkmark — top right
            if isSelected {
                Circle()
                    .fill(NostosTheme.accent)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(5)
            }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? NostosTheme.accent : Color.clear, lineWidth: 2.5)
                .padding(isSelected ? -1.25 : 0)
        )
        .scaleEffect(hovered && !isSelected ? 1.04 : 1)
        .shadow(color: .black.opacity(hovered ? 0.22 : 0), radius: 8, x: 0, y: 4)
        .animation(.spring(response: 0.18, dampingFraction: 0.64), value: hovered)
        .onHover { hovered = $0 }
        .onAppear { loadThumbnail() }
        .accessibilityIdentifier("galleryPhotoTile")
    }

    @ViewBuilder
    private func tileBadge(_ text: String, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .heavy))
            .foregroundColor(.white)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    @ViewBuilder
    private func inVaultBadge() -> some View {
        HStack(spacing: 3) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 7, weight: .bold))
            Text("In Vault")
                .font(.system(size: 8, weight: .heavy))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(NostosTheme.green)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    private func loadThumbnail() {
        guard image == nil else { return }
        let localThumbnailPath = photo.thumbnailPath
        let localPath = photo.path
        let localId = photo.id
        Task.detached(priority: .userInitiated) {
            let thumbPath: String? = {
                if let p = localThumbnailPath { return p }
                if let id = localId {
                    return ThumbnailService.thumbnail(for: id, sourceURL: URL(fileURLWithPath: localPath))
                }
                return nil
            }()
            await MainActor.run {
                if let p = thumbPath { image = ThumbnailService.loadImage(path: p) }
            }
        }
    }
}
