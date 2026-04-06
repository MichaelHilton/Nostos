package organizer_test

import (
	"context"
	"image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"
	"testing"
	"time"

	"photosorter/internal/db"
	"photosorter/internal/organizer"
)

// makeJPEG writes a tiny valid JPEG to path.
func makeJPEG(t *testing.T, path string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatal(err)
	}
	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	img.SetRGBA(0, 0, color.RGBA{R: 100, G: 150, B: 200, A: 255})
	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := jpeg.Encode(f, img, nil); err != nil {
		t.Fatal(err)
	}
}

func openTestDB(t *testing.T) *db.DB {
	t.Helper()
	database, err := db.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { database.Close() })
	return database
}

func insertPhoto(t *testing.T, database *db.DB, path string, takenAt *time.Time) int64 {
	t.Helper()
	info, _ := os.Stat(path)
	var size int64
	if info != nil {
		size = info.Size()
	}
	p := &db.Photo{
		Path:      path,
		Hash:      path, // use path as fake hash for test isolation
		FileSize:  size,
		TakenAt:   takenAt,
		Status:    db.StatusNew,
		ScannedAt: time.Now(),
	}
	id, err := database.UpsertPhoto(p)
	if err != nil {
		t.Fatalf("upsert photo: %v", err)
	}
	return id
}

func TestOrganizer_DryRun(t *testing.T) {
	srcDir := t.TempDir()
	dstDir := t.TempDir()
	database := openTestDB(t)

	photoPath := filepath.Join(srcDir, "IMG_001.jpg")
	makeJPEG(t, photoPath)

	takenAt := time.Date(2023, 7, 4, 12, 0, 0, 0, time.UTC)
	insertPhoto(t, database, photoPath, &takenAt)

	org := organizer.New(database)
	jobID, err := org.Run(context.Background(), organizer.Request{
		DestinationRoot: dstDir,
		FolderFormat:    "YYYY/MM/DD",
		DryRun:          true,
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}

	// Wait for job to finish
	job := waitForJob(t, database, jobID)
	if job.Status != db.JobCompleted {
		t.Errorf("expected job completed, got %s", job.Status)
	}

	// In dry-run, no files should be copied to disk
	dest := filepath.Join(dstDir, "2023", "07", "04", "IMG_001.jpg")
	if _, err := os.Stat(dest); err == nil {
		t.Error("dry-run should not have created any files on disk")
	}

	// But results should be recorded
	results, err := database.ListOrganizeResults(jobID)
	if err != nil {
		t.Fatal(err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	if results[0].Action != db.ActionCopy {
		t.Errorf("expected action %s, got %s", db.ActionCopy, results[0].Action)
	}
	expectedDest := filepath.Join(dstDir, "2023", "07", "04", "IMG_001.jpg")
	if results[0].Destination != expectedDest {
		t.Errorf("expected destination %s, got %s", expectedDest, results[0].Destination)
	}
}

func TestOrganizer_ActualCopy(t *testing.T) {
	srcDir := t.TempDir()
	dstDir := t.TempDir()
	database := openTestDB(t)

	photoPath := filepath.Join(srcDir, "vacation.jpg")
	makeJPEG(t, photoPath)

	takenAt := time.Date(2022, 12, 25, 9, 0, 0, 0, time.UTC)
	insertPhoto(t, database, photoPath, &takenAt)

	org := organizer.New(database)
	jobID, err := org.Run(context.Background(), organizer.Request{
		DestinationRoot: dstDir,
		FolderFormat:    "YYYY/MM/DD",
		DryRun:          false,
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}

	job := waitForJob(t, database, jobID)
	if job.Status != db.JobCompleted {
		t.Errorf("expected job completed, got %s", job.Status)
	}

	dest := filepath.Join(dstDir, "2022", "12", "25", "vacation.jpg")
	if _, err := os.Stat(dest); err != nil {
		t.Errorf("copied file not found at %s: %v", dest, err)
	}
	// Original should still exist (non-destructive)
	if _, err := os.Stat(photoPath); err != nil {
		t.Errorf("original file was removed from %s: %v", photoPath, err)
	}
}

func TestOrganizer_SkipsExistingIdentical(t *testing.T) {
	srcDir := t.TempDir()
	dstDir := t.TempDir()
	database := openTestDB(t)

	photoPath := filepath.Join(srcDir, "photo.jpg")
	makeJPEG(t, photoPath)

	takenAt := time.Date(2021, 6, 15, 10, 0, 0, 0, time.UTC)
	insertPhoto(t, database, photoPath, &takenAt)

	// Pre-place an identical file at the expected destination
	destDir := filepath.Join(dstDir, "2021", "06", "15")
	_ = os.MkdirAll(destDir, 0755)
	srcData, _ := os.ReadFile(photoPath)
	_ = os.WriteFile(filepath.Join(destDir, "photo.jpg"), srcData, 0644)

	org := organizer.New(database)
	jobID, err := org.Run(context.Background(), organizer.Request{
		DestinationRoot: dstDir,
		FolderFormat:    "YYYY/MM/DD",
		DryRun:          false,
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}

	job := waitForJob(t, database, jobID)
	if job.CopiedFiles != 0 {
		t.Errorf("expected 0 copied, got %d", job.CopiedFiles)
	}
	if job.SkippedFiles != 1 {
		t.Errorf("expected 1 skipped, got %d", job.SkippedFiles)
	}

	results, _ := database.ListOrganizeResults(jobID)
	if len(results) == 0 || results[0].Action != db.ActionSkipExists {
		t.Errorf("expected skip_exists action")
	}
}

func TestOrganizer_SkipsDuplicateNonKept(t *testing.T) {
	srcDir := t.TempDir()
	dstDir := t.TempDir()
	database := openTestDB(t)

	photo1 := filepath.Join(srcDir, "dup1.jpg")
	photo2 := filepath.Join(srcDir, "dup2.jpg")
	makeJPEG(t, photo1)
	makeJPEG(t, photo2)

	takenAt := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)

	// Make photo2 larger so it gets picked as "kept"
	_ = os.WriteFile(photo2, append([]byte("padding"), func() []byte {
		data, _ := os.ReadFile(photo2)
		return data
	}()...), 0644)

	id1 := insertPhoto(t, database, photo1, &takenAt)
	id2 := insertPhoto(t, database, photo2, &takenAt)

	// Create a duplicate group manually
	groupID, _ := database.CreateDuplicateGroup(db.DupReasonHash)
	_ = database.AssignDuplicateGroup(id1, groupID, false) // not kept
	_ = database.AssignDuplicateGroup(id2, groupID, true)  // kept
	_ = database.SetPhotoKept(id2)

	org := organizer.New(database)
	jobID, err := org.Run(context.Background(), organizer.Request{
		DestinationRoot: dstDir,
		FolderFormat:    "YYYY/MM/DD",
		DryRun:          false,
	})
	if err != nil {
		t.Fatalf("Run: %v", err)
	}

	job := waitForJob(t, database, jobID)

	// Only 1 file should be copied (the kept one); the other is skipped
	if job.CopiedFiles != 1 {
		t.Errorf("expected 1 copied file, got %d", job.CopiedFiles)
	}
	if job.SkippedFiles != 1 {
		t.Errorf("expected 1 skipped file (duplicate), got %d", job.SkippedFiles)
	}
}

func waitForJob(t *testing.T, database *db.DB, jobID int64) *db.OrganizeJob {
	t.Helper()
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		job, err := database.GetOrganizeJob(jobID)
		if err != nil {
			t.Fatalf("GetOrganizeJob: %v", err)
		}
		if job.Status != db.JobRunning {
			return job
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatal("job did not complete within timeout")
	return nil
}
