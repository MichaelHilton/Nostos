import Foundation
import AppKit

@MainActor
final class AppState: ObservableObject {
    private(set) var db: AppDatabase
    @Published private(set) var vaultRootURL: URL?

    var directoryPicker: DirectoryPickerProtocol
    var container: ServiceContainer

    // MARK: - Scan state
    @Published var scanRuns: [ScanRun] = []
    @Published var scanOperation: ScanOperation?

    // MARK: - Gallery state
    @Published var photos: [Photo] = []
    @Published var totalPhotoCount: Int = 0
    @Published var photoFilter = PhotoFilter()
    @Published var isLoadingMorePhotos: Bool = false
    @Published var cameraModels: [String] = []
    @Published var years: [Int] = []

    // MARK: - Duplicates state
    @Published var duplicateGroups: [DuplicateGroupWithPhotos] = []
    @Published var duplicateDetectOperation: DuplicateDetectOperation?

    // MARK: - Vault state
    @Published var organizeJobs: [OrganizeJob] = []
    @Published var organizeOperation: OrganizeOperation?
    @Published var lastOrganizeResults: [OrganizeResult] = []

    // MARK: - Backup state
    @Published var backupJobs: [BackupJob] = []
    @Published var backupOperation: BackupOperation?
    @Published var lastBackupResults: [BackupResult] = []

    // MARK: - Vault breakdown state
    @Published var totalPhotoSize: Int64 = 0
    @Published var formatBreakdown: [(ext: String, count: Int, bytes: Int64)] = []
    @Published var yearBreakdown: [(year: Int, count: Int)] = []
    @Published var cameraBreakdown: [(model: String, count: Int)] = []

    // MARK: - General error state
    @Published var errorMessage: String?
    @Published private(set) var isInitialDataLoaded: Bool = false

    init() {
        let defaultVaultRoot = AppState.defaultVaultRootURL()
        self.vaultRootURL = defaultVaultRoot
        self.directoryPicker = DefaultDirectoryPicker()
        do {
            db = try AppDatabase.makeShared(vaultRootURL: defaultVaultRoot)
        } catch {
            fatalError("Failed to open database: \(error)")
        }
        self.container = ServiceContainer(db: db)
        ThumbnailService.configure(vaultRootURL: defaultVaultRoot)
        // Start with a reasonable page size for the gallery to avoid loading
        // thousands of photos into memory at once. Use `0` for no limit.
        photoFilter.limit = 200
        Task { await loadInitialData() }
    }

    init(vaultRootURL: URL) {
        self.vaultRootURL = vaultRootURL
        self.directoryPicker = DefaultDirectoryPicker()
        do {
            db = try AppDatabase.makeShared(vaultRootURL: vaultRootURL)
        } catch {
            fatalError("Failed to open database: \(error)")
        }
        self.container = ServiceContainer(db: db)
        ThumbnailService.configure(vaultRootURL: vaultRootURL)
        // Start with a reasonable page size for the gallery to avoid loading
        // thousands of photos into memory at once. Use `0` for no limit.
        photoFilter.limit = 200
        seedUITestDataIfNeeded()
        if ProcessInfo.processInfo.environment["UI_TESTING_SEED_DATA"] == "1" {
            photoFilter.limit = 10
        }
        Task { await loadInitialData() }
    }

    init(db: AppDatabase, directoryPicker: DirectoryPickerProtocol = DefaultDirectoryPicker()) {
        self.db = db
        self.vaultRootURL = nil
        self.directoryPicker = directoryPicker
        self.container = ServiceContainer(db: db)
    }

    // MARK: - Data loading

    func loadInitialData() async {
        // Start all independent reads as concurrent child tasks
        async let a: () = loadScanRuns()
        async let b: () = loadPhotos()
        async let c: () = loadTotalPhotoCount()
        async let d: () = loadCameraModels()
        async let e: () = loadYears()
        async let f: () = loadDuplicates()
        async let g: () = loadOrganizeJobs()
        async let h: () = loadBackupJobs()
        async let i: () = loadVaultBreakdowns()
        await a; await b; await c; await d; await e; await f; await g; await h; await i
        isInitialDataLoaded = true
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
        guard scanOperation?.isLoading != true else { return }

        let operation = ScanOperation(container: container, rootURL: rootURL)
        scanOperation = operation
        errorMessage = nil

        operation.execute()

        Task {
            while operation.isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            await loadInitialData()
        }
    }


    func applyFilter(_ filter: PhotoFilter) {
        photoFilter = filter
        Task { await loadPhotos() }
    }

    func loadMorePhotos() {
        guard !isLoadingMorePhotos else { return }
        guard photoFilter.limit != 0 else { return } // already unlimited

        isLoadingMorePhotos = true
        let pageSize = max(photoFilter.limit, 200)
        let (newLimit, overflow) = photoFilter.limit.addingReportingOverflow(pageSize)
        photoFilter.limit = overflow ? Int.max : newLimit
        Task {
            await loadPhotos()
            isLoadingMorePhotos = false
        }
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
        guard organizeOperation?.isLoading != true else { return }

        let operation = OrganizeOperation(
            container: container,
            destination: destination,
            folderFormat: folderFormat,
            dryRun: dryRun
        )
        organizeOperation = operation
        errorMessage = nil

        operation.execute()

        Task {
            while operation.isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            if let jobId = operation.result?.id {
                lastOrganizeResults = (try? db.fetchOrganizeResults(jobId: jobId)) ?? []
            }
            await loadOrganizeJobs()
            await loadPhotos()
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

    func loadVaultBreakdowns() async {
        do {
            totalPhotoSize = try db.totalPhotoSizeBytes()
            formatBreakdown = try db.fetchFormatBreakdown()
            yearBreakdown = try db.fetchYearBreakdown()
            cameraBreakdown = try db.fetchCameraBreakdown()
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
        guard backupOperation?.isLoading != true else { return }

        let operation = BackupOperation(
            container: container,
            vaultRootURL: vaultRootURL,
            folderFormat: folderFormat,
            filter: filter,
            dryRun: dryRun
        )
        backupOperation = operation
        errorMessage = nil

        operation.execute()

        Task {
            while operation.isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            if let jobId = operation.result?.id {
                lastBackupResults = (try? db.fetchBackupResults(jobId: jobId)) ?? []
            }
            await loadBackupJobs()
        }
    }
    // MARK: - Directory picker

    func pickDirectory() -> URL? {
        directoryPicker.pickSourceDirectory()
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
        directoryPicker.pickVaultDirectory()
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
        container = ServiceContainer(db: db)
        UserDefaults.standard.set(newVaultRootURL.path, forKey: "vaultRootPath")
        ThumbnailService.configure(vaultRootURL: newVaultRootURL)
        seedUITestDataIfNeeded()

        scanRuns = []
        scanOperation = nil
        photos = []
        photoFilter = PhotoFilter()
        if ProcessInfo.processInfo.environment["UI_TESTING_SEED_DATA"] == "1" {
            photoFilter.limit = 10
        }
        cameraModels = []
        years = []
        duplicateGroups = []
        duplicateDetectOperation = nil
        organizeJobs = []
        organizeOperation = nil
        lastOrganizeResults = []
        backupJobs = []
        backupOperation = nil
        lastBackupResults = []
        errorMessage = nil

        Task {
            await loadInitialData()
        }
    }

    private func seedUITestDataIfNeeded() {
        guard ProcessInfo.processInfo.environment["UI_TESTING_SEED_DATA"] == "1" else { return }

        // Avoid seeding twice into the same vault (tests may launch multiple app instances
        // pointing at the same `vaultRootPath`). If the `photos` table already has rows,
        // assume the seed has already run.
        if ((try? db.photoCount()) ?? 0) > 0 { return }

        do {
            let now = Date()

            var scanRun = ScanRun(
                rootPath: "/tmp/ui-test-source",
                startedAt: now.addingTimeInterval(-3600),
                finishedAt: now.addingTimeInterval(-3500),
                photosFound: 36,
                duplicatesFound: 1,
                status: .completed
            )
            try db.insertScanRun(&scanRun)

            var duplicateGroup = DuplicateGroup(reason: .hashMatch, keptPhotoId: nil)
            try db.insertDuplicateGroup(&duplicateGroup)

            var seededPhotoIds: [Int64] = []

            let cameraModels = ["Canon EOS R5", "Sony A7 IV", "Nikon Z6 II", "iPhone 15 Pro", "Fujifilm X-T5"]
            let years = [2021, 2022, 2023, 2024]
            let photosPerYear = 9

            var photoIndex = 1
            for year in years {
                for photoInYear in 1...photosPerYear {
                    let dateComponents = DateComponents(year: year, month: 6, day: photoInYear)
                    guard let takenAt = Calendar.current.date(from: dateComponents) else { continue }

                    let cameraModel = cameraModels[(photoIndex - 1) % cameraModels.count]

                    var photo = Photo(
                        id: nil,
                        path: "/tmp/ui-test-source/photo-\(photoIndex).jpg",
                        hash: photoIndex <= 2 ? "shared-hash" : "hash-\(photoIndex)",
                        fileSize: Int64(1_024 + photoIndex),
                        width: 160,
                        height: 160,
                        takenAt: takenAt,
                        cameraMake: nil,
                        cameraModel: cameraModel,
                        gpsLat: nil,
                        gpsLon: nil,
                        thumbnailPath: nil,
                        duplicateGroupId: photoIndex <= 2 ? duplicateGroup.id : nil,
                        isKept: photoIndex == 1,
                        status: photoIndex.isMultiple(of: 3) ? .copied : .new,
                        scannedAt: now,
                        scanRunId: scanRun.id
                    )
                    try db.insertPhoto(&photo)
                    if let photoId = photo.id {
                        seededPhotoIds.append(photoId)
                    }
                    photoIndex += 1
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

