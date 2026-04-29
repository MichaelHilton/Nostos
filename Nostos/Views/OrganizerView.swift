import SwiftUI

struct VaultView: View {
    @EnvironmentObject var state: AppState
    let onVaultRootChange: (URL) -> Void
    @State private var folderFormat = "YYYY/MM/DD"
    @State private var dryRun = true
    @State private var showResults = false
    @State private var pendingVaultURL: URL?

    init(onVaultRootChange: @escaping (URL) -> Void = { _ in }) {
        self.onVaultRootChange = onVaultRootChange
    }

    var inVaultCount: Int {
        state.photos.filter { $0.status == .copied }.count
    }

    var notYetVaultedCount: Int {
        state.totalPhotoCount - inVaultCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeaderView(
                title: "Vault",
                subtitle: "Organise and copy photos into your structured vault folder"
            )

            ScrollView {
                VStack(spacing: NostosSpacing.xxxl) {
                    StarDotBackground()

                    // Stat cards row
                    HStack(spacing: NostosSpacing.xl) {
                        NostosStatCard("Photos Scanned", value: "\(state.totalPhotoCount)", color: .nostosFg1)
                        NostosStatCard("In Vault", value: "\(inVaultCount)", color: .nostosGreen)
                        NostosStatCard("Not Yet Vaulted", value: "\(notYetVaultedCount)", color: .nostosOrange)
                        NostosStatCard("Total Size", value: formatBytes(state.totalPhotoSize), color: .nostosAccent)
                    }
                    .padding(.horizontal, NostosSpacing.pagePadding)

                    // Format breakdown
                    if !state.formatBreakdown.isEmpty {
                        CardView {
                            VStack(alignment: .leading, spacing: NostosSpacing.lg) {
                                SectionLabel("Storage Breakdown — Format", diamond: true)

                                ForEach(Array(state.formatBreakdown.enumerated()), id: \.offset) { _, row in
                                    formatBreakdownRow(row)
                                }
                            }
                            .padding(NostosSpacing.lg)
                        }
                        .padding(.horizontal, NostosSpacing.pagePadding)
                    }

                    // Year breakdown
                    if !state.yearBreakdown.isEmpty {
                        CardView {
                            VStack(alignment: .leading, spacing: NostosSpacing.lg) {
                                SectionLabel("Breakdown — Year Taken", diamond: true)

                                ForEach(Array(state.yearBreakdown.enumerated()), id: \.offset) { _, row in
                                    yearBreakdownRow(row)
                                }
                            }
                            .padding(NostosSpacing.lg)
                        }
                        .padding(.horizontal, NostosSpacing.pagePadding)
                    }

                    // Camera breakdown
                    if !state.cameraBreakdown.isEmpty {
                        CardView {
                            VStack(alignment: .leading, spacing: NostosSpacing.lg) {
                                SectionLabel("Breakdown — Camera", diamond: true)

                                ForEach(Array(state.cameraBreakdown.enumerated()), id: \.offset) { _, row in
                                    cameraBreakdownRow(row)
                                }
                            }
                            .padding(NostosSpacing.lg)
                        }
                        .padding(.horizontal, NostosSpacing.pagePadding)
                    }

                    // Vault location and format settings
                    CardView {
                        VStack(alignment: .leading, spacing: NostosSpacing.lg) {
                            VStack(alignment: .leading, spacing: NostosSpacing.sm) {
                                SectionLabel("Vault Location", diamond: true)

                                HStack(spacing: NostosSpacing.xl) {
                                    Text(state.vaultRootURL?.path ?? "No vault selected")
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .foregroundColor(.nostosFg2)
                                        .padding(.horizontal, NostosSpacing.md)
                                        .padding(.vertical, NostosSpacing.sm)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.nostosSurface2)
                                        .border(Color.nostosBorder, width: 1)
                                        .cornerRadius(NostosRadii.md)

                                    Button(action: {
                                        pendingVaultURL = state.pickVaultDirectory()
                                    }) {
                                        Text("Change…")
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("vaultChangeVaultButton")
                                }
                            }

                            Divider()
                                .padding(.vertical, NostosSpacing.sm)

                            VStack(alignment: .leading, spacing: NostosSpacing.sm) {
                                SectionLabel("Folder Format", diamond: true)

                                HStack(spacing: NostosSpacing.xl) {
                                    TextField("YYYY/MM/DD", text: $folderFormat)
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .padding(.horizontal, NostosSpacing.md)
                                        .padding(.vertical, NostosSpacing.sm)
                                        .background(Color.nostosSurface2)
                                        .border(Color.nostosBorder, width: 1)
                                        .cornerRadius(NostosRadii.md)

                                    Text("YYYY, MM, DD")
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundColor(.nostosFg3)
                                }
                            }
                        }
                        .padding(NostosSpacing.lg)
                    }
                    .padding(.horizontal, NostosSpacing.pagePadding)

                    // Organize button
                    HStack(spacing: NostosSpacing.md) {
                        Button(action: startOrganize) {
                            Text(state.organizeProgress.isRunning ? "↻  Vaulting…" : "▶  Organise Vault")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.vaultRootURL == nil || state.organizeProgress.isRunning)
                        .accessibilityIdentifier(dryRun ? "vaultPreviewButton" : "vaultSaveButton")

                        if state.organizeProgress.isRunning {
                            vaultSpinnerView()
                        }
                    }
                    .padding(.horizontal, NostosSpacing.pagePadding)

                    // Progress card
                    if state.organizeProgress.isRunning || state.organizeProgress.total > 0 {
                        CardView {
                            VStack(alignment: .leading, spacing: NostosSpacing.lg) {
                                SectionLabel("Progress", diamond: true)

                                if state.organizeProgress.total > 0 {
                                    NostosProgressBar(
                                        Double(state.organizeProgress.copied + state.organizeProgress.skipped),
                                        total: Double(state.organizeProgress.total)
                                    )
                                }

                                HStack(spacing: 40) {
                                    Stat("Total", value: "\(state.organizeProgress.total)")
                                    Stat("Copied", value: "\(state.organizeProgress.copied)", color: .nostosGreen)
                                    Stat("Skipped", value: "\(state.organizeProgress.skipped)", color: .nostosOrange)
                                }
                            }
                            .padding(NostosSpacing.lg)
                        }
                        .padding(.horizontal, NostosSpacing.pagePadding)
                    }

                    // Last run results
                    if !state.lastOrganizeResults.isEmpty {
                        CardView {
                            VStack(alignment: .leading, spacing: NostosSpacing.lg) {
                                HStack {
                                    SectionLabel("Last Run Results", diamond: true)
                                    Spacer()
                                    Button(action: { showResults.toggle() }) {
                                        Text(showResults ? "Hide" : "Show Details")
                                            .font(.system(size: 10, weight: .semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(.nostosAccent)
                                    .accessibilityIdentifier("vaultToggleDetailsButton")
                                }

                                if showResults {
                                    if #available(macOS 13, *) {
                                        Table(state.lastOrganizeResults) {
                                            TableColumn("Source") { r in
                                                Text(URL(fileURLWithPath: r.source).lastPathComponent)
                                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                                    .lineLimit(1)
                                            }
                                            TableColumn("Destination") { r in
                                                Text(r.destination.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "—")
                                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                                    .lineLimit(1)
                                            }
                                            TableColumn("Action") { r in
                                                Text(r.action.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                                    .foregroundColor(actionColor(r.action))
                                            }
                                            .width(120)
                                        }
                                        .frame(minHeight: 200)
                                    } else {
                                        LegacyOrganizeResultsView(results: state.lastOrganizeResults)
                                            .frame(minHeight: 200)
                                    }
                                }
                            }
                            .padding(NostosSpacing.lg)
                        }
                        .padding(.horizontal, NostosSpacing.pagePadding)
                    }
                }
                .padding(.vertical, NostosSpacing.xxxl)
            }
            .background(Color.nostosBg)
            .overlay(alignment: .topLeading) {
                StarDotBackground()
            }
        }
        .confirmationDialog(
            "Change vault location?",
            isPresented: Binding(
                get: { pendingVaultURL != nil },
                set: { if !$0 { pendingVaultURL = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Change Vault", role: .destructive) {
                guard let url = pendingVaultURL else { return }
                pendingVaultURL = nil
                state.changeVaultRoot(to: url)
                onVaultRootChange(url)
            }
            .accessibilityIdentifier("vaultConfirmChangeButton")
            Button("Cancel", role: .cancel) {
                pendingVaultURL = nil
            }
            .accessibilityIdentifier("vaultCancelChangeButton")
        } message: {
            Text("Nostos will reopen the database and thumbnails from the selected folder.")
        }
    }

    private func startOrganize() {
        state.startVault(folderFormat: folderFormat, dryRun: dryRun)
    }

    @ViewBuilder
    private func formatBreakdownRow(_ row: (ext: String, count: Int, bytes: Int64)) -> some View {
        HStack(spacing: NostosSpacing.lg) {
            Text(row.ext.isEmpty ? "No extension" : ".\(row.ext)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.nostosFg1)
                .frame(width: 60, alignment: .leading)

            let totalBytes = state.totalPhotoSize
            let percentage = totalBytes > 0 ? Double(row.bytes) / Double(totalBytes) : 0.0
            NostosProgressBar(percentage, total: 1.0, color: .nostosAccent)
                .frame(height: 5)

            Text("\(row.count)")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.nostosFg1)
                .frame(width: 40, alignment: .trailing)

            Text(formatBytes(row.bytes))
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.nostosFg3)
                .frame(width: 60, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func yearBreakdownRow(_ row: (year: Int, count: Int)) -> some View {
        let maxCount = state.yearBreakdown.map { $0.count }.max() ?? 1
        let percentage = Double(row.count) / Double(maxCount)

        HStack(spacing: NostosSpacing.lg) {
            Text("\(row.year)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.nostosFg1)
                .frame(width: 50, alignment: .leading)

            NostosProgressBar(percentage, total: 1.0, color: .nostosGold)
                .frame(height: 5)

            Text("\(row.count)")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.nostosFg1)
                .frame(width: 40, alignment: .trailing)

            Text("\(Int(percentage * 100))%")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.nostosFg3)
                .frame(width: 40, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func cameraBreakdownRow(_ row: (model: String, count: Int)) -> some View {
        let maxCount = state.cameraBreakdown.map { $0.count }.max() ?? 1
        let percentage = Double(row.count) / Double(maxCount)

        HStack(spacing: NostosSpacing.lg) {
            Text(row.model)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.nostosFg1)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 120, alignment: .leading)

            NostosProgressBar(percentage, total: 1.0, color: .nostosAccent)
                .frame(height: 5)

            Text("\(row.count)")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.nostosFg1)
                .frame(width: 40, alignment: .trailing)

            Text("\(Int(percentage * 100))%")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.nostosFg3)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func actionColor(_ action: OrganizeAction) -> Color {
        switch action {
        case .copy:            return .nostosGreen
        case .skipExists:      return .nostosFg3
        case .skipDuplicate:   return .nostosOrange
        case .renameConflict:  return .nostosGold
        }
    }

    @ViewBuilder
    private func vaultSpinnerView() -> some View {
        Circle()
            .trim(from: 0.1, to: 0.9)
            .stroke(Color.nostosAccent, lineWidth: 2)
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(45))
    }
}

typealias OrganizerView = VaultView

private struct LegacyOrganizeResultsView: View {
    let results: [OrganizeResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 4) {
                    Text(URL(fileURLWithPath: result.source).lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 12) {
                        Text(result.destination.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "—")
                        Text(result.action.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                            .foregroundColor(actionColor(result.action))
                    }
                    .font(.caption)
                    Divider()
                }
            }
        }
    }

    private func actionColor(_ action: OrganizeAction) -> Color {
        switch action {
        case .copy:            return .green
        case .skipExists:      return .secondary
        case .skipDuplicate:   return .orange
        case .renameConflict:  return .yellow
        }
    }
}
