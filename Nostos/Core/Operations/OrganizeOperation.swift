import Foundation

@MainActor
final class OrganizeOperation: Operation<OrganizeJob> {
    @Published var organizeProgress = OrganizeProgress()

    private let container: ServiceContainer
    private let destination: URL
    private let folderFormat: String
    private let dryRun: Bool

    init(
        container: ServiceContainer,
        destination: URL,
        folderFormat: String,
        dryRun: Bool
    ) {
        self.container = container
        self.destination = destination
        self.folderFormat = folderFormat
        self.dryRun = dryRun
        super.init {
            OrganizeJob(
                destinationRoot: destination.path,
                folderFormat: folderFormat,
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
                let onProgress: @Sendable (OrganizeProgress) -> Void = { [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.organizeProgress = progress
                    }
                }

                let organizer = container.makeOrganizer(onProgress: onProgress)
                let job = try await organizer.organize(
                    destination: destination,
                    folderFormat: folderFormat,
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
