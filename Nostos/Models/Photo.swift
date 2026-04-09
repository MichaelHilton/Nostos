import Foundation
import GRDB

enum PhotoStatus: String, Codable, CaseIterable {
    case new
    case copied
    case skippedDuplicate = "skipped_duplicate"
    case skippedExists = "skipped_exists"
    case skippedConflict = "skipped_conflict"
}

struct Photo: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var path: String
    var hash: String?
    var fileSize: Int64
    var width: Int?
    var height: Int?
    var takenAt: Date?
    var cameraMake: String?
    var cameraModel: String?
    var gpsLat: Double?
    var gpsLon: Double?
    var thumbnailPath: String?
    var duplicateGroupId: Int64?
    var isKept: Bool
    var status: PhotoStatus
    var scannedAt: Date
    var scanRunId: Int64?

    static let databaseTableName = "photos"

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case hash
        case fileSize = "file_size"
        case width
        case height
        case takenAt = "taken_at"
        case cameraMake = "camera_make"
        case cameraModel = "camera_model"
        case gpsLat = "gps_lat"
        case gpsLon = "gps_lon"
        case thumbnailPath = "thumbnail_path"
        case duplicateGroupId = "duplicate_group_id"
        case isKept = "is_kept"
        case status
        case scannedAt = "scanned_at"
        case scanRunId = "scan_run_id"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct PhotoFilter {
    // Multi-select filters
    var status: Set<PhotoStatus> = []
    var cameraModels: Set<String> = []
    var dateFrom: Date?
    var dateTo: Date?
    // Use Set<Bool> where `true` = has duplicates, `false` = no duplicates.
    // Empty set means no duplicates filter (any).
    var hasDuplicates: Set<Bool> = []

    var limit: Int = 100
    var offset: Int = 0
}
