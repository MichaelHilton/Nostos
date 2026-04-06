package api_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"photosorter/internal/api"
	"photosorter/internal/db"
)

// openDB creates a temporary SQLite database for testing.
func openDB(t *testing.T) *db.DB {
	t.Helper()
	database, err := db.Open(filepath.Join(t.TempDir(), "test.db"))
	if err != nil {
		t.Fatalf("db.Open: %v", err)
	}
	t.Cleanup(func() { database.Close() })
	return database
}

func newTestServer(t *testing.T) (*db.DB, http.Handler) {
	t.Helper()
	database := openDB(t)
	handler := api.NewRouter(database, t.TempDir())
	return database, handler
}

func doJSON(t *testing.T, handler http.Handler, method, path string, body any) *httptest.ResponseRecorder {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		_ = json.NewEncoder(&buf).Encode(body)
	}
	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	return rr
}

func idPath(base string, id int64) string {
	return fmt.Sprintf("%s/%d", base, id)
}

// ---- /api/scan --------------------------------------------------------------

func TestHandleListScans_Empty(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodGet, "/api/scan", nil)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestHandleStartScan_MissingRootPath(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodPost, "/api/scan", map[string]string{})
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rr.Code)
	}
}

func TestHandleStartScan_InvalidDirectory(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodPost, "/api/scan", map[string]string{
		"root_path": "/nonexistent/path/that/does/not/exist",
	})
	// Scanner validates path; may be 400 or 202 depending on async vs sync validation
	if rr.Code != http.StatusBadRequest && rr.Code != http.StatusAccepted {
		t.Fatalf("expected 400 or 202, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestHandleGetScan_NotFound(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodGet, "/api/scan/9999", nil)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rr.Code)
	}
}

func TestHandleGetScan_InvalidID(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodGet, "/api/scan/notanid", nil)
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rr.Code)
	}
}

// ---- /api/photos ------------------------------------------------------------

func TestHandleListPhotos_Empty(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodGet, "/api/photos", nil)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp map[string]any
	if err := json.NewDecoder(rr.Body).Decode(&resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if v, ok := resp["total"]; !ok || v.(float64) != 0 {
		t.Errorf("expected total=0, got %v", resp["total"])
	}
}

func TestHandleListPhotos_WithFilters(t *testing.T) {
	database, handler := newTestServer(t)

	takenAt := time.Date(2024, 3, 15, 10, 0, 0, 0, time.UTC)
	_, err := database.UpsertPhoto(&db.Photo{
		Path:        "/photos/test.jpg",
		Hash:        "abc123",
		FileSize:    2048,
		CameraModel: "Canon EOS R5",
		TakenAt:     &takenAt,
		Status:      db.StatusNew,
		ScannedAt:   time.Now(),
	})
	if err != nil {
		t.Fatalf("UpsertPhoto: %v", err)
	}

	rr := doJSON(t, handler, http.MethodGet, "/api/photos?status=new&limit=10", nil)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp map[string]any
	json.NewDecoder(rr.Body).Decode(&resp)
	if resp["total"].(float64) != 1 {
		t.Errorf("expected total=1, got %v", resp["total"])
	}
}

func TestHandleGetPhoto_NotFound(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodGet, "/api/photos/9999", nil)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rr.Code)
	}
}

func TestHandleGetPhoto_OK(t *testing.T) {
	database, handler := newTestServer(t)

	id, _ := database.UpsertPhoto(&db.Photo{
		Path:      "/photos/img.jpg",
		Hash:      "deadbeef",
		FileSize:  1000,
		Status:    db.StatusNew,
		ScannedAt: time.Now(),
	})

	rr := doJSON(t, handler, http.MethodGet, idPath("/api/photos", id), nil)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}

// ---- /api/thumbnails --------------------------------------------------------

func TestHandleThumbnail_NotFound(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodGet, "/api/thumbnails/9999", nil)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rr.Code)
	}
}

func TestHandleThumbnail_InvalidID(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodGet, "/api/thumbnails/notanid", nil)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rr.Code)
	}
}

// ---- /api/duplicates --------------------------------------------------------

func TestHandleListDuplicates_Empty(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodGet, "/api/duplicates", nil)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}
}

func TestHandleResolveDuplicate_MissingKeptID(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodPost, "/api/duplicates/1/resolve", map[string]any{})
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d", rr.Code)
	}
}

func TestHandleResolveDuplicate_OK(t *testing.T) {
	database, handler := newTestServer(t)

	id1, _ := database.UpsertPhoto(&db.Photo{Path: "/d1.jpg", Hash: "hh", FileSize: 100, Status: db.StatusNew, ScannedAt: time.Now()})
	id2, _ := database.UpsertPhoto(&db.Photo{Path: "/d2.jpg", Hash: "hh", FileSize: 200, Status: db.StatusNew, ScannedAt: time.Now()})
	groupID, _ := database.CreateDuplicateGroup(db.DupReasonHash)
	_ = database.AssignDuplicateGroup(id1, groupID, false)
	_ = database.AssignDuplicateGroup(id2, groupID, true)

	rr := doJSON(t, handler, http.MethodPost, idPath("/api/duplicates", groupID)+"/resolve",
		map[string]any{"kept_photo_id": id2})
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}

// ---- /api/organize ----------------------------------------------------------

func TestHandleStartOrganize_MissingDest(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodPost, "/api/organize", map[string]any{
		"dry_run": true,
	})
	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestHandleStartOrganize_DryRun(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodPost, "/api/organize", map[string]any{
		"destination_root": t.TempDir(),
		"folder_format":    "YYYY/MM",
		"dry_run":          true,
	})
	if rr.Code != http.StatusAccepted {
		t.Fatalf("expected 202, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp map[string]any
	json.NewDecoder(rr.Body).Decode(&resp)
	if resp["job_id"] == nil {
		t.Error("expected job_id in response")
	}
}

func TestHandleGetOrganize_NotFound(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodGet, "/api/organize/9999", nil)
	if rr.Code != http.StatusNotFound {
		t.Fatalf("expected 404, got %d", rr.Code)
	}
}

func TestHandleGetOrganize_AfterCreate(t *testing.T) {
	_, handler := newTestServer(t)

	createRR := doJSON(t, handler, http.MethodPost, "/api/organize", map[string]any{
		"destination_root": t.TempDir(),
		"dry_run":          true,
	})
	if createRR.Code != http.StatusAccepted {
		t.Fatalf("create: expected 202, got %d", createRR.Code)
	}
	var createResp map[string]any
	json.NewDecoder(createRR.Body).Decode(&createResp)
	jobID := int64(createResp["job_id"].(float64))

	rr := doJSON(t, handler, http.MethodGet, idPath("/api/organize", jobID), nil)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp map[string]any
	json.NewDecoder(rr.Body).Decode(&resp)
	if resp["job"] == nil {
		t.Error("expected 'job' key in response")
	}
}

// ---- CORS -------------------------------------------------------------------

func TestCORSPreflight(t *testing.T) {
	_, handler := newTestServer(t)
	req := httptest.NewRequest(http.MethodOptions, "/api/photos", nil)
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("expected 204 for preflight, got %d", rr.Code)
	}
	if rr.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Error("expected CORS Access-Control-Allow-Origin: * header")
	}
}

func TestCORSHeaderOnRegularRequest(t *testing.T) {
	_, handler := newTestServer(t)
	rr := doJSON(t, handler, http.MethodGet, "/api/photos", nil)
	if rr.Header().Get("Access-Control-Allow-Origin") != "*" {
		t.Error("expected CORS header on regular requests")
	}
}
