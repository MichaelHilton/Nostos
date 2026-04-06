package api

import (
	"net/http"

	"photosorter/internal/db"
)

// NewRouter builds and returns the HTTP mux wired with all routes.
func NewRouter(database *db.DB, thumbsDir string) http.Handler {
	h := newHandler(database, thumbsDir)

	mux := http.NewServeMux()

	// Scan
	mux.HandleFunc("POST /api/scan", h.handleStartScan)
	mux.HandleFunc("GET /api/scan", h.handleListScans)
	mux.HandleFunc("GET /api/scan/{id}", h.handleGetScan)

	// Photos
	mux.HandleFunc("GET /api/photos", h.handleListPhotos)
	mux.HandleFunc("GET /api/photos/{id}", h.handleGetPhoto)

	// Thumbnails
	mux.HandleFunc("GET /api/thumbnails/{id}", h.handleThumbnail)

	// Duplicates
	mux.HandleFunc("GET /api/duplicates", h.handleListDuplicates)
	mux.HandleFunc("POST /api/duplicates/{id}/resolve", h.handleResolveDuplicate)

	// Organize
	mux.HandleFunc("POST /api/organize", h.handleStartOrganize)
	mux.HandleFunc("GET /api/organize/{id}", h.handleGetOrganize)

	return corsMiddleware(mux)
}

// corsMiddleware adds permissive CORS headers for local dev (Vite on :5173).
func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
