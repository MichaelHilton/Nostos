import XCTest
@testable import Nostos

final class PhotoModelTests: XCTestCase {

    func testPhotoEncodingDecodingPreservesFields() throws {
        let now = Date()
        let original = Photo(id: nil,
                             path: "/tmp/photo.jpg",
                             hash: "abc123",
                             fileSize: 12345,
                             width: 800,
                             height: 600,
                             takenAt: now,
                             cameraMake: "Canon",
                             cameraModel: "EOS",
                             gpsLat: 12.34,
                             gpsLon: 56.78,
                             thumbnailPath: "/tmp/thumb.jpg",
                             duplicateGroupId: nil,
                             isKept: true,
                             status: .copied,
                             scannedAt: now,
                             scanRunId: nil)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Photo.self, from: data)

        XCTAssertEqual(decoded.path, original.path)
        XCTAssertEqual(decoded.hash, original.hash)
        XCTAssertEqual(decoded.fileSize, original.fileSize)
        XCTAssertEqual(decoded.width, original.width)
        XCTAssertEqual(decoded.height, original.height)
        XCTAssertEqual(decoded.cameraMake, original.cameraMake)
        XCTAssertEqual(decoded.cameraModel, original.cameraModel)
        XCTAssertEqual(decoded.isKept, original.isKept)
        XCTAssertEqual(decoded.status, original.status)
    }

    func testCodingKeysUseSnakeCaseForDatabaseFields() throws {
        let photo = Photo(id: nil,
                          path: "/tmp/photo.jpg",
                          hash: nil,
                          fileSize: 1,
                          width: nil,
                          height: nil,
                          takenAt: nil,
                          cameraMake: nil,
                          cameraModel: nil,
                          gpsLat: nil,
                          gpsLon: nil,
                          thumbnailPath: nil,
                          duplicateGroupId: nil,
                          isKept: false,
                          status: .new,
                          scannedAt: Date(),
                          scanRunId: nil)

        let encoder = JSONEncoder()
        let data = try encoder.encode(photo)
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = obj as? [String: Any] else {
            XCTFail("Encoded JSON is not a dictionary")
            return
        }

        XCTAssertNotNil(dict["file_size"], "Expected 'file_size' key in encoded JSON")
        XCTAssertNotNil(dict["scanned_at"], "Expected 'scanned_at' key in encoded JSON")
    }
}
