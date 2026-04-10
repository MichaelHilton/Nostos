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
        // Fetch all photos that have a hash and are not yet grouped, in one query
        let photos = try db.dbWriter.read { db in
            try Photo.filter(
                Column("hash") != nil && Column("duplicate_group_id") == nil
            ).fetchAll(db)
        }

        // Group in memory by hash
        var byHash: [String: [Photo]] = [:]
        for photo in photos {
            guard let hash = photo.hash else { continue }
            byHash[hash, default: []].append(photo)
        }
        let duplicateGroups = byHash.values.filter { $0.count >= 2 }
        guard !duplicateGroups.isEmpty else { return 0 }

        // Insert all groups and update all photos in a single transaction
        var created = 0
        try db.dbWriter.write { db in
            for candidates in duplicateGroups {
                var group = DuplicateGroup(reason: .hashMatch, keptPhotoId: candidates.first?.id)
                try group.insert(db)

                var keptSet = false
                for var photo in candidates {
                    photo.duplicateGroupId = group.id
                    photo.isKept = !keptSet
                    keptSet = true
                    try photo.update(db)
                }
                // Update keptPhotoId after we have group.id set on the kept photo
                if let keptId = candidates.first?.id {
                    try db.execute(sql: "UPDATE duplicate_groups SET kept_photo_id = ? WHERE id = ?",
                                   arguments: [keptId, group.id])
                }
                created += 1
            }
        }
        return created
    }

    // MARK: - EXIF-based near-duplicate detection

    private func detectExifDuplicates() throws -> Int {
        // Fetch all ungrouped photos with both taken_at and camera_model, in one query
        let photos = try db.dbWriter.read { db in
            try Photo.filter(
                Column("taken_at") != nil
                    && Column("camera_model") != nil
                    && Column("duplicate_group_id") == nil
            ).fetchAll(db)
        }

        // Group in memory by (taken_at, camera_model)
        struct Key: Hashable { let takenAt: Date; let cameraModel: String }
        var byKey: [Key: [Photo]] = [:]
        for photo in photos {
            guard let t = photo.takenAt, let m = photo.cameraModel else { continue }
            byKey[Key(takenAt: t, cameraModel: m), default: []].append(photo)
        }
        let duplicateGroups = byKey.values.filter { $0.count >= 2 }
        guard !duplicateGroups.isEmpty else { return 0 }

        // Insert all groups and update all photos in a single transaction
        var created = 0
        try db.dbWriter.write { db in
            for candidates in duplicateGroups {
                var group = DuplicateGroup(reason: .exifMatch, keptPhotoId: candidates.first?.id)
                try group.insert(db)

                var keptSet = false
                for var photo in candidates {
                    photo.duplicateGroupId = group.id
                    photo.isKept = !keptSet
                    keptSet = true
                    try photo.update(db)
                }
                if let keptId = candidates.first?.id {
                    try db.execute(sql: "UPDATE duplicate_groups SET kept_photo_id = ? WHERE id = ?",
                                   arguments: [keptId, group.id])
                }
                created += 1
            }
        }
        return created
    }
}
