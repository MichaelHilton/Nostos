import Foundation
import GRDB

enum BackupAction: String, Codable {
    case copy
    case skipInVault = "skip_in_vault"
    case skipDuplicate = "skip_duplicate"
}

struct VaultPhoto: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var vaultPath: String
    var hash: String
    var fileSize: Int64
    var sourcePath: String?
    var backedUpAt: Date
    var backupJobId: Int64?

    static let databaseTableName = "vault_photos"

    enum CodingKeys: String, CodingKey {
        case id
        case vaultPath = "vault_path"
        case hash
        case fileSize = "file_size"
        case sourcePath = "source_path"
        case backedUpAt = "backed_up_at"
        case backupJobId = "backup_job_id"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct BackupJob: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var folderFormat: String
    var filterSummary: String?
    var dryRun: Bool
    var startedAt: Date
    var finishedAt: Date?
    var status: JobStatus
    var totalFiles: Int
    var copiedFiles: Int
    var skippedFiles: Int

    static let databaseTableName = "backup_jobs"

    enum CodingKeys: String, CodingKey {
        case id
        case folderFormat = "folder_format"
        case filterSummary = "filter_summary"
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

struct BackupResult: Identifiable, Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var jobId: Int64
    var photoId: Int64
    var source: String
    var vaultPath: String?
    var action: BackupAction
    var reason: String?

    static let databaseTableName = "backup_results"

    enum CodingKeys: String, CodingKey {
        case id
        case jobId = "job_id"
        case photoId = "photo_id"
        case source
        case vaultPath = "vault_path"
        case action
        case reason
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct BackupProgress {
    var total: Int = 0
    var copied: Int = 0
    var skipped: Int = 0
    var isRunning: Bool = false
    var error: String?
}
