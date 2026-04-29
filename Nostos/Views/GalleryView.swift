import SwiftUI

struct GalleryView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedPhoto: Photo?
    @State private var hoveredPhotoId: Int64?

    // Filter state
    @State private var filterStatus: Set<PhotoStatus> = []
    @State private var filterCameraModels: Set<String> = []
    @State private var filterIncludeNoCamera: Bool = false
    @State private var filterHasDuplicates: Set<Bool> = []
    @State private var filterYearFrom: Int?
    @State private var filterYearTo: Int?
    @State private var tileSize: CGFloat = 145

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Main content
                VStack(spacing: 0) {
                    // Toolbar
                    toolbarArea

                    // Photos grid with month grouping
                    if filteredPhotos.isEmpty {
                        emptyStateArea
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 22) {
                                StarDotBackground()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                ForEach(Array(monthGroups.enumerated()), id: \.offset) { _, group in
                                    monthGroupSection(group)
                                }
                                .padding(.horizontal, NostosSpacing.lg)
                                .padding(.vertical, NostosSpacing.xxxl)
                            }
                            .background(Color.nostosBg)
                        }
                        .overlay(alignment: .topLeading) {
                            StarDotBackground()
                        }
                    }

                    // Selected photo panel
                    if let photo = selectedPhoto {
                        selectedPhotoPanel(photo)
                    }

                    // Backup footer bar
                    BackupFooterBar(matchCount: backupCandidateCount)
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)

                // Filter sidebar
                filterSidebar
                    .frame(width: 216)
                    .background(Color.nostosSurface)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .frame(width: 1)
                            .foregroundColor(Color.nostosBorder)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed properties

    private var filteredPhotos: [Photo] {
        state.photos.filter { photo in
            if !filterStatus.isEmpty && !filterStatus.contains(photo.status) { return false }
            if !filterCameraModels.isEmpty || filterIncludeNoCamera {
                let hasCamera = photo.cameraModel != nil
                if filterIncludeNoCamera && !hasCamera { return true }
                if !filterCameraModels.isEmpty && hasCamera && filterCameraModels.contains(photo.cameraModel!) { return true }
                return false
            }
            if !filterHasDuplicates.isEmpty {
                let hasDup = photo.duplicateGroupId != nil
                if filterHasDuplicates.contains(hasDup) { return true }
                return false
            }
            if let yearFrom = filterYearFrom, let date = photo.takenAt {
                if Calendar.current.component(.year, from: date) < yearFrom { return false }
            }
            if let yearTo = filterYearTo, let date = photo.takenAt {
                if Calendar.current.component(.year, from: date) > yearTo { return false }
            }
            return true
        }
    }

    private var monthGroups: [MonthGroup] {
        var groups: [MonthKey: [Photo]] = [:]
        for photo in filteredPhotos {
            let key: MonthKey
            if let date = photo.takenAt {
                let components = Calendar.current.dateComponents([.year, .month], from: date)
                key = MonthKey(year: components.year ?? 0, month: components.month ?? 0)
            } else {
                key = MonthKey(year: 0, month: 0)
            }
            groups[key, default: []].append(photo)
        }

        return groups.sorted { $0.key > $1.key }
            .map { key, photos in
                MonthGroup(year: key.year, month: key.month, photos: photos.sorted { $0.takenAt ?? Date.distantFuture > $1.takenAt ?? Date.distantFuture })
            }
    }

    private var backupCandidateCount: Int {
        filteredPhotos.filter { $0.status != .copied }.count
    }

    // MARK: - UI Components

    @ViewBuilder
    private var toolbarArea: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("\(filteredPhotos.count) of \(state.totalPhotoCount) photos")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.nostosFg3)

                Spacer()

                HStack(spacing: 6) {
                    Text("Filter:")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.nostosFg3)

                    filterChip("Duplicates", isActive: filterHasDuplicates.contains(true)) {
                        if filterHasDuplicates.contains(true) {
                            filterHasDuplicates.remove(true)
                        } else {
                            filterHasDuplicates.insert(true)
                        }
                        applyLocalFilters()
                    }

                    filterChip("In Vault", isActive: filterStatus.contains(.copied)) {
                        if filterStatus.contains(.copied) {
                            filterStatus.remove(.copied)
                        } else {
                            filterStatus.insert(.copied)
                        }
                        applyLocalFilters()
                    }

                    if isFiltered {
                        Button("Clear all") {
                            clearFilters()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.nostosAccent)
                    }

                    Divider()
                        .frame(height: 16)

                    HStack(spacing: 7) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 13))
                            .foregroundColor(.nostosFg3)
                            .opacity(0.4)

                        Slider(value: $tileSize, in: 80...220, step: 10)
                            .frame(width: 72)

                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 16))
                            .foregroundColor(.nostosFg3)
                            .opacity(0.4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, NostosSpacing.lg)
            .padding(.vertical, 7)
            .background(Color.nostosSurface)

            Divider()
                .frame(height: 1)
                .background(Color.nostosBorder)
        }
    }

    private func filterChip(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(isActive ? Color.nostosAccent : Color.clear)
        .foregroundColor(isActive ? .white : .nostosFg2)
        .border(Color.nostosBorder, width: 1)
        .cornerRadius(5)
    }

    @ViewBuilder
    private var emptyStateArea: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo")
                .font(.system(size: 72, weight: .thin))
                .foregroundColor(.nostosAccent)
                .opacity(0.18)

            Text("No photos match")
                .font(.nostosDisplay(size: 24, weight: .semibold))
                .foregroundColor(.nostosFg1)

            Text("Try adjusting your filters or clearing the selection.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.nostosFg3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)

            Button(action: clearFilters) {
                Text("Clear all filters")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.nostosBg)
    }

    private func monthGroupSection(_ group: MonthGroup) -> some View {
        VStack(alignment: .leading, spacing: NostosSpacing.xl) {
            monthHeader(group)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: tileSize, maximum: tileSize), spacing: 5)], spacing: 5) {
                ForEach(group.photos) { photo in
                    photoTile(photo)
                }
            }
        }
    }

    private func monthHeader(_ group: MonthGroup) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(monthName(group.month))
                .font(.nostosDisplay(size: 22, weight: .semibold))
                .foregroundColor(.nostosFg1)

            Text(String(group.year))
                .font(.nostosDisplay(size: 16, weight: .regular))
                .foregroundColor(.nostosFg3)
                .italic()

            Spacer()

            Text("\(group.photos.count)")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.nostosFg3)
        }
    }

    private func photoTile(_ photo: Photo) -> some View {
        ZStack(alignment: .topTrailing) {
            // Gradient placeholder
            LinearGradient(gradient: Gradient(colors: [Color.nostosAccent.opacity(0.3), Color.nostosAccent.opacity(0.1)]), startPoint: .topLeading, endPoint: .bottomTrailing)

            // Thumbnail
            if let thumbPath = photo.thumbnailPath, let img = ThumbnailService.loadImage(path: thumbPath) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            }

            // Hover overlay
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                LinearGradient(gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.68)]), startPoint: .top, endPoint: .bottom)
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(photo.path.split(separator: "/").last.map(String.init) ?? "")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(1)

                            Text(dateLabel(photo.takenAt))
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        .padding(6)
                    }
            }
            .opacity(hoveredPhotoId == photo.id || selectedPhoto?.id == photo.id ? 1 : 0)
            .animation(.easeInOut(duration: 0.15), value: hoveredPhotoId)

            // Badges (top-left)
            HStack(spacing: 3) {
                if photo.duplicateGroupId != nil {
                    Badge(label: "DUP", bg: Color.nostosOrange)
                }
                if photo.status == .copied {
                    VaultBadge()
                }
                Spacer()
            }
            .padding(4)

            // Selection checkmark (top-right)
            if selectedPhoto?.id == photo.id {
                Circle()
                    .fill(Color.nostosAccent)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .padding(5)
            }
        }
        .frame(height: tileSize)
        .cornerRadius(NostosRadii.md)
        .clipped()
        .border(selectedPhoto?.id == photo.id ? Color.nostosAccent : Color.clear, width: 2.5)
        .onHover { hovering in
            hoveredPhotoId = hovering ? photo.id : nil
        }
        .onTapGesture {
            if selectedPhoto?.id == photo.id {
                selectedPhoto = nil
            } else {
                selectedPhoto = photo
            }
        }
    }

    private func selectedPhotoPanel(_ photo: Photo) -> some View {
        HStack(alignment: .top, spacing: NostosSpacing.lg) {
            // Thumbnail
            if let thumbPath = photo.thumbnailPath, let img = ThumbnailService.loadImage(path: thumbPath) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 68, height: 68)
                    .cornerRadius(7)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.nostosSurface2)
                    .frame(width: 68, height: 68)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(photo.path.split(separator: "/").last.map(String.init) ?? "")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.nostosFg1)
                        .lineLimit(1)

                    Spacer()

                    Button("Dismiss") {
                        selectedPhoto = nil
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.nostosAccent)
                }

                VStack(alignment: .leading, spacing: 0) {
                    metadataGrid(photo)
                }
                .font(.system(size: 11, weight: .regular))
            }
        }
        .padding(NostosSpacing.lg)
        .padding(.vertical, 11)
        .borderTop(width: 1, color: Color.nostosBorder)
        .background(Color.nostosSurface)
    }

    private func metadataGrid(_ photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                metaRow("Camera", photo.cameraModel ?? "—")
                metaRow("Date", dateLabel(photo.takenAt))
                metaRow("Size", ByteCountFormatter.string(fromByteCount: photo.fileSize, countStyle: .file))
                metaRow("Dims", photo.width.map { w in "\(w) × \(photo.height ?? 0)" } ?? "—")
                metaRow("Status", photo.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                metaRow("Format", photo.path.split(separator: ".").last.map(String.init)?.uppercased() ?? "—")
            }
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: NostosSpacing.lg) {
            Text(label)
                .foregroundColor(.nostosFg3)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .foregroundColor(.nostosFg1)
                .lineLimit(1)
            Spacer()
        }
    }

    @ViewBuilder
    private var filterSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Backup Status
                SectionLabel("Backup Status", diamond: true)
                    .padding(.horizontal, NostosSpacing.lg)
                    .padding(.top, NostosSpacing.lg)

                ForEach([PhotoStatus.new, .copied, .skippedDuplicate], id: \.self) { status in
                    filterCheckbox(status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized, isChecked: filterStatus.contains(status)) {
                        if filterStatus.contains(status) {
                            filterStatus.remove(status)
                        } else {
                            filterStatus.insert(status)
                        }
                        applyLocalFilters()
                    }
                }
                .padding(.horizontal, NostosSpacing.lg)
                .padding(.bottom, NostosSpacing.lg)

                Divider()
                    .padding(.horizontal, NostosSpacing.lg)
                    .padding(.vertical, NostosSpacing.lg)

                // Camera
                SectionLabel("Camera", diamond: true)
                    .padding(.horizontal, NostosSpacing.lg)

                ForEach(state.cameraModels, id: \.self) { model in
                    filterCheckbox(model, isChecked: filterCameraModels.contains(model)) {
                        if filterCameraModels.contains(model) {
                            filterCameraModels.remove(model)
                        } else {
                            filterCameraModels.insert(model)
                        }
                        applyLocalFilters()
                    }
                }
                filterCheckbox("No camera info", isChecked: filterIncludeNoCamera) {
                    filterIncludeNoCamera.toggle()
                    applyLocalFilters()
                }
                .padding(.horizontal, NostosSpacing.lg)
                .padding(.bottom, NostosSpacing.lg)

                Divider()
                    .padding(.horizontal, NostosSpacing.lg)
                    .padding(.vertical, NostosSpacing.lg)

                // Duplicates
                SectionLabel("Duplicates", diamond: true)
                    .padding(.horizontal, NostosSpacing.lg)

                filterCheckbox("With duplicates", isChecked: filterHasDuplicates.contains(true)) {
                    if filterHasDuplicates.contains(true) {
                        filterHasDuplicates.remove(true)
                    } else {
                        filterHasDuplicates.insert(true)
                    }
                    applyLocalFilters()
                }
                filterCheckbox("No duplicates", isChecked: filterHasDuplicates.contains(false)) {
                    if filterHasDuplicates.contains(false) {
                        filterHasDuplicates.remove(false)
                    } else {
                        filterHasDuplicates.insert(false)
                    }
                    applyLocalFilters()
                }
                .padding(.horizontal, NostosSpacing.lg)
                .padding(.bottom, NostosSpacing.lg)

                Divider()
                    .padding(.horizontal, NostosSpacing.lg)
                    .padding(.vertical, NostosSpacing.lg)

                // Year Range
                SectionLabel("Year Range", diamond: true)
                    .padding(.horizontal, NostosSpacing.lg)

                yearRangeSlider
                    .padding(.horizontal, NostosSpacing.lg)
                    .padding(.bottom, NostosSpacing.lg)

                Divider()
                    .padding(.horizontal, NostosSpacing.lg)
                    .padding(.vertical, NostosSpacing.lg)

                Button(action: clearFilters) {
                    Text("Clear All Filters")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .foregroundColor(.nostosRed)
                .border(Color.nostosRed, width: 1)
                .padding(.horizontal, NostosSpacing.lg)
                .padding(.bottom, NostosSpacing.lg)
            }
        }
    }

    private func filterCheckbox(_ label: String, isChecked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundColor(isChecked ? .nostosAccent : .nostosFg3)

                Text(label)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.nostosFg2)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 5)
    }

    @ViewBuilder
    private var yearRangeSlider: some View {
        let years = Array(Set(state.photos.compactMap { $0.takenAt }.map { Calendar.current.component(.year, from: $0) })).sorted()

        if years.isEmpty {
            Text("No date data")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.nostosFg3)
        } else {
            VerticalYearRangeSlider(years: years, yearFrom: $filterYearFrom, yearTo: $filterYearTo) {
                applyLocalFilters()
            }
        }
    }

    // MARK: - Helpers

    private var isFiltered: Bool {
        !filterStatus.isEmpty || !filterCameraModels.isEmpty || filterIncludeNoCamera || !filterHasDuplicates.isEmpty || filterYearFrom != nil || filterYearTo != nil
    }

    private func applyLocalFilters() {
        // Filters are applied via computed property, no action needed
    }

    private func clearFilters() {
        filterStatus = []
        filterCameraModels = []
        filterIncludeNoCamera = false
        filterHasDuplicates = []
        filterYearFrom = nil
        filterYearTo = nil
    }

    private func monthName(_ month: Int) -> String {
        let months = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        return months[safe: month] ?? "Unknown"
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        let month = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][safe: components.month ?? 0] ?? "—"
        return "\(month) \(components.day ?? 0)"
    }
}

// MARK: - Helper Types

struct MonthKey: Hashable, Comparable {
    let year: Int
    let month: Int

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        return lhs.month < rhs.month
    }
}

struct MonthGroup {
    let year: Int
    let month: Int
    let photos: [Photo]
}

struct Badge: View {
    let label: String
    let bg: Color

    var body: some View {
        Text(label)
            .font(.system(size: 8, weight: .heavy))
            .foregroundColor(.white)
            .padding(.vertical, 2)
            .padding(.horizontal, 5)
            .background(bg)
            .cornerRadius(3)
    }
}

struct VaultBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 7))

            Text("IN VAULT")
                .font(.system(size: 7, weight: .heavy))
        }
        .foregroundColor(.white)
        .padding(.vertical, 2)
        .padding(.horizontal, 5)
        .background(Color.nostosGreen)
        .cornerRadius(3)
    }
}

// MARK: - Backup Footer Bar
struct BackupFooterBar: View {
    let matchCount: Int
    @State private var backupState: BackupState = .idle
    @State private var progress: Double = 0
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: NostosSpacing.xl) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 18))
                .foregroundColor(.nostosAccent)

            VStack(alignment: .leading, spacing: 0) {
                if backupState == .done {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11))
                        Text("Backup complete")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.nostosGreen)
                } else {
                    Text("\(matchCount) photos to back up")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.nostosFg2)
                }
            }

            if backupState == .running || backupState == .paused {
                NostosProgressBar(progress, color: .nostosAccent)
                    .frame(width: 100)

                Text("\(Int(progress))%")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.nostosFg3)
            }

            Spacer()

            if backupState == .done {
                Button("Back Up Again") {
                    backupState = .idle
                    progress = 0
                }
                .buttonStyle(.bordered)
                .font(.system(size: 12, weight: .medium))
            } else if backupState == .idle {
                Button(action: { startBackup() }) {
                    Image(systemName: "play.fill")
                    Text("Back Up to Vault")
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 12, weight: .medium))
                .disabled(matchCount == 0)
            } else {
                Button(action: { backupState = backupState == .running ? .paused : .running }) {
                    Image(systemName: backupState == .running ? "pause.fill" : "play.fill")
                }
                .frame(width: 28, height: 28)
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, NostosSpacing.lg)
        .padding(.vertical, 10)
        .borderTop(width: 1, color: Color.nostosBorder)
        .background(Color.nostosSurface)
    }

    private func startBackup() {
        backupState = .running
        progress = 0

        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            progress += Double.random(in: 0.5...3)
            if progress >= 100 {
                progress = 100
                backupState = .done
                Timer.scheduledTimer(withTimeInterval: 0.01, repeats: false) { _ in
                    // Backup complete
                }
            }
        }
        _ = timer
    }

    enum BackupState {
        case idle
        case running
        case paused
        case done
    }
}

// MARK: - Year Range Slider
struct VerticalYearRangeSlider: View {
    let years: [Int]
    @Binding var yearFrom: Int?
    @Binding var yearTo: Int?
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let from = yearFrom, let to = yearTo {
                    Text("\(from) – \(to)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.nostosFg1)
                } else {
                    Text("All years")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.nostosFg3)
                        .italic()
                }

                Spacer()

                if yearFrom != nil || yearTo != nil {
                    Button("Clear") {
                        yearFrom = nil
                        yearTo = nil
                        onChange()
                    }
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.nostosAccent)
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 10)

            HStack(spacing: 0) {
                VStack(spacing: 28) {
                    ForEach(years, id: \.self) { year in
                        Text("\(year)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.nostosFg3)
                            .frame(height: 28, alignment: .center)
                    }
                }
                .padding(.leading, 10)

                Spacer(minLength: 10)
            }
        }
    }
}

// Array safe subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Text {
    func trailing(_ spacing: CGFloat = 0) -> some View {
        HStack(spacing: spacing) {
            self
            Spacer()
        }
    }
}
