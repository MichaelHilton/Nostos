package main

import (
	"embed"
	"log"
	"os"
	"path/filepath"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"

	"photosorter/internal/db"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	home, err := os.UserHomeDir()
	if err != nil {
		home = "."
	}
	dataDir := filepath.Join(home, ".photosorter")
	dbPath := filepath.Join(dataDir, "photosorter.db")
	thumbsDir := filepath.Join(dataDir, "thumbnails")

	for _, d := range []string{dataDir, thumbsDir} {
		if err := os.MkdirAll(d, 0755); err != nil {
			log.Fatalf("create directory %s: %v", d, err)
		}
	}

	database, err := db.Open(dbPath)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	defer database.Close()

	app := NewApp(database, thumbsDir)

	err = wails.Run(&options.App{
		Title:  "Photosorter",
		Width:  1280,
		Height: 800,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		OnStartup: app.startup,
		Bind: []interface{}{
			app,
		},
	})
	if err != nil {
		log.Fatal(err)
	}
}
