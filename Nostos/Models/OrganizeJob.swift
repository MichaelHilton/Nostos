import Foundation
import GRDB

enum JobStatus: String, Codable {
    case running, completed, failed
}

enum OrganizeAction: String, Codable {
    case copy
    case skipExists = "skip_exists"
    case skipDuplicate = "skip_duplicate"
    case renameConflict = "rename_conflict"
}

struct OrganizeJob: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var destinationRoot: String
    var folderFormat: String
    var dryRun: Bool
    var startedAt: Date
    var finishedAt: Date?
    var status: JobStatus
    var totalFiles: Int
    var copiedFiles: Int
    var skippedFiles: Int

    static let databaseTableName = "organize_jobs"

    enum CodingKeys: String, CodingKey {
        case id
        case destinationRoot = "destination_root"
        case folderFormat = "folder_format"
        case dryRun = "dry_run"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case status
        case totalFiles = "total_files"
        case copiedFiles = "copied_files"
        case skippedFiles = "skipped_files"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct OrganizeResult: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var jobId: Int64
    var photoId: Int64
    var source: String
    var destination: String?
    var action: OrganizeAction
    var reason: String?

    static let databaseTableName = "organize_results"

    enum CodingKeys: String, CodingKey {
        case id
        case jobId = "job_id"
        case photoId = "photo_id"
        case source
        case destination
        case action
        case reason
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct OrganizeProgress {
    var total: Int = 0
    var copied: Int = 0
    var skipped: Int = 0
    var isRunning: Bool = false
    var error: String?
}
