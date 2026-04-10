import Foundation
import CryptoKit
import ImageIO

private let supportedExtensions: Set<String> = [
    "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif",
    "cr2", "cr3", "nef", "arw", "dng", "raf", "orf", "rw2", "pef"
]

private let maxConcurrency = ProcessInfo.processInfo.activeProcessorCount

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
    private let onProgress: @Sendable (ScanProgress) async -> Void

    init(db: AppDatabase, onProgress: @Sendable @escaping (ScanProgress) async -> Void) {
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

        // Do a fast count pass first so we can show total in progress
        let total = countPhotos(in: rootURL)

        await onProgress(ScanProgress(total: total, processed: 0, isScanning: true))

        let counter = ScanCounter()
        let knownPaths = (try? db.fetchAllPaths()) ?? []

        // Stream the enumerator directly — never holds all URLs in memory at once
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            run.status = .completed
            try db.updateScanRun(run)
            return run
        }

        await withTaskGroup(of: Void.self) { group in
            var active = 0
            var lastProgressDate = Date.distantPast
            let progressThrottle = 0.15 // seconds between UI updates
            for case let url as URL in enumerator {
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
                guard supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }

                if active >= maxConcurrency {
                    await group.next()
                    active -= 1
                }
                let runId = run.id!
                group.addTask { [self] in
                    await self.processPhoto(url: url, scanRunId: runId, knownPaths: knownPaths, counter: counter)
                }
                active += 1

                let now = Date()
                if now.timeIntervalSince(lastProgressDate) >= progressThrottle {
                    lastProgressDate = now
                    let snap = await counter.snapshot()
                    await onProgress(ScanProgress(total: total, processed: min(snap.processed, total), isScanning: true))
                }
            }
            await group.waitForAll()
        }

        let snap = await counter.snapshot()

        run.finishedAt = Date()
        run.photosFound = snap.processed
        run.duplicatesFound = snap.duplicatesFound
        run.status = .completed
        try db.updateScanRun(run)

        await onProgress(ScanProgress(total: total, processed: snap.processed, duplicatesFound: snap.duplicatesFound, isScanning: false))
        return run
    }

    private func countPhotos(in root: URL) -> Int {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        var count = 0
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else { continue }
            if supportedExtensions.contains(url.pathExtension.lowercased()) { count += 1 }
        }
        return count
    }

    private func processPhoto(url: URL, scanRunId: Int64, knownPaths: Set<String>, counter: ScanCounter) async {
        // Skip if already scanned
        if knownPaths.contains(url.path) { return }

        // Open file once; derive file size, EXIF, and thumbnail from the same source
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }

        // File size from attributes (CGImageSource doesn't expose raw byte count)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        let hash = computeHash(url: url)
        let exif = EXIFReader.read(from: imageSource)
        let modDate = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)

        var photo = Photo(
            path: url.path,
            hash: hash,
            fileSize: fileSize,
            width: exif.width,
            height: exif.height,
            takenAt: exif.takenAt ?? modDate,
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

        // Generate thumbnail before the DB write so we can store the path in one shot
        // Use a temp ID of 0; we remap after insert using the real id
        do {
            try db.upsertPhoto(&photo)
            // Now that we have a real id, generate (or locate) the thumbnail
            if let photoId = photo.id {
                let thumbPath = ThumbnailService.thumbnail(for: photoId, sourceURL: url, imageSource: imageSource)
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

        // Fast partial hash: first 64KB + last 64KB.
        // Full-file reads on large RAW files would dominate scan time;
        // partial hashing is sufficient to detect duplicates in practice.
        let chunkSize = 65536
        var hasher = SHA256()

        let head = handle.readData(ofLength: chunkSize)
        guard !head.isEmpty else { return nil }
        hasher.update(data: head)

        // Seek to last 64KB if file is large enough
        if let end = try? handle.seekToEnd(), end > UInt64(chunkSize * 2) {
            let tailOffset = end - UInt64(chunkSize)
            try? handle.seek(toOffset: tailOffset)
            let tail = handle.readData(ofLength: chunkSize)
            if !tail.isEmpty { hasher.update(data: tail) }
        }

        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}
