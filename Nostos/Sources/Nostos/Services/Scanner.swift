import Foundation
import CryptoKit

private let supportedExtensions: Set<String> = [
    "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif",
    "cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2", "pef"
]

private let maxConcurrency = 8

actor ScanCounter {
    var processed: Int = 0
    var duplicatesFound: Int = 0

    func increment() { processed += 1 }
    func addDuplicates(_ n: Int) { duplicatesFound += n }
    func snapshot() -> (processed: Int, duplicatesFound: Int) {
        (processed, duplicatesFound)
    }
}

final class Scanner {
    private let db: AppDatabase
    private let onProgress: @Sendable (ScanProgress) -> Void

    init(db: AppDatabase, onProgress: @Sendable @escaping (ScanProgress) -> Void) {
        self.db = db
        self.onProgress = onProgress
    }

    func scan(rootURL: URL) async throws -> ScanRun {
        var run = ScanRun(
            rootPath: rootURL.path,
            startedAt: Date(),
            photosFound: 0,
            duplicatesFound: 0,
            status: .running
        )
        try db.insertScanRun(&run)

        // Collect all photo paths first
        let paths = collectPhotoPaths(in: rootURL)
        let total = paths.count

        onProgress(ScanProgress(total: total, processed: 0, isScanning: true))

        let counter = ScanCounter()

        // Process with bounded concurrency
        await withTaskGroup(of: Void.self) { group in
            var active = 0
            for url in paths {
                if active >= maxConcurrency {
                    await group.next()
                    active -= 1
                }
                let runId = run.id!
                group.addTask { [weak self] in
                    await self?.processPhoto(url: url, scanRunId: runId, counter: counter)
                }
                active += 1

                let snap = await counter.snapshot()
                onProgress(ScanProgress(total: total, processed: snap.processed, isScanning: true))
            }
            await group.waitForAll()
        }

        let snap = await counter.snapshot()

        run.finishedAt = Date()
        run.photosFound = snap.processed
        run.duplicatesFound = snap.duplicatesFound
        run.status = .completed
        try db.updateScanRun(run)

        onProgress(ScanProgress(total: total, processed: snap.processed, duplicatesFound: snap.duplicatesFound, isScanning: false))
        return run
    }

    private func collectPhotoPaths(in root: URL) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var paths: [URL] = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            if supportedExtensions.contains(url.pathExtension.lowercased()) {
                paths.append(url)
            }
        }
        return paths
    }

    private func processPhoto(url: URL, scanRunId: Int64, counter: ScanCounter) async {
        // Skip if already scanned
        if (try? db.fetchPhoto(path: url.path)) != nil { return }

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return }
        let fileSize = (attrs[.size] as? Int64) ?? 0

        let hash = computeHash(url: url)
        let exif = EXIFReader.read(from: url)

        var photo = Photo(
            path: url.path,
            hash: hash,
            fileSize: fileSize,
            width: exif.width,
            height: exif.height,
            takenAt: exif.takenAt ?? (attrs[.modificationDate] as? Date),
            cameraMake: exif.cameraMake,
            cameraModel: exif.cameraModel,
            gpsLat: exif.gpsLat,
            gpsLon: exif.gpsLon,
            thumbnailPath: nil,
            duplicateGroupId: nil,
            isKept: false,
            status: .new,
            scannedAt: Date(),
            scanRunId: scanRunId
        )

        do {
            try db.upsertPhoto(&photo)
            // Generate thumbnail after inserting so we have an id
            if let photoId = photo.id {
                let thumbPath = ThumbnailService.thumbnail(for: photoId, sourceURL: url)
                if thumbPath != photo.thumbnailPath {
                    photo.thumbnailPath = thumbPath
                    try db.updatePhoto(photo)
                }
            }
        } catch {
            // Skip photos that fail to insert (e.g. duplicate path race)
        }

        await counter.increment()
    }

    private func computeHash(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 65536)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}
