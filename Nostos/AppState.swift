import Foundation
import AppKit

@MainActor
final class AppState: ObservableObject {
    private(set) var db: AppDatabase
    @Published private(set) var vaultRootURL: URL?

    // MARK: - Scan state
    @Published var scanRuns: [ScanRun] = []
    @Published var scanProgress = ScanProgress()

    // MARK: - Gallery state
    @Published var photos: [Photo] = []
    @Published var totalPhotoCount: Int = 0
    @Published var photoFilter = PhotoFilter()
    @Published var cameraModels: [String] = []
    @Published var years: [Int] = []

    // MARK: - Duplicates state
    @Published var duplicateGroups: [DuplicateGroupWithPhotos] = []

    // MARK: - Vault state
    @Published var organizeJobs: [OrganizeJob] = []
    @Published var organizeProgress = OrganizeProgress()
    @Published var lastOrganizeResults: [OrganizeResult] = []

    // MARK: - Backup state
    @Published var backupJobs: [BackupJob] = []
    @Published var backupProgress = BackupProgress()
    @Published var lastBackupResults: [BackupResult] = []

    // MARK: - General error state
    @Published var errorMessage: String?

    init() {
        let defaultVaultRoot = AppState.defaultVaultRootURL()
        self.vaultRootURL = defaultVaultRoot
        do {
            db = try AppDatabase.makeShared(vaultRootURL: defaultVaultRoot)
        } catch {
            fatalError("Failed to open database: \(error)")
        }
        ThumbnailService.configure(vaultRootURL: defaultVaultRoot)
        Task { await loadInitialData() }
    }

    init(vaultRootURL: URL) {
        self.vaultRootURL = vaultRootURL
        do {
            db = try AppDatabase.makeShared(vaultRootURL: vaultRootURL)
        } catch {
            fatalError("Failed to open database: \(error)")
        }
        ThumbnailService.configure(vaultRootURL: vaultRootURL)
        seedUITestDataIfNeeded()
        if ProcessInfo.processInfo.environment["UI_TESTING_SEED_DATA"] == "1" {
            photoFilter.limit = 10
        }
        Task { await loadInitialData() }
    }

    init(db: AppDatabase) {
        self.db = db
        self.vaultRootURL = nil
    }

    // MARK: - Data loading

    func loadInitialData() async {
        await loadScanRuns()
        await loadPhotos()
        await loadTotalPhotoCount()
        await loadCameraModels()
        await loadDuplicates()
        await loadOrganizeJobs()
        await loadBackupJobs()
    }

    func loadScanRuns() async {
        do {
            scanRuns = try db.fetchAllScanRuns()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPhotos() async {
        do {
            photos = try db.fetchPhotos(filter: photoFilter)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadTotalPhotoCount() async {
        do {
            totalPhotoCount = try db.photoCount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCameraModels() async {
        do {
            cameraModels = try db.fetchDistinctCameraModels()
        } catch {}
        await loadYears()
    }

    func loadYears() async {
        do {
            years = try db.fetchDistinctYears()
        } catch {
            // ignore
        }
    }

    func loadDuplicates() async {
        do {
            duplicateGroups = try db.fetchDuplicateGroupsWithPhotos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadOrganizeJobs() async {
        do {
            organizeJobs = try db.fetchAllOrganizeJobs()
            if let latestJobId = organizeJobs.first?.id {
                lastOrganizeResults = (try? db.fetchOrganizeResults(jobId: latestJobId)) ?? []
            } else {
                lastOrganizeResults = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Scanning

    func startScan(rootURL: URL) {
        guard !scanProgress.isScanning else { return }
        scanProgress = ScanProgress(isScanning: true)
        errorMessage = nil

        Task {
            let scanner = Scanner(db: db) { [weak self] progress in
                await MainActor.run { [weak self] in
                    self?.scanProgress = progress
                }
            }
            do {
                _ = try await scanner.scan(rootURL: rootURL)

                // Run duplicate detection after scan
                let detector = DuplicateDetector(db: db)
                let groups = try detector.detect()

                await loadInitialData()
                scanProgress.duplicatesFound = groups
            } catch {
                errorMessage = error.localizedDescription
                scanProgress.isScanning = false
                scanProgress.error = error.localizedDescription
            }
        }
    }

    // MARK: - Gallery

    func applyFilter(_ filter: PhotoFilter) {
        photoFilter = filter
        Task { await loadPhotos() }
    }

    // MARK: - Duplicates

    func setKeptPhoto(groupId: Int64, photoId: Int64) {
        do {
            try db.setKeptPhoto(groupId: groupId, photoId: photoId)
            Task { await loadDuplicates() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Vault

    func startVault(folderFormat: String, dryRun: Bool) {
        guard let vaultRootURL else {
            errorMessage = "Select a vault before organizing files."
            return
        }
        startOrganize(destination: vaultRootURL, folderFormat: folderFormat, dryRun: dryRun)
    }

    func startOrganize(destination: URL, folderFormat: String, dryRun: Bool) {
        guard !organizeProgress.isRunning else { return }
        organizeProgress = OrganizeProgress(isRunning: true)
        errorMessage = nil

        Task {
            let organizer = Organizer(db: db) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.organizeProgress = progress
                }
            }
            do {
                let job = try await organizer.organize(
                    destination: destination,
                    folderFormat: folderFormat,
                    dryRun: dryRun
                )
                if let jobId = job.id {
                    lastOrganizeResults = (try? db.fetchOrganizeResults(jobId: jobId)) ?? []
                }
                await loadOrganizeJobs()
                await loadPhotos()
            } catch {
                errorMessage = error.localizedDescription
                organizeProgress.isRunning = false
            }
        }
    }

    // MARK: - Backup

    func loadBackupJobs() async {
        do {
            backupJobs = try db.fetchAllBackupJobs()
            if let latestJobId = backupJobs.first?.id {
                lastBackupResults = (try? db.fetchBackupResults(jobId: latestJobId)) ?? []
            } else {
                lastBackupResults = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func countPhotosForBackup(filter: PhotoFilter) -> Int {
        (try? db.countPhotosForBackup(filter: filter)) ?? 0
    }

    func startBackup(folderFormat: String, filter: PhotoFilter, dryRun: Bool) {
        guard let vaultRootURL else {
            errorMessage = "Select a vault before backing up."
            return
        }
        guard !backupProgress.isRunning else { return }
        backupProgress = BackupProgress(isRunning: true)
        errorMessage = nil

        Task {
            let service = BackupService(db: db) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.backupProgress = progress
                }
            }
            do {
                let job = try await service.backup(
                    vaultRootURL: vaultRootURL,
                    folderFormat: folderFormat,
                    filter: filter,
                    dryRun: dryRun
                )
                if let jobId = job.id {
                    lastBackupResults = (try? db.fetchBackupResults(jobId: jobId)) ?? []
                }
                await loadBackupJobs()
            } catch {
                errorMessage = error.localizedDescription
                backupProgress.isRunning = false
            }
        }
    }

    // MARK: - Directory picker

    func pickDirectory() -> URL? {
        if let uiTestingURL = ProcessInfo.processInfo.environment["UI_TESTING_SOURCE_DIRECTORY_TO_PICK"], !uiTestingURL.isEmpty {
            return URL(fileURLWithPath: uiTestingURL)
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Choose a folder to scan"
        panel.prompt = "Select"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func defaultVaultRootURL() -> URL {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("Nostos", isDirectory: true)
    }

    func pickVaultDirectory() -> URL? {
        if let uiTestingURL = ProcessInfo.processInfo.environment["UI_TESTING_VAULT_DIRECTORY_TO_PICK"], !uiTestingURL.isEmpty {
            return URL(fileURLWithPath: uiTestingURL)
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose a vault folder"
        panel.prompt = "Select"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    func changeVaultRoot(to newVaultRootURL: URL) {
        guard newVaultRootURL != vaultRootURL else { return }

        do {
            db = try AppDatabase.makeShared(vaultRootURL: newVaultRootURL)
        } catch {
            errorMessage = "Failed to open vault at \(newVaultRootURL.path): \(error.localizedDescription)"
            return
        }

        vaultRootURL = newVaultRootURL
        UserDefaults.standard.set(newVaultRootURL.path, forKey: "vaultRootPath")
        ThumbnailService.configure(vaultRootURL: newVaultRootURL)
        seedUITestDataIfNeeded()

        scanRuns = []
        scanProgress = ScanProgress()
        photos = []
        photoFilter = PhotoFilter()
        if ProcessInfo.processInfo.environment["UI_TESTING_SEED_DATA"] == "1" {
            photoFilter.limit = 10
        }
        cameraModels = []
        years = []
        duplicateGroups = []
        organizeJobs = []
        organizeProgress = OrganizeProgress()
        lastOrganizeResults = []
        backupJobs = []
        backupProgress = BackupProgress()
        lastBackupResults = []
        errorMessage = nil

        Task {
            await loadInitialData()
        }
    }

    private func seedUITestDataIfNeeded() {
        guard ProcessInfo.processInfo.environment["UI_TESTING_SEED_DATA"] == "1" else { return }

        do {
            let now = Date()

            var scanRun = ScanRun(
                rootPath: "/tmp/ui-test-source",
                startedAt: now.addingTimeInterval(-3600),
                finishedAt: now.addingTimeInterval(-3500),
                photosFound: 26,
                duplicatesFound: 1,
                status: .completed
            )
            try db.insertScanRun(&scanRun)

            var duplicateGroup = DuplicateGroup(reason: .hashMatch, keptPhotoId: nil)
            try db.insertDuplicateGroup(&duplicateGroup)

            var seededPhotoIds: [Int64] = []

            for index in 1...26 {
                var photo = Photo(
                    id: nil,
                    path: "/tmp/ui-test-source/photo-\(index).jpg",
                    hash: index <= 2 ? "shared-hash" : "hash-\(index)",
                    fileSize: Int64(1_024 + index),
                    width: 160,
                    height: 160,
                    takenAt: Calendar.current.date(byAdding: .day, value: -index, to: now),
                    cameraMake: index.isMultiple(of: 2) ? "Canon" : "Nikon",
                    cameraModel: index.isMultiple(of: 2) ? "EOS" : "Z8",
                    gpsLat: nil,
                    gpsLon: nil,
                    thumbnailPath: nil,
                    duplicateGroupId: index <= 2 ? duplicateGroup.id : nil,
                    isKept: index == 1,
                    status: index.isMultiple(of: 3) ? .copied : .new,
                    scannedAt: now,
                    scanRunId: scanRun.id
                )
                try db.insertPhoto(&photo)
                if let photoId = photo.id {
                    seededPhotoIds.append(photoId)
                }
            }

            if let groupId = duplicateGroup.id, let firstPhotoId = seededPhotoIds.first {
                try db.setKeptPhoto(groupId: groupId, photoId: firstPhotoId)
            }

            var organizeJob = OrganizeJob(
                destinationRoot: "/tmp/ui-test-vault",
                folderFormat: "YYYY/MM/DD",
                dryRun: true,
                startedAt: now.addingTimeInterval(-1800),
                finishedAt: now.addingTimeInterval(-1700),
                status: .completed,
                totalFiles: 2,
                copiedFiles: 1,
                skippedFiles: 1
            )
            try db.insertOrganizeJob(&organizeJob)

            guard let jobId = organizeJob.id else { return }

            var result1 = OrganizeResult(
                id: nil,
                jobId: jobId,
                photoId: 1,
                source: "/tmp/ui-test-source/photo-1.jpg",
                destination: "/tmp/ui-test-vault/2026/04/01/photo-1.jpg",
                action: .copy,
                reason: nil
            )
            var result2 = OrganizeResult(
                id: nil,
                jobId: jobId,
                photoId: 2,
                source: "/tmp/ui-test-source/photo-2.jpg",
                destination: nil,
                action: .skipExists,
                reason: "Already exists"
            )
            try db.insertOrganizeResult(&result1)
            try db.insertOrganizeResult(&result2)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
