# Maestro UI Tests for Nostos

This directory contains Maestro test flows for the Nostos macOS application. These tests run alongside the existing XCTest UI tests to allow comparison between the two frameworks.

## What is Maestro?

[Maestro](https://maestro.mobile.dev/) is a mobile/desktop UI testing framework that uses simple YAML files to define test flows. It provides:

- Declarative YAML syntax (easier to read/write than XCTest code)
- Built-in retry logic and smart waiting
- Better error messages and debugging
- Cross-platform support (iOS, Android, macOS, web)
- No compilation required - just edit and run

## Setup

Maestro is already installed if you see this README. If you need to reinstall:

```bash
curl -fsSL https://get.maestro.mobile.dev | bash
export PATH="$PATH:$HOME/.maestro/bin"
```

## Running Maestro Tests

### Run all tests

```bash
./Nostos/scripts/test-maestro.sh
```

### Run a specific test

```bash
./Nostos/scripts/test-maestro.sh 01-tab-navigation
```

### Run tests from .maestro directory

```bash
maestro test .maestro/
```

### Run with analysis

```bash
maestro test .maestro/ --analyze | bash
```

## Test Coverage

The Maestro test suite mirrors the existing XCTest UI tests:

| Test File | XCTest Equivalent | Description |
|-----------|-------------------|-------------|
| `01-tab-navigation.yaml` | `testTabNavigation()` | Tab navigation across Gallery, Scanner, Duplicates, Vault |
| `02-scanner-buttons.yaml` | `testScannerButtons()` | Scanner Choose and Start Scan buttons |
| `03-gallery-photo-selection.yaml` | `testGalleryPhotoSelectionAndDismiss()` | Photo selection and detail panel |
| `04-gallery-filter-chips.yaml` | `testGalleryToolbarFilterChips()` | Toolbar filter chips and Clear All |
| `05-gallery-sidebar-filters.yaml` | `testGallerySidebar*Filters()` | Sidebar duplicate/status/camera filters |
| `06-gallery-backup-workflow.yaml` | `testGalleryBackupToVaultAndBackUpAgain()` | Backup workflow and reset |
| `07-duplicates-group-interaction.yaml` | `testDuplicatesGroupInteraction()` | Duplicate group expansion and selection |
| `08-vault-dry-run-toggle.yaml` | `testVaultDryRunToggle()` | Vault Dry Run toggle functionality |
| `09-vault-toggle-details.yaml` | `testVaultToggleDetails()` | Vault details table toggle |
| `10-gallery-year-range-slider.yaml` | `testGalleryYearRangeSlider()` | Year range filter |
| `11-vault-change-cancel.yaml` | `testVaultChangeVaultCancelPath()` | Cancel vault change dialog |
| `12-gallery-vault-badge.yaml` | `testGalleryPhotoShowsVaultBadgeAfterBackup()` | Vault badge after backup |

## Comparison: Maestro vs XCTest

### XCTest (Existing)

**Pros:**
- Native Apple framework - no external dependencies
- Integrates directly with Xcode
- Full Swift API access
- Detailed accessibility hierarchy inspection
- Works in Xcode Test Navigator

**Cons:**
- Verbose Swift code
- Requires compilation for every change
- Complex async/wait handling
- Harder to read test intent
- Platform-specific (macOS/iOS only)

### Maestro (New)

**Pros:**
- Simple YAML syntax - easy to read/write
- No compilation - instant iteration
- Built-in smart waiting and retries
- Better failure messages with screenshots
- Cross-platform (can run same tests on iOS if needed)
- Non-developers can write/modify tests

**Cons:**
- External dependency (requires Maestro CLI)
- Less debugging control than XCTest
- Newer tool - smaller community
- Cannot access Swift APIs directly

## Running Both Test Suites

### XCTest UI Tests

```bash
# Run all UI tests
./Nostos/scripts/test-ui.sh

# Run specific test
./Nostos/scripts/test-ui.sh testTabNavigation
```

### Maestro Tests

```bash
# Run all Maestro tests
./Nostos/scripts/test-maestro.sh

# Run specific test
./Nostos/scripts/test-maestro.sh 01-tab-navigation
```

## Test Environment Variables

Both test suites use the same environment variables for seeding data:

- `UI_TESTING=1` - Indicates app is running in test mode
- `UI_TESTING_SEED_DATA=1` - Seeds 26 photos + scan run + organize job
- `UI_TESTING_VAULT_ROOT` - Sets the vault root path
- `UI_TESTING_SOURCE_DIRECTORY_TO_PICK` - Pre-fills source directory picker
- `UI_TESTING_VAULT_DIRECTORY_TO_PICK` - Pre-fills vault directory picker

## Adding New Tests

### XCTest

1. Add test method to `Tests/NostosUITests/NostosUITests.swift`
2. Run `swift test` or use Xcode Test Navigator

### Maestro

1. Create new YAML file in `.maestro/` directory
2. Use accessibility IDs from your SwiftUI views
3. Run `maestro test .maestro/your-new-test.yaml`

## Debugging

### XCTest Debugging

- Use Xcode debugger
- Check `freshApp.debugDescription` for accessibility hierarchy
- Add print statements in test code

### Maestro Debugging

```bash
# Run with debug output
maestro test .maestro/01-tab-navigation.yaml --debug-output /tmp/maestro-debug

# Studio mode (interactive)
maestro studio

# Screenshot on failure (automatic)
# Check ~/.maestro/tests/ for failure screenshots
```

## CI Integration

The existing GitHub Actions workflow (`.github/workflows/swift.yml`) runs XCTest UI tests. To add Maestro:

```yaml
- name: Install Maestro
  run: curl -fsSL https://get.maestro.mobile.dev | bash

- name: Run Maestro UI Tests
  run: ./Nostos/scripts/test-maestro.sh
```

## Recommendations

**Use XCTest for:**
- Complex interactions requiring Swift API access
- Tests that need detailed debugging
- When you want IDE integration

**Use Maestro for:**
- Quick iteration on test scenarios
- Readable test documentation
- When non-developers need to modify tests
- Rapid prototyping of new test cases

Both test suites will be maintained in parallel to compare effectiveness, maintainability, and developer experience over time.
