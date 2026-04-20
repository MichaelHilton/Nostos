import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedPath: String

    init() {
        let sourcePath = ProcessInfo.processInfo.environment["UI_TESTING_SOURCE_DIRECTORY_TO_PICK"] ?? ""
        _selectedPath = State(initialValue: sourcePath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NostosPageHeader(
                title: "Scanner",
                subtitle: "Scan a folder to find and catalogue your photos"
            )

            ScrollView {
                ZStack(alignment: .topLeading) {
                    StarDotBackground()
                    VStack(alignment: .leading, spacing: 14) {
                        // Source folder
                        NostosCard {
                            SectionLabel(title: "Source Folder")
                            HStack(spacing: 10) {
                                Text(selectedPath.isEmpty ? "No folder selected" : selectedPath)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(selectedPath.isEmpty ? NostosTheme.fg3 : NostosTheme.fg2)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(NostosTheme.surface2)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(NostosTheme.border, lineWidth: 1)
                                    )
                                Button("Choose…") {
                                    if let url = state.pickDirectory() {
                                        selectedPath = url.path
                                    }
                                }
                                .buttonStyle(NostosButtonStyle(variant: .bordered))
                                .accessibilityIdentifier("scannerChooseDirectoryButton")
                            }
                        }

                        // Start scan button
                        HStack(spacing: 12) {
                            Button(action: startScan) {
                                Label(
                                    state.scanProgress.isScanning ? "Scanning…" : "Start Scan",
                                    systemImage: state.scanProgress.isScanning ? "arrow.triangle.2.circlepath" : "play.fill"
                                )
                            }
                            .buttonStyle(NostosButtonStyle(variant: .primary))
                            .disabled(selectedPath.isEmpty || state.scanProgress.isScanning)
                            .accessibilityIdentifier("scannerStartScanButton")

                            if state.scanProgress.isScanning {
                                SpinnerView()
                            }
                        }

                        // Progress
                        if state.scanProgress.isScanning || state.scanProgress.processed > 0 {
                            NostosCard {
                                SectionLabel(title: "Progress")
                                NostosProgressBar(
                                    value: Double(state.scanProgress.processed) / max(1, Double(state.scanProgress.total))
                                )
                                HStack(spacing: 40) {
                                    StatCell(label: "Files Found",
                                             value: "\(state.scanProgress.total)")
                                    StatCell(label: "Processed",
                                             value: "\(state.scanProgress.processed)",
                                             color: NostosTheme.accent)
                                    StatCell(label: "Duplicates",
                                             value: "\(state.scanProgress.duplicatesFound)",
                                             color: NostosTheme.orange)
                                }
                                .padding(.top, 14)
                            }
                        }

                        // Recent scans
                        if !state.scanRuns.isEmpty {
                            NostosCard {
                                SectionLabel(title: "Recent Scans")
                                if #available(macOS 13, *) {
                                    NostosRecentScansTable(scanRuns: state.scanRuns)
                                } else {
                                    LegacyRecentScansTable(scanRuns: state.scanRuns)
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
    }

    private func startScan() {
        state.startScan(rootURL: URL(fileURLWithPath: selectedPath))
    }
}

// MARK: - Recent scans table

@available(macOS 13, *)
private struct NostosRecentScansTable: View {
    let scanRuns: [ScanRun]

    var body: some View {
        Table(scanRuns) {
            TableColumn("Path") { run in
                Text(run.rootPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(NostosTheme.fg1)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            TableColumn("Status") { run in
                Text(run.status.rawValue.capitalized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(statusColor(run.status))
            }
            .width(80)
            TableColumn("Photos") { run in
                Text("\(run.photosFound)")
                    .font(.system(size: 12))
                    .foregroundColor(NostosTheme.fg1)
            }
            .width(60)
            TableColumn("Dups") { run in
                Text("\(run.duplicatesFound)")
                    .font(.system(size: 12))
                    .foregroundColor(NostosTheme.orange)
            }
            .width(50)
            TableColumn("Date") { run in
                Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(NostosTheme.fg3)
            }
            .width(160)
        }
        .frame(minHeight: 140)
    }

    private func statusColor(_ status: ScanStatus) -> Color {
        switch status {
        case .running:   return NostosTheme.orange
        case .completed: return NostosTheme.green
        case .failed:    return NostosTheme.red
        }
    }
}

private struct LegacyRecentScansTable: View {
    let scanRuns: [ScanRun]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(scanRuns.enumerated()), id: \.element.id) { idx, run in
                HStack(spacing: 8) {
                    Text(run.rootPath)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(NostosTheme.fg1)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(run.status.rawValue.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(statusColor(run.status))
                        .frame(width: 76)
                    Text("\(run.photosFound)")
                        .font(.system(size: 11))
                        .foregroundColor(NostosTheme.fg1)
                        .frame(width: 44, alignment: .trailing)
                    Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(NostosTheme.fg3)
                        .frame(width: 140, alignment: .trailing)
                }
                .padding(.vertical, 8)
                if idx < scanRuns.count - 1 {
                    Rectangle()
                        .fill(NostosTheme.borderFaint)
                        .frame(height: 1)
                }
            }
        }
        .frame(minHeight: 140)
    }

    private func statusColor(_ status: ScanStatus) -> Color {
        switch status {
        case .running:   return NostosTheme.orange
        case .completed: return NostosTheme.green
        case .failed:    return NostosTheme.red
        }
    }
}

// MARK: - Spinner (avoids NSProgressIndicator crash on macOS 12)

struct SpinnerView: View {
    @State private var angle: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0.1, to: 0.9)
            .stroke(NostosTheme.accent, lineWidth: 2)
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(angle))
            .onAppear {
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

// MARK: - Button style

enum NostosButtonVariant { case primary, bordered, plain, danger }

struct NostosButtonStyle: ButtonStyle {
    var variant: NostosButtonVariant = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 13)
            .padding(.vertical, 5)
            .foregroundColor(fgColor(pressed: configuration.isPressed))
            .background(bgColor(pressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private func fgColor(pressed: Bool) -> Color {
        switch variant {
        case .primary:  return .white
        case .bordered: return NostosTheme.fg1
        case .plain:    return NostosTheme.accent
        case .danger:   return NostosTheme.red
        }
    }

    private func bgColor(pressed: Bool) -> Color {
        switch variant {
        case .primary:  return pressed ? NostosTheme.accentHov : NostosTheme.accent
        case .bordered: return pressed ? NostosTheme.surface2 : Color.clear
        case .plain:    return Color.clear
        case .danger:   return pressed ? NostosTheme.red.opacity(0.1) : Color.clear
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary:  return Color.clear
        case .bordered: return NostosTheme.border
        case .plain:    return Color.clear
        case .danger:   return NostosTheme.red
        }
    }
}
