# Nostos Design System

> **Nostos** — Self-Hosted Photo Management  
> A native macOS app for scanning, deduplicating, organizing, and backing up your photo library.  
> No cloud. No subscriptions. No server.

---

## Sources

| Source | Path / URL |
|--------|-----------|
| Codebase (SwiftUI, macOS) | `Nostos/` (attached via File System Access API) |
| GitHub repo | https://github.com/michaelhilton/nostos |
| Logo brand sheet | `assets/brand_sheet.png` |
| Logo horizontal (light bg) | `assets/logo_horizontal_light.png` |
| Logo square (light bg) | `assets/logo_square_light.png` |
| Logo square (dark bg) | `assets/logo_square.png` |

---

## Products

| Surface | Description |
|---------|------------|
| **macOS app** | Native SwiftUI app — `NavigationSplitView` sidebar + 5 detail screens |

### App screens
- **Scanner** — directory picker, progress bar, recent scans table
- **Gallery** — lazy photo grid (160 × 160 tiles), filter sidebar, selected photo panel
- **Duplicates** — horizontal scroll cards per group; tap to mark as "kept"
- **Vault** — folder format config, dry-run toggle, copy-job progress
- **Backup** — filter by camera/year/date, estimated count, dry-run/backup run

---

## File Index

```
README.md                     ← this file
SKILL.md                      ← agent skill definition
colors_and_type.css           ← all CSS variables (colors + type scale)
assets/
  logo_square.png             ← square logo (dark bg)
  logo_horizontal.png         ← horizontal lockup
  logo_horizontal_light.png   ← horizontal lockup on white
  logo_square_light.png       ← square logo on white
  brand_sheet.png             ← full brand kit sheet
preview/                      ← design system cards (Design System tab)
  brand-logo.html
  colors-brand.html
  colors-neutral.html
  colors-semantic.html
  type-scale.html
  type-brand.html
  spacing-radii.html
  spacing-tokens.html
  components-buttons.html
  components-badges.html
  components-groupbox.html
  components-photo-tile.html
  components-sidebar.html
ui_kits/
  nostos_app/
    index.html                ← full interactive macOS app prototype
```

---

## CONTENT FUNDAMENTALS

### Voice & Tone
- **Concise and functional.** Copy is minimal and task-oriented. No marketing language inside the app.
- **Sentence case** throughout (not title case). E.g. "Start scan", "No vault selected", "Dry run".
- **Second-person implicit.** The UI speaks directly but impersonally — no "you" or "your" in labels. Button labels are imperatives: "Start Scan", "Choose…", "Back Up Now".
- **Ellipsis (…) on buttons** that open a dialog or picker — a macOS convention strictly followed. E.g. "Choose…", "Change Vault…".
- **No emoji** in the app UI. SF Symbols are used for all iconography.
- **Status words are capitalized:** Completed, Running, Failed, Copied, Skipped.
- **Technical copy is unadorned:** file paths shown in monospace, hash values shown truncated with `…`.
- **Error messages** are plain and factual, shown in an `.alert` modal with a single "OK" dismiss.
- **Placeholder text:** "No folder selected", "No vault selected", "No Photos", "No Duplicates Found" — always a noun phrase.
- **Empty states** have a title + SF Symbol + one-sentence instruction. E.g. "Scan a folder to import photos."

### Example copy
> "Recursively walks any directory and indexes photos."  
> "Nostos will reopen the database and thumbnails from the selected folder."  
> "Copy selected photos to the vault. Photos already in the vault (matched by file hash) are automatically skipped."

---

## VISUAL FOUNDATIONS

### Colors
Primary brand colors extracted from the logo brand sheet (`assets/brand_sheet.png`):

| Token | Hex | Usage |
|-------|-----|-------|
| `--nostos-navy` | `#203238` | Wordmark, primary text, headings |
| `--nostos-indigo` | `#200E96` | Dark background / alt accent |
| `--nostos-teal-light` | `#2BABB8` | Outer logo rings, hover states |
| `--nostos-teal-mid` | `#1B7A8A` | Primary accent, active nav, progress bars, primary buttons |
| `--nostos-teal-dark` | `#1A5068` | Pressed/active accent, inner logo |
| `--nostos-gold` | `#C4932A` | Compass north needle — used sparingly as a warm accent |
| `--nostos-rose` | `#BA8A88` | Muted warm accent (rarely used in app UI) |
| `--nostos-lavender` | `#FAcEFF` | Very light surface / highlight bg |

**Status colors:** Green `#22C55E` (success/copied), Orange `#F59E0B` (warning/duplicate), Red `#EF4444` (error), Blue `#3B82F6` (selected/info).

**Neutral scale:** 9 steps from `#F6F7F8` (bg-base) to `#111820` (near-black).

### Typography
- **Platform:** SF Pro (macOS system font). For web use, substitute **Inter** (regular + Inter Tight for display).
- **Display / wordmark:** Inter Tight 800, very tight letter-spacing (`-0.03em`). Lowercase "nostos" is the canonical wordmark.
- **UI body:** Inter 400, 13px (macOS default HIG size).
- **Headlines in app:** `.largeTitle .bold` = 34px weight 700; `.headline` = 13px weight 600.
- **Uppercase labels:** `font-size: 10–11px, font-weight: 600, letter-spacing: 0.06–0.08em` — used on GroupBox headers, filter section headings.
- **Monospace:** SF Mono / Fira Code — used for file paths, hash values, tokens.

> ⚠️ **Font substitution:** Inter is used as a Google Fonts proxy for SF Pro. For production assets targeting macOS, use `-apple-system, BlinkMacSystemFont` to get native SF Pro.

### Spacing
- **Page padding:** 24px (consistent across all screens)
- **Component internal padding:** 12–14px
- **Grid gap (photo tiles):** 8px
- **Nav item padding:** 7px 14px
- Base unit: 4px. Scale: 4, 8, 12, 16, 20, 24, 32.

### Corner Radii
- `4px` — badges, small chips
- `6px` — photo tiles, buttons, text fields
- `8px` — GroupBox containers, detail panels
- `10px` — window chrome, large cards
- `14px` — year slider panel (rounded panel)
- `9999px` — pill badges, capsule shapes

### Backgrounds & Surfaces
- **App background:** `#F6F7F8` (near-white, macOS `.windowBackgroundColor`)
- **Sidebar:** `#ECEEF1` (light gray, slightly cooler than bg)
- **Cards/GroupBox:** White surface, `1px solid #D8DCE1` border, `border-radius: 8px`
- **No full-bleed imagery** inside the app UI. Photography fills photo grid tiles only.
- **No decorative gradients** in the app UI — gradients appear in the logo only.

### Animation & Interaction
- **Transitions:** Subtle, ~100–150ms `ease` — background on hover, progress fill on width change.
- **No bounce animations.** macOS convention: linear/ease-out for standard transitions.
- **Progress bars:** Smooth linear fill (custom `SafeLinearProgressStyle` — avoids macOS 12 crashes).
- **Spinner:** Rotating circular arc, `accentColor` stroke, `0.8s linear` repeat.
- **Hover states:** Background color shift on nav items and buttons. No opacity change.
- **Press/active:** Slightly darker background (no scale shrink).

### Hover & Press States
- **Nav items:** Transparent → `#D8DCE1` on hover; `#1B7A8A` (teal) when active.
- **Primary button:** `#1B7A8A` → `#2BABB8` on hover.
- **Bordered button:** Transparent → `#ECEEF1` on hover.
- **Photo tile:** Cursor pointer; selection shown via `2px solid teal-light` outline.

### Borders & Shadows
- **Standard border:** `1px solid #D8DCE1`
- **Subtle border:** `rgba(0,0,0,0.06)`
- **Shadow sm:** `0 1px 2px rgba(0,0,0,0.08)` — small elements
- **Shadow md:** `0 2px 8px rgba(0,0,0,0.10)` — cards
- **Shadow lg:** `0 4px 20px rgba(0,0,0,0.12)` — window/modal

### Photo Tile Design
- 160 × 160px (adaptive grid, min 130px)
- `border-radius: 6px`, clipped
- Selection: `2px solid teal-light` outline, inset `-2px`
- Overlay gradient: `linear-gradient(to bottom, transparent 40%, rgba(0,0,0,0.65) 100%)`
- Badges at bottom-left: 9px bold uppercase, color-coded

### Imagery vibe
- Photography is the content, not decoration.
- **No color treatment** or filters applied to user photos.
- Placeholder/loading state: `.windowBackgroundColor` fill + centered spinner (scale 0.6).

---

## ICONOGRAPHY

### Approach
Nostos uses **SF Symbols** exclusively in the macOS app. No custom icon font, no SVG icons, no emoji in the UI.

### Navigation icons (SF Symbols)
| Screen | SF Symbol |
|--------|-----------|
| Scanner | `magnifyingglass` |
| Gallery | `photo.on.rectangle.angled` |
| Duplicates | `doc.on.doc` |
| Vault | `archivebox` |
| Backup | `tray.and.arrow.down` |

### In-app icons
- `play.fill` — Start Scan / Save to Vault / Preview
- `stop.circle` — Running state
- `tray.and.arrow.down.fill` — Back Up Now
- `equal.circle` — Exact Match (duplicates)
- `arrow.triangle.2.circlepath` — Near Duplicate
- `checkmark.circle.fill` — Kept photo indicator
- `photo.on.rectangle` — Empty state (no photos)
- `checkmark.seal` — Empty state (no duplicates)
- `calendar` — Year range label
- `photo.stack` — Photo count estimate
- `ellipsis.circle` — Per-page menu

### Logo
The Nostos logo combines two visual metaphors:
1. **Camera shutter** — spinning aperture blades (teal gradient `#2BABB8 → #1A5068`)
2. **Compass rose** — cardinal direction points; the "N" needle is gold (`#C4932A`)

This expresses both **photography** (shutter) and **navigation/discovery** (compass), reinforcing the product's "find and organize your memories" message. The wordmark "nostos" is set in a bold rounded sans at lowercase, projecting approachability.

**For web use:** SF Symbols are not available outside macOS/iOS. Substitute with **Lucide Icons** (same stroke style) from CDN: `https://unpkg.com/lucide@latest/dist/umd/lucide.min.js`.

---

## UI Kits

| Kit | Path | Description |
|-----|------|-------------|
| Nostos macOS App | `ui_kits/nostos_app/index.html` | Full 5-screen interactive prototype in React |
