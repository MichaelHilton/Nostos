import Foundation

final class Organizer {
    private let db: AppDatabase
    private let onProgress: @Sendable (OrganizeProgress) -> Void

    init(db: AppDatabase, onProgress: @Sendable @escaping (OrganizeProgress) -> Void) {
        self.db = db
        self.onProgress = onProgress
    }

    func organize(
        destination: URL,
        folderFormat: String,
        dryRun: Bool
    ) async throws -> OrganizeJob {
        var job = OrganizeJob(
            destinationRoot: destination.path,
            folderFormat: folderFormat,
            dryRun: dryRun,
            startedAt: Date(),
            status: .running,
            totalFiles: 0,
            copiedFiles: 0,
            skippedFiles: 0
        )
        try db.insertOrganizeJob(&job)

        let total = (try? db.photoCount()) ?? 0
        job.totalFiles = total
        try db.updateOrganizeJob(job)

        onProgress(OrganizeProgress(total: total, isRunning: true))

        var copied = 0
        var skipped = 0

        let photos = try db.fetchAllPhotos()
        for photo in photos {
            guard let photoId = photo.id else { continue }

            let (action, reason, destPath) = planAction(
                photo: photo,
                destination: destination,
                folderFormat: folderFormat
            )

            var result = OrganizeResult(
                jobId: job.id!,
                photoId: photoId,
                source: photo.path,
                destination: destPath,
                action: action,
                reason: reason
            )

            if !dryRun && action == .copy, let dest = destPath {
                do {
                    let destURL = URL(fileURLWithPath: dest)
                    try FileManager.default.createDirectory(
                        at: destURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try FileManager.default.copyItem(
                        at: URL(fileURLWithPath: photo.path),
                        to: destURL
                    )

                    var updated = photo
                    updated.status = .copied
                    try db.updatePhoto(updated)
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

            try db.insertOrganizeResult(&result)
            onProgress(OrganizeProgress(total: total, copied: copied, skipped: skipped, isRunning: true))
        }

        job.finishedAt = Date()
        job.copiedFiles = copied
        job.skippedFiles = skipped
        job.status = .completed
        try db.updateOrganizeJob(job)

        onProgress(OrganizeProgress(total: total, copied: copied, skipped: skipped, isRunning: false))
        return job
    }

    private func planAction(
        photo: Photo,
        destination: URL,
        folderFormat: String
    ) -> (OrganizeAction, String?, String?) {
        // Skip non-kept members of a duplicate group
        if photo.duplicateGroupId != nil && !photo.isKept {
            return (.skipDuplicate, "not the kept copy", nil)
        }

        // Skip already-copied photos
        if photo.status == .copied {
            return (.skipExists, "already copied", nil)
        }

        let date = photo.takenAt ?? photo.scannedAt
        let folder = formatFolder(date: date, format: folderFormat)
        let sourceURL = URL(fileURLWithPath: photo.path)
        let destDir = destination.appendingPathComponent(folder)
        var destURL = destDir.appendingPathComponent(sourceURL.lastPathComponent)

        // Conflict resolution: if a different file exists at destination
        if FileManager.default.fileExists(atPath: destURL.path) {
            if let existingHash = hashOfFile(at: destURL), existingHash == photo.hash {
                return (.skipExists, "identical file exists", destURL.path)
            }
            // Rename with a suffix
            let name = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            destURL = destDir.appendingPathComponent("\(name)_1.\(ext)")
            return (.renameConflict, "name conflict", destURL.path)
        }

        return (.copy, nil, destURL.path)
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

    private func hashOfFile(at url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = CryptoKit.SHA256()
        while true {
            let chunk = handle.readData(ofLength: 65536)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}

// Import CryptoKit for the hash helper
import CryptoKit
