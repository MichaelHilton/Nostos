import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var state: AppState
    @State var selectedPath: String

    init() {
        let sourcePath = ProcessInfo.processInfo.environment["UI_TESTING_SOURCE_DIRECTORY_TO_PICK"] ?? ""
        _selectedPath = State(initialValue: sourcePath)
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeaderView(
                title: "Scanner",
                subtitle: "Scan a folder to find and catalogue your photos"
            )

            ScrollView {
                VStack(spacing: NostosSpacing.xxxl) {
                    // Stat cards row
                    HStack(spacing: NostosSpacing.xl) {
                        NostosStatCard("Total Scanned", value: "\(state.totalPhotoCount)")
                        NostosStatCard("Catalogued", value: "\(state.totalPhotoCount)")
                        NostosStatCard("Duplicates", value: "\(state.duplicateGroups.count)")
                        NostosStatCard("Last Scan", value: state.scanRuns.lastScanLabel)
                    }
                    .padding(.horizontal, NostosSpacing.pagePadding)

                    // Source folder card
                    SourceFolderCard(selectedPath: selectedPath, onChoose: {
                        if let url = state.pickDirectory() {
                            selectedPath = url.path
                        }
                    })

                    // Scan button
                    ScanActionBar(
                        isScanning: state.scanProgress.isScanning,
                        isDisabled: selectedPath.isEmpty || state.scanProgress.isScanning,
                        onStartScan: {
                            state.startScan(rootURL: URL(fileURLWithPath: selectedPath))
                        }
                    )

                    // Progress card
                    if state.scanProgress.isScanning || state.scanProgress.processed > 0 {
                        CardView {
                            VStack(alignment: .leading, spacing: NostosSpacing.lg) {
                                SectionLabel("Progress")

                                let progress = Double(state.scanProgress.processed) / Double(max(1, state.scanProgress.total))
                                NostosProgressBar(progress, total: 1.0)

                                HStack(spacing: 40) {
                                    Stat("Files Found", value: "\(state.scanProgress.total)")
                                    Stat("Processed", value: "\(state.scanProgress.processed)")
                                    Stat("Duplicates", value: "\(state.scanProgress.duplicatesFound)")
                                }
                            }
                            .padding(NostosSpacing.lg)
                        }
                    }

                    // Recent scans table
                    if !state.scanRuns.isEmpty {
                        CardView {
                            VStack(alignment: .leading, spacing: 0) {
                                SectionLabel("Recent Scans")
                                    .padding(NostosSpacing.lg)

                                recentScansTable
                                    .padding(NostosSpacing.lg)
                            }
                        }
                    }
                }
                .padding(.vertical, NostosSpacing.xxxl)
            }
            .background(Color.nostosBg)
            .overlay(alignment: .topLeading) {
                StarDotBackground()
                    .allowsHitTesting(false)
            }
        }
    }

    private var recentScansTable: some View {
        RecentScansTable(scanRuns: state.scanRuns)
    }
}

struct SourceFolderCard: View {
    let selectedPath: String
    let onChoose: () -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: NostosSpacing.lg) {
                SectionLabel("Source Folder")

                HStack(spacing: NostosSpacing.xl) {
                    Text(selectedPath.isEmpty ? "No folder selected" : selectedPath)
                        .accessibilityIdentifier("scannerSelectedPathText")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.nostosFg2)
                        .padding(.horizontal, NostosSpacing.md)
                        .padding(.vertical, NostosSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.nostosSurface2)
                        .border(Color.nostosBorder, width: 1)
                        .cornerRadius(NostosRadii.md)

                    Button(action: onChoose) {
                        Text("Choose…")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("scannerChooseDirectoryButton")
                }
            }
            .padding(NostosSpacing.lg)
        }
        .accessibilityIdentifier("scannerSourceFolderCard")
        .accessibilityLabel(selectedPath.isEmpty ? "Source Folder. No folder selected" : "Source Folder. \(selectedPath)")
    }
}

struct ScanActionBar: View {
    let isScanning: Bool
    let isDisabled: Bool
    let onStartScan: () -> Void

    var body: some View {
        HStack(spacing: NostosSpacing.md) {
            Button(action: onStartScan) {
                Text(isScanning ? "↻  Scanning…" : "▶  Start Scan")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDisabled)
            .accessibilityIdentifier("scannerStartScanButton")

            if isScanning {
                SpinnerView()
            }
        }
        .padding(.horizontal, NostosSpacing.pagePadding)
    }
}

struct SpinnerView: View {
    @State var angle: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.9)
            .stroke(Color.nostosAccent, lineWidth: 2)
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(angle))
            .onAppear { startRotation() }
    }

    func startRotation() {
        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
            angle = 360
        }
    }
}

struct RecentScansTable: View {
    let scanRuns: [ScanRun]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(scanRuns) { (run: ScanRun) in
                VStack(alignment: .leading, spacing: 4) {
                    Text(run.rootPath)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(.nostosFg1)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 12) {
                        Text(run.status.rawValue.capitalized)
                            .foregroundColor(run.status.color)
                        Text("Photos: \(run.photosFound)")
                        Text("Dups: \(run.duplicatesFound)")
                        Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.nostosFg3)
                    Divider()
                        .background(Color.nostosBorder)
                }
            }
        }
        .frame(minHeight: 140)
    }
}
