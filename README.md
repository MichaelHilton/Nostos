# PhotoSorter

A self-hosted photo management tool that scans, deduplicates, and organises your photo library.

## Features

- **Scan** — Recursively walks any directory and indexes photos (JPEG, PNG, HEIC, TIFF and 12 RAW formats).
- **Metadata extraction** — Reads EXIF data (date taken, camera make/model, GPS) via a native Go parser with an `exiftool` fallback for RAW files.
- **Duplicate detection** — Groups identical photos by SHA-256 hash and near-duplicates by EXIF timestamp + camera model.
- **Thumbnail generation** — Creates 300 × 300 cached thumbnails; uses embedded JPEG previews for RAW files.
- **Gallery** — Browse photos with filters for status, camera model, date range, and duplicates.
- **Organizer** — Copies photos into a date-based folder structure (`YYYY/MM/DD` or custom). Supports dry-run mode.
- **Dark-mode UI** — Svelte single-page app with a sidebar for Scanner, Gallery, Duplicates, and Organizer views.

## Architecture

```
PhotoSorter
├── backend/          Go 1.23 HTTP API + SQLite database
│   ├── cmd/server/   Entry-point (CLI flags)
│   └── internal/
│       ├── api/      REST handlers & router
│       ├── db/       SQLite schema, models, CRUD
│       ├── scanner/  Concurrent directory walker
│       ├── duplicates/ Hash + EXIF dedup engine
│       ├── organizer/  Date-folder copy jobs
│       ├── exif/     Metadata reader
│       └── thumbnails/ Thumbnail generator
└── frontend/         Svelte + Vite SPA
    └── src/
        ├── routes/   Scanner, Gallery, Duplicates, Organizer
        └── lib/      api.js, PhotoCard, PhotoGrid
```

## Prerequisites

| Tool     | Version                              |
| -------- | ------------------------------------ |
| Go       | 1.23+                                |
| Node.js  | 20+                                  |
| exiftool | any (optional, improves RAW support) |

Install `exiftool` on macOS: `brew install exiftool`  
Install `exiftool` on Debian/Ubuntu: `sudo apt install libimage-exiftool-perl`

## Running locally

### Backend

```bash
cd backend
go run ./cmd/server             # listens on :8080 by default
# Options:
#   --port   8080
#   --db     ~/.photosorter/photosorter.db
#   --thumbs ~/.photosorter/thumbnails
```

### Frontend (dev)

```bash
cd frontend
npm install
npm run dev                     # Vite dev server on :5173, proxies /api → :8080
```

Open http://localhost:5173 in your browser.

### Frontend (production build)

```bash
cd frontend
npm run build                   # output in frontend/dist/
```

Serve `dist/` with any static file server or embed it behind the Go binary.

## API Reference

| Method | Path                           | Description                                                                                                  |
| ------ | ------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| `POST` | `/api/scan`                    | Start a directory scan (`{"root_path": "..."}`)                                                              |
| `GET`  | `/api/scan`                    | List all scan runs                                                                                           |
| `GET`  | `/api/scan/{id}`               | Get scan run status                                                                                          |
| `GET`  | `/api/photos`                  | List photos (filters: `status`, `camera_model`, `date_from`, `date_to`, `has_duplicates`, `limit`, `offset`) |
| `GET`  | `/api/photos/{id}`             | Get single photo                                                                                             |
| `GET`  | `/api/thumbnails/{id}`         | Serve thumbnail JPEG                                                                                         |
| `GET`  | `/api/duplicates`              | List duplicate groups                                                                                        |
| `POST` | `/api/duplicates/{id}/resolve` | Mark a photo as kept (`{"kept_photo_id": N}`)                                                                |
| `POST` | `/api/organize`                | Start organize job (`destination_root`, `folder_format`, `dry_run`, `source_photo_ids`)                      |
| `GET`  | `/api/organize/{id}`           | Get organize job status + results                                                                            |

## Docker

### Build & run with Docker Compose

```bash
# Mount your photo library at ./photos (read-only)
PHOTO_LIBRARY=/path/to/your/photos docker compose up --build
```

The app is available at http://localhost:8080.

Data (database + thumbnails) is persisted in a Docker volume (`photosorter_data`).

### Build the image manually

```bash
docker build -t photosorter .
docker run -p 8080:8080 \
  -v photosorter_data:/data \
  -v /path/to/photos:/photos:ro \
  photosorter
```

## Running tests

```bash
cd backend
go test ./...
```

All 7 packages have test coverage: `db`, `duplicates`, `organizer`, `scanner`, `api`, `exif`, `thumbnails`.

## Configuration

All configuration is via CLI flags (backend):

| Flag       | Default                         | Description               |
| ---------- | ------------------------------- | ------------------------- |
| `--port`   | `8080`                          | HTTP listen port          |
| `--db`     | `~/.photosorter/photosorter.db` | SQLite database path      |
| `--thumbs` | `~/.photosorter/thumbnails`     | Thumbnail cache directory |

## Supported file formats

JPEG, PNG, HEIC, TIFF — Canon CR2/CR3 — Nikon NEF — Sony ARW — Adobe DNG — Fujifilm RAF — Olympus ORF — Panasonic RW2 — Pentax PEF
