import SwiftUI

struct BackupView: View {
    @EnvironmentObject var state: AppState

    // Filter state
    @State private var filterCameraModels: Set<String> = []
    @State private var filterIncludeNoCamera: Bool = false
    @State private var filterYearFrom: Int?
    @State private var filterYearTo: Int?
    @State private var filterDateFrom: Date?
    @State private var filterDateTo: Date?

    // Options
    @State private var folderFormat: String = "YYYY/MM/DD"
    @State private var dryRun: Bool = true

    // UI
    @State private var showResults: Bool = false
    @State private var estimatedCount: Int = 0

    private var orderedYears: [Int] { state.years.sorted() }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Backup")
                    .font(.largeTitle).bold()

                Text("Copy selected photos to the vault. Photos already in the vault (matched by file hash) are automatically skipped.")
                    .foregroundColor(.secondary)

                filterSection
                optionsSection
                actionRow

                if state.backupProgress.isRunning || state.backupProgress.total > 0 {
                    progressSection
                }

                if !state.lastBackupResults.isEmpty {
                    resultsSection
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: filterCameraModels)   { _ in refreshCount() }
        .onChange(of: filterIncludeNoCamera){ _ in refreshCount() }
        .onChange(of: filterYearFrom)       { _ in refreshCount() }
        .onChange(of: filterYearTo)         { _ in refreshCount() }
        .onChange(of: filterDateFrom)       { _ in refreshCount() }
        .onChange(of: filterDateTo)         { _ in refreshCount() }
        .onAppear { refreshCount() }
    }

    // MARK: - Sections

    private var filterSection: some View {
        GroupBox("Filter — Which photos to back up") {
            VStack(alignment: .leading, spacing: 12) {
                // Camera models
                if !state.cameraModels.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Camera").font(.subheadline).foregroundColor(.secondary)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)],
                            alignment: .leading,
                            spacing: 4
                        ) {
                            ForEach(state.cameraModels, id: \.self) { model in
                                Toggle(model, isOn: Binding(
                                    get: { filterCameraModels.contains(model) },
                                    set: { on in
                                        if on { filterCameraModels.insert(model) }
                                        else  { filterCameraModels.remove(model) }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                            }
                            Toggle("No camera metadata", isOn: $filterIncludeNoCamera)
                                .toggleStyle(.checkbox)
                        }
                    }
                    Divider()
                }

                // Year range
                VStack(alignment: .leading, spacing: 6) {
                    Text("Year range").font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        yearPicker("From", years: orderedYears, selection: $filterYearFrom)
                        Text("–").foregroundColor(.secondary)
                        yearPicker("To", years: orderedYears, selection: $filterYearTo)
                        if filterYearFrom != nil || filterYearTo != nil {
                            Button("Clear") {
                                filterYearFrom = nil
                                filterYearTo = nil
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                // Date range (exact)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Exact date range").font(.subheadline).foregroundColor(.secondary)
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
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                // Estimated count
                HStack {
                    Image(systemName: "photo.stack")
                        .foregroundColor(.secondary)
                    Text("**\(estimatedCount)** photo\(estimatedCount == 1 ? "" : "s") match current filter")
                        .foregroundColor(.secondary)
                    Spacer()
                    if filterCameraModels.isEmpty && filterYearFrom == nil && filterYearTo == nil
                        && filterDateFrom == nil && filterDateTo == nil && !filterIncludeNoCamera {
                        Text("(all eligible photos)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 2)
            }
            .padding(6)
        }
    }

    private var optionsSection: some View {
        GroupBox("Options") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Folder Format")
                        .frame(width: 110, alignment: .trailing)
                    TextField("YYYY/MM/DD", text: $folderFormat)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                    Text("Tokens: YYYY, MM, DD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Toggle("Dry Run (preview only, no files copied)", isOn: $dryRun)
            }
            .padding(4)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(action: startBackup) {
                Label(
                    state.backupProgress.isRunning
                        ? "Backing up…"
                        : (dryRun ? "Preview" : "Back Up Now"),
                    systemImage: state.backupProgress.isRunning ? "stop.circle" : "tray.and.arrow.down.fill"
                )
            }
            .disabled(state.vaultRootURL == nil || state.backupProgress.isRunning || estimatedCount == 0)
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(dryRun ? "backupPreviewButton" : "backupRunButton")

            if state.backupProgress.isRunning {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.leading, 4)
            }

            if state.vaultRootURL == nil {
                Text("No vault selected — go to Vault to choose one.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private var progressSection: some View {
        GroupBox("Progress") {
            VStack(alignment: .leading, spacing: 8) {
                if state.backupProgress.total > 0 {
                    ProgressView(
                        value: Double(state.backupProgress.copied + state.backupProgress.skipped),
                        total: Double(state.backupProgress.total)
                    )
                }
                HStack(spacing: 24) {
                    stat("Total",   state.backupProgress.total,   .primary)
                    stat("Copied",  state.backupProgress.copied,  .green)
                    stat("Skipped", state.backupProgress.skipped, .orange)
                }
            }
            .padding(4)
        }
    }

    private var resultsSection: some View {
        GroupBox {
            HStack {
                Text("Last Run Results")
                    .font(.headline)
                Spacer()
                Button(showResults ? "Hide" : "Show Details") {
                    showResults.toggle()
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("backupToggleDetailsButton")
            }
            .padding(.bottom, 4)

            if showResults {
                if #available(macOS 13, *) {
                    Table(state.lastBackupResults) {
                        TableColumn("Source") { r in
                            Text(URL(fileURLWithPath: r.source).lastPathComponent)
                                .lineLimit(1)
                        }
                        TableColumn("Vault Path") { r in
                            Text(r.vaultPath.map { URL(fileURLWithPath: $0).relativePath } ?? "—")
                                .lineLimit(1)
                        }
                        TableColumn("Action") { r in
                            Text(backupActionLabel(r.action))
                                .foregroundColor(backupActionColor(r.action))
                        }
                        .width(120)
                        TableColumn("Reason") { r in
                            Text(r.reason ?? "")
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(minHeight: 200)
                } else {
                    LegacyBackupResultsView(results: state.lastBackupResults)
                        .frame(minHeight: 200)
                }
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func yearPicker(_ label: String, years: [Int], selection: Binding<Int?>) -> some View {
        Picker(label, selection: selection) {
            Text("Any").tag(Optional<Int>(nil))
            ForEach(years, id: \.self) { y in
                Text(String(y)).tag(Optional(y))
            }
        }
        .labelsHidden()
        .frame(width: 90)
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.title3).bold()
                .foregroundColor(color)
        }
    }

    private func refreshCount() {
        estimatedCount = state.countPhotosForBackup(filter: currentFilter)
    }

    private func startBackup() {
        state.startBackup(folderFormat: folderFormat, filter: currentFilter, dryRun: dryRun)
        showResults = false
    }

    private var currentFilter: PhotoFilter {
        var f = PhotoFilter()
        f.cameraModels = filterCameraModels
        f.includeNoCamera = filterIncludeNoCamera
        f.yearFrom = filterYearFrom
        f.yearTo = filterYearTo
        f.dateFrom = filterDateFrom
        f.dateTo = filterDateTo
        // No pagination — BackupService fetches all matching rows
        f.limit = Int.max
        f.offset = 0
        return f
    }

    private func backupActionLabel(_ action: BackupAction) -> String {
        switch action {
        case .copy:           return "Copied"
        case .skipInVault:    return "Already in vault"
        case .skipDuplicate:  return "Duplicate"
        }
    }

    private func backupActionColor(_ action: BackupAction) -> Color {
        switch action {
        case .copy:           return .green
        case .skipInVault:    return .secondary
        case .skipDuplicate:  return .orange
        }
    }
}

// MARK: - Legacy fallback (macOS 12)

private struct LegacyBackupResultsView: View {
    let results: [BackupResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 4) {
                    Text(URL(fileURLWithPath: result.source).lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 12) {
                        Text(result.vaultPath ?? "—")
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(labelFor(result.action))
                            .foregroundColor(colorFor(result.action))
                    }
                    .font(.caption)
                    Divider()
                }
            }
        }
    }

    private func labelFor(_ action: BackupAction) -> String {
        switch action {
        case .copy:           return "Copied"
        case .skipInVault:    return "Already in vault"
        case .skipDuplicate:  return "Duplicate"
        }
    }

    private func colorFor(_ action: BackupAction) -> Color {
        switch action {
        case .copy:           return .green
        case .skipInVault:    return .secondary
        case .skipDuplicate:  return .orange
        }
    }
}
