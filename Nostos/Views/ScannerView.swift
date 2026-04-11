import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedPath: String

    init() {
        let sourcePath = ProcessInfo.processInfo.environment["UI_TESTING_SOURCE_DIRECTORY_TO_PICK"] ?? ""
        _selectedPath = State(initialValue: sourcePath)
    }

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
                    .accessibilityIdentifier("scannerChooseDirectoryButton")
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
                .accessibilityIdentifier("scannerStartScanButton")

                if state.scanProgress.isScanning {
                    SpinnerView()
                        .padding(.leading, 4)
                }
            }

            if state.scanProgress.isScanning || state.scanProgress.processed > 0 {
                GroupBox("Progress") {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(
                            value: Double(state.scanProgress.processed),
                            total: max(1.0, Double(state.scanProgress.total))
                        )
                        .progressViewStyle(SafeLinearProgressStyle())
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
                    if #available(macOS 13, *) {
                        recentScansTable
                    } else {
                        LegacyRecentScansTable(scanRuns: state.scanRuns)
                    }
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

    @available(macOS 13, *)
    private var recentScansTable: some View {
        RecentScansTable(scanRuns: state.scanRuns)
    }
}

@available(macOS 13, *)
private struct RecentScansTable: View {
    let scanRuns: [ScanRun]

    var body: some View {
        Table(scanRuns) {
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

    private func statusColor(_ status: ScanStatus) -> Color {
        switch status {
        case .running:   return .orange
        case .completed: return .green
        case .failed:    return .red
        }
    }
}

/// Pure-SwiftUI spinner — avoids NSProgressIndicator which crashes with
/// EXC_BAD_INSTRUCTION in validateDimension on macOS 12.
private struct SpinnerView: View {
    @State private var angle: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.9)
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

/// Pure-SwiftUI linear progress bar — avoids NSProgressIndicator which
/// crashes with EXC_BAD_INSTRUCTION in validateDimension on macOS 12.
private struct SafeLinearProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.25))
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * CGFloat(configuration.fractionCompleted ?? 0))
            }
        }
        .frame(height: 6)
    }
}

private struct LegacyRecentScansTable: View {
    let scanRuns: [ScanRun]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(scanRuns) { run in
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.rootPath)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 12) {
                        Text(run.status.rawValue.capitalized)
                            .foregroundColor(statusColor(run.status))
                        Text("Photos: \(run.photosFound)")
                        Text("Duplicates: \(run.duplicatesFound)")
                        Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption)
                    Divider()
                }
            }
        }
        .frame(minHeight: 140)
    }

    private func statusColor(_ status: ScanStatus) -> Color {
        switch status {
        case .running:   return .orange
        case .completed: return .green
        case .failed:    return .red
        }
    }
}
