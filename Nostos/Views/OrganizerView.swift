import SwiftUI

struct OrganizerView: View {
    @EnvironmentObject var state: AppState
    @State private var destinationPath = ""
    @State private var folderFormat = "YYYY/MM/DD"
    @State private var dryRun = true
    @State private var showResults = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Organizer")
                .font(.largeTitle).bold()

            GroupBox("Destination Folder") {
                HStack {
                    Text(destinationPath.isEmpty ? "No folder selected" : destinationPath)
                        .foregroundColor(destinationPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Choose…") {
                        if let url = state.pickDestinationDirectory() {
                            destinationPath = url.path
                        }
                    }
                }
                .padding(4)
            }

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

            HStack {
                Button(action: startOrganize) {
                    Label(
                        state.organizeProgress.isRunning
                            ? "Organizing…"
                            : (dryRun ? "Preview" : "Start Organizing"),
                        systemImage: state.organizeProgress.isRunning ? "stop.circle" : "play.fill"
                    )
                }
                .disabled(destinationPath.isEmpty || state.organizeProgress.isRunning)
                .buttonStyle(.borderedProminent)

                if state.organizeProgress.isRunning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.leading, 4)
                }
            }

            if state.organizeProgress.isRunning || state.organizeProgress.total > 0 {
                GroupBox("Progress") {
                    VStack(alignment: .leading, spacing: 8) {
                        if state.organizeProgress.total > 0 {
                            ProgressView(
                                value: Double(state.organizeProgress.copied + state.organizeProgress.skipped),
                                total: Double(state.organizeProgress.total)
                            )
                        }
                        HStack(spacing: 24) {
                            stat("Total", state.organizeProgress.total, .primary)
                            stat("Copied", state.organizeProgress.copied, .green)
                            stat("Skipped", state.organizeProgress.skipped, .orange)
                        }
                    }
                    .padding(4)
                }
            }

            if !state.lastOrganizeResults.isEmpty {
                GroupBox {
                    HStack {
                        Text("Last Run Results")
                            .font(.headline)
                        Spacer()
                        Button(showResults ? "Hide" : "Show Details") {
                            showResults.toggle()
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.bottom, 4)

                    if showResults {
                        if #available(macOS 13, *) {
                            Table(state.lastOrganizeResults) {
                                TableColumn("Source") { r in
                                    Text(URL(fileURLWithPath: r.source).lastPathComponent)
                                        .lineLimit(1)
                                }
                                TableColumn("Destination") { r in
                                    Text(r.destination.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "—")
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
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func startOrganize() {
        state.startOrganize(
            destination: URL(fileURLWithPath: destinationPath),
            folderFormat: folderFormat,
            dryRun: dryRun
        )
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

    private func actionColor(_ action: OrganizeAction) -> Color {
        switch action {
        case .copy:            return .green
        case .skipExists:      return .secondary
        case .skipDuplicate:   return .orange
        case .renameConflict:  return .yellow
        }
    }
}

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
