import Foundation
import SwiftUI
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

extension Array where Element == ScanRun {
    var lastScanLabel: String {
        guard let last = first, let finishedAt = last.finishedAt else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: finishedAt, relativeTo: Date())
    }
}

extension ScanStatus {
    var color: Color {
        switch self {
        case .running:   return .nostosOrange
        case .completed: return .nostosGreen
        case .failed:    return .nostosRed
        }
    }
}
