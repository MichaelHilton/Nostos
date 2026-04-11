# Nostos

A native macOS app for scanning, deduplicating, and organising your photo library. Built with SwiftUI and backed by a local SQLite database — no server, no cloud, no subscriptions.

## Features

- **Scan** — Recursively walks any directory and indexes photos (JPEG, PNG, HEIC, HEIF, TIFF, and 9 RAW formats including CR2, CR3, NEF, ARW, DNG, RAF, ORF, RW2, PEF).
- **EXIF extraction** — Reads date taken, camera make/model, GPS coordinates, and image dimensions via `ImageIO` / `CoreGraphics` — no third-party tools required.
- **Duplicate detection** — Groups exact duplicates by SHA-256 hash and near-duplicates by EXIF timestamp + camera model. Marks one photo as "kept" per group automatically.
- **Thumbnail generation** — Creates 300 × 300 cached JPEG thumbnails per photo, stored inside the vault alongside the database.
- **Gallery** — Browse all indexed photos with filters for status, camera model, year, and duplicate groups.
- **Vault / Organizer** — Copies photos into a configurable date-based folder structure. Supports dry-run mode and detects rename conflicts.
- **Vault workflow** — The app stores its database and thumbnails in a hidden `.nostos/` folder inside whichever directory you choose as your vault root.

## Requirements

| Tool        | Version  |
| ----------- | -------- |
| macOS       | 12+      |
| Xcode       | 14+      |
| Swift       | 5.7+     |

No external tools or dependencies are required at runtime. EXIF reading uses Apple's `ImageIO` framework and thumbnail generation uses `CoreGraphics`.

## Getting started

1. Clone the repo and open `Nostos.xcodeproj` (or `Package.swift`) in Xcode.
2. Build and run the `Nostos` scheme (`⌘R`).
3. On first launch you will be prompted to choose a **vault root** — the folder that contains (or will contain) your photo library. The app creates a hidden `.nostos/` directory there to store its database and thumbnail cache.
4. Use the **Scanner** tab to index photos, then explore them in **Gallery**, resolve duplicates in **Duplicates**, and copy/organise them via the **Vault** tab.

## Project structure

```
Nostos/
├── NostosApp.swift          Entry point (@main); handles vault-root selection
├── AppState.swift           @MainActor observable store — owns all published state
├── Database/
│   └── AppDatabase.swift    GRDB DatabasePool wrapper + WAL-mode migrations
├── Models/
│   ├── Photo.swift          Photo record + PhotoFilter + PhotoStatus
│   ├── DuplicateGroup.swift DuplicateGroup + DuplicateGroupWithPhotos
│   ├── OrganizeJob.swift    OrganizeJob + OrganizeResult + OrganizeAction
│   └── ScanRun.swift        ScanRun record + ScanProgress
├── Services/
│   ├── Scanner.swift        Concurrent directory walker (CryptoKit SHA-256)
│   ├── EXIFReader.swift     ImageIO/CoreGraphics metadata extraction
│   ├── DuplicateDetector.swift  Hash-based + EXIF-based duplicate grouping
│   ├── Organizer.swift      Date-folder copy engine with conflict handling
│   └── ThumbnailService.swift   300×300 JPEG thumbnail generator + disk cache
└── Views/
    ├── ContentView.swift    NavigationSplitView sidebar + tab routing
    ├── ScannerView.swift    Scan progress UI
    ├── GalleryView.swift    Photo grid with filters
    ├── DuplicatesView.swift Duplicate group resolution UI
    └── OrganizerView.swift  (VaultView) Copy-job configuration + results
Tests/
├── NostosTests/             Unit + integration tests (Swift Testing / XCTest)
└── NostosUITests/           UI tests (XCUITest)
```

## Dependencies

| Package       | Source                              | Used for                       |
| ------------- | ----------------------------------- | ------------------------------ |
| GRDB.swift 6  | github.com/groue/GRDB.swift         | SQLite ORM + migrations        |
| ViewInspector | github.com/nalexn/ViewInspector     | SwiftUI view testing           |

## Data storage

All app data lives inside the vault root you choose:

```
<vault root>/
└── .nostos/
    ├── nostos.db        SQLite database (WAL mode)
    └── thumbnails/
        └── <id>.jpg     300×300 JPEG per photo
```

If no vault root is configured (e.g. during unit tests), the database falls back to `~/Library/Application Support/Nostos/`.

## Running tests

### In Xcode

Press `⌘U` or use **Product → Test**.

### From the command line

```bash
swift test
```

### With HTML coverage report

```bash
./Nostos/scripts/test-with-coverage.sh
# Opens coverage/index.html
```

The script runs `swift test --enable-code-coverage`, uses `llvm-cov` to produce an LCOV report, and renders it as HTML via `genhtml`.

## Supported file formats

JPEG · PNG · HEIC · HEIF · TIFF — Canon CR2/CR3 — Nikon NEF — Sony ARW — Adobe DNG — Fujifilm RAF — Olympus ORF — Panasonic RW2 — Pentax PEF
