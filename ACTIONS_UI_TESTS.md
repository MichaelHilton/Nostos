## Action → UI Test Coverage

This table lists user-facing actions and the corresponding UI test(s) found in `Tests/NostosUITests/NostosUITests.swift`. If no UI test exists, the table shows "NA".

| Action | UI Test(s) | UI Elements |
|---|---|---|
| Pick Source Directory | testScannerChooseSourceDirectory | Scanner tab → `scannerChooseDirectoryButton` / source path label `scannerSelectedPathText` |
| Start Scan | testScannerStartScan | Scanner tab → `scannerStartScanButton` (Start Scan button) |
| Cancel/Stop Scan | NA | Scanner tab → Cancel/Stop button shown during scan (progress UI) |
| View Scan Runs | testScannerViewScanRuns | Scanner tab → Scan runs list / Scan history panel (scan run rows) |
| Inspect Scanned File | NA | Scanner/Scan run details → per-file row with metadata panel (hash, size) |
| Open Gallery | testTabNavigation, testGalleryPhotoSelectionAndDismiss | Sidebar → `galleryTabButton`; Gallery grid → `galleryPhotoTile` |
| Filter Photos | testGalleryToolbarFilterChips, testGallerySidebarDuplicateFilters, testGallerySidebarStatusFilters, testGalleryYearRangeSlider | Toolbar filter chips (`galleryFilterChip*`), sidebar checkboxes (`galleryFilter*`), year-range slider (`galleryFilterYear_*`) |
| Search Photos | NA | Gallery toolbar → search field (filename/metadata search box) |
| Sort Photos | NA | Gallery toolbar → sort menu / dropdown (sort by date/name/size) |
| Select Photo(s) | testGalleryPhotoSelectionAndDismiss | Click photo tiles (`galleryPhotoTile`) — supports multi-select (shift/cmd) |
| Inspect Photo Details | testGalleryPhotoSelectionAndDismiss, testGalleryPhotoShowsVaultBadgeAfterBackup | Photo detail panel opened from `galleryPhotoTile` — shows EXIF, dimensions, badges (`galleryClearSelectionButton` to dismiss) |
| View Full-Size Photo | testGalleryPhotoSelectionAndDismiss | Photo detail panel / zoom control in detail view (opened from tile) |
| Reveal in Finder | NA | Photo detail → "Reveal in Finder" button/menu item (opens Finder at file path) |
| Copy/Export Photo | NA | Photo detail or toolbar → "Export" / "Copy" action (file save dialog) |
| Delete Photo | NA | Photo detail or contextual menu → "Delete" action with confirmation dialog |
| Add/Remove Tags or Notes | NA | Photo detail → tags/notes editor (text fields / tag chips) |
| Generate / Refresh Thumbnail | NA | Photo detail / thumbnail cache menu → "Regenerate Thumbnail" action |
| Run Duplicate Detection | NA (covered in unit tests) | Scanner completion triggers Duplicate detection automatically; duplicates view has controls to run manually (if available) |
| View Duplicate Groups | testDuplicatesGroupInteraction | `duplicatesTabButton` in sidebar → Duplicate groups list; expand button `duplicateExpandGroupButton` and photo tiles `duplicatePhotoTile` |
| Mark Kept Photo | testDuplicatesGroupInteraction, testDuplicateGroupCardKeepFirstButton | Duplicate group UI → select photo tile and click `duplicatesKeepFirstButton` or contextual "Keep" action |
| Keep All in All Groups | testDuplicatesKeepAllInAllGroups | Duplicate group UI → footer button `duplicatesKeepAllButton` resolves all groups |
| Resolve Duplicate Group | testDuplicatesGroupInteraction | Duplicate group actions → Keep/Delete/Resolve buttons; `duplicatesClearSelectionsButton` to clear selection |
| Inspect Duplicate Details | testDuplicatesGroupInteraction | Duplicate group expand view → side-by-side previews and metadata rows for each photo |
| Configure Vault Root / Setup Vault | testVaultChangeVaultCancelPath | Vault tab → `vaultChangeVaultButton` opens change-vault sheet (path picker + Confirm/Cancel) |
| Run Organizer (Copy into Vault) | testVaultDryRunToggle | Vault tab → `vaultPreviewButton` (dry-run preview) and `vaultSaveButton` (perform organize) |
| Dry-Run Organize | testVaultDryRunToggle | `vaultDryRunToggle` switch toggles between preview (`vaultPreviewButton`) and save (`vaultSaveButton`) modes |
| View Organize Job Status | testVaultToggleDetails | Vault results panel → `vaultToggleDetailsButton` shows/hides results table with job rows |
| Resolve Organize Conflicts | NA | Organize results → conflict rows with Resolve/Skip buttons and filename conflict dialog |
| Cancel Organizer Job | NA | Organizer progress UI → Cancel button (shown while organizing) |
| View Organize Results | testVaultToggleDetails | Results table in Vault tab (rows for `OrganizeResult`) toggled by `vaultToggleDetailsButton` |
| Create Backup Job | testGalleryBackupToVaultAndBackUpAgain | Gallery toolbar → `galleryBackUpToVaultButton` opens backup flow / confirms backup source selection |
| Run Backup | testGalleryBackupToVaultAndBackUpAgain, testGalleryPhotoShowsVaultBadgeAfterBackup | `galleryBackUpToVaultButton` triggers backup; progress shown and primary button changes to `galleryBackUpAgainButton` when complete |
| View Backup Job Status | testGalleryBackupToVaultAndBackUpAgain | Backup progress UI / status indicator in Gallery or Backup tab; pause/resume controls (if available) |
| Cancel Backup Job | NA | Backup progress UI → Cancel/Pause button to stop backup |
| Inspect Vault Photo Records | testGalleryPhotoShowsVaultAfterBackup | Gallery photo badges ("IN VAULT") displayed on `galleryPhotoTile` and filter `galleryFilterChipInVault` |
| Restore from Backup | NA | Backup details view → Restore button/menu (choose destination) |
| Configure ThumbnailService | NA | App Preferences / Setup flow → Thumbnail cache folder setting and `ThumbnailService.configure` call |
| Generate Thumbnails | NA | Background job triggered on import/organize; UI may provide "Regenerate Thumbnails" action in Tools/Preferences |
| Clear Thumbnail Cache | NA | Preferences or Tools menu → "Clear Thumbnail Cache" button (confirmation dialog) |
| Read EXIF | NA (covered in unit tests) | EXIF is read on import; photo detail shows EXIF fields (Taken At, Camera, GPS) in detail panel |
| Edit Metadata | NA | Photo detail → Edit metadata button opens metadata editor (save/cancel) |
| Use EXIF for Deduping | NA (covered in unit tests) | Duplicate detection settings toggle in Preferences or Duplicate tab controls |
| View Database Records | NA | Developer/Debug view or Preferences → Database viewer listing `photos`, `scan_runs`, `duplicate_groups` |
| Export/Import DB | NA | Preferences or Tools → Import/Export DB buttons (file chooser) |
| Clear Vault / Reset App State | NA | Preferences / Vault setup → Reset Vault button or onboarding flow (confirmation) |
| Switch Tabs | testTabNavigation | Sidebar tab buttons: `scannerTabButton`, `galleryTabButton`, `duplicatesTabButton`, `vaultTabButton` |
| Open Vault Setup | NA | On first launch or via Preferences → Vault setup flow with `vaultChangeVaultButton` and directory picker |
| Enable UI Testing Flags | NA | Developer-only: set environment variables (`UI_TESTING*`) when launching app for tests |
| View Empty States / Help | NA | Empty-state views and help buttons shown in each tab (onboarding cards / EmptyStateView) |
| Open App Preferences / Settings | NA | App menu → Preferences / Settings window (various toggles and path selectors) |
| Run Tests / Debug Tools | NA | Developer scripts in `scripts/` (not UI): `test-ui.sh`, `test-maestro.sh`, `test-with-coverage.sh` |

If you'd like, I can add links to the specific test lines in `Tests/NostosUITests/NostosUITests.swift` or export this table as CSV.
