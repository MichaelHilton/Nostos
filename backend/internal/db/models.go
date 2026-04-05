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
	ActionCopy            = "copy"
	ActionSkipExists      = "skip_exists"
	ActionSkipDuplicate   = "skip_duplicate"
	ActionRenameConflict  = "rename_conflict"
)

// Photo represents a single image file tracked in the database.
type Photo struct {
	ID               int64
	Path             string
	Hash             string
	FileSize         int64
	Width            int
	Height           int
	TakenAt          *time.Time
	CameraMake       string
	CameraModel      string
	GPSLat           *float64
	GPSLon           *float64
	ThumbnailPath    string
	DuplicateGroupID *int64
	IsKept           bool
	Status           string
	ScannedAt        time.Time
	ScanRunID        *int64
}

// ScanRun represents one directory scan session.
type ScanRun struct {
	ID              int64
	RootPath        string
	StartedAt       time.Time
	FinishedAt      *time.Time
	PhotosFound     int
	DuplicatesFound int
	Status          string
}

// DuplicateGroup clusters identical or near-identical photos.
type DuplicateGroup struct {
	ID          int64
	Reason      string
	KeptPhotoID *int64
	Photos      []Photo // populated on demand
}

// OrganizeJob tracks a batch copy operation.
type OrganizeJob struct {
	ID              int64
	DestinationRoot string
	FolderFormat    string
	DryRun          bool
	StartedAt       time.Time
	FinishedAt      *time.Time
	Status          string
	TotalFiles      int
	CopiedFiles     int
	SkippedFiles    int
}

// OrganizeResult records the outcome of one file in an organize job.
type OrganizeResult struct {
	ID          int64
	JobID       int64
	PhotoID     int64
	Source      string
	Destination string
	Action      string
	Reason      string
}

// PhotoFilter contains optional filters for listing photos.
type PhotoFilter struct {
	Status      string
	CameraModel string
	DateFrom    *time.Time
	DateTo      *time.Time
	HasDuplicates *bool
	Limit       int
	Offset      int
}
