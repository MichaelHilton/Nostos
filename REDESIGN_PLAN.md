# Nostos UI Redesign — Implementation Plan

Source design: `Nostos Design System-handoff.zip` → `project/Nostos Redesign v2.html`

---

## What the design changes

### Visual language

The redesign introduces an "Aegean" identity: warm parchment backgrounds, teal accent (`#1B7A8A`), Cormorant Garamond serif for display headings/stat numbers, and decorative touches (Greek meander divider below page titles, a subtle repeating dot pattern behind content, a compass/wave-lens watermark in the sidebar).

### Structural changes (the big ones)

1. **Backup tab is eliminated from the nav.** Backup functionality moves into the Gallery view as a persistent footer bar. The `Tab` enum shrinks from 5 to 4 items: Scanner, Gallery, Duplicates, Vault.
2. **Sidebar is reorganized** into two labeled sections — "Catalogue" (Scanner, Gallery) and "Manage" (Duplicates, Vault) — with a new Wave-Lens logo mark, vault path footer, and a ⌘K hint.
3. **Gallery is restructured**: photos are grouped by month with serif month/year headers; the backup footer bar lives below the grid; the filter panel moves to the right side and gains a vertical year-range slider.
4. **Vault screen gains a statistics dashboard** (format/year/camera breakdowns with mini bar charts) in addition to the existing organize controls.
5. **Scanner screen gains a 4-stat summary row** at the top.
6. **Duplicates screen** switches from a vertical list to an auto-fill card grid.

---

## Color & design tokens

All tokens should be defined once in a `DesignTokens.swift` file as `Color` extensions and `CGFloat` constants.

| Token | Hex | Usage |
|---|---|---|
| `.nostosAccent` | `#1B7A8A` | Primary buttons, active nav, progress bars |
| `.nostosAccentHover` | `#22909F` | Button hover (can be `.nostosAccent.opacity(0.85)`) |
| `.nostosAccentLight` | `#E8F4F6` | Selection halo |
| `.nostosGold` | `#B8892A` | Diamond accents, compass N needle |
| `.nostosGreen` | `#1D8A56` | Success / In Vault status |
| `.nostosOrange` | `#C07828` | Duplicate warning |
| `.nostosRed` | `#C03C3C` | Error / destructive |
| `.nostosBg` | `#F8F6F1` | Window background (warm parchment) |
| `.nostosSidebar` | `#EAE5DC` | Sidebar fill |
| `.nostosSidebarBorder` | `#D8D2C8` | Sidebar divider |
| `.nostosSurface` | `#FFFFFF` | Cards / group boxes |
| `.nostosSurface2` | `#F4F1EA` | Monospace field background |
| `.nostosBorder` | `#DDD8CE` | Card borders |
| `.nostosFg1` | `#1A2E3C` | Primary text |
| `.nostosFg2` | `#5A6E7A` | Secondary text |
| `.nostosFg3` | `#9AAEBB` | Muted/placeholder text |
| `.nostosProgressBg` | `#D8EEF2` | Progress bar track |

**Spacing constants:** 4 / 8 / 12 / 14 / 16 / 20 / 24 / 26 / 32 pt. Page padding is 26pt.

**Corner radii:** 4 (badges) / 6 (tiles, fields, buttons) / 8–9 (cards) / 14 (year slider panel).

---

## Typography

The design uses two families:

- **Display (serif):** Cormorant Garamond — used for page titles (34pt bold), month headers in Gallery (22pt semi-bold), stat numbers (28pt bold). Must be bundled as a font resource since macOS does not ship it.
- **UI body:** System font (SF Pro) — everything else: labels, body copy, table cells, buttons.
- **Monospace:** `Font.system(.caption, design: .monospaced)` — file paths, hash values.

### Bundling Cormorant Garamond

Download the `.ttf` files for weights 400, 600, 700, and 700 Italic from Google Fonts. Add them to the Xcode project under `Nostos/Resources/Fonts/` and register in the `Package.swift` target's `resources` array as `.process("Resources")`. Reference in SwiftUI with `Font.custom("Cormorant Garamond", size: 34).weight(.bold)`.

---

## New shared components (`Nostos/Views/DesignSystem/`)

Create a `DesignSystem/` subdirectory under `Views/` with these files:

### `DesignTokens.swift`
`Color` and `Font` extensions, spacing/radius `CGFloat` constants. No SwiftUI views here, pure values.

### `NostosComponents.swift`
Reusable primitive views:

- **`PageHeaderView(title:, subtitle:, actions:)`** — serif `Text` for title, `Text` for subtitle, `MeanderDivider` below. Actions slot is a trailing `@ViewBuilder` for toolbar buttons.
- **`CardView`** — white surface, `nostosBorder` 1pt border, `cornerRadius(9)`, padding 13×15.
- **`SectionLabel(text:, diamond:)`** — 10pt, 600 weight, uppercase, 0.09em letter-spacing. `diamond: true` prepends a small gold diamond `Shape`.
- **`NostosStatCard(label:, value:, color:)`** — white surface card with uppercase label (10pt) and 28pt serif bold value.
- **`NostosProgressBar(value:, total:)`** — 4pt height, teal fill, `.nostosProgressBg` track, `cornerRadius(2)`.
- **`MeanderDivider`** — a `Canvas`-based repeating Greek key/step pattern, ~7pt tall, teal at 18% opacity. Implement as a tiling `Path` drawn left-to-right.
- **`StarDotBackground`** — a `Canvas` view drawn in a `ZStack` behind content. Repeating 28pt grid of teal circles (0.9pt radius, 16% opacity) with smaller corner dots.
- **`DiamondAccent(size:, color:)`** — a tiny rotated square `Rectangle` used as section bullet.

### `WaveLensLogo.swift`
SwiftUI `Canvas` or `Shape` implementation of the Wave-Lens mark shown in the sidebar header. Key elements:
- Teal rounded-rect background
- White elliptical/wave path (the lens warp curve)
- Two concentric circles (outer ring semi-opaque, inner ring)
- Gold north-needle tick + gold circle at top
- Use exact proportions from the HTML SVG `viewBox="0 0 1 1"` paths.

### `NavIcons.swift`
Custom `Canvas`-based icons for the four nav items (the design uses custom SVG icons, not SF Symbols). Each is a 16×16 pt canvas:
- **Scanner:** magnifying glass + two horizontal scan lines inside
- **Gallery:** 2×2 grid of rounded rectangles + a tiny mountain polyline in bottom-right cell
- **Duplicates:** two overlapping rounded rectangles + two horizontal lines
- **Vault:** circular vault door with spokes, handle bar, two hinge dots

---

## Phase 1 — Design tokens and shared components

**Files to create:**
- `Nostos/Views/DesignSystem/DesignTokens.swift`
- `Nostos/Views/DesignSystem/NostosComponents.swift`
- `Nostos/Views/DesignSystem/WaveLensLogo.swift`
- `Nostos/Views/DesignSystem/NavIcons.swift`
- `Nostos/Resources/Fonts/CormorantGaramond-Regular.ttf` (+ Bold, SemiBold, Italic variants)

**Package.swift change:** Add `.process("Resources")` to the `Nostos` target's `resources` array.

No existing files changed in this phase. All new additions.

---

## Phase 2 — Sidebar and navigation restructure

**File modified:** `Nostos/Views/ContentView.swift`

### Tab enum
Remove `.backup`. `Tab` becomes: `scanner | gallery | duplicates | vault`.

### Sidebar redesign
Replace the current `VStack` of `Button` rows with a fully custom sidebar:

```
Sidebar (196pt wide, nostosSidebar background)
  ├── Header (48pt tall, nostosSidebarBorder bottom)
  │     WaveLensLogo mark (28×28) + "nostos" serif 17pt + "Photo Management" 9pt uppercase
  ├── Nav body (padding 10pt 8pt)
  │     Section label "Catalogue" (9pt, 700, uppercase, nostosFg3)
  │       NavRow for Scanner
  │       NavRow for Gallery
  │     Section label "Manage"
  │       NavRow for Duplicates
  │       NavRow for Vault
  ├── Watermark (absolute, bottom-offset, 148×148, opacity 0.13)
  │     WaveLensLogo watermark variant (teal strokes only, no fill)
  └── Footer (padding 8×14, nostosSidebarBorder top)
        Monospace vault path text (9pt, nostosFg3, truncated)
        ⌘K row (kbd badge + "Command palette" caption)
```

**NavRow state:** Transparent background → `nostosSurface2` on hover → `nostosAccent` fill + white text when active. Use `onHover` modifier. Active rows show the custom nav icon in white; inactive in `nostosFg3`.

### Detail area
Remove `BackupView` from the switch. Keep `VaultView` handling (with vault root change callback).

---

## Phase 3 — Scanner view

**File modified:** `Nostos/Views/ScannerView.swift`

### New layout

```
PageHeaderView(title: "Scanner", subtitle: "Scan a folder to find and catalogue your photos")
MeanderDivider (included in PageHeaderView)

ScrollView {
  StarDotBackground (ZStack layer)

  // Row 1: 4 stat cards
  HStack(4 equal columns, gap 10) {
    NostosStatCard("Total Scanned", value from db.photoCount())
    NostosStatCard("Catalogued",    value same, color: nostosAccent)
    NostosStatCard("Duplicates",    value from duplicateGroups.count, color: nostosOrange)
    NostosStatCard("Last Scan",     value: formatted date of latest scan run, color: nostosGreen)
  }

  // Row 2: Source folder card
  CardView {
    SectionLabel("Source Folder", diamond: true)
    HStack {
      monospace path field (nostosSurface2 bg, nostosBorder, cornerRadius 6)
      Btn("Choose…", variant: .bordered)
    }
  }

  // Row 3: Start button + status
  HStack {
    Btn("▶  Start Scan", variant: .primary) / "↻  Scanning…" while running
    if done: green "✓ Scan complete — N photos found"
  }

  // Row 4: Progress card (shown only when scanning or done)
  if scanning || done {
    CardView {
      SectionLabel("Progress", diamond: true)
      NostosProgressBar(value: processed, total: total)
      HStack(gap 40) {
        Stat("Files Found", total)
        Stat("Processed",   processed, nostosAccent)
        Stat("Duplicates",  duplicates, nostosOrange)
      }
    }
  }

  // Row 5: Recent scans table
  CardView {
    SectionLabel("Recent Scans", diamond: true)
    Table/ForEach of scan runs:
      Path (monospace, 10pt, truncated) | Status (colored) | Photos | Dups | Date
      Row divider: nostosBorderFaint
  }
}
```

**AppState additions needed:** A computed property `lastScanDate: Date?` derived from `scanRuns.first?.finishedAt`.

---

## Phase 4 — Gallery view

**File modified:** `Nostos/Views/GalleryView.swift`

This is the most complex change.

### Layout skeleton

```
HStack {
  // Main column
  VStack(spacing: 0) {
    GalleryToolbar          ← new
    ScrollView {
      StarDotBackground
      ForEach(monthGroups) { group in
        MonthHeader(group.month, group.year, group.count)
        LazyVGrid(columns: adaptive(min: tileSize)) {
          ForEach(group.photos) { PhotoTile(...) }
        }
      }
    }
    if selectedPhoto != nil { SelectedPhotoPanel }
    BackupFooterBar          ← new
  }

  // Filter sidebar (right, 216pt)
  GalleryFilterSidebar
}
```

### Month grouping
Add a helper in `GalleryView` (not `AppState`) that partitions the `photos` array by `(year, month)` derived from `takenAt`, sorted descending. A group with no `takenAt` can be collected into an "Unknown date" bucket at the bottom.

### `GalleryToolbar`
7pt vertical padding, `nostosSurface` background, `nostosBorder` bottom:
- Left: "{N} of {total} photos" (11pt)
- Right: quick-filter chips ("Duplicates", "In Vault") + tile-size slider (80–220pt range) + small/large grid icons

### `PhotoTile`
The tile is a `ZStack` with `cornerRadius(6)` clip:
- Bottom layer: `AsyncImage` / thumbnail (or colored placeholder if not loaded)
- Hover overlay: gradient `linear from transparent to rgba(0,0,0,0.68)`, shows filename + date + camera tail on top
- Top-left badges: "DUP" orange, "IN VAULT" green (with tiny vault icon)
- Top-right selection check: teal circle with white checkmark
- Selection outline: 2.5pt teal `overlay(RoundedRectangle.stroke)`

Use `onHover` for the hover overlay. Selection is a `@State var selectedPhoto`.

### `SelectedPhotoPanel`
Appears between grid and BackupFooterBar when a photo is selected. Horizontal layout: 68×68 thumbnail + metadata grid (Camera, Date, Size, Dims, Status, Format) + "Dismiss" plain button.

### `BackupFooterBar`
Persistent bar at the very bottom of the Gallery column (between photo panel and edge):
- Left: vault icon (custom `NavIcon` for vault) in teal + "{N} photos to back up"
- Center: `NostosProgressBar` + copied count (only while running)
- Right: "Back Up to Vault" primary button / pause/play toggle while running / "✓ Backup complete" when done

The backup logic calls `AppState.startBackup(...)` with `filter: currentGalleryFilter, dryRun: false`.

### `GalleryFilterSidebar` (right side, 216pt)
`VStack` in a `ScrollView`:
- "Backup Status" checkboxes (Not backed up / In Vault / Kept duplicate)
- Divider
- "Camera" checkboxes (one per camera model + "No camera info")
- Divider
- "Duplicates" checkboxes (With duplicates / No duplicates)
- Divider
- "Year Range" vertical slider
- Divider
- "Clear All Filters" danger-style button

### Vertical year-range slider (`YearRangeSlider`)
A custom view using `DragGesture` on two thumb handles:
- Vertical track (2pt width, `nostosProgressBg` fill, teal active fill between thumbs)
- Each row is 28pt tall; years listed as labels to the right of the track
- Selected range rows have `nostosAccent` at 8% opacity background and bold text
- Thumbs are 16×16 white circles with teal 2pt border and a drop shadow
- "Clear" button appears next to the range summary when not showing all years

---

## Phase 5 — Duplicates view

**File modified:** `Nostos/Views/DuplicatesView.swift`

### New layout

```
PageHeaderView(title: "Duplicates",
  subtitle: "{N} groups · {N} photos · {N} of {N} resolved")

ScrollView {
  StarDotBackground

  LazyVGrid(columns: adaptive(min: 280pt), spacing: 8) {
    ForEach(duplicateGroups) { group in
      DupGroupCard(group, kept, expanded)
    }
  }

  // Footer actions
  Divider
  HStack {
    Btn("Keep First in All Groups", .bordered)
    Btn("Clear Selections", .danger)
    Spacer()
    if someResolved && !allResolved:
      Btn("Remove N resolved duplicates", .bordered)
    Btn("Remove all N duplicates", .primary)
      .disabled(!allResolved)
  }
}
```

### `DupGroupCard`
`VStack` in a white card with 1.5pt border (green-tinted when resolved):
- Header row: reason badge ("Exact" orange / "Near" teal, with DiamondAccent) + photo count + ✓ resolved indicator + expand/collapse toggle button (↑/↓)
- Thumbnail row: `HStack` of thumbnail squares (52pt collapsed, 86pt expanded, wrapping when expanded)
  - Selected (kept) thumbnail: green 2.5pt outline + green checkmark circle top-right
  - Filename label below each thumb only when expanded
  - Tap any thumb to mark it as kept

---

## Phase 6 — Vault view

**File modified:** `Nostos/Views/OrganizerView.swift`

### New layout

```
PageHeaderView(title: "Vault",
  subtitle: "Organise and copy photos into your structured vault folder")

ScrollView {
  StarDotBackground

  // Row 1: 4 stat cards
  HStack(4 equal columns) {
    StatCard("Photos Scanned", db.photoCount())
    StatCard("In Vault",       db.countPhotosForBackup(filter:copiedFilter))
    StatCard("Not Yet Vaulted", db.photoCount() - inVault)
    StatCard("Total Size",     formatted totalBytes)   ← new AppDatabase query needed
  }

  // Row 2: Storage breakdown by format
  CardView {
    SectionLabel("Storage Breakdown — Format", diamond: true)
    ForEach(formatBreakdown) { row in
      HStack {
        Text(row.ext).monospace.w32
        MiniBarChart(pct: row.pct, color: nostosAccent)
        Text(row.count).w36
        Text(row.size).w52.muted
      }
    }
  }

  // Row 3: Year breakdown
  CardView {
    SectionLabel("Breakdown — Year Taken", diamond: true)
    ForEach(yearBreakdown) { row in
      HStack {
        Text(row.year)
        MiniBarChart(pct: row.pct, color: nostosGold)
        Text(row.count)
        Text("\(row.pct)%").muted
      }
    }
  }

  // Row 4: Camera breakdown
  CardView {
    SectionLabel("Breakdown — Camera", diamond: true)
    ForEach(cameraBreakdown) { row in
      HStack {
        Text(row.model).w104.truncated
        MiniBarChart(pct: row.pct, color: nostosAccent)
        Text(row.count)
        Text("\(row.pct)%").muted
      }
    }
  }

  // Row 5: Vault location + format (existing controls, restyled)
  CardView {
    SectionLabel("Vault Location", diamond: true)
    HStack { monospace path field | Btn("Change…", .bordered) }
    SectionLabel("Folder Format", diamond: true)
    HStack { monospace text field | preview label }
  }

  // Organize button + progress card (existing logic, restyled)
  Btn("▶  Organise Vault")
  if running || done { ProgressCard }
}
```

### `MiniBarChart`
A simple 5pt-tall `GeometryReader`-based progress-style bar, teal (or gold) at 75% opacity on `nostosProgressBg` track. Reusable across all three breakdown cards.

### New `AppDatabase` queries needed
- `func totalPhotoSizeBytes() throws -> Int64` — `SELECT SUM(file_size) FROM photos`
- `func fetchFormatBreakdown() throws -> [(ext: String, count: Int, bytes: Int64)]` — group by uppercased extension from path
- `func fetchYearBreakdown() throws -> [(year: Int, count: Int)]`
- `func fetchCameraBreakdown() throws -> [(model: String, count: Int)]`

These feed new published properties on `AppState`: `formatBreakdown`, `yearBreakdown`, `cameraBreakdown`, loaded in `loadInitialData()`.

---

## Phase 7 — Remove Backup tab, integrate into Gallery

**Files modified:** `Nostos/Views/BackupView.swift`, `Nostos/AppState.swift`, `Nostos/NostosApp.swift`

- Delete `Nostos/Views/BackupView.swift` (or keep as a dead file stripped to a stub until all references are removed).
- Remove `.backup` from the `Tab` enum in `ContentView.swift`.
- Remove the `backupTabButton` from the sidebar.
- The `BackupFooterBar` in `GalleryView` becomes the only UI surface for triggering backups. It calls `appState.startBackup(...)` and reads `appState.backupProgress` / `appState.lastBackupResults`.
- `AppState` backup methods are unchanged; only the view entry point moves.

---

## Phase 8 — Vault setup screen

**File modified:** `Nostos/NostosApp.swift` (`VaultSetupView`)

Restyle `VaultSetupView` to use the new design tokens: parchment background, serif title, teal "Choose Vault…" button, same `WaveLensLogo` mark. Keep existing functional logic unchanged.

---

## Implementation order

Implement phases in this order to keep the app buildable at each step:

1. **Phase 1** — Design tokens + components (no UI changes, just new files)
2. **Phase 2** — Sidebar (visual-only, no logic change)
3. **Phase 3** — Scanner (low risk, mostly additive)
4. **Phase 6** — Vault stats + breakdown charts (needs new DB queries first)
5. **Phase 5** — Duplicates grid
6. **Phase 4** — Gallery (most complex; do last)
7. **Phase 7** — Remove Backup tab (cleanup, once Gallery backup footer is working)
8. **Phase 8** — Vault setup screen

---

## Risk / tradeoff notes

| Area | Risk | Mitigation |
|---|---|---|
| Cormorant Garamond bundling | Font must be in `Package.swift` resources; Xcode and `swift build` handle it differently | Test both; add font to `.xcodeproj` target manually if `swift build` path fails |
| Vertical year-range slider | No native SwiftUI equivalent; custom `DragGesture` implementation | Scope it carefully; a simpler two-`Picker` fallback works if slider proves flaky |
| Gallery month grouping + filters | Filter changes must re-derive month groups; expensive if naïve | Compute groups in a `var computedGroups: [MonthGroup]` derived from `photos` array already in `AppState`, no extra DB round-trip |
| Backup in Gallery footer | `BackupService` is async and reports progress via callback; the footer bar needs to observe `AppState.backupProgress` | Already `@Published`; no architecture change needed |
| `AppDatabase` breakdown queries | New queries add startup load | Make them lazy — only called when Vault tab is selected, not in `loadInitialData()` |
| Removing BackupView | UI tests reference `backupTabButton` accessibility identifier | Update `NostosUITests.swift` when the tab is removed |
