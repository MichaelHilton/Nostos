package scanner_test

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
	"photosorter/internal/scanner"
)

// makeJPEG writes a tiny valid JPEG to path.
func makeJPEG(t *testing.T, path string) {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	img.SetRGBA(0, 0, color.RGBA{R: 255, G: 0, B: 0, A: 255})

	f, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := jpeg.Encode(f, img, nil); err != nil {
		t.Fatal(err)
	}
}

func TestSupportedExtensions(t *testing.T) {
	required := []string{
		".jpg", ".jpeg", ".png", ".heic", ".cr2", ".cr3",
		".nef", ".arw", ".dng", ".raf", ".orf", ".rw2", ".pef",
	}
	for _, ext := range required {
		if !scanner.SupportedExtensions[ext] {
			t.Errorf("extension %s should be supported", ext)
		}
	}
}

func TestScanner_EmptyDirectory(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(t.TempDir(), "test.db")
	thumbsDir := filepath.Join(t.TempDir(), "thumbs")

	database, err := db.Open(dbPath)
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer database.Close()

	s := scanner.New(database, thumbsDir)
	_, err = s.StartScan(context.Background(), dir)
	if err != nil {
		t.Fatalf("StartScan: %v", err)
	}

	// Give the goroutine a moment to finish
	waitForScanRun(t, database, 1)

	photos, total, err := database.ListPhotos(db.PhotoFilter{Limit: 100})
	if err != nil {
		t.Fatal(err)
	}
	if total != 0 || len(photos) != 0 {
		t.Errorf("expected 0 photos in empty dir, got %d", total)
	}
}

func TestScanner_FindsJPEGs(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(t.TempDir(), "test.db")
	thumbsDir := filepath.Join(t.TempDir(), "thumbs")

	// Create 3 JPEG files in nested dirs
	sub := filepath.Join(dir, "2023", "vacation")
	_ = os.MkdirAll(sub, 0755)
	makeJPEG(t, filepath.Join(dir, "photo1.jpg"))
	makeJPEG(t, filepath.Join(dir, "photo2.jpeg"))
	makeJPEG(t, filepath.Join(sub, "photo3.jpg"))
	// Create a non-image file that should be ignored
	_ = os.WriteFile(filepath.Join(dir, "notes.txt"), []byte("ignored"), 0644)

	database, err := db.Open(dbPath)
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer database.Close()

	s := scanner.New(database, thumbsDir)
	_, err = s.StartScan(context.Background(), dir)
	if err != nil {
		t.Fatalf("StartScan: %v", err)
	}

	waitForScanRun(t, database, 3)

	_, total, err := database.ListPhotos(db.PhotoFilter{Limit: 100})
	if err != nil {
		t.Fatal(err)
	}
	if total != 3 {
		t.Errorf("expected 3 photos, got %d", total)
	}
}

func TestScanner_Idempotent(t *testing.T) {
	dir := t.TempDir()
	dbPath := filepath.Join(t.TempDir(), "test.db")
	thumbsDir := filepath.Join(t.TempDir(), "thumbs")

	makeJPEG(t, filepath.Join(dir, "photo1.jpg"))

	database, err := db.Open(dbPath)
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer database.Close()

	s := scanner.New(database, thumbsDir)

	// Scan twice
	for i := range 2 {
		_, err = s.StartScan(context.Background(), dir)
		if err != nil {
			t.Fatalf("StartScan round %d: %v", i+1, err)
		}
		waitForScanRun(t, database, 1)
	}

	// Should still be 1 photo (upsert, not duplicate insert)
	_, total, err := database.ListPhotos(db.PhotoFilter{Limit: 100})
	if err != nil {
		t.Fatal(err)
	}
	if total != 1 {
		t.Errorf("expected 1 photo after 2 scans, got %d", total)
	}
}

// waitForScanRun polls the database until at least minPhotos have been scanned
// or a 10-second timeout is reached.
func waitForScanRun(t *testing.T, database *db.DB, minPhotos int) {
	t.Helper()
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		_, total, _ := database.ListPhotos(db.PhotoFilter{Limit: 100})
		if total >= minPhotos {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Logf("waitForScanRun: timed out waiting for %d photos", minPhotos)
}
