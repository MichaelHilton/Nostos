import Foundation
import ImageIO
import CoreGraphics
import AppKit

enum ThumbnailService {
    static let size: Int = 300

    // Test hook: when set, `loadImage(path:)` will use this closure instead of reading disk.
    static var testImageLoader: ((String) -> NSImage?)? = nil

    private static var cacheDir: URL = {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("Nostos/thumbnails", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static func configure(vaultRootURL: URL? = nil) {
        let fm = FileManager.default

        if let vaultRootURL {
            let dir = vaultRootURL.appendingPathComponent(".nostos/thumbnails", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            cacheDir = dir
        } else {
            cacheDir = {
                let appSupport = try! fm.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                let dir = appSupport.appendingPathComponent("Nostos/thumbnails", isDirectory: true)
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir
            }()
        }
    }

    /// Returns the path to the thumbnail, generating it if needed.
    static func thumbnail(for photoId: Int64, sourceURL: URL, imageSource: CGImageSource? = nil) -> String? {
        let dest = cacheDir.appendingPathComponent("\(photoId).jpg")
        if FileManager.default.fileExists(atPath: dest.path) {
            return dest.path
        }
        return generate(from: sourceURL, imageSource: imageSource, to: dest)
    }

    @discardableResult
    private static func generate(from source: URL, imageSource: CGImageSource?, to dest: URL) -> String? {
        let src: CGImageSource
        if let provided = imageSource {
            src = provided
        } else {
            guard let created = CGImageSourceCreateWithURL(source as CFURL, nil) else { return nil }
            src = created
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: size,
            kCGImageSourceShouldCacheImmediately: false
        ]

        guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
            return nil
        }

        let data = NSMutableData()
        guard let imgDest = CGImageDestinationCreateWithData(
            data, "public.jpeg" as CFString, 1, nil
        ) else { return nil }

        let jpegOptions: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.8]
        CGImageDestinationAddImage(imgDest, thumb, jpegOptions as CFDictionary)
        guard CGImageDestinationFinalize(imgDest) else { return nil }

        do {
            // ensure parent directory still exists (some tests remove the vault)
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try (data as Data).write(to: dest, options: .atomic)
            return dest.path
        } catch {
            return nil
        }
    }

    static func loadImage(path: String) -> NSImage? {
        if let loader = Self.testImageLoader {
            return loader(path)
        }

        if let cached = ImageCache.shared.image(forKey: path) {
            return cached
        }

        if let img = NSImage(contentsOfFile: path) {
            ImageCache.shared.insert(img, forKey: path)
            return img
        }
        return nil
    }

    static func loadImageAsync(path: String) async -> NSImage? {
        if let cached = ImageCache.shared.image(forKey: path) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Use Image I/O to downsample while loading to avoid creating large images
                let url = URL(fileURLWithPath: path)
                if let src = CGImageSourceCreateWithURL(url as CFURL, nil) {
                    let options: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: size,
                        kCGImageSourceShouldCacheImmediately: false
                    ]
                    if let cgThumb = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) {
                        // Create NSImage on the main thread (AppKit is not thread-safe).
                        DispatchQueue.main.async {
                            let img = NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
                            ImageCache.shared.insert(img, forKey: path)
                            continuation.resume(returning: img)
                        }
                        return
                    }
                }

                // Fallback to NSImage on main thread if Image I/O failed
                DispatchQueue.main.async {
                    let loadedImage = NSImage(contentsOfFile: path)
                    if let img = loadedImage {
                        ImageCache.shared.insert(img, forKey: path)
                    }
                    continuation.resume(returning: loadedImage)
                }
            }
        }
    }
}
