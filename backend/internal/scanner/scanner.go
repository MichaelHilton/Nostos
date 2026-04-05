package scanner

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"

	"photosorter/internal/db"
	"photosorter/internal/duplicates"
	"photosorter/internal/exif"
	"photosorter/internal/thumbnails"
)

// SupportedExtensions lists all file extensions the scanner will process.
var SupportedExtensions = map[string]bool{
	// Standard
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".heic": true,
	".tiff": true,
	".tif":  true,
	// Canon
	".cr2": true,
	".cr3": true,
	// Nikon
	".nef": true,
	// Sony
	".arw": true,
	// Adobe DNG
	".dng": true,
	// Fujifilm
	".raf": true,
	// Olympus
	".orf": true,
	// Panasonic
	".rw2": true,
	// Pentax
	".pef": true,
}

// Progress carries live progress information during a scan.
type Progress struct {
	ScanRunID       int64
	FilesFound      int64
	FilesProcessed  int64
	DuplicatesFound int64
	Errors          []string
	mu              sync.Mutex
}

func (p *Progress) addError(msg string) {
	p.mu.Lock()
	p.Errors = append(p.Errors, msg)
	p.mu.Unlock()
}

// Scanner walks a directory and records every image file in the database.
type Scanner struct {
	DB          *db.DB
	ThumbsDir   string
	Concurrency int
}

// New creates a Scanner with sensible defaults.
func New(database *db.DB, thumbsDir string) *Scanner {
	return &Scanner{
		DB:          database,
		ThumbsDir:   thumbsDir,
		Concurrency: 8,
	}
}

// StartScan creates a scan run record, kicks off an async worker, and returns
// the run ID immediately so callers can poll progress via the database.
func (s *Scanner) StartScan(ctx context.Context, rootPath string) (int64, error) {
	if info, err := os.Stat(rootPath); err != nil || !info.IsDir() {
		return 0, fmt.Errorf("%s is not an accessible directory", rootPath)
	}

	runID, err := s.DB.CreateScanRun(rootPath)
	if err != nil {
		return 0, fmt.Errorf("create scan run: %w", err)
	}

	go func() {
		_, _ = s.scan(ctx, rootPath, runID)
	}()

	return runID, nil
}

// scan does the actual directory walk and is called from a goroutine.
func (s *Scanner) scan(ctx context.Context, rootPath string, runID int64) (*Progress, error) {
	prog := &Progress{ScanRunID: runID}

	// Collect all image paths first (fast walk)
	var paths []string
	err := filepath.WalkDir(rootPath, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			log.Printf("walk error at %s: %v", path, err)
			return nil // keep walking
		}
		if d.IsDir() {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(path))
		if SupportedExtensions[ext] {
			paths = append(paths, path)
			atomic.AddInt64(&prog.FilesFound, 1)
		}
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("walk directory: %w", err)
	}

	// Process concurrently with a bounded worker pool
	jobs := make(chan string, s.Concurrency*2)
	var wg sync.WaitGroup

	for i := 0; i < s.Concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for path := range jobs {
				select {
				case <-ctx.Done():
					return
				default:
				}
				if err := s.processFile(ctx, path, runID, prog); err != nil {
					prog.addError(fmt.Sprintf("%s: %v", path, err))
				}
				atomic.AddInt64(&prog.FilesProcessed, 1)
			}
		}()
	}

	for _, p := range paths {
		select {
		case <-ctx.Done():
			break
		case jobs <- p:
		}
	}
	close(jobs)
	wg.Wait()

	// Detect duplicates across new photos from this scan run
	dupCount, err := duplicates.DetectForScanRun(s.DB, runID)
	if err != nil {
		log.Printf("duplicate detection error: %v", err)
	}
	atomic.AddInt64(&prog.DuplicatesFound, int64(dupCount))

	status := db.ScanCompleted
	if ctx.Err() != nil {
		status = db.ScanFailed
	}
	_ = s.DB.FinishScanRun(runID, status, int(prog.FilesProcessed), dupCount)

	return prog, nil
}

func (s *Scanner) processFile(ctx context.Context, path string, runID int64, prog *Progress) error {
	info, err := os.Stat(path)
	if err != nil {
		return fmt.Errorf("stat: %w", err)
	}

	// Compute hash
	hash, err := duplicates.HashFile(path)
	if err != nil {
		return fmt.Errorf("hash: %w", err)
	}

	// Read EXIF
	meta := exif.Read(path)

	// Build photo record
	photo := &db.Photo{
		Path:        path,
		Hash:        hash,
		FileSize:    info.Size(),
		Width:       meta.Width,
		Height:      meta.Height,
		TakenAt:     meta.TakenAt,
		CameraMake:  meta.CameraMake,
		CameraModel: meta.CameraModel,
		GPSLat:      meta.GPSLat,
		GPSLon:      meta.GPSLon,
		Status:      db.StatusNew,
		ScannedAt:   info.ModTime(),
	}
	photo.ScannedAt = info.ModTime()
	runIDCopy := runID
	photo.ScanRunID = &runIDCopy

	photoID, err := s.DB.UpsertPhoto(photo)
	if err != nil {
		return fmt.Errorf("upsert photo: %w", err)
	}

	// Generate thumbnail (non-fatal if it fails)
	thumbPath, err := thumbnails.Generate(path, photoID, s.ThumbsDir)
	if err != nil {
		log.Printf("thumbnail %s: %v", path, err)
	} else if thumbPath != "" {
		_ = s.DB.UpdatePhotoThumbnail(photoID, thumbPath)
	}

	return nil
}
