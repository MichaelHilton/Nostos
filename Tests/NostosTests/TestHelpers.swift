import Foundation
import AppKit
import ImageIO
import CoreGraphics
@testable import Nostos

// MARK: - Metadata

struct EXIFMetadata {
    var takenAt: Date?
    var cameraMake: String?
    var cameraModel: String?
    var gpsLat: Double?
    var gpsLon: Double?
}

// MARK: - JPEG Creation

// Backward compatibility: accept old-style dictionary metadata
func createJPEGFile(at url: URL, metadata: [String: Any]?) throws {
    let width = 16
    let height = 16
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        throw NSError(domain: "Test", code: 1, userInfo: nil)
    }
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "Test", code: 1, userInfo: nil)
    }

    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else {
        throw NSError(domain: "Test", code: 1, userInfo: nil)
    }

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
        throw NSError(domain: "Test", code: 1, userInfo: nil)
    }

    var properties: [String: Any] = [
        kCGImagePropertyPixelWidth as String: width,
        kCGImagePropertyPixelHeight as String: height,
    ]
    if let metadata = metadata {
        properties.merge(metadata) { current, _ in current }
    }

    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "Test", code: 1, userInfo: nil)
    }
}

// New-style EXIF metadata
func createJPEGFileWithExif(at url: URL, metadata: EXIFMetadata = EXIFMetadata()) throws {
    let width = 16
    let height = 16
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        throw NSError(domain: "Test", code: 1, userInfo: nil)
    }
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "Test", code: 1, userInfo: nil)
    }

    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let cgImage = context.makeImage() else {
        throw NSError(domain: "Test", code: 1, userInfo: nil)
    }

    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
        throw NSError(domain: "Test", code: 1, userInfo: nil)
    }

    var properties: [String: Any] = [
        kCGImagePropertyPixelWidth as String: width,
        kCGImagePropertyPixelHeight as String: height,
    ]

    // Build EXIF metadata if provided
    var exifDict: [String: Any] = [:]
    var tiffDict: [String: Any] = [:]
    var gpsDict: [String: Any] = [:]

    if let takenAt = metadata.takenAt {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let dateString = formatter.string(from: takenAt)
        exifDict[kCGImagePropertyExifDateTimeOriginal as String] = dateString
        tiffDict[kCGImagePropertyTIFFDateTime as String] = dateString
    }

    if let cameraMake = metadata.cameraMake {
        tiffDict[kCGImagePropertyTIFFMake as String] = cameraMake
    }

    if let cameraModel = metadata.cameraModel {
        tiffDict[kCGImagePropertyTIFFModel as String] = cameraModel
    }

    if let gpsLat = metadata.gpsLat {
        gpsDict[kCGImagePropertyGPSLatitude as String] = abs(gpsLat)
        gpsDict[kCGImagePropertyGPSLatitudeRef as String] = gpsLat >= 0 ? "N" : "S"
    }

    if let gpsLon = metadata.gpsLon {
        gpsDict[kCGImagePropertyGPSLongitude as String] = abs(gpsLon)
        gpsDict[kCGImagePropertyGPSLongitudeRef as String] = gpsLon >= 0 ? "E" : "W"
    }

    if !exifDict.isEmpty {
        properties[kCGImagePropertyExifDictionary as String] = exifDict
    }
    if !tiffDict.isEmpty {
        properties[kCGImagePropertyTIFFDictionary as String] = tiffDict
    }
    if !gpsDict.isEmpty {
        properties[kCGImagePropertyGPSDictionary as String] = gpsDict
    }

    CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "Test", code: 1, userInfo: nil)
    }
}

// MARK: - Directory Helpers

func makeTempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func createTempDirectory() throws -> URL {
    try makeTempDir()
}

func makeSourceDirectory(photos: [(filename: String, metadata: EXIFMetadata)]) throws -> URL {
    let dir = try makeTempDir()
    for (filename, metadata) in photos {
        let photoURL = dir.appendingPathComponent(filename)
        try createJPEGFileWithExif(at: photoURL, metadata: metadata)
    }
    return dir
}

// MARK: - Photo Builder

func makePhoto(
    path: String,
    hash: String? = nil,
    takenAt: Date? = nil,
    cameraMake: String? = nil,
    cameraModel: String? = nil,
    duplicateGroupId: Int64? = nil,
    isKept: Bool = true,
    status: PhotoStatus = .new,
    scannedAt: Date = Date()
) -> Photo {
    Photo(
        id: nil,
        path: path,
        hash: hash,
        fileSize: 1,
        width: nil,
        height: nil,
        takenAt: takenAt,
        cameraMake: cameraMake,
        cameraModel: cameraModel,
        gpsLat: nil,
        gpsLon: nil,
        thumbnailPath: nil,
        duplicateGroupId: duplicateGroupId,
        isKept: isKept,
        status: status,
        scannedAt: scannedAt,
        scanRunId: nil
    )
}

// MARK: - Cleanup

func removeTempDirectory(_ url: URL) throws {
    try FileManager.default.removeItem(at: url)
}
