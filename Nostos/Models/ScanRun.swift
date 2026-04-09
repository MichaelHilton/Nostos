import Foundation
import GRDB

enum ScanStatus: String, Codable {
    case running, completed, failed
}

struct ScanRun: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var rootPath: String
    var startedAt: Date
    var finishedAt: Date?
    var photosFound: Int
    var duplicatesFound: Int
    var status: ScanStatus

    static let databaseTableName = "scan_runs"

    enum CodingKeys: String, CodingKey {
        case id
        case rootPath = "root_path"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case photosFound = "photos_found"
        case duplicatesFound = "duplicates_found"
        case status
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct ScanProgress {
    var total: Int = 0
    var processed: Int = 0
    var duplicatesFound: Int = 0
    var isScanning: Bool = false
    var error: String?
}
