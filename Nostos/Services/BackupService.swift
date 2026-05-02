import Foundation
import CryptoKit

final class BackupService {
    private let db: AppDatabase
    private let onProgress: @Sendable (BackupProgress) -> Void

    init(db: AppDatabase, onProgress: @Sendable @escaping (BackupProgress) -> Void) {
        self.db = db
        self.onProgress = onProgress
    }

    func backup(
        vaultRootURL: URL,
        folderFormat: String,
        filter: PhotoFilter,
        dryRun: Bool,
        isPaused: @Sendable () async -> Bool = { false }
    ) async throws -> BackupJob {
        var job = BackupJob(
            folderFormat: folderFormat,
            filterSummary: describeFilter(filter),
            dryRun: dryRun,
            startedAt: Date(),
            status: .running,
            totalFiles: 0,
            copiedFiles: 0,
            skippedFiles: 0
        )
        try db.insertBackupJob(&job)

        let candidates = try db.fetchPhotosForBackup(filter: filter)
        let total = candidates.count

        job.totalFiles = total
        try db.updateBackupJob(job)

        onProgress(BackupProgress(total: total, isRunning: true))

        // Load vault hashes once for O(1) lookup — avoids per-photo DB round-trips
        let vaultHashes = (try? db.fetchAllVaultHashes()) ?? []

        var copied = 0
        var skipped = 0

        for photo in candidates {
            while await isPaused() {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            guard let photoId = photo.id else { continue }

            let (action, reason, destRelPath) = planAction(
                photo: photo,
                folderFormat: folderFormat,
                vaultHashes: vaultHashes
            )

            let destAbsPath = destRelPath.map { vaultRootURL.appendingPathComponent($0).path }

            var result = BackupResult(
                jobId: job.id!,
                photoId: photoId,
                source: photo.path,
                vaultPath: destAbsPath,
                action: action,
                reason: reason
            )

            if !dryRun && action == .copy, let destRel = destRelPath {
                do {
                    let destURL = vaultRootURL.appendingPathComponent(destRel)
                    try FileManager.default.createDirectory(
                        at: destURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try FileManager.default.copyItem(
                        at: URL(fileURLWithPath: photo.path),
                        to: destURL
                    )

                    var vaultPhoto = VaultPhoto(
                        vaultPath: destRel,
                        hash: photo.hash ?? "",
                        fileSize: photo.fileSize,
                        sourcePath: photo.path,
                        backedUpAt: Date(),
                        backupJobId: job.id
                    )
                    try db.insertVaultPhoto(&vaultPhoto)
                    copied += 1
                } catch {
                    result.reason = error.localizedDescription
                    skipped += 1
                }
            } else if action == .copy {
                copied += 1
            } else {
                skipped += 1
            }

            try db.insertBackupResult(&result)
            onProgress(BackupProgress(total: total, copied: copied, skipped: skipped, isRunning: true))
        }

        job.finishedAt = Date()
        job.copiedFiles = copied
        job.skippedFiles = skipped
        job.status = .completed
        try db.updateBackupJob(job)

        onProgress(BackupProgress(total: total, copied: copied, skipped: skipped, isRunning: false))
        return job
    }

    // MARK: - Private helpers

    private func planAction(
        photo: Photo,
        folderFormat: String,
        vaultHashes: Set<String>
    ) -> (BackupAction, String?, String?) {
        // Non-kept duplicate members are excluded at the query level, but guard just in case
        if photo.duplicateGroupId != nil && !photo.isKept {
            return (.skipDuplicate, "not the kept copy", nil)
        }

        // Skip if a file with this hash is already in the vault
        if let hash = photo.hash, !hash.isEmpty, vaultHashes.contains(hash) {
            return (.skipInVault, "already in vault", nil)
        }

        let date = photo.takenAt ?? photo.scannedAt
        let folder = formatFolder(date: date, format: folderFormat)
        let sourceURL = URL(fileURLWithPath: photo.path)
        let destRel = "\(folder)/\(sourceURL.lastPathComponent)"

        return (.copy, nil, destRel)
    }

    private func formatFolder(date: Date, format: String) -> String {
        let cal = Calendar.current
        let year  = String(cal.component(.year,  from: date))
        let month = String(format: "%02d", cal.component(.month, from: date))
        let day   = String(format: "%02d", cal.component(.day,   from: date))
        return format
            .replacingOccurrences(of: "YYYY", with: year)
            .replacingOccurrences(of: "MM",   with: month)
            .replacingOccurrences(of: "DD",   with: day)
    }

    private func describeFilter(_ filter: PhotoFilter) -> String {
        var parts: [String] = []
        if !filter.cameraModels.isEmpty {
            parts.append("cameras: \(filter.cameraModels.sorted().joined(separator: ", "))")
        }
        if let from = filter.yearFrom { parts.append("year ≥ \(from)") }
        if let to   = filter.yearTo   { parts.append("year ≤ \(to)")   }
        if let from = filter.dateFrom {
            parts.append("from \(from.formatted(date: .abbreviated, time: .omitted))")
        }
        if let to = filter.dateTo {
            parts.append("to \(to.formatted(date: .abbreviated, time: .omitted))")
        }
        return parts.isEmpty ? "all eligible photos" : parts.joined(separator: "; ")
    }
}
