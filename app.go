package main

import (
	"context"
	"encoding/base64"
	"fmt"
	"os"
	"time"

	"github.com/wailsapp/wails/v2/pkg/runtime"

	"photosorter/internal/db"
	"photosorter/internal/organizer"
	"photosorter/internal/scanner"
)

// App holds all dependencies and exposes bound methods to the frontend.
type App struct {
	ctx       context.Context
	database  *db.DB
	thumbsDir string
}

// NewApp creates a new App instance.
func NewApp(database *db.DB, thumbsDir string) *App {
	return &App{database: database, thumbsDir: thumbsDir}
}

// startup is called by Wails after the window is ready. Stores the context
// needed for runtime calls (events, dialogs).
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// ---- Directory pickers ------------------------------------------------------

// PickDirectory opens a native OS folder-picker and returns the chosen path.
func (a *App) PickDirectory() (string, error) {
	return runtime.OpenDirectoryDialog(a.ctx, runtime.OpenDialogOptions{
		Title: "Choose a folder to scan",
	})
}

// PickDestinationDirectory opens a native folder-picker for the organize destination.
func (a *App) PickDestinationDirectory() (string, error) {
	return runtime.OpenDirectoryDialog(a.ctx, runtime.OpenDialogOptions{
		Title: "Choose destination folder",
	})
}

// ---- Scan -------------------------------------------------------------------

// ScanResult is returned immediately when a scan is started.
type ScanResult struct {
	ScanRunID int64  `json:"scan_run_id"`
	Status    string `json:"status"`
}

// StartScan begins a background directory scan and immediately returns the run ID.
// Progress is delivered to the frontend via "scan:progress" and "scan:done" events.
func (a *App) StartScan(rootPath string) (ScanResult, error) {
	s := scanner.New(a.database, a.thumbsDir)
	runID, err := s.StartScan(a.ctx, rootPath)
	if err != nil {
		return ScanResult{}, err
	}
	go a.watchScan(runID)
	return ScanResult{ScanRunID: runID, Status: "running"}, nil
}

// watchScan polls the DB and emits Wails events until the scan finishes.
func (a *App) watchScan(runID int64) {
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()
	for range ticker.C {
		run, err := a.database.GetScanRun(runID)
		if err != nil {
			return
		}
		runtime.EventsEmit(a.ctx, "scan:progress", run)
		if run.Status != db.ScanRunning {
			runtime.EventsEmit(a.ctx, "scan:done", run)
			return
		}
	}
}

// GetScan returns a single scan run by ID.
func (a *App) GetScan(id int64) (*db.ScanRun, error) {
	return a.database.GetScanRun(id)
}

// ListScans returns all scan runs, newest first.
func (a *App) ListScans() ([]db.ScanRun, error) {
	runs, err := a.database.ListScanRuns()
	if runs == nil {
		runs = []db.ScanRun{}
	}
	return runs, err
}

// ---- Photos -----------------------------------------------------------------

// PhotoQuery is the parameter struct for ListPhotos.
type PhotoQuery struct {
	Status        string `json:"status"`
	CameraModel   string `json:"camera_model"`
	DateFrom      string `json:"date_from"`
	DateTo        string `json:"date_to"`
	HasDuplicates *bool  `json:"has_duplicates"`
	Limit         int    `json:"limit"`
	Offset        int    `json:"offset"`
}

// PhotosResult is the paginated response from ListPhotos.
type PhotosResult struct {
	Photos []db.Photo `json:"photos"`
	Total  int        `json:"total"`
	Offset int        `json:"offset"`
	Limit  int        `json:"limit"`
}

// ListPhotos returns a filtered, paginated list of photos.
func (a *App) ListPhotos(q PhotoQuery) (PhotosResult, error) {
	filter := db.PhotoFilter{
		Status:        q.Status,
		CameraModel:   q.CameraModel,
		HasDuplicates: q.HasDuplicates,
		Limit:         q.Limit,
		Offset:        q.Offset,
	}
	if q.DateFrom != "" {
		if t, err := time.Parse("2006-01-02", q.DateFrom); err == nil {
			filter.DateFrom = &t
		}
	}
	if q.DateTo != "" {
		if t, err := time.Parse("2006-01-02", q.DateTo); err == nil {
			filter.DateTo = &t
		}
	}
	photos, total, err := a.database.ListPhotos(filter)
	if err != nil {
		return PhotosResult{}, err
	}
	if photos == nil {
		photos = []db.Photo{}
	}
	return PhotosResult{Photos: photos, Total: total, Offset: q.Offset, Limit: q.Limit}, nil
}

// GetPhoto returns a single photo by ID.
func (a *App) GetPhoto(id int64) (*db.Photo, error) {
	return a.database.GetPhoto(id)
}

// GetThumbnailDataURL reads a photo's cached thumbnail from disk and returns it
// as a base64 data URL (data:image/jpeg;base64,...). This replaces the old
// HTTP /api/thumbnails/:id endpoint.
func (a *App) GetThumbnailDataURL(photoID int64) (string, error) {
	p, err := a.database.GetPhoto(photoID)
	if err != nil {
		return "", err
	}
	if p == nil || p.ThumbnailPath == "" {
		return "", fmt.Errorf("no thumbnail for photo %d", photoID)
	}
	data, err := os.ReadFile(p.ThumbnailPath)
	if err != nil {
		return "", err
	}
	return "data:image/jpeg;base64," + base64.StdEncoding.EncodeToString(data), nil
}

// ---- Duplicates -------------------------------------------------------------

// ListDuplicates returns all duplicate groups with their photos.
func (a *App) ListDuplicates() ([]db.DuplicateGroup, error) {
	groups, err := a.database.ListDuplicateGroups()
	if groups == nil {
		groups = []db.DuplicateGroup{}
	}
	return groups, err
}

// ResolveDuplicate marks keptPhotoID as the photo to keep within its group.
func (a *App) ResolveDuplicate(groupID int64, keptPhotoID int64) error {
	return a.database.SetPhotoKept(keptPhotoID)
}

// ---- Organize ---------------------------------------------------------------

// OrganizeRequest is the parameter struct for StartOrganize.
type OrganizeRequest struct {
	SourcePhotoIDs  []int64 `json:"source_photo_ids"`
	DestinationRoot string  `json:"destination_root"`
	FolderFormat    string  `json:"folder_format"`
	DryRun          bool    `json:"dry_run"`
}

// StartOrganizeResult is returned immediately when an organize job is started.
type StartOrganizeResult struct {
	JobID  int64  `json:"job_id"`
	Status string `json:"status"`
}

// OrganizeJobResult is used for event payloads and GetOrganizeJob responses.
type OrganizeJobResult struct {
	Job     *db.OrganizeJob    `json:"job"`
	Results []db.OrganizeResult `json:"results"`
}

// StartOrganize begins a background organize job and immediately returns the job ID.
// Progress is delivered via "organize:progress" and "organize:done" events.
func (a *App) StartOrganize(req OrganizeRequest) (StartOrganizeResult, error) {
	if req.FolderFormat == "" {
		req.FolderFormat = "YYYY/MM/DD"
	}
	org := organizer.New(a.database)
	jobID, err := org.Run(a.ctx, organizer.Request{
		SourcePhotoIDs:  req.SourcePhotoIDs,
		DestinationRoot: req.DestinationRoot,
		FolderFormat:    req.FolderFormat,
		DryRun:          req.DryRun,
	})
	if err != nil {
		return StartOrganizeResult{}, err
	}
	go a.watchOrganize(jobID)
	return StartOrganizeResult{JobID: jobID, Status: "running"}, nil
}

// watchOrganize polls the DB and emits Wails events until the organize job finishes.
func (a *App) watchOrganize(jobID int64) {
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()
	for range ticker.C {
		job, err := a.database.GetOrganizeJob(jobID)
		if err != nil {
			return
		}
		results, _ := a.database.ListOrganizeResults(jobID)
		if results == nil {
			results = []db.OrganizeResult{}
		}
		payload := OrganizeJobResult{Job: job, Results: results}
		runtime.EventsEmit(a.ctx, "organize:progress", payload)
		if job.Status != db.JobRunning {
			runtime.EventsEmit(a.ctx, "organize:done", payload)
			return
		}
	}
}

// GetOrganizeJob returns the current state of an organize job plus all its results.
func (a *App) GetOrganizeJob(id int64) (OrganizeJobResult, error) {
	job, err := a.database.GetOrganizeJob(id)
	if err != nil {
		return OrganizeJobResult{}, err
	}
	results, _ := a.database.ListOrganizeResults(id)
	if results == nil {
		results = []db.OrganizeResult{}
	}
	return OrganizeJobResult{Job: job, Results: results}, nil
}
