package duplicates

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"time"

	"photosorter/internal/db"
)

// HashFile computes the SHA-256 hash of a file's contents.
func HashFile(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", fmt.Errorf("open: %w", err)
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", fmt.Errorf("hash: %w", err)
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// DetectForScanRun finds duplicates among photos from the given scan run
// and groups them in the database. Returns the number of groups created.
func DetectForScanRun(database *db.DB, scanRunID int64) (int, error) {
	// Load all photos from this scan run
	photos, _, err := database.ListPhotos(db.PhotoFilter{Limit: 1_000_000})
	if err != nil {
		return 0, fmt.Errorf("list photos: %w", err)
	}

	newGroups := 0

	// --- Pass 1: exact hash duplicates ---
	byHash := make(map[string][]db.Photo)
	for _, p := range photos {
		if p.Hash != "" {
			byHash[p.Hash] = append(byHash[p.Hash], p)
		}
	}

	for hash, group := range byHash {
		if len(group) < 2 {
			continue
		}
		// Check if any already have a group assigned
		hasGroup := false
		for _, p := range group {
			if p.DuplicateGroupID != nil {
				hasGroup = true
				break
			}
		}
		if hasGroup {
			continue
		}

		groupID, err := database.CreateDuplicateGroup(db.DupReasonHash)
		if err != nil {
			return newGroups, fmt.Errorf("create dup group (hash %s): %w", hash, err)
		}

		// Pick the kept copy: largest file size wins (best quality proxy)
		keptIdx := pickKept(group)
		for i, p := range group {
			if err := database.AssignDuplicateGroup(p.ID, groupID, i == keptIdx); err != nil {
				return newGroups, fmt.Errorf("assign dup group: %w", err)
			}
		}
		if err := database.SetPhotoKept(group[keptIdx].ID); err != nil {
			return newGroups, fmt.Errorf("set kept: %w", err)
		}
		newGroups++
	}

	// --- Pass 2: EXIF-based near-duplicates (same timestamp + camera model + similar size) ---
	type exifKey struct {
		takenAt     string
		cameraModel string
	}
	byExif := make(map[exifKey][]db.Photo)
	for _, p := range photos {
		if p.DuplicateGroupID != nil {
			continue // already grouped
		}
		if p.TakenAt == nil || p.CameraModel == "" {
			continue
		}
		key := exifKey{
			takenAt:     p.TakenAt.UTC().Format(time.RFC3339),
			cameraModel: p.CameraModel,
		}
		byExif[key] = append(byExif[key], p)
	}

	for _, group := range byExif {
		if len(group) < 2 {
			continue
		}
		groupID, err := database.CreateDuplicateGroup(db.DupReasonExif)
		if err != nil {
			return newGroups, fmt.Errorf("create exif dup group: %w", err)
		}
		keptIdx := pickKept(group)
		for i, p := range group {
			if err := database.AssignDuplicateGroup(p.ID, groupID, i == keptIdx); err != nil {
				return newGroups, fmt.Errorf("assign exif dup group: %w", err)
			}
		}
		if err := database.SetPhotoKept(group[keptIdx].ID); err != nil {
			return newGroups, fmt.Errorf("set exif kept: %w", err)
		}
		newGroups++
	}

	return newGroups, nil
}

// pickKept returns the index of the photo to keep from a group.
// Strategy: largest file size (best quality proxy); ties broken by first seen.
func pickKept(photos []db.Photo) int {
	best := 0
	for i, p := range photos {
		if p.FileSize > photos[best].FileSize {
			best = i
		}
	}
	return best
}
