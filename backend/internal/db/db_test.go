package db_test

import (
	"path/filepath"
	"testing"
	"time"

	"photosorter/internal/db"
)

func openDB(t *testing.T) *db.DB {
	t.Helper()
	database, err := db.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("db.Open: %v", err)
	}
	t.Cleanup(func() { database.Close() })
	return database
}

func TestUpsertAndGetPhoto(t *testing.T) {
	database := openDB(t)
	takenAt := time.Date(2023, 7, 4, 12, 0, 0, 0, time.UTC)

	p := &db.Photo{
		Path:        "/photos/IMG_001.jpg",
		Hash:        "abc123",
		FileSize:    1024,
		Width:       4000,
		Height:      3000,
		TakenAt:     &takenAt,
		CameraMake:  "Canon",
		CameraModel: "EOS R5",
		Status:      db.StatusNew,
		ScannedAt:   time.Now(),
	}

	id, err := database.UpsertPhoto(p)
	if err != nil {
		t.Fatalf("UpsertPhoto: %v", err)
	}
	if id == 0 {
		t.Error("expected non-zero ID")
	}

	got, err := database.GetPhoto(id)
	if err != nil {
		t.Fatalf("GetPhoto: %v", err)
	}
	if got.Path != p.Path {
		t.Errorf("path: got %s, want %s", got.Path, p.Path)
	}
	if got.Hash != p.Hash {
		t.Errorf("hash: got %s, want %s", got.Hash, p.Hash)
	}
	if got.CameraModel != p.CameraModel {
		t.Errorf("camera_model: got %s, want %s", got.CameraModel, p.CameraModel)
	}
	if got.TakenAt == nil || !got.TakenAt.Equal(takenAt) {
		t.Errorf("taken_at: got %v, want %v", got.TakenAt, takenAt)
	}
}

func TestUpsertPhoto_Idempotent(t *testing.T) {
	database := openDB(t)

	p := &db.Photo{
		Path:      "/photos/same.jpg",
		Hash:      "hash1",
		FileSize:  500,
		Status:    db.StatusNew,
		ScannedAt: time.Now(),
	}
	id1, err := database.UpsertPhoto(p)
	if err != nil {
		t.Fatal(err)
	}

	// Update hash and upsert again
	p.Hash = "hash2"
	id2, err := database.UpsertPhoto(p)
	if err != nil {
		t.Fatal(err)
	}

	if id1 != id2 {
		t.Errorf("upsert should return same ID: got %d and %d", id1, id2)
	}

	// Hash should be updated
	got, _ := database.GetPhoto(id1)
	if got.Hash != "hash2" {
		t.Errorf("expected updated hash, got %s", got.Hash)
	}
}

func TestListPhotos_Filter(t *testing.T) {
	database := openDB(t)

	early := time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)
	late := time.Date(2023, 1, 1, 0, 0, 0, 0, time.UTC)

	for i, p := range []*db.Photo{
		{Path: "/a.jpg", Hash: "h1", Status: db.StatusNew, ScannedAt: time.Now(), TakenAt: &early},
		{Path: "/b.jpg", Hash: "h2", Status: db.StatusCopied, ScannedAt: time.Now(), TakenAt: &late},
		{Path: "/c.jpg", Hash: "h3", Status: db.StatusNew, ScannedAt: time.Now(), TakenAt: &late},
	} {
		if _, err := database.UpsertPhoto(p); err != nil {
			t.Fatalf("upsert %d: %v", i, err)
		}
	}

	// Filter by status
	photos, total, err := database.ListPhotos(db.PhotoFilter{Status: db.StatusNew, Limit: 50})
	if err != nil {
		t.Fatal(err)
	}
	if total != 2 {
		t.Errorf("expected 2 'new' photos, got %d", total)
	}
	_ = photos

	// Filter by date
	from := time.Date(2022, 1, 1, 0, 0, 0, 0, time.UTC)
	photos, total, err = database.ListPhotos(db.PhotoFilter{DateFrom: &from, Limit: 50})
	if err != nil {
		t.Fatal(err)
	}
	if total != 2 {
		t.Errorf("expected 2 photos after 2022-01-01, got %d", total)
	}
}

func TestDuplicateGroups(t *testing.T) {
	database := openDB(t)

	id1, _ := database.UpsertPhoto(&db.Photo{
		Path: "/dup1.jpg", Hash: "same", FileSize: 100, Status: db.StatusNew, ScannedAt: time.Now(),
	})
	id2, _ := database.UpsertPhoto(&db.Photo{
		Path: "/dup2.jpg", Hash: "same", FileSize: 200, Status: db.StatusNew, ScannedAt: time.Now(),
	})

	groupID, err := database.CreateDuplicateGroup(db.DupReasonHash)
	if err != nil {
		t.Fatalf("CreateDuplicateGroup: %v", err)
	}

	_ = database.AssignDuplicateGroup(id1, groupID, false)
	_ = database.AssignDuplicateGroup(id2, groupID, true)
	if err := database.SetPhotoKept(id2); err != nil {
		t.Fatalf("SetPhotoKept: %v", err)
	}

	groups, err := database.ListDuplicateGroups()
	if err != nil {
		t.Fatalf("ListDuplicateGroups: %v", err)
	}
	if len(groups) != 1 {
		t.Fatalf("expected 1 group, got %d", len(groups))
	}
	g := groups[0]
	if g.KeptPhotoID == nil || *g.KeptPhotoID != id2 {
		t.Errorf("expected kept photo ID %d, got %v", id2, g.KeptPhotoID)
	}
	if len(g.Photos) != 2 {
		t.Errorf("expected 2 photos in group, got %d", len(g.Photos))
	}
}

func TestScanRun(t *testing.T) {
	database := openDB(t)

	id, err := database.CreateScanRun("/photos/drive1")
	if err != nil {
		t.Fatalf("CreateScanRun: %v", err)
	}
	if id == 0 {
		t.Error("expected non-zero scan run ID")
	}

	run, err := database.GetScanRun(id)
	if err != nil {
		t.Fatalf("GetScanRun: %v", err)
	}
	if run.Status != db.ScanRunning {
		t.Errorf("expected status running, got %s", run.Status)
	}

	if err := database.FinishScanRun(id, db.ScanCompleted, 42, 3); err != nil {
		t.Fatalf("FinishScanRun: %v", err)
	}

	run, _ = database.GetScanRun(id)
	if run.Status != db.ScanCompleted {
		t.Errorf("expected status completed, got %s", run.Status)
	}
	if run.PhotosFound != 42 {
		t.Errorf("expected 42 photos, got %d", run.PhotosFound)
	}
	if run.FinishedAt == nil {
		t.Error("expected finished_at to be set")
	}
}
