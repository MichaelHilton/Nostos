import XCTest
@testable import Nostos

final class AppDatabaseFilterTests: XCTestCase {
    var db: AppDatabase!

    override func setUpWithError() throws {
        db = try AppDatabase.makeInMemory()
    }

    private func makePhoto(
        path: String,
        cameraModel: String? = nil,
        takenAt: Date? = nil,
        duplicateGroupId: Int64? = nil,
        isKept: Bool = true
    ) -> Photo {
        Photo(
            id: nil,
            path: path,
            hash: "hash_\(path)",
            fileSize: 1024,
            width: 800,
            height: 600,
            takenAt: takenAt,
            cameraMake: cameraModel != nil ? "Canon" : nil,
            cameraModel: cameraModel,
            gpsLat: nil,
            gpsLon: nil,
            thumbnailPath: nil,
            duplicateGroupId: duplicateGroupId,
            isKept: isKept,
            status: .new,
            scannedAt: Date(),
            scanRunId: nil
        )
    }

    // MARK: - fetchPhotos tests

    func testFetchPhotos_includeNoCamera_onlyNullCamera() throws {
        var noCamera = makePhoto(path: "/no_camera.jpg", cameraModel: nil)
        var withCamera = makePhoto(path: "/with_camera.jpg", cameraModel: "Canon")

        try db.insertPhoto(&noCamera)
        try db.insertPhoto(&withCamera)

        let filter = PhotoFilter(includeNoCamera: true)
        let results = try db.fetchPhotos(filter: filter)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, "/no_camera.jpg")
    }

    func testFetchPhotos_cameraModelsAndIncludeNoCamera() throws {
        var nikon = makePhoto(path: "/nikon.jpg", cameraModel: "Nikon")
        var noCamera = makePhoto(path: "/no_camera.jpg", cameraModel: nil)
        var sony = makePhoto(path: "/sony.jpg", cameraModel: "Sony")

        try db.insertPhoto(&nikon)
        try db.insertPhoto(&noCamera)
        try db.insertPhoto(&sony)

        var filter = PhotoFilter()
        filter.cameraModels = ["Nikon"]
        filter.includeNoCamera = true

        let results = try db.fetchPhotos(filter: filter)

        XCTAssertEqual(results.count, 2)
        let paths = Set(results.map { $0.path })
        XCTAssertEqual(paths, ["/nikon.jpg", "/no_camera.jpg"])
    }

    func testFetchPhotos_yearFromOnly() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components2022 = DateComponents()
        components2022.year = 2022
        components2022.month = 1
        components2022.day = 1
        components2022.timeZone = TimeZone(abbreviation: "UTC")
        let date2022 = calendar.date(from: components2022)!

        var components2024 = DateComponents()
        components2024.year = 2024
        components2024.month = 1
        components2024.day = 1
        components2024.timeZone = TimeZone(abbreviation: "UTC")
        let date2024 = calendar.date(from: components2024)!

        var photo2022 = makePhoto(path: "/2022.jpg", takenAt: date2022)
        var photo2024 = makePhoto(path: "/2024.jpg", takenAt: date2024)

        try db.insertPhoto(&photo2022)
        try db.insertPhoto(&photo2024)

        var filter = PhotoFilter()
        filter.yearFrom = 2023

        let results = try db.fetchPhotos(filter: filter)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, "/2024.jpg")
    }

    func testFetchPhotos_yearToOnly() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components2022 = DateComponents()
        components2022.year = 2022
        components2022.month = 1
        components2022.day = 1
        components2022.timeZone = TimeZone(abbreviation: "UTC")
        let date2022 = calendar.date(from: components2022)!

        var components2024 = DateComponents()
        components2024.year = 2024
        components2024.month = 1
        components2024.day = 1
        components2024.timeZone = TimeZone(abbreviation: "UTC")
        let date2024 = calendar.date(from: components2024)!

        var photo2022 = makePhoto(path: "/2022.jpg", takenAt: date2022)
        var photo2024 = makePhoto(path: "/2024.jpg", takenAt: date2024)

        try db.insertPhoto(&photo2022)
        try db.insertPhoto(&photo2024)

        var filter = PhotoFilter()
        filter.yearTo = 2023

        let results = try db.fetchPhotos(filter: filter)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, "/2022.jpg")
    }

    // MARK: - fetchDistinctYears test

    func testFetchDistinctYears() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components2022 = DateComponents()
        components2022.year = 2022
        components2022.month = 1
        components2022.day = 1
        components2022.timeZone = TimeZone(abbreviation: "UTC")
        let date2022 = calendar.date(from: components2022)!

        var components2024 = DateComponents()
        components2024.year = 2024
        components2024.month = 6
        components2024.day = 15
        components2024.timeZone = TimeZone(abbreviation: "UTC")
        let date2024 = calendar.date(from: components2024)!

        var photo2022 = makePhoto(path: "/2022.jpg", takenAt: date2022)
        var photo2024 = makePhoto(path: "/2024.jpg", takenAt: date2024)

        try db.insertPhoto(&photo2022)
        try db.insertPhoto(&photo2024)

        let years = try db.fetchDistinctYears()

        XCTAssertEqual(Set(years), [2022, 2024])
    }

    // MARK: - enumerateAllPhotos test

    func testEnumerateAllPhotos() throws {
        var photo1 = makePhoto(path: "/photo1.jpg")
        var photo2 = makePhoto(path: "/photo2.jpg")
        var photo3 = makePhoto(path: "/photo3.jpg")

        try db.insertPhoto(&photo1)
        try db.insertPhoto(&photo2)
        try db.insertPhoto(&photo3)

        var collected: [Photo] = []
        try db.enumerateAllPhotos { photo in
            collected.append(photo)
        }

        XCTAssertEqual(collected.count, 3)
        let paths = Set(collected.map { $0.path })
        XCTAssertEqual(paths, ["/photo1.jpg", "/photo2.jpg", "/photo3.jpg"])
    }

    // MARK: - updateDuplicateGroup test

    func testUpdateDuplicateGroup() throws {
        var group = DuplicateGroup(id: nil, reason: .hashMatch, keptPhotoId: nil)
        try db.insertDuplicateGroup(&group)
        let groupId = group.id!

        var photo1 = makePhoto(path: "/photo1.jpg", duplicateGroupId: groupId)
        var photo2 = makePhoto(path: "/photo2.jpg", duplicateGroupId: groupId)

        try db.insertPhoto(&photo1)
        try db.insertPhoto(&photo2)

        let photoId = photo2.id!

        var updatedGroup = group
        updatedGroup.keptPhotoId = photoId

        try db.updateDuplicateGroup(updatedGroup)

        let fetchedGroups = try db.fetchDuplicateGroupsWithPhotos()
        let fetchedGroup = fetchedGroups.first { $0.group.id == groupId }

        XCTAssertNotNil(fetchedGroup)
        XCTAssertEqual(fetchedGroup?.group.keptPhotoId, photoId)
    }

    // MARK: - fetchPhotosForBackup tests

    func testFetchPhotosForBackup_includeNoCamera_onlyNull() throws {
        var noCamera = makePhoto(path: "/no_camera.jpg", cameraModel: nil)
        var withCamera = makePhoto(path: "/with_camera.jpg", cameraModel: "Canon")

        try db.insertPhoto(&noCamera)
        try db.insertPhoto(&withCamera)

        let filter = PhotoFilter(includeNoCamera: true)
        let results = try db.fetchPhotosForBackup(filter: filter)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, "/no_camera.jpg")
    }

    func testFetchPhotosForBackup_cameraModelsAndIncludeNoCamera() throws {
        var nikon = makePhoto(path: "/nikon.jpg", cameraModel: "Nikon")
        var noCamera = makePhoto(path: "/no_camera.jpg", cameraModel: nil)
        var sony = makePhoto(path: "/sony.jpg", cameraModel: "Sony")

        try db.insertPhoto(&nikon)
        try db.insertPhoto(&noCamera)
        try db.insertPhoto(&sony)

        var filter = PhotoFilter()
        filter.cameraModels = ["Nikon"]
        filter.includeNoCamera = true

        let results = try db.fetchPhotosForBackup(filter: filter)

        XCTAssertEqual(results.count, 2)
        let paths = Set(results.map { $0.path })
        XCTAssertEqual(paths, ["/nikon.jpg", "/no_camera.jpg"])
    }

    func testFetchPhotosForBackup_yearFromOnly() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components2022 = DateComponents()
        components2022.year = 2022
        components2022.month = 1
        components2022.day = 1
        components2022.timeZone = TimeZone(abbreviation: "UTC")
        let date2022 = calendar.date(from: components2022)!

        var components2024 = DateComponents()
        components2024.year = 2024
        components2024.month = 1
        components2024.day = 1
        components2024.timeZone = TimeZone(abbreviation: "UTC")
        let date2024 = calendar.date(from: components2024)!

        var photo2022 = makePhoto(path: "/2022.jpg", takenAt: date2022)
        var photo2024 = makePhoto(path: "/2024.jpg", takenAt: date2024)

        try db.insertPhoto(&photo2022)
        try db.insertPhoto(&photo2024)

        var filter = PhotoFilter()
        filter.yearFrom = 2023

        let results = try db.fetchPhotosForBackup(filter: filter)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, "/2024.jpg")
    }

    func testFetchPhotosForBackup_yearToOnly() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components2022 = DateComponents()
        components2022.year = 2022
        components2022.month = 1
        components2022.day = 1
        components2022.timeZone = TimeZone(abbreviation: "UTC")
        let date2022 = calendar.date(from: components2022)!

        var components2024 = DateComponents()
        components2024.year = 2024
        components2024.month = 1
        components2024.day = 1
        components2024.timeZone = TimeZone(abbreviation: "UTC")
        let date2024 = calendar.date(from: components2024)!

        var photo2022 = makePhoto(path: "/2022.jpg", takenAt: date2022)
        var photo2024 = makePhoto(path: "/2024.jpg", takenAt: date2024)

        try db.insertPhoto(&photo2022)
        try db.insertPhoto(&photo2024)

        var filter = PhotoFilter()
        filter.yearTo = 2023

        let results = try db.fetchPhotosForBackup(filter: filter)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, "/2022.jpg")
    }

    func testFetchPhotosForBackup_dateRange() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components2022 = DateComponents()
        components2022.year = 2022
        components2022.month = 1
        components2022.day = 1
        components2022.timeZone = TimeZone(abbreviation: "UTC")
        let date2022 = calendar.date(from: components2022)!

        var components2025 = DateComponents()
        components2025.year = 2025
        components2025.month = 1
        components2025.day = 1
        components2025.timeZone = TimeZone(abbreviation: "UTC")
        let date2025 = calendar.date(from: components2025)!

        var photo2022 = makePhoto(path: "/2022.jpg", takenAt: date2022)
        var photo2025 = makePhoto(path: "/2025.jpg", takenAt: date2025)

        try db.insertPhoto(&photo2022)
        try db.insertPhoto(&photo2025)

        var components2023 = DateComponents()
        components2023.year = 2023
        components2023.month = 1
        components2023.day = 1
        components2023.timeZone = TimeZone(abbreviation: "UTC")
        let dateFrom = calendar.date(from: components2023)!

        var filter = PhotoFilter()
        filter.dateFrom = dateFrom

        let results = try db.fetchPhotosForBackup(filter: filter)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, "/2025.jpg")
    }

    func testFetchPhotosForBackup_dateTo() throws {
        let calendar = Calendar(identifier: .gregorian)
        var components2022 = DateComponents()
        components2022.year = 2022
        components2022.month = 1
        components2022.day = 1
        components2022.timeZone = TimeZone(abbreviation: "UTC")
        let date2022 = calendar.date(from: components2022)!

        var components2025 = DateComponents()
        components2025.year = 2025
        components2025.month = 1
        components2025.day = 1
        components2025.timeZone = TimeZone(abbreviation: "UTC")
        let date2025 = calendar.date(from: components2025)!

        var photo2022 = makePhoto(path: "/2022.jpg", takenAt: date2022)
        var photo2025 = makePhoto(path: "/2025.jpg", takenAt: date2025)

        try db.insertPhoto(&photo2022)
        try db.insertPhoto(&photo2025)

        var components2023 = DateComponents()
        components2023.year = 2023
        components2023.month = 1
        components2023.day = 1
        components2023.timeZone = TimeZone(abbreviation: "UTC")
        let dateTo = calendar.date(from: components2023)!

        var filter = PhotoFilter()
        filter.dateTo = dateTo

        let results = try db.fetchPhotosForBackup(filter: filter)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].path, "/2022.jpg")
    }
}
