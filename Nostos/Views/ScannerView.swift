import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedPath: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Scanner")
                .font(.largeTitle)
                .bold()

            // Directory picker
            GroupBox("Source Folder") {
                HStack {
                    Text(selectedPath.isEmpty ? "No folder selected" : selectedPath)
                        .foregroundColor(selectedPath.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Choose…") {
                        if let url = state.pickDirectory() {
                            selectedPath = url.path
                        }
                    }
                }
                .padding(4)
            }

            // Scan button + progress
            HStack {
                Button(action: startScan) {
                    Label(state.scanProgress.isScanning ? "Scanning…" : "Start Scan",
                          systemImage: "play.fill")
                }
                .disabled(selectedPath.isEmpty || state.scanProgress.isScanning)
                .buttonStyle(.borderedProminent)

                if state.scanProgress.isScanning {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.leading, 4)
                }
            }

            if state.scanProgress.isScanning || state.scanProgress.processed > 0 {
                GroupBox("Progress") {
                    VStack(alignment: .leading, spacing: 8) {
                        if state.scanProgress.total > 0 {
                            ProgressView(
                                value: Double(state.scanProgress.processed),
                                total: Double(state.scanProgress.total)
                            )
                        } else {
                            ProgressView()
                        }
                        HStack(spacing: 24) {
                            stat("Files Found", state.scanProgress.total)
                            stat("Processed", state.scanProgress.processed)
                            stat("Duplicates", state.scanProgress.duplicatesFound)
                        }
                    }
                    .padding(4)
                }
            }

            // Recent scans table
            if !state.scanRuns.isEmpty {
                GroupBox("Recent Scans") {
                    recentScansTable
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func startScan() {
        state.startScan(rootURL: URL(fileURLWithPath: selectedPath))
    }

    @ViewBuilder
    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.title3)
                .bold()
        }
    }

    private func statusColor(_ status: ScanStatus) -> Color {
        switch status {
        case .running:   return .orange
        case .completed: return .green
        case .failed:    return .red
        }
    }

    private var recentScansTable: some View {
        Table(state.scanRuns) {
            TableColumn("Path") { run in
                Text(run.rootPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            TableColumn("Status") { run in
                Text(run.status.rawValue.capitalized)
                    .foregroundColor(statusColor(run.status))
            }
            .width(80)
            TableColumn("Photos") { run in
                Text("\(run.photosFound)")
            }
            .width(60)
            TableColumn("Duplicates") { run in
                Text("\(run.duplicatesFound)")
            }
            .width(80)
            TableColumn("Started") { run in
                Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .width(160)
        }
        .frame(minHeight: 140)
    }
}
