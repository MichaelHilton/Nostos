# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Build

```bash
# CLI (from repo root)
swift build

# Xcode (opens the project)
open Nostos.xcodeproj
```

### Test

```bash
# Unit tests (from repo root)
swift test

# Run a single test class or method
swift test --filter AppDatabaseTests
swift test --filter AppDatabaseTests/testInsertAndFetchScanRun

# UI tests (requires Xcode — from repo root)
./Nostos/scripts/test-ui.sh
./Nostos/scripts/test-ui.sh testClicksPrimaryButtonsAcrossTheApp

# Tests with HTML coverage report (output → coverage/index.html)
./Nostos/scripts/test-with-coverage.sh
```

CI runs `swift build -v` and `swift test -v` from the `Nostos/` subdirectory (`working-directory: Nostos` in `.github/workflows/swift.yml`).

## Architecture

Nostos is a SwiftUI/macOS app with a strict three-layer architecture:

```
NostosApp (entry point)
  └── AppState (@MainActor ObservableObject — single source of truth)
        ├── AppDatabase (GRDB DatabasePool wrapper, WAL mode)
        ├── Services (Scanner, DuplicateDetector, Organizer, BackupService, EXIFReader, ThumbnailService)
        └── Views (SwiftUI — receive AppState via @EnvironmentObject)
```

### AppState (`Nostos/AppState.swift`)

The single `@MainActor ObservableObject` that owns all published UI state. Views never call services directly — they call `AppState` methods, which spawn `Task` blocks that call services and then reload state via `loadInitialData()` or targeted `load*()` methods. All five tabs (Scanner, Gallery, Duplicates, Vault, Backup) read from `AppState`.

### AppDatabase (`Nostos/Database/AppDatabase.swift`)

Thin GRDB `DatabasePool` wrapper with three registered migrations (v1: core tables, v2: index, v3: backup tables). All queries are plain GRDB `QueryInterfaceRequest` calls or raw SQL; there is no repository layer. Tests use `AppDatabase.makeInMemory()` which creates an in-memory `DatabaseQueue` and runs all migrations.

Vault root drives the database location: `<vault root>/.nostos/nostos.db`. When no vault root is set (unit tests), it falls back to `~/Library/Application Support/Nostos/`.

### Services

| Service | What it does |
|---|---|
| `Scanner` | Concurrent directory walk using `TaskGroup` (bounded by `activeProcessorCount`). Partial SHA-256 hash: first + last 64 KB of each file for speed. |
| `DuplicateDetector` | Two passes: exact-hash groups, then EXIF (takenAt + cameraModel) near-duplicate groups. Runs synchronously after each scan. |
| `Organizer` | Copies photos into a date-based folder structure; supports dry-run mode and detects rename conflicts. |
| `BackupService` | Similar to Organizer but backed by `vault_photos` table for hash-based dedup against the vault. |
| `EXIFReader` | `ImageIO`/`CoreGraphics` only — reads takenAt, camera make/model, GPS, and dimensions. No third-party tools. |
| `ThumbnailService` | Generates 300×300 JPEG thumbnails and caches them at `<vault root>/.nostos/thumbnails/<id>.jpg`. Must be configured with `ThumbnailService.configure(vaultRootURL:)` before use. |

### Models

All models conform to GRDB's `FetchableRecord` + `MutablePersistableRecord`. Swift property names are camelCase; database column names are snake_case via `CodingKeys`. `didInsert(_:)` assigns the autoincrement `id` back to the struct after insert.

Key models: `Photo`, `ScanRun`, `DuplicateGroup`, `OrganizeJob`, `OrganizeResult`, `BackupJob`, `BackupResult`, `VaultPhoto`.

### Views

`ContentView` uses `NavigationSplitView` (macOS 13+) with a custom sidebar of `Button`s switching a `@State var selectedTab: Tab`. Each tab is a dedicated view: `ScannerView`, `GalleryView`, `DuplicatesView`, `OrganizerView` (Vault tab), `BackupView`. All views get `AppState` via `.environmentObject(appState)` set on `ContentView` in `NostosApp`.

Vault setup (`VaultSetupView`) is shown instead of `ContentView` when `vaultRootPath` is empty in `@AppStorage`.

## Testing patterns

Unit tests use `AppDatabase.makeInMemory()` — never a real database file. UI tests communicate with the app via environment variables:

| Env var | Purpose |
|---|---|
| `UI_TESTING_SEED_DATA=1` | Seeds 26 photos + scan run + organize job into the vault |
| `UI_TESTING_FORCE_SETUP=1` | Clears `vaultRootPath` to force vault setup screen |
| `UI_TESTING_VAULT_ROOT` | Sets the vault root path at launch |
| `UI_TESTING_VAULT_DIRECTORY_TO_PICK` | Pre-fills the vault directory picker result |
| `UI_TESTING_SOURCE_DIRECTORY_TO_PICK` | Pre-fills the source directory picker result |

## Database schema

Three migrations define the schema:
- **v1**: `scan_runs`, `duplicate_groups`, `photos`, `organize_jobs`, `organize_results`
- **v2**: Composite index on `photos(taken_at, camera_model)` for EXIF duplicate detection
- **v3**: `backup_jobs`, `vault_photos`, `backup_results`

Backup dedup logic: a photo is a backup candidate only if it has no `duplicate_group_id` or it is the `is_kept = 1` photo in its group.
