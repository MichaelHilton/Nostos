import Foundation
import AppKit

@MainActor
final class AppState: ObservableObject {
    let db: AppDatabase

    // MARK: - Scan state
    @Published var scanRuns: [ScanRun] = []
    @Published var scanProgress = ScanProgress()

    // MARK: - Gallery state
    @Published var photos: [Photo] = []
    @Published var photoFilter = PhotoFilter()
    @Published var cameraModels: [String] = []

    // MARK: - Duplicates state
    @Published var duplicateGroups: [DuplicateGroupWithPhotos] = []

    // MARK: - Organizer state
    @Published var organizeJobs: [OrganizeJob] = []
    @Published var organizeProgress = OrganizeProgress()
    @Published var lastOrganizeResults: [OrganizeResult] = []

    // MARK: - General error state
    @Published var errorMessage: String?

    init() {
        do {
            db = try AppDatabase.makeShared()
        } catch {
            fatalError("Failed to open database: \(error)")
        }
        Task { await loadInitialData() }
    }

    init(db: AppDatabase) {
        self.db = db
    }

    // MARK: - Data loading

    func loadInitialData() async {
        await loadScanRuns()
        await loadPhotos()
        await loadCameraModels()
        await loadDuplicates()
        await loadOrganizeJobs()
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

    func loadCameraModels() async {
        do {
            cameraModels = try db.fetchDistinctCameraModels()
        } catch {}
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
                Task { @MainActor [weak self] in
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

    // MARK: - Organizer

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

    // MARK: - Directory picker

    func pickDirectory() -> URL? {
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

    func pickDestinationDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose a destination folder"
        panel.prompt = "Select"
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
