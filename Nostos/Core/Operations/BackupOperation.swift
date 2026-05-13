import Foundation

@MainActor
final class BackupOperation: Operation<BackupJob> {
    @Published var backupProgress = BackupProgress()

    private let container: ServiceContainer
    private let vaultRootURL: URL
    private let folderFormat: String
    private let filter: PhotoFilter
    private let dryRun: Bool

    init(
        container: ServiceContainer,
        vaultRootURL: URL,
        folderFormat: String,
        filter: PhotoFilter,
        dryRun: Bool
    ) {
        self.container = container
        self.vaultRootURL = vaultRootURL
        self.folderFormat = folderFormat
        self.filter = filter
        self.dryRun = dryRun
        super.init {
            BackupJob(
                folderFormat: folderFormat,
                filterSummary: nil,
                dryRun: dryRun,
                startedAt: Date(),
                status: .running,
                totalFiles: 0,
                copiedFiles: 0,
                skippedFiles: 0
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
                let onProgress: @Sendable (BackupProgress) -> Void = { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.backupProgress = progress
                    }
                }

                let backupService = container.makeBackupService(onProgress: onProgress)
                let job = try await backupService.backup(
                    vaultRootURL: vaultRootURL,
                    folderFormat: folderFormat,
                    filter: filter,
                    dryRun: dryRun
                )

                result = job
            } catch {
                self.error = error.localizedDescription
            }

            isLoading = false
        }
    }
}
