import Foundation

@MainActor
final class ScanOperation: Operation<ScanRun> {
    @Published var scanProgress = ScanProgress()

    private let container: ServiceContainer
    private let rootURL: URL

    init(container: ServiceContainer, rootURL: URL) {
        self.container = container
        self.rootURL = rootURL
        super.init {
            ScanRun(
                rootPath: rootURL.path,
                startedAt: Date(),
                photosFound: 0,
                duplicatesFound: 0,
                status: .completed
            )
        }
    }

    override func execute() {
        cancel()

        isLoading = true
        error = nil
        result = nil

        _cancelTask = Task {
            do {
                let onProgress: @Sendable (ScanProgress) async -> Void = { [weak self] progress in
                    await MainActor.run { [weak self] in
                        self?.scanProgress = progress
                    }
                }

                let scanner = container.makeScanner(onProgress: onProgress)
                let run = try await scanner.scan(rootURL: rootURL)

                let detector = container.duplicateDetector
                _ = try detector.detect()

                result = run
            } catch {
                self.error = error.localizedDescription
            }

            isLoading = false
        }
    }
}
