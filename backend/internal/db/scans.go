package db

import (
	"database/sql"
	"time"
)

// CreateScanRun inserts a new running scan and returns its ID.
func (db *DB) CreateScanRun(rootPath string) (int64, error) {
	res, err := db.Exec(
		`INSERT INTO scan_runs (root_path, started_at, status) VALUES (?, ?, ?)`,
		rootPath, time.Now().UTC().Format(time.RFC3339), ScanRunning,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// FinishScanRun marks a scan run as completed or failed and records totals.
func (db *DB) FinishScanRun(id int64, status string, photosFound, dupsFound int) error {
	_, err := db.Exec(
		`UPDATE scan_runs SET finished_at=?, status=?, photos_found=?, duplicates_found=? WHERE id=?`,
		time.Now().UTC().Format(time.RFC3339), status, photosFound, dupsFound, id,
	)
	return err
}

// GetScanRun retrieves a scan run by ID.
func (db *DB) GetScanRun(id int64) (*ScanRun, error) {
	const q = `SELECT id, root_path, started_at, finished_at, photos_found, duplicates_found, status
	           FROM scan_runs WHERE id = ?`
	row := db.QueryRow(q, id)
	return scanScanRun(row)
}

// ListScanRuns returns all scan runs, newest first.
func (db *DB) ListScanRuns() ([]ScanRun, error) {
	const q = `SELECT id, root_path, started_at, finished_at, photos_found, duplicates_found, status
	           FROM scan_runs ORDER BY id DESC`
	rows, err := db.Query(q)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var runs []ScanRun
	for rows.Next() {
		var r ScanRun
		var startedAt, finishedAt sql.NullString
		err := rows.Scan(&r.ID, &r.RootPath, &startedAt, &finishedAt,
			&r.PhotosFound, &r.DuplicatesFound, &r.Status)
		if err != nil {
			return nil, err
		}
		if startedAt.Valid {
			r.StartedAt, _ = time.Parse(time.RFC3339, startedAt.String)
		}
		if finishedAt.Valid {
			t, _ := time.Parse(time.RFC3339, finishedAt.String)
			r.FinishedAt = &t
		}
		runs = append(runs, r)
	}
	return runs, rows.Err()
}

// ---- organize jobs ----------------------------------------------------------

// CreateOrganizeJob inserts a new organize job and returns its ID.
func (db *DB) CreateOrganizeJob(destRoot, folderFormat string, dryRun bool) (int64, error) {
	res, err := db.Exec(
		`INSERT INTO organize_jobs (destination_root, folder_format, dry_run, started_at, status)
		 VALUES (?, ?, ?, ?, ?)`,
		destRoot, folderFormat, boolToInt(dryRun),
		time.Now().UTC().Format(time.RFC3339), JobRunning,
	)
	if err != nil {
		return 0, err
	}
	return res.LastInsertId()
}

// FinishOrganizeJob marks a job done and writes final counters.
func (db *DB) FinishOrganizeJob(id int64, status string, total, copied, skipped int) error {
	_, err := db.Exec(
		`UPDATE organize_jobs SET finished_at=?, status=?, total_files=?, copied_files=?, skipped_files=? WHERE id=?`,
		time.Now().UTC().Format(time.RFC3339), status, total, copied, skipped, id,
	)
	return err
}

// GetOrganizeJob retrieves an organize job by ID including its results.
func (db *DB) GetOrganizeJob(id int64) (*OrganizeJob, error) {
	const q = `SELECT id, destination_root, folder_format, dry_run, started_at, finished_at,
	                  status, total_files, copied_files, skipped_files
	           FROM organize_jobs WHERE id = ?`
	row := db.QueryRow(q, id)

	var j OrganizeJob
	var startedAt, finishedAt sql.NullString
	err := row.Scan(&j.ID, &j.DestinationRoot, &j.FolderFormat, &j.DryRun,
		&startedAt, &finishedAt, &j.Status, &j.TotalFiles, &j.CopiedFiles, &j.SkippedFiles)
	if err != nil {
		return nil, err
	}
	if startedAt.Valid {
		j.StartedAt, _ = time.Parse(time.RFC3339, startedAt.String)
	}
	if finishedAt.Valid {
		t, _ := time.Parse(time.RFC3339, finishedAt.String)
		j.FinishedAt = &t
	}
	return &j, nil
}

// AddOrganizeResult inserts a single file's organize outcome.
func (db *DB) AddOrganizeResult(r OrganizeResult) error {
	_, err := db.Exec(
		`INSERT INTO organize_results (job_id, photo_id, source, destination, action, reason)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		r.JobID, r.PhotoID, r.Source, r.Destination, r.Action, r.Reason,
	)
	return err
}

// ListOrganizeResults returns all results for a job.
func (db *DB) ListOrganizeResults(jobID int64) ([]OrganizeResult, error) {
	const q = `SELECT id, job_id, photo_id, source, destination, action, reason
	           FROM organize_results WHERE job_id = ? ORDER BY id`
	rows, err := db.Query(q, jobID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []OrganizeResult
	for rows.Next() {
		var r OrganizeResult
		if err := rows.Scan(&r.ID, &r.JobID, &r.PhotoID, &r.Source, &r.Destination, &r.Action, &r.Reason); err != nil {
			return nil, err
		}
		results = append(results, r)
	}
	return results, rows.Err()
}

// ---- helpers ----------------------------------------------------------------

func scanScanRun(row *sql.Row) (*ScanRun, error) {
	var r ScanRun
	var startedAt, finishedAt sql.NullString
	err := row.Scan(&r.ID, &r.RootPath, &startedAt, &finishedAt,
		&r.PhotosFound, &r.DuplicatesFound, &r.Status)
	if err != nil {
		return nil, err
	}
	if startedAt.Valid {
		r.StartedAt, _ = time.Parse(time.RFC3339, startedAt.String)
	}
	if finishedAt.Valid {
		t, _ := time.Parse(time.RFC3339, finishedAt.String)
		r.FinishedAt = &t
	}
	return &r, nil
}
