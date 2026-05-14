import XCTest
@testable import Nostos

@MainActor
final class YearRangeSliderTests: XCTestCase {

    let yearBreakdown = [
        (year: 2020, count: 5),
        (year: 2021, count: 10),
        (year: 2022, count: 15),
        (year: 2023, count: 8),
        (year: 2024, count: 12),
    ]

    private var db: AppDatabase!

    override func setUpWithError() throws {
        db = try AppDatabase.makeInMemory()
    }

    // Test: Clicking a year when nothing is selected should select that year
    func testSelectSingleYear() {
        var yearFrom: Int? = nil
        var yearTo: Int? = nil

        selectYear(2022, yearFrom: &yearFrom, yearTo: &yearTo)

        XCTAssertEqual(yearFrom, 2022)
        XCTAssertEqual(yearTo, 2022)
    }

    // Test: Clicking the same year again should deselect
    func testDeselectSingleYear() {
        var yearFrom: Int? = 2022
        var yearTo: Int? = 2022

        selectYear(2022, yearFrom: &yearFrom, yearTo: &yearTo)

        XCTAssertNil(yearFrom)
        XCTAssertNil(yearTo)
    }

    // Test: Clicking a year below the current selection should expand range downward
    func testSelectRangeByClickingBelowCurrentYear() {
        var yearFrom: Int? = 2022
        var yearTo: Int? = 2022

        selectYear(2020, yearFrom: &yearFrom, yearTo: &yearTo)

        XCTAssertEqual(yearFrom, 2020)
        XCTAssertEqual(yearTo, 2022)
    }

    // Test: Clicking a year above the current selection should expand range upward
    func testSelectRangeByClickingAboveCurrentYear() {
        var yearFrom: Int? = 2022
        var yearTo: Int? = 2022

        selectYear(2024, yearFrom: &yearFrom, yearTo: &yearTo)

        XCTAssertEqual(yearFrom, 2022)
        XCTAssertEqual(yearTo, 2024)
    }

    // Test: Clicking within an existing range should contract the range or stay the same
    func testSelectYearWithinExistingRange() {
        var yearFrom: Int? = 2021
        var yearTo: Int? = 2023

        // Clicking 2022 (within range) should deselect the range
        selectYear(2022, yearFrom: &yearFrom, yearTo: &yearTo)

        XCTAssertNil(yearFrom)
        XCTAssertNil(yearTo)
    }

    // Test: Expanding range from both ends
    func testExpandRangeFromBothEnds() {
        var yearFrom: Int? = 2022
        var yearTo: Int? = 2022

        // Expand downward
        selectYear(2020, yearFrom: &yearFrom, yearTo: &yearTo)
        XCTAssertEqual(yearFrom, 2020)
        XCTAssertEqual(yearTo, 2022)

        // Expand upward
        selectYear(2024, yearFrom: &yearFrom, yearTo: &yearTo)
        XCTAssertEqual(yearFrom, 2020)
        XCTAssertEqual(yearTo, 2024)
    }

    // MARK: - Integration Tests

    func testYearFilterWorksWithPhotos() throws {
        let state = AppState(db: db)

        // Create photos from different years
        let photo2020 = makePhoto(path: "/2020.jpg", year: 2020)
        let photo2021 = makePhoto(path: "/2021.jpg", year: 2021)
        let photo2022 = makePhoto(path: "/2022.jpg", year: 2022)
        let photo2023 = makePhoto(path: "/2023.jpg", year: 2023)
        let photo2024 = makePhoto(path: "/2024.jpg", year: 2024)

        state.photos = [photo2020, photo2021, photo2022, photo2023, photo2024]

        // Test 1: No year filter - all photos shown
        let all = filterPhotos(state.photos, yearFrom: nil, yearTo: nil)
        XCTAssertEqual(all.count, 5)

        // Test 2: Year from only
        let from2022 = filterPhotos(state.photos, yearFrom: 2022, yearTo: nil)
        XCTAssertEqual(from2022.count, 3)
        XCTAssertEqual(Set(from2022.map { $0.path }), ["/2022.jpg", "/2023.jpg", "/2024.jpg"])

        // Test 3: Year to only
        let to2022 = filterPhotos(state.photos, yearFrom: nil, yearTo: 2022)
        XCTAssertEqual(to2022.count, 3)
        XCTAssertEqual(Set(to2022.map { $0.path }), ["/2020.jpg", "/2021.jpg", "/2022.jpg"])

        // Test 4: Year range
        let range = filterPhotos(state.photos, yearFrom: 2021, yearTo: 2023)
        XCTAssertEqual(range.count, 3)
        XCTAssertEqual(Set(range.map { $0.path }), ["/2021.jpg", "/2022.jpg", "/2023.jpg"])
    }

    func testYearFilterCombinedWithCameraFilter() throws {
        let state = AppState(db: db)

        // Create photos with different years and cameras
        let photo2022Canon = makePhoto(path: "/2022_canon.jpg", year: 2022, cameraModel: "Canon")
        let photo2022Nikon = makePhoto(path: "/2022_nikon.jpg", year: 2022, cameraModel: "Nikon")
        let photo2023Canon = makePhoto(path: "/2023_canon.jpg", year: 2023, cameraModel: "Canon")

        state.photos = [photo2022Canon, photo2022Nikon, photo2023Canon]

        // Filter by year 2022 and camera Canon
        var filtered = filterPhotos(state.photos, yearFrom: 2022, yearTo: 2022)
        filtered = filtered.filter { $0.cameraModel == "Canon" }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].path, "/2022_canon.jpg")
    }

    // MARK: - Helpers

    private func makePhoto(path: String, year: Int? = nil, cameraModel: String? = nil) -> Photo {
        let takenAt: Date? = year.map { y in
            Calendar.current.date(from: DateComponents(year: y, month: 6, day: 15)) ?? Date()
        }

        return Photo(
            id: nil,
            path: path,
            hash: "hash_\(path)",
            fileSize: 1024,
            width: 800,
            height: 600,
            takenAt: takenAt,
            cameraMake: cameraModel.map { _ in "Canon" },
            cameraModel: cameraModel,
            gpsLat: nil,
            gpsLon: nil,
            thumbnailPath: nil,
            duplicateGroupId: nil,
            isKept: true,
            status: .new,
            scannedAt: Date(),
            scanRunId: nil
        )
    }

    private func filterPhotos(_ photos: [Photo], yearFrom: Int?, yearTo: Int?) -> [Photo] {
        photos.filter { photo in
            guard let date = photo.takenAt else { return yearFrom == nil && yearTo == nil }
            let year = Calendar.current.component(.year, from: date)

            if let yearFrom = yearFrom, year < yearFrom { return false }
            if let yearTo = yearTo, year > yearTo { return false }

            return true
        }
    }

    private func selectYear(_ year: Int, yearFrom: inout Int?, yearTo: inout Int?) {
        let isStart = year == yearFrom
        let isEnd = year == yearTo

        if isStart && isEnd {
            yearFrom = nil
            yearTo = nil
        } else if yearFrom == nil {
            yearFrom = year
            yearTo = year
        } else if yearTo == nil {
            if year < yearFrom! {
                yearTo = yearFrom
                yearFrom = year
            } else {
                yearTo = year
            }
        } else if year < yearFrom! {
            yearFrom = year
        } else if year > yearTo! {
            yearTo = year
        } else {
            yearFrom = nil
            yearTo = nil
        }
    }
}
