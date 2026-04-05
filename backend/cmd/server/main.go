package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"photosorter/internal/api"
	"photosorter/internal/db"
)

func main() {
	home, err := os.UserHomeDir()
	if err != nil {
		home = "."
	}
	defaultData := filepath.Join(home, ".photosorter")

	var (
		port      = flag.Int("port", 8080, "HTTP server port")
		dbPath    = flag.String("db", filepath.Join(defaultData, "photosorter.db"), "SQLite database path")
		thumbsDir = flag.String("thumbs", filepath.Join(defaultData, "thumbnails"), "Thumbnail cache directory")
	)
	flag.Parse()

	// Ensure data directories exist
	for _, dir := range []string{filepath.Dir(*dbPath), *thumbsDir} {
		if err := os.MkdirAll(dir, 0755); err != nil {
			log.Fatalf("create directory %s: %v", dir, err)
		}
	}

	database, err := db.Open(*dbPath)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	defer database.Close()

	router := api.NewRouter(database, *thumbsDir)

	addr := fmt.Sprintf(":%d", *port)
	log.Printf("Photosorter API listening on http://localhost%s", addr)
	log.Printf("Database: %s", *dbPath)
	log.Printf("Thumbnails: %s", *thumbsDir)

	if err := http.ListenAndServe(addr, router); err != nil {
		log.Fatal(err)
	}
}
