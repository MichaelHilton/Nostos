import Foundation
import GRDB

enum DuplicateReason: String, Codable {
    case hashMatch = "hash_match"
    case exifMatch = "exif_match"
}

struct DuplicateGroup: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var reason: DuplicateReason
    var keptPhotoId: Int64?

    static let databaseTableName = "duplicate_groups"

    enum CodingKeys: String, CodingKey {
        case id
        case reason
        case keptPhotoId = "kept_photo_id"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct DuplicateGroupWithPhotos: Identifiable {
    var group: DuplicateGroup
    var photos: [Photo]

    var id: Int64? { group.id }
}
