#!/usr/bin/env bash
set -euo pipefail

# Run unit tests and UI tests, merge coverage, and list uncovered lines.
# Usage: ./scripts/test-all-with-coverage.sh [ui-test-name...]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_CODECOV_DIR="$ROOT_DIR/.build/debug/codecov"
OUTPUT_DIR="$ROOT_DIR/coverage"
SCHEME="Nostos"
ARCH=$(uname -m)   # arm64 on Apple Silicon, x86_64 on Intel
DESTINATION="platform=macOS,arch=$ARCH"
UI_TEST_TARGET="NostosUITests"

# SPM always builds into an arch-specific subdirectory; the .build/debug symlink
# also works, but scoping searches here prevents picking up xcodebuild artifacts.
SPM_DEBUG_DIR="$ROOT_DIR/.build/${ARCH}-apple-macosx/debug"
if [ ! -d "$SPM_DEBUG_DIR" ]; then
  SPM_DEBUG_DIR="$ROOT_DIR/.build/debug"  # fallback to symlink
fi

IGNORE_REGEX='(\.build|Tests)(/|$)'

mkdir -p "$BUILD_CODECOV_DIR"
mkdir -p "$OUTPUT_DIR"

# Phase 1: build the coverage-instrumented test binary.
# swift test --enable-code-coverage compiles correctly but on Swift 5.9 / macOS 13
# SPM's internal llvm-profdata merge call fails ("no input files") because the
# test process uses the %10m pool-file pattern which silently drops profraw on
# this system. We ignore the non-zero exit so we get the instrumented binary.
echo "Building and running tests with code coverage (phase 1: build + first run)..."
set +e
swift test --enable-code-coverage
SWIFT_TEST_EXIT=$?
set -e
if [ $SWIFT_TEST_EXIT -ne 0 ]; then
  echo "Note: swift test exited with $SWIFT_TEST_EXIT (expected SPM profdata merge failure on Swift 5.9)" >&2
fi

# Phase 2: re-run the instrumented test bundle with LLVM_PROFILE_FILE set to a
# simple %p pattern so the profraw lands in the codecov directory. SPM overrides
# any parent-process LLVM_PROFILE_FILE, so we must run xctest directly here.
TEST_BUNDLE=$(find "$SPM_DEBUG_DIR" -name "*.xctest" -type d 2>/dev/null | head -1)
if [ -z "$TEST_BUNDLE" ]; then
  echo "Test bundle not found in .build — ensure swift test --enable-code-coverage succeeded above." >&2
  exit 1
fi
echo "Collecting profraw data (phase 2: direct xctest run)..."
set +e
LLVM_PROFILE_FILE="$BUILD_CODECOV_DIR/default%p.profraw" xcrun xctest "$TEST_BUNDLE" >/dev/null 2>&1
set -e

echo "Running UI tests (xcodebuild) with code coverage..."
DERIVED_DATA="$BUILD_CODECOV_DIR/xcode"
XCODEARGS=(test -scheme "$SCHEME" -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA" -enableCodeCoverage YES)

if [ "$#" -eq 0 ]; then
  XCODEARGS+=("-only-testing:${UI_TEST_TARGET}")
else
  for test_name in "$@"; do
    XCODEARGS+=("-only-testing:${UI_TEST_TARGET}/${UI_TEST_TARGET}/${test_name}")
  done
fi

echo "xcodebuild ${XCODEARGS[*]}"
set +e
xcodebuild "${XCODEARGS[@]}"
XCODE_EXIT=$?
set -e
if [ $XCODE_EXIT -ne 0 ]; then
  echo "Warning: xcodebuild returned exit code $XCODE_EXIT" >&2
fi

# Capture the xcresult bundle produced by xcodebuild for later UI coverage filtering.
XCRESULT=$(find "$DERIVED_DATA" -name "*.xcresult" -type d 2>/dev/null | head -1)
if [ -n "$XCRESULT" ]; then
  echo "Found xcresult: $(basename "$XCRESULT")"
else
  echo "No xcresult found under $DERIVED_DATA — UI coverage filtering will be skipped." >&2
fi

# Gather all .profraw files under the codecov dir
echo "Searching for .profraw files..."
# Use a null-separated list to handle filenames with spaces
find "$BUILD_CODECOV_DIR" -name "*.profraw" -print0 2>/dev/null > /tmp/profraw_files.txt 2>/dev/null || true

# Count the files
PROFRAW_COUNT=$(find "$BUILD_CODECOV_DIR" -name "*.profraw" 2>/dev/null | wc -l)

if [ "$PROFRAW_COUNT" -eq 0 ]; then
  echo "No .profraw files found under $BUILD_CODECOV_DIR. Coverage may be unavailable from UI tests." >&2
fi

# Find llvm tools
if command -v llvm-profdata >/dev/null 2>&1 && command -v llvm-cov >/dev/null 2>&1; then
  LLVM_PROFDATA="llvm-profdata"
  LLVM_COV="llvm-cov"
elif command -v xcrun >/dev/null 2>&1; then
  LLVM_PROFDATA="xcrun llvm-profdata"
  LLVM_COV="xcrun llvm-cov"
else
  echo "Neither llvm-profdata/llvm-cov nor xcrun were found in PATH. Install llvm or Xcode command line tools." >&2
  exit 1
fi

# Merge profraws into a single profdata
PROFDATA="$BUILD_CODECOV_DIR/default.profdata"
if [ "$PROFRAW_COUNT" -gt 0 ]; then
  echo "Merging $PROFRAW_COUNT profraw files into $PROFDATA"
  # Use find with -print0 and xargs to handle filenames with spaces
  find "$BUILD_CODECOV_DIR" -name "*.profraw" -print0 2>/dev/null | xargs -0 $LLVM_PROFDATA merge -sparse -o "$PROFDATA"
fi

if [ ! -f "$PROFDATA" ]; then
  echo "No profdata found at $PROFDATA" >&2
  echo "Ensure unit tests ran with --enable-code-coverage and xcodebuild was able to produce profraw files." >&2
  exit 1
fi

# Locate the test executable for llvm-cov mapping.
# Search only the SPM debug dir so we never accidentally pick up a xcodebuild
# artifact (which lives under BUILD_CODECOV_DIR/xcode and may be a different arch).
TEST_EXECUTABLE=""
if command -v find >/dev/null 2>&1; then
  TEST_EXECUTABLE=$(find "$SPM_DEBUG_DIR" -path '*/Contents/MacOS/*' -type f -perm -111 -print -quit 2>/dev/null || true)
  if [ -z "$TEST_EXECUTABLE" ]; then
    TEST_EXECUTABLE=$(find "$SPM_DEBUG_DIR" -type f -perm -111 \( ! -name '*.dylib' ! -name '*.so' ! -name '*.a' ! -name '*.o' ! -name '*.swiftmodule' \) -print -quit 2>/dev/null || true)
  fi
fi

if [ -z "$TEST_EXECUTABLE" ]; then
  echo "Test executable not found in .build; ensure 'swift test --enable-code-coverage' ran successfully." >&2
  exit 1
fi

echo "Using test executable: $TEST_EXECUTABLE"

echo "Generating HTML coverage report in $OUTPUT_DIR"
$LLVM_COV show \
  --format=html \
  --Xdemangler=swift \
  --instr-profile="$PROFDATA" \
  "$TEST_EXECUTABLE" \
  --ignore-filename-regex="$IGNORE_REGEX" \
  --output-dir="$OUTPUT_DIR" > /dev/null 2>&1

echo "Generating text summary report"
RAW_REPORT_FILE="$(mktemp "$BUILD_CODECOV_DIR/coverage_raw.XXXXXX" )"
FILTERED_REPORT_FILE="$(mktemp "$BUILD_CODECOV_DIR/coverage_filtered.XXXXXX" )"

$LLVM_COV report --instr-profile="$PROFDATA" --ignore-filename-regex="$IGNORE_REGEX" "$TEST_EXECUTABLE" >"$RAW_REPORT_FILE" 2>&1 || true

sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' "$RAW_REPORT_FILE" > "$BUILD_CODECOV_DIR/coverage_cleaned.txt" || cp "$RAW_REPORT_FILE" "$BUILD_CODECOV_DIR/coverage_cleaned.txt" || true
grep -F -v ".build/" "$BUILD_CODECOV_DIR/coverage_cleaned.txt" > "$FILTERED_REPORT_FILE" || true

cat "$FILTERED_REPORT_FILE"

echo
echo "Listing uncovered lines (best-effort):"
# Produce annotated text and parse lines with 0 hits. Output format varies by llvm-cov; we attempt a robust parse.
ANNOTATED_FILE="$BUILD_CODECOV_DIR/coverage_annotated.txt"
$LLVM_COV show --format=text --Xdemangler=swift --instr-profile="$PROFDATA" "$TEST_EXECUTABLE" --ignore-filename-regex="$IGNORE_REGEX" > "$ANNOTATED_FILE" 2>/dev/null || true

awk '
  BEGIN { file="" }
  # file header lines typically end with a colon and are the filename
  /^[^[:space:]].*:[[:space:]]*$/ { file=substr($0,1,length($0)-1); next }
  # match lines that start with 0: or  0: optionally with spaces, then capture the source line number
  /^[[:space:]]*0:[[:space:]]*/ {
    # Extract the line number after "0:"
    for (i=1; i<=NF; i++) {
      if ($i ~ /^[0-9]+$/) {
        print file":"$i
        break
      }
    }
  }
' "$ANNOTATED_FILE" | sort -u || true

echo
echo "HTML report: $OUTPUT_DIR/index.html"

# Generate uncovered-lines file from HTML coverage if extractor script exists
EXTRACTOR="$ROOT_DIR/scripts/extract_uncovered_lines.py"
if [ -f "$EXTRACTOR" ]; then
  echo "Generating coverage-uncovered.txt using $EXTRACTOR"
  # run extractor but do not fail the whole script if it errors
  set +e
  python3 "$EXTRACTOR"
  PY_RET=$?
  set -e
  if [ $PY_RET -ne 0 ]; then
    echo "Warning: coverage extractor exited with code $PY_RET" >&2
  else
    echo "Wrote coverage-uncovered.txt"
  fi
else
  echo "No extractor script found at $EXTRACTOR; skipping uncovered-lines generation"
fi

# Remove from coverage-uncovered.txt any lines that the UI tests actually exercised.
UI_FILTER="$ROOT_DIR/scripts/filter_ui_coverage.py"
if [ -n "${XCRESULT:-}" ] && [ -d "$XCRESULT" ] && [ -f "$UI_FILTER" ]; then
  echo "Filtering coverage-uncovered.txt with UI test coverage..."
  set +e
  python3 "$UI_FILTER" "$XCRESULT" "$ROOT_DIR"
  UI_FILTER_EXIT=$?
  set -e
  if [ $UI_FILTER_EXIT -ne 0 ]; then
    echo "Warning: UI coverage filter returned exit code $UI_FILTER_EXIT" >&2
  fi
else
  echo "Skipping UI coverage filter (xcresult or filter script not found)."
fi

echo "Done."
