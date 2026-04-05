package api

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"photosorter/internal/db"
	"photosorter/internal/organizer"
	"photosorter/internal/scanner"
)

// Handler holds shared dependencies for all HTTP handlers.
type Handler struct {
	DB        *db.DB
	ThumbsDir string
}

func newHandler(database *db.DB, thumbsDir string) *Handler {
	return &Handler{
		DB:        database,
		ThumbsDir: thumbsDir,
	}
}

// respond writes JSON to the response writer.
func respond(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func respondError(w http.ResponseWriter, status int, msg string) {
	respond(w, status, map[string]string{"error": msg})
}

func parseID(r *http.Request) (int64, error) {
	return strconv.ParseInt(r.PathValue("id"), 10, 64)
}

// ---- /api/scan --------------------------------------------------------------

type scanRequest struct {
	RootPath string `json:"root_path"`
}

func (h *Handler) handleStartScan(w http.ResponseWriter, r *http.Request) {
	var req scanRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.RootPath == "" {
		respondError(w, http.StatusBadRequest, "root_path is required")
		return
	}

	s := scanner.New(h.DB, h.ThumbsDir)
	// Use a long-lived background context; scans self-terminate on completion.
	runID, err := s.StartScan(context.Background(), req.RootPath)
	if err != nil {
		respondError(w, http.StatusBadRequest, err.Error())
		return
	}

	respond(w, http.StatusAccepted, map[string]any{
		"scan_run_id": runID,
		"status":      "running",
	})
}

func (h *Handler) handleGetScan(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid id")
		return
	}
	run, err := h.DB.GetScanRun(id)
	if err != nil {
		respondError(w, http.StatusNotFound, "scan run not found")
		return
	}
	respond(w, http.StatusOK, run)
}

func (h *Handler) handleListScans(w http.ResponseWriter, r *http.Request) {
	runs, err := h.DB.ListScanRuns()
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}
	respond(w, http.StatusOK, runs)
}

// ---- /api/photos ------------------------------------------------------------

func (h *Handler) handleListPhotos(w http.ResponseWriter, r *http.Request) {
	q := r.URL.Query()

	filter := db.PhotoFilter{
		Status:      q.Get("status"),
		CameraModel: q.Get("camera_model"),
	}
	if lim := q.Get("limit"); lim != "" {
		filter.Limit, _ = strconv.Atoi(lim)
	}
	if off := q.Get("offset"); off != "" {
		filter.Offset, _ = strconv.Atoi(off)
	}
	if from := q.Get("date_from"); from != "" {
		if t, err := time.Parse("2006-01-02", from); err == nil {
			filter.DateFrom = &t
		}
	}
	if to := q.Get("date_to"); to != "" {
		if t, err := time.Parse("2006-01-02", to); err == nil {
			filter.DateTo = &t
		}
	}
	if dups := q.Get("has_duplicates"); dups != "" {
		v := dups == "true"
		filter.HasDuplicates = &v
	}

	photos, total, err := h.DB.ListPhotos(filter)
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}
	respond(w, http.StatusOK, map[string]any{
		"photos": photos,
		"total":  total,
		"offset": filter.Offset,
		"limit":  filter.Limit,
	})
}

func (h *Handler) handleGetPhoto(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid id")
		return
	}
	p, err := h.DB.GetPhoto(id)
	if err != nil || p == nil {
		respondError(w, http.StatusNotFound, "photo not found")
		return
	}
	respond(w, http.StatusOK, p)
}

// ---- /api/thumbnails/:id ----------------------------------------------------

func (h *Handler) handleThumbnail(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	p, err := h.DB.GetPhoto(id)
	if err != nil || p == nil || p.ThumbnailPath == "" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Cache-Control", "public, max-age=86400")
	http.ServeFile(w, r, p.ThumbnailPath)
}

// ---- /api/duplicates --------------------------------------------------------

func (h *Handler) handleListDuplicates(w http.ResponseWriter, r *http.Request) {
	groups, err := h.DB.ListDuplicateGroups()
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}
	respond(w, http.StatusOK, groups)
}

type resolveRequest struct {
	KeptPhotoID int64 `json:"kept_photo_id"`
}

func (h *Handler) handleResolveDuplicate(w http.ResponseWriter, r *http.Request) {
	var req resolveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.KeptPhotoID == 0 {
		respondError(w, http.StatusBadRequest, "kept_photo_id is required")
		return
	}
	if err := h.DB.SetPhotoKept(req.KeptPhotoID); err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}
	respond(w, http.StatusOK, map[string]string{"status": "ok"})
}

// ---- /api/organize ----------------------------------------------------------

type organizeRequest struct {
	SourcePhotoIDs  []int64 `json:"source_photo_ids"`
	DestinationRoot string  `json:"destination_root"`
	FolderFormat    string  `json:"folder_format"`
	DryRun          bool    `json:"dry_run"`
}

func (h *Handler) handleStartOrganize(w http.ResponseWriter, r *http.Request) {
	var req organizeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.DestinationRoot == "" {
		respondError(w, http.StatusBadRequest, "destination_root is required")
		return
	}
	if req.FolderFormat == "" {
		req.FolderFormat = "YYYY/MM/DD"
	}

	org := organizer.New(h.DB)
	jobID, err := org.Run(context.Background(), organizer.Request{
		SourcePhotoIDs:  req.SourcePhotoIDs,
		DestinationRoot: req.DestinationRoot,
		FolderFormat:    req.FolderFormat,
		DryRun:          req.DryRun,
	})
	if err != nil {
		respondError(w, http.StatusInternalServerError, err.Error())
		return
	}
	respond(w, http.StatusAccepted, map[string]any{
		"job_id": jobID,
		"status": "running",
	})
}

func (h *Handler) handleGetOrganize(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		respondError(w, http.StatusBadRequest, "invalid id")
		return
	}
	job, err := h.DB.GetOrganizeJob(id)
	if err != nil {
		respondError(w, http.StatusNotFound, "job not found")
		return
	}
	results, _ := h.DB.ListOrganizeResults(id)
	respond(w, http.StatusOK, map[string]any{
		"job":     job,
		"results": results,
	})
}
