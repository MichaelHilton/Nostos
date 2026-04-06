package db

import (
	"database/sql"
	"fmt"

	_ "modernc.org/sqlite"
)

const schema = `
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS scan_runs (
	id              INTEGER PRIMARY KEY AUTOINCREMENT,
	root_path       TEXT    NOT NULL,
	started_at      DATETIME NOT NULL,
	finished_at     DATETIME,
	photos_found    INTEGER  DEFAULT 0,
	duplicates_found INTEGER DEFAULT 0,
	status          TEXT     NOT NULL DEFAULT 'running'
);

CREATE TABLE IF NOT EXISTS duplicate_groups (
	id            INTEGER PRIMARY KEY AUTOINCREMENT,
	reason        TEXT NOT NULL,
	kept_photo_id INTEGER
);

CREATE TABLE IF NOT EXISTS photos (
	id                 INTEGER  PRIMARY KEY AUTOINCREMENT,
	path               TEXT     NOT NULL UNIQUE,
	hash               TEXT,
	file_size          INTEGER,
	width              INTEGER,
	height             INTEGER,
	taken_at           DATETIME,
	camera_make        TEXT,
	camera_model       TEXT,
	gps_lat            REAL,
	gps_lon            REAL,
	thumbnail_path     TEXT,
	duplicate_group_id INTEGER  REFERENCES duplicate_groups(id),
	is_kept            INTEGER  NOT NULL DEFAULT 0,
	status             TEXT     NOT NULL DEFAULT 'new',
	scanned_at         DATETIME NOT NULL,
	scan_run_id        INTEGER  REFERENCES scan_runs(id)
);

CREATE INDEX IF NOT EXISTS idx_photos_hash             ON photos(hash);
CREATE INDEX IF NOT EXISTS idx_photos_status           ON photos(status);
CREATE INDEX IF NOT EXISTS idx_photos_taken_at         ON photos(taken_at);
CREATE INDEX IF NOT EXISTS idx_photos_duplicate_group  ON photos(duplicate_group_id);
CREATE INDEX IF NOT EXISTS idx_photos_scan_run         ON photos(scan_run_id);

CREATE TABLE IF NOT EXISTS organize_jobs (
	id               INTEGER  PRIMARY KEY AUTOINCREMENT,
	destination_root TEXT     NOT NULL,
	folder_format    TEXT     NOT NULL DEFAULT 'YYYY/MM/DD',
	dry_run          INTEGER  NOT NULL DEFAULT 1,
	started_at       DATETIME NOT NULL,
	finished_at      DATETIME,
	status           TEXT     NOT NULL DEFAULT 'running',
	total_files      INTEGER  DEFAULT 0,
	copied_files     INTEGER  DEFAULT 0,
	skipped_files    INTEGER  DEFAULT 0
);

CREATE TABLE IF NOT EXISTS organize_results (
	id          INTEGER PRIMARY KEY AUTOINCREMENT,
	job_id      INTEGER NOT NULL REFERENCES organize_jobs(id),
	photo_id    INTEGER NOT NULL REFERENCES photos(id),
	source      TEXT    NOT NULL,
	destination TEXT    NOT NULL,
	action      TEXT    NOT NULL,
	reason      TEXT
);
`

// DB wraps sql.DB with app-specific methods.
type DB struct {
	*sql.DB
}

// Open opens or creates the SQLite database at path and applies migrations.
func Open(path string) (*DB, error) {
	sqlDB, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	// SQLite does not support concurrent writers; one connection is safest.
	sqlDB.SetMaxOpenConns(1)

	db := &DB{sqlDB}
	if err := db.migrate(); err != nil {
		_ = sqlDB.Close()
		return nil, fmt.Errorf("migrate: %w", err)
	}
	return db, nil
}

func (db *DB) migrate() error {
	_, err := db.Exec(schema)
	return err
}
