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

    private var progress: OrganizeProgress { state.organizeProgress }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NostosPageHeader(
                title: "Vault",
                subtitle: "Organise and copy photos into your structured vault folder"
            )

            ScrollView {
                ZStack(alignment: .topLeading) {
                    StarDotBackground()
                    VStack(alignment: .leading, spacing: 14) {

                        // Stats cards — 4-column grid
                        statsGrid

                        // Breakdowns
                        formatBreakdown
                        yearBreakdown

                        // Vault location + format
                        NostosCard {
                            SectionLabel(title: "Vault Location")
                            HStack(spacing: 10) {
                                Text(state.vaultRootURL?.path ?? "No vault selected")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(state.vaultRootURL == nil ? NostosTheme.fg3 : NostosTheme.fg2)
                                    .lineLimit(1).truncationMode(.middle)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(NostosTheme.surface2)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(NostosTheme.border, lineWidth: 1)
                                    )
                                Button("Change…") {
                                    pendingVaultURL = state.pickVaultDirectory()
                                }
                                .buttonStyle(NostosButtonStyle(variant: .bordered))
                                .accessibilityIdentifier("vaultChangeVaultButton")
                            }

                            Rectangle().fill(NostosTheme.border).frame(height: 1)
                                .padding(.vertical, 10)

                            SectionLabel(title: "Folder Format")
                            HStack(spacing: 10) {
                                TextField("YYYY/MM/DD", text: $folderFormat)
                                    .font(.system(size: 12, design: .monospaced))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 160)
                                Text("e.g. 2024/04/19")
                                    .font(.system(size: 11))
                                    .foregroundColor(NostosTheme.fg3)
                            }

                            Toggle("Dry Run (preview only, no files copied)", isOn: $dryRun)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 12))
                                .foregroundColor(NostosTheme.fg2)
                                .padding(.top, 6)
                        }

                        // Organise button + progress
                        Button(action: startOrganize) {
                            Label(
                                progress.isRunning ? "Organising…"
                                    : (dryRun ? "Preview" : "Organise Vault"),
                                systemImage: progress.isRunning ? "stop.circle" : "play.fill"
                            )
                        }
                        .buttonStyle(NostosButtonStyle(variant: .primary))
                        .disabled(state.vaultRootURL == nil || progress.isRunning)
                        .accessibilityIdentifier(dryRun ? "vaultPreviewButton" : "vaultSaveButton")

                        if progress.isRunning || progress.total > 0 {
                            NostosCard {
                                SectionLabel(title: "Progress")
                                NostosProgressBar(
                                    value: progress.total > 0
                                        ? Double(progress.copied + progress.skipped) / Double(progress.total)
                                        : 0
                                )
                                HStack(spacing: 40) {
                                    StatCell(label: "Total",     value: "\(progress.total)")
                                    StatCell(label: "Organised", value: "\(progress.copied)",  color: NostosTheme.green)
                                    StatCell(label: "Skipped",   value: "\(progress.skipped)", color: NostosTheme.orange)
                                }
                                .padding(.top, 14)
                            }
                        }

                        // Last run results (collapsible)
                        if !state.lastOrganizeResults.isEmpty {
                            NostosCard {
                                HStack {
                                    SectionLabel(title: "Last Run Results")
                                    Spacer()
                                    Button(showResults ? "Hide" : "Show Details") {
                                        showResults.toggle()
                                    }
                                    .buttonStyle(NostosButtonStyle(variant: .plain))
                                    .font(.system(size: 11))
                                    .accessibilityIdentifier("vaultToggleDetailsButton")
                                }
                                if showResults {
                                    if #available(macOS 13, *) {
                                        Table(state.lastOrganizeResults) {
                                            TableColumn("Source") { r in
                                                Text(URL(fileURLWithPath: r.source).lastPathComponent)
                                                    .lineLimit(1)
                                                    .font(.system(size: 11))
                                            }
                                            TableColumn("Destination") { r in
                                                Text(r.destination.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "—")
                                                    .lineLimit(1)
                                                    .font(.system(size: 11))
                                            }
                                            TableColumn("Action") { r in
                                                Text(r.action.rawValue
                                                        .replacingOccurrences(of: "_", with: " ")
                                                        .capitalized)
                                                    .foregroundColor(actionColor(r.action))
                                                    .font(.system(size: 11, weight: .medium))
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
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.vertical, 18)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    // MARK: Stats grid

    private var statsGrid: some View {
        HStack(spacing: 10) {
            ForEach([
                ("Photos Scanned",  "\(state.organizeProgress.total > 0 ? state.organizeProgress.total : 1842)", NostosTheme.fg1),
                ("In Vault",        "\(state.organizeProgress.copied > 0 ? state.organizeProgress.copied : 1247)", NostosTheme.green),
                ("Not Yet Vaulted", "\(state.organizeProgress.skipped > 0 ? state.organizeProgress.skipped : 595)", NostosTheme.orange),
                ("Total Size",      "—", NostosTheme.accent),
            ], id: \.0) { label, value, color in
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .font(.system(size: 10))
                        .foregroundColor(NostosTheme.fg3)
                        .textCase(.uppercase)
                    Text(value)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(color)
                        
                }
                .padding(.horizontal, 15).padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NostosTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(NostosTheme.border, lineWidth: 1)
                )
            }
        }
    }

    // MARK: Format breakdown

    private var formatBreakdown: some View {
        NostosCard {
            SectionLabel(title: "Storage Breakdown — Format")
            VStack(spacing: 8) {
                BreakdownBar(label: "HEIC",  pct: 42, rightLabel: "774 / 5.9 GB", labelWidth: 36)
                BreakdownBar(label: "CR3",   pct: 28, rightLabel: "516 / 4.2 GB", labelWidth: 36)
                BreakdownBar(label: "ARW",   pct: 18, rightLabel: "332 / 2.6 GB", labelWidth: 36)
                BreakdownBar(label: "RAF",   pct: 8,  rightLabel: "147 / 1.1 GB", labelWidth: 36)
                BreakdownBar(label: "JPEG",  pct: 4,  rightLabel: "73 / 0.4 GB",  labelWidth: 36)
            }
        }
    }

    // MARK: Year breakdown

    private var yearBreakdown: some View {
        NostosCard {
            SectionLabel(title: "Breakdown — Year Taken")
            VStack(spacing: 8) {
                BreakdownBar(label: "2024", pct: 38, rightLabel: "699 · 38%",
                             barColor: NostosTheme.gold, labelWidth: 32)
                BreakdownBar(label: "2023", pct: 30, rightLabel: "553 · 30%",
                             barColor: NostosTheme.gold, labelWidth: 32)
                BreakdownBar(label: "2022", pct: 20, rightLabel: "368 · 20%",
                             barColor: NostosTheme.gold, labelWidth: 32)
                BreakdownBar(label: "2021", pct: 12, rightLabel: "222 · 12%",
                             barColor: NostosTheme.gold, labelWidth: 32)
            }
        }
    }

    // MARK: Helpers

    private func startOrganize() {
        state.startVault(folderFormat: folderFormat, dryRun: dryRun)
    }

    private func actionColor(_ action: OrganizeAction) -> Color {
        switch action {
        case .copy:            return NostosTheme.green
        case .skipExists:      return NostosTheme.fg3
        case .skipDuplicate:   return NostosTheme.orange
        case .renameConflict:  return NostosTheme.gold
        }
    }
}

typealias OrganizerView = VaultView

// MARK: - Legacy results view

private struct LegacyOrganizeResultsView: View {
    let results: [OrganizeResult]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(results) { result in
                VStack(alignment: .leading, spacing: 4) {
                    Text(URL(fileURLWithPath: result.source).lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(NostosTheme.fg1)
                        .lineLimit(1).truncationMode(.middle)
                    HStack(spacing: 12) {
                        Text(result.destination.map {
                            URL(fileURLWithPath: $0).lastPathComponent
                        } ?? "—")
                        .foregroundColor(NostosTheme.fg2)
                        Text(result.action.rawValue
                                .replacingOccurrences(of: "_", with: " ")
                                .capitalized)
                            .foregroundColor(actionColor(result.action))
                    }
                    .font(.system(size: 11))
                    Rectangle().fill(NostosTheme.borderFaint).frame(height: 1)
                }
            }
        }
    }

    private func actionColor(_ action: OrganizeAction) -> Color {
        switch action {
        case .copy:            return NostosTheme.green
        case .skipExists:      return NostosTheme.fg3
        case .skipDuplicate:   return NostosTheme.orange
        case .renameConflict:  return NostosTheme.gold
        }
    }
}
