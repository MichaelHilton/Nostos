import Foundation
import ImageIO
import CoreGraphics
import AppKit

enum ThumbnailService {
    static let size: Int = 300

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

    /// Returns the path to the thumbnail, generating it if needed.
    static func thumbnail(for photoId: Int64, sourceURL: URL) -> String? {
        let dest = cacheDir.appendingPathComponent("\(photoId).jpg")
        if FileManager.default.fileExists(atPath: dest.path) {
            return dest.path
        }
        return generate(from: sourceURL, to: dest)
    }

    @discardableResult
    private static func generate(from source: URL, to dest: URL) -> String? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: size,
            kCGImageSourceShouldCacheImmediately: false
        ]

        guard let src = CGImageSourceCreateWithURL(source as CFURL, nil),
              let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
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
            try (data as Data).write(to: dest, options: .atomic)
            return dest.path
        } catch {
            return nil
        }
    }

    static func loadImage(path: String) -> NSImage? {
        NSImage(contentsOfFile: path)
    }
}
