import Foundation

@MainActor
final class ServiceContainer {
    private let db: AppDatabase

    private var _duplicateDetector: DuplicateDetector?

    init(db: AppDatabase) {
        self.db = db
    }

    // MARK: - Stateless Services (Singletons)

    var duplicateDetector: DuplicateDetector {
        if _duplicateDetector == nil {
            _duplicateDetector = DuplicateDetector(db: db)
        }
        return _duplicateDetector!
    }

    // MARK: - Progress-Aware Services (Factory Methods)

    func makeScanner(onProgress: @Sendable @escaping (ScanProgress) async -> Void) -> Scanner {
        Scanner(db: db, onProgress: onProgress)
    }

    func makeOrganizer(onProgress: @Sendable @escaping (OrganizeProgress) -> Void) -> Organizer {
        Organizer(db: db, onProgress: onProgress)
    }

    func makeBackupService(onProgress: @Sendable @escaping (BackupProgress) -> Void) -> BackupService {
        BackupService(db: db, onProgress: onProgress)
    }

    // MARK: - Testing

    func resetServices() {
        _duplicateDetector = nil
    }
}
