package db

import (
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"time"
)

// UpsertPhoto inserts a photo or updates it if the path already exists.
// Returns the photo's ID.
func (db *DB) UpsertPhoto(p *Photo) (int64, error) {
	const q = `
	INSERT INTO photos
		(path, hash, file_size, width, height, taken_at, camera_make, camera_model,
		 gps_lat, gps_lon, thumbnail_path, is_kept, status, scanned_at, scan_run_id)
	VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
	ON CONFLICT(path) DO UPDATE SET
		hash           = excluded.hash,
		file_size      = excluded.file_size,
		width          = excluded.width,
		height         = excluded.height,
		taken_at       = excluded.taken_at,
		camera_make    = excluded.camera_make,
		camera_model   = excluded.camera_model,
		gps_lat        = excluded.gps_lat,
		gps_lon        = excluded.gps_lon,
		thumbnail_path = excluded.thumbnail_path,
		scanned_at     = excluded.scanned_at,
		scan_run_id    = excluded.scan_run_id
	RETURNING id`

	var id int64
	err := db.QueryRow(q,
		p.Path, p.Hash, p.FileSize, p.Width, p.Height,
		nullTime(p.TakenAt), p.CameraMake, p.CameraModel,
		nullFloat64(p.GPSLat), nullFloat64(p.GPSLon),
		p.ThumbnailPath, boolToInt(p.IsKept), p.Status,
		p.ScannedAt.UTC().Format(time.RFC3339), nullInt64(p.ScanRunID),
	).Scan(&id)
	return id, err
}

// GetPhoto retrieves a single photo by ID.
func (db *DB) GetPhoto(id int64) (*Photo, error) {
	const q = `SELECT ` + photoColumns + ` FROM photos WHERE id = ?`
	row := db.QueryRow(q, id)
	return scanPhoto(row)
}

// GetPhotoByPath retrieves a photo by its filesystem path.
func (db *DB) GetPhotoByPath(path string) (*Photo, error) {
	const q = `SELECT ` + photoColumns + ` FROM photos WHERE path = ?`
	row := db.QueryRow(q, path)
	p, err := scanPhoto(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return p, err
}

// GetPhotoByHash returns the first photo matching a given hash (or nil).
func (db *DB) GetPhotoByHash(hash string) (*Photo, error) {
	const q = `SELECT ` + photoColumns + ` FROM photos WHERE hash = ? LIMIT 1`
	row := db.QueryRow(q, hash)
	p, err := scanPhoto(row)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return p, err
}

// GetPhotosByHash returns all photos with a given hash.
func (db *DB) GetPhotosByHash(hash string) ([]Photo, error) {
	const q = `SELECT ` + photoColumns + ` FROM photos WHERE hash = ?`
	return db.queryPhotos(q, hash)
}

// ListPhotos returns photos matching optional filters.
func (db *DB) ListPhotos(f PhotoFilter) ([]Photo, int, error) {
	where, args := buildPhotoWhere(f)

	countQ := `SELECT COUNT(*) FROM photos` + where
	var total int
	if err := db.QueryRow(countQ, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count photos: %w", err)
	}

	limit := f.Limit
	if limit <= 0 {
		limit = 50
	}
	listQ := `SELECT ` + photoColumns + ` FROM photos` + where +
		` ORDER BY COALESCE(taken_at, scanned_at) DESC` +
		fmt.Sprintf(` LIMIT %d OFFSET %d`, limit, f.Offset)

	photos, err := db.queryPhotos(listQ, args...)
	return photos, total, err
}

// UpdatePhotoStatus sets the status field for a photo.
func (db *DB) UpdatePhotoStatus(id int64, status string) error {
	_, err := db.Exec(`UPDATE photos SET status = ? WHERE id = ?`, status, id)
	return err
}

// UpdatePhotoThumbnail sets the thumbnail_path for a photo.
func (db *DB) UpdatePhotoThumbnail(id int64, thumbPath string) error {
	_, err := db.Exec(`UPDATE photos SET thumbnail_path = ? WHERE id = ?`, thumbPath, id)
	return err
}

// SetPhotoKept marks a photo as the kept copy within its duplicate group.
func (db *DB) SetPhotoKept(photoID int64) error {
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	// Get the group
	var groupID sql.NullInt64
	if err := tx.QueryRow(`SELECT duplicate_group_id FROM photos WHERE id = ?`, photoID).Scan(&groupID); err != nil {
		return err
	}
	if !groupID.Valid {
		return fmt.Errorf("photo %d is not in a duplicate group", photoID)
	}

	// Clear kept on all group members
	if _, err := tx.Exec(`UPDATE photos SET is_kept = 0 WHERE duplicate_group_id = ?`, groupID.Int64); err != nil {
		return err
	}
	// Mark the chosen one
	if _, err := tx.Exec(`UPDATE photos SET is_kept = 1 WHERE id = ?`, photoID); err != nil {
		return err
	}
	// Update group record
	if _, err := tx.Exec(`UPDATE duplicate_groups SET kept_photo_id = ? WHERE id = ?`, photoID, groupID.Int64); err != nil {
		return err
	}
	return tx.Commit()
}

// CreateDuplicateGroup inserts a new duplicate group and returns its ID.
func (db *DB) CreateDuplicateGroup(reason string) (int64, error) {
	res, err := db.Exec(`INSERT INTO duplicate_groups (reason) VALUES (?)`, reason)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// AssignDuplicateGroup assigns a photo to a duplicate group.
func (db *DB) AssignDuplicateGroup(photoID, groupID int64, isKept bool) error {
	_, err := db.Exec(
		`UPDATE photos SET duplicate_group_id = ?, is_kept = ? WHERE id = ?`,
		groupID, boolToInt(isKept), photoID,
	)
	return err
}

// ListDuplicateGroups returns all duplicate groups with their photos.
func (db *DB) ListDuplicateGroups() ([]DuplicateGroup, error) {
	rows, err := db.Query(`SELECT id, reason, kept_photo_id FROM duplicate_groups ORDER BY id`)
	if err != nil {
		return nil, err
	}

	// Collect groups first, then close the cursor before issuing sub-queries.
	// This avoids a deadlock with MaxOpenConns(1).
	type rawGroup struct {
		id     int64
		reason string
		kept   sql.NullInt64
	}
	var rawGroups []rawGroup
	for rows.Next() {
		var g rawGroup
		if err := rows.Scan(&g.id, &g.reason, &g.kept); err != nil {
			rows.Close()
			return nil, err
		}
		rawGroups = append(rawGroups, g)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}

	var groups []DuplicateGroup
	for _, rg := range rawGroups {
		g := DuplicateGroup{
			ID:     rg.id,
			Reason: rg.reason,
		}
		if rg.kept.Valid {
			g.KeptPhotoID = &rg.kept.Int64
		}
		photos, err := db.queryPhotos(
			`SELECT `+photoColumns+` FROM photos WHERE duplicate_group_id = ? ORDER BY file_size DESC`,
			g.ID,
		)
		if err != nil {
			return nil, err
		}
		g.Photos = photos
		groups = append(groups, g)
	}
	return groups, nil
}

// ---- helpers ----------------------------------------------------------------

const photoColumns = `id, path, hash, file_size, width, height,
	taken_at, camera_make, camera_model, gps_lat, gps_lon,
	thumbnail_path, duplicate_group_id, is_kept, status, scanned_at, scan_run_id`

func scanPhoto(row *sql.Row) (*Photo, error) {
	var p Photo
	var takenAt, scannedAt sql.NullString
	var groupID, scanRunID sql.NullInt64
	var lat, lon sql.NullFloat64
	var isKept int64

	err := row.Scan(
		&p.ID, &p.Path, &p.Hash, &p.FileSize, &p.Width, &p.Height,
		&takenAt, &p.CameraMake, &p.CameraModel, &lat, &lon,
		&p.ThumbnailPath, &groupID, &isKept, &p.Status, &scannedAt, &scanRunID,
	)
	if err != nil {
		return nil, err
	}
	p.IsKept = isKept == 1
	if takenAt.Valid {
		if t, err := time.Parse(time.RFC3339, takenAt.String); err == nil {
			p.TakenAt = &t
		}
	}
	if scannedAt.Valid {
		p.ScannedAt, _ = time.Parse(time.RFC3339, scannedAt.String)
	}
	if groupID.Valid {
		p.DuplicateGroupID = &groupID.Int64
	}
	if scanRunID.Valid {
		p.ScanRunID = &scanRunID.Int64
	}
	if lat.Valid {
		p.GPSLat = &lat.Float64
	}
	if lon.Valid {
		p.GPSLon = &lon.Float64
	}
	return &p, nil
}

func (db *DB) queryPhotos(q string, args ...any) ([]Photo, error) {
	rows, err := db.Query(q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var photos []Photo
	for rows.Next() {
		var p Photo
		var takenAt, scannedAt sql.NullString
		var groupID, scanRunID sql.NullInt64
		var lat, lon sql.NullFloat64
		var isKept int64

		if err := rows.Scan(
			&p.ID, &p.Path, &p.Hash, &p.FileSize, &p.Width, &p.Height,
			&takenAt, &p.CameraMake, &p.CameraModel, &lat, &lon,
			&p.ThumbnailPath, &groupID, &isKept, &p.Status, &scannedAt, &scanRunID,
		); err != nil {
			return nil, err
		}
		p.IsKept = isKept == 1
		if takenAt.Valid {
			if t, err := time.Parse(time.RFC3339, takenAt.String); err == nil {
				p.TakenAt = &t
			}
		}
		if scannedAt.Valid {
			p.ScannedAt, _ = time.Parse(time.RFC3339, scannedAt.String)
		}
		if groupID.Valid {
			p.DuplicateGroupID = &groupID.Int64
		}
		if scanRunID.Valid {
			p.ScanRunID = &scanRunID.Int64
		}
		if lat.Valid {
			p.GPSLat = &lat.Float64
		}
		if lon.Valid {
			p.GPSLon = &lon.Float64
		}
		photos = append(photos, p)
	}
	return photos, rows.Err()
}

func buildPhotoWhere(f PhotoFilter) (string, []any) {
	var clauses []string
	var args []any

	if f.Status != "" {
		clauses = append(clauses, "status = ?")
		args = append(args, f.Status)
	}
	if f.CameraModel != "" {
		clauses = append(clauses, "camera_model = ?")
		args = append(args, f.CameraModel)
	}
	if f.DateFrom != nil {
		clauses = append(clauses, "taken_at >= ?")
		args = append(args, f.DateFrom.UTC().Format(time.RFC3339))
	}
	if f.DateTo != nil {
		clauses = append(clauses, "taken_at <= ?")
		args = append(args, f.DateTo.UTC().Format(time.RFC3339))
	}
	if f.HasDuplicates != nil {
		if *f.HasDuplicates {
			clauses = append(clauses, "duplicate_group_id IS NOT NULL")
		} else {
			clauses = append(clauses, "duplicate_group_id IS NULL")
		}
	}

	if len(clauses) == 0 {
		return "", args
	}
	return " WHERE " + strings.Join(clauses, " AND "), args
}

// ---- null helpers -----------------------------------------------------------

func nullTime(t *time.Time) any {
	if t == nil {
		return nil
	}
	return t.UTC().Format(time.RFC3339)
}

func nullFloat64(f *float64) any {
	if f == nil {
		return nil
	}
	return *f
}

func nullInt64(i *int64) any {
	if i == nil {
		return nil
	}
	return *i
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
