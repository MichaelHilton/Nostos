package organizer

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"photosorter/internal/db"
	"photosorter/internal/duplicates"
)

// Request specifies what to copy and where.
type Request struct {
	// SourcePhotoIDs limits the job to specific photos; nil means all eligible.
	SourcePhotoIDs  []int64
	DestinationRoot string
	// FolderFormat uses YYYY MM DD as tokens, e.g. "YYYY/MM/DD".
	FolderFormat string
	DryRun       bool
}

// Organizer runs copy jobs.
type Organizer struct {
	DB *db.DB
}

func New(database *db.DB) *Organizer {
	return &Organizer{DB: database}
}

// Run executes an organize job. Returns the job ID immediately; progress can
// be polled via the database.
func (o *Organizer) Run(ctx context.Context, req Request) (int64, error) {
	if req.FolderFormat == "" {
		req.FolderFormat = "YYYY/MM/DD"
	}

	jobID, err := o.DB.CreateOrganizeJob(req.DestinationRoot, req.FolderFormat, req.DryRun)
	if err != nil {
		return 0, fmt.Errorf("create organize job: %w", err)
	}

	go func() {
		if err := o.execute(ctx, jobID, req); err != nil {
			_ = o.DB.FinishOrganizeJob(jobID, db.JobFailed, 0, 0, 0)
		}
	}()

	return jobID, nil
}

func (o *Organizer) execute(ctx context.Context, jobID int64, req Request) error {
	photos, err := o.loadEligiblePhotos(req)
	if err != nil {
		return err
	}

	total, copied, skipped := len(photos), 0, 0

	for _, p := range photos {
		select {
		case <-ctx.Done():
			_ = o.DB.FinishOrganizeJob(jobID, db.JobFailed, total, copied, skipped)
			return ctx.Err()
		default:
		}

		result := o.planCopy(p, req)
		result.JobID = jobID

		switch result.Action {
		case db.ActionCopy:
			if !req.DryRun {
				if err := copyFile(result.Source, result.Destination); err != nil {
					result.Action = db.ActionSkipExists
					result.Reason = fmt.Sprintf("copy failed: %v", err)
					skipped++
				} else {
					copied++
					_ = o.DB.UpdatePhotoStatus(p.ID, db.StatusCopied)
				}
			} else {
				copied++ // dry-run: count as "would copy"
			}
		case db.ActionRenameConflict:
			if !req.DryRun {
				if err := copyFile(result.Source, result.Destination); err != nil {
					result.Reason += fmt.Sprintf(" (copy failed: %v)", err)
					skipped++
				} else {
					copied++
					_ = o.DB.UpdatePhotoStatus(p.ID, db.StatusSkippedConflict)
				}
			} else {
				copied++
			}
		default:
			// skip_exists or skip_duplicate
			skipped++
			status := db.StatusSkippedExists
			if result.Action == db.ActionSkipDuplicate {
				status = db.StatusSkippedDuplicate
			}
			if !req.DryRun {
				_ = o.DB.UpdatePhotoStatus(p.ID, status)
			}
		}

		_ = o.DB.AddOrganizeResult(result)
	}

	_ = o.DB.FinishOrganizeJob(jobID, db.JobCompleted, total, copied, skipped)
	return nil
}

// loadEligiblePhotos returns all photos that should appear in the job.
// Already-copied photos are excluded. Non-kept duplicates are included but
// will receive ActionSkipDuplicate in planCopy.
func (o *Organizer) loadEligiblePhotos(req Request) ([]db.Photo, error) {
	var photos []db.Photo
	var err error

	if len(req.SourcePhotoIDs) > 0 {
		for _, id := range req.SourcePhotoIDs {
			p, err := o.DB.GetPhoto(id)
			if err != nil || p == nil {
				continue
			}
			photos = append(photos, *p)
		}
	} else {
		photos, _, err = o.DB.ListPhotos(db.PhotoFilter{Limit: 1_000_000})
		if err != nil {
			return nil, err
		}
	}

	var eligible []db.Photo
	for _, p := range photos {
		// Skip already-copied
		if p.Status == db.StatusCopied {
			continue
		}
		eligible = append(eligible, p)
	}
	return eligible, nil
}

// planCopy decides what action to take for a single photo.
func (o *Organizer) planCopy(p db.Photo, req Request) db.OrganizeResult {
	result := db.OrganizeResult{
		PhotoID: p.ID,
		Source:  p.Path,
	}

	destDir := filepath.Join(req.DestinationRoot, dateDir(p.TakenAt, req.FolderFormat))
	destPath := filepath.Join(destDir, filepath.Base(p.Path))
	result.Destination = destPath

	// Non-kept duplicate: record the skip, do not copy
	if p.DuplicateGroupID != nil && !p.IsKept {
		result.Action = db.ActionSkipDuplicate
		result.Reason = "non-kept copy in duplicate group"
		return result
	}

	existingInfo, err := os.Stat(destPath)
	if err != nil {
		// Destination does not exist → safe to copy
		result.Action = db.ActionCopy
		result.Reason = "destination does not exist"
		return result
	}

	// Destination exists — compare hashes
	if existingInfo.Size() > 0 {
		srcHash, _ := duplicates.HashFile(p.Path)
		dstHash, _ := duplicates.HashFile(destPath)
		if srcHash != "" && srcHash == dstHash {
			result.Action = db.ActionSkipExists
			result.Reason = "identical file already exists at destination"
			return result
		}
	}

	// Different content — rename to avoid overwriting
	result.Destination = resolveConflictName(destDir, filepath.Base(p.Path))
	result.Action = db.ActionRenameConflict
	result.Reason = fmt.Sprintf("destination exists with different content; renaming to %s", filepath.Base(result.Destination))
	return result
}

// ---- helpers ----------------------------------------------------------------

// dateDir converts a time to a folder path using the format template.
// Tokens: YYYY, MM, DD.
func dateDir(t *time.Time, format string) string {
	if t == nil {
		return filepath.Join("unknown", "unknown", "unknown")
	}
	result := format
	result = strings.ReplaceAll(result, "YYYY", t.Format("2006"))
	result = strings.ReplaceAll(result, "MM", t.Format("01"))
	result = strings.ReplaceAll(result, "DD", t.Format("02"))
	return filepath.FromSlash(result)
}

// resolveConflictName finds a non-colliding filename by appending _2, _3 …
func resolveConflictName(dir, base string) string {
	ext := filepath.Ext(base)
	stem := strings.TrimSuffix(base, ext)
	for i := 2; i < 1000; i++ {
		candidate := filepath.Join(dir, fmt.Sprintf("%s_%d%s", stem, i, ext))
		if _, err := os.Stat(candidate); os.IsNotExist(err) {
			return candidate
		}
	}
	return filepath.Join(dir, fmt.Sprintf("%s_conflict%s", stem, ext))
}

// copyFile copies src to dst, creating destination directories as needed.
func copyFile(src, dst string) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return fmt.Errorf("mkdir: %w", err)
	}

	in, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("open src: %w", err)
	}
	defer in.Close()

	out, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("create dst: %w", err)
	}
	defer func() {
		_ = out.Close()
		if err != nil {
			_ = os.Remove(dst) // clean up partial copy on error
		}
	}()

	if _, err = io.Copy(out, in); err != nil {
		return fmt.Errorf("copy: %w", err)
	}
	return out.Close()
}
