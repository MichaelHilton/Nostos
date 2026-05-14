import Foundation
import AppKit

final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        // Set a conservative cost limit (bytes). Adjust as needed.
        cache.totalCostLimit = 200 * 1024 * 1024 // 200 MB
    }

    func image(forKey key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func insert(_ image: NSImage, forKey key: String) {
        let cost = imageCost(image: image)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private func imageCost(image: NSImage) -> Int {
        guard let rep = image.representations.first else { return 0 }
        let pixels = rep.pixelsWide * rep.pixelsHigh
        // Assume 4 bytes per pixel (RGBA)
        return max(1, pixels * 4)
    }
}

final class ThumbnailLoader: ObservableObject {
    @Published var image: NSImage?

    private var task: Task<Void, Never>?
    private var workItem: DispatchWorkItem?

    func load(thumbnailPath: String?, fallbackGenerate: (() -> String?)? = nil) {
        // Cancel any previous work
        task?.cancel()
        image = nil

        guard let path = thumbnailPath ?? fallbackGenerate?() else { return }

        if let cached = ImageCache.shared.image(forKey: path) {
            image = cached
            return
        }

        // Cancel any previous work item
        workItem?.cancel()

        let work = DispatchWorkItem(qos: .userInitiated) { [weak self] in
            let img = NSImage(contentsOfFile: path)
            DispatchQueue.main.async {
                if let img = img {
                    ImageCache.shared.insert(img, forKey: path)
                }
                self?.image = img
            }
        }
        workItem = work
        DispatchQueue.global(qos: .userInitiated).async(execute: work)
        // Keep a placeholder Task so `cancel()` can be used to cancel both Task and workItem
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64.max)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        workItem?.cancel()
        workItem = nil
    }
}
