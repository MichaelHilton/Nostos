import Foundation
import GRDB

final class DuplicateDetector {
    private let db: AppDatabase

    init(db: AppDatabase) {
        self.db = db
    }

    /// Runs both hash-based and EXIF-based duplicate detection across all photos.
    func detect() throws -> Int {
        var groupsCreated = 0
        groupsCreated += try detectHashDuplicates()
        groupsCreated += try detectExifDuplicates()
        return groupsCreated
    }

    // MARK: - Hash-based detection

    private func detectHashDuplicates() throws -> Int {
        // Group photos by hash, find groups with 2+ photos
        let rows = try db.dbWriter.read { db in
            try Row.fetchAll(db, sql: """
                SELECT hash, COUNT(*) as cnt
                FROM photos
                WHERE hash IS NOT NULL AND duplicate_group_id IS NULL
                GROUP BY hash
                HAVING cnt >= 2
            """)
        }

        var created = 0
        for row in rows {
            guard let hash: String = row["hash"] else { continue }

            let photos = try db.dbWriter.read { db in
                try Photo.filter(Column("hash") == hash && Column("duplicate_group_id") == nil).fetchAll(db)
            }
            guard photos.count >= 2 else { continue }

            var group = DuplicateGroup(reason: .hashMatch, keptPhotoId: photos.first?.id)
            try db.insertDuplicateGroup(&group)

            // Mark the oldest (or first by id) as kept
            var keptSet = false
            try db.dbWriter.write { db in
                for var photo in photos {
                    photo.duplicateGroupId = group.id
                    photo.isKept = !keptSet
                    keptSet = true
                    try photo.update(db)
                }
            }
            if let keptPhoto = photos.first {
                group.keptPhotoId = keptPhoto.id
                try db.updateDuplicateGroup(group)
            }
            created += 1
        }
        return created
    }

    // MARK: - EXIF-based near-duplicate detection

    private func detectExifDuplicates() throws -> Int {
        // Group photos not yet in a duplicate group by (taken_at, camera_model)
        let rows = try db.dbWriter.read { db in
            try Row.fetchAll(db, sql: """
                SELECT taken_at, camera_model, COUNT(*) as cnt
                FROM photos
                WHERE taken_at IS NOT NULL
                  AND camera_model IS NOT NULL
                  AND duplicate_group_id IS NULL
                GROUP BY taken_at, camera_model
                HAVING cnt >= 2
            """)
        }

        var created = 0
        for row in rows {
            guard let takenAt: Date = row["taken_at"],
                  let cameraModel: String = row["camera_model"] else { continue }

            let photos = try db.dbWriter.read { db in
                try Photo
                    .filter(Column("taken_at") == takenAt
                        && Column("camera_model") == cameraModel
                        && Column("duplicate_group_id") == nil)
                    .fetchAll(db)
            }
            guard photos.count >= 2 else { continue }

            var group = DuplicateGroup(reason: .exifMatch, keptPhotoId: photos.first?.id)
            try db.insertDuplicateGroup(&group)

            var keptSet = false
            try db.dbWriter.write { db in
                for var photo in photos {
                    photo.duplicateGroupId = group.id
                    photo.isKept = !keptSet
                    keptSet = true
                    try photo.update(db)
                }
            }
            if let keptPhoto = photos.first {
                group.keptPhotoId = keptPhoto.id
                try db.updateDuplicateGroup(group)
            }
            created += 1
        }
        return created
    }
}
