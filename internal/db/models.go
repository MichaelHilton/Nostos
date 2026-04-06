package db

import "time"

// PhotoStatus values.
const (
	StatusNew              = "new"
	StatusCopied           = "copied"
	StatusSkippedDuplicate = "skipped_duplicate"
	StatusSkippedExists    = "skipped_exists"
	StatusSkippedConflict  = "skipped_conflict"
)

// ScanStatus values.
const (
	ScanRunning   = "running"
	ScanCompleted = "completed"
	ScanFailed    = "failed"
)

// JobStatus values.
const (
	JobRunning   = "running"
	JobCompleted = "completed"
	JobFailed    = "failed"
)

// DuplicateReason values.
const (
	DupReasonHash = "hash_match"
	DupReasonExif = "exif_match"
)

// OrganizeAction values.
const (
	ActionCopy           = "copy"
	ActionSkipExists     = "skip_exists"
	ActionSkipDuplicate  = "skip_duplicate"
	ActionRenameConflict = "rename_conflict"
)

// Photo represents a single image file tracked in the database.
type Photo struct {
	ID               int64      `json:"id"`
	Path             string     `json:"path"`
	Hash             string     `json:"hash"`
	FileSize         int64      `json:"file_size"`
	Width            int        `json:"width"`
	Height           int        `json:"height"`
	TakenAt          *time.Time `json:"taken_at"`
	CameraMake       string     `json:"camera_make"`
	CameraModel      string     `json:"camera_model"`
	GPSLat           *float64   `json:"gps_lat"`
	GPSLon           *float64   `json:"gps_lon"`
	ThumbnailPath    string     `json:"thumbnail_path"`
	DuplicateGroupID *int64     `json:"duplicate_group_id"`
	IsKept           bool       `json:"is_kept"`
	Status           string     `json:"status"`
	ScannedAt        time.Time  `json:"scanned_at"`
	ScanRunID        *int64     `json:"scan_run_id"`
}

// ScanRun represents one directory scan session.
type ScanRun struct {
	ID              int64      `json:"id"`
	RootPath        string     `json:"root_path"`
	StartedAt       time.Time  `json:"started_at"`
	FinishedAt      *time.Time `json:"finished_at"`
	PhotosFound     int        `json:"photos_found"`
	DuplicatesFound int        `json:"duplicates_found"`
	Status          string     `json:"status"`
}

// DuplicateGroup clusters identical or near-identical photos.
type DuplicateGroup struct {
	ID          int64   `json:"id"`
	Reason      string  `json:"reason"`
	KeptPhotoID *int64  `json:"kept_photo_id"`
	Photos      []Photo `json:"photos"`
}

// OrganizeJob tracks a batch copy operation.
type OrganizeJob struct {
	ID              int64      `json:"id"`
	DestinationRoot string     `json:"destination_root"`
	FolderFormat    string     `json:"folder_format"`
	DryRun          bool       `json:"dry_run"`
	StartedAt       time.Time  `json:"started_at"`
	FinishedAt      *time.Time `json:"finished_at"`
	Status          string     `json:"status"`
	TotalFiles      int        `json:"total_files"`
	CopiedFiles     int        `json:"copied_files"`
	SkippedFiles    int        `json:"skipped_files"`
}

// OrganizeResult records the outcome of one file in an organize job.
type OrganizeResult struct {
	ID          int64  `json:"id"`
	JobID       int64  `json:"job_id"`
	PhotoID     int64  `json:"photo_id"`
	Source      string `json:"source"`
	Destination string `json:"destination"`
	Action      string `json:"action"`
	Reason      string `json:"reason"`
}

// PhotoFilter contains optional filters for listing photos.
type PhotoFilter struct {
	Status        string
	CameraModel   string
	DateFrom      *time.Time
	DateTo        *time.Time
	HasDuplicates *bool
	Limit         int
	Offset        int
}
