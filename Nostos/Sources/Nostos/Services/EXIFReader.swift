import Foundation
import ImageIO
import CoreFoundation

struct EXIFData {
    var takenAt: Date?
    var cameraMake: String?
    var cameraModel: String?
    var gpsLat: Double?
    var gpsLon: Double?
    var width: Int?
    var height: Int?
}

enum EXIFReader {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func read(from url: URL) -> EXIFData {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let rawProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil),
              let props = rawProps as? [String: Any] else {
            return EXIFData()
        }

        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let gps  = props[kCGImagePropertyGPSDictionary as String] as? [String: Any]

        // Date taken — prefer EXIF DateTimeOriginal, fall back to DateTime
        var takenAt: Date?
        let dateString = exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String
            ?? exif?[kCGImagePropertyExifDateTimeDigitized as String] as? String
            ?? tiff?[kCGImagePropertyTIFFDateTime as String] as? String
        if let str = dateString {
            takenAt = dateFormatter.date(from: str)
        }

        // Camera info from TIFF IFD
        let cameraMake  = tiff?[kCGImagePropertyTIFFMake as String] as? String
        let cameraModel = tiff?[kCGImagePropertyTIFFModel as String] as? String

        // GPS
        var gpsLat: Double?
        var gpsLon: Double?
        if let gpsDict = gps,
           let lat = gpsDict[kCGImagePropertyGPSLatitude as String] as? Double,
           let lon = gpsDict[kCGImagePropertyGPSLongitude as String] as? Double {
            let latRef = gpsDict[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
            let lonRef = gpsDict[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
            gpsLat = latRef == "S" ? -lat : lat
            gpsLon = lonRef == "W" ? -lon : lon
        }

        // Pixel dimensions
        let width  = props[kCGImagePropertyPixelWidth as String] as? Int
        let height = props[kCGImagePropertyPixelHeight as String] as? Int

        return EXIFData(
            takenAt: takenAt,
            cameraMake: cameraMake,
            cameraModel: cameraModel,
            gpsLat: gpsLat,
            gpsLon: gpsLon,
            width: width,
            height: height
        )
    }
}
