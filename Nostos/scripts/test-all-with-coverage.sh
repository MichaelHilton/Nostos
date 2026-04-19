#!/usr/bin/env bash
set -euo pipefail

# Run unit tests and UI tests, merge coverage, and list uncovered lines.
# Usage: ./scripts/test-all-with-coverage.sh [ui-test-name...]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_CODECOV_DIR="$ROOT_DIR/.build/debug/codecov"
OUTPUT_DIR="$ROOT_DIR/coverage"
SCHEME="Nostos"
DESTINATION="platform=macOS"
UI_TEST_TARGET="NostosUITests"

IGNORE_REGEX='\.build(/|$)'

mkdir -p "$BUILD_CODECOV_DIR"
mkdir -p "$OUTPUT_DIR"

echo "Running unit tests with code coverage..."
swift test --enable-code-coverage

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

# Gather all .profraw files under the codecov dir
echo "Searching for .profraw files..."
PROFRAW_FILES=( $(find "$BUILD_CODECOV_DIR" -name "*.profraw" 2>/dev/null || true) )

if [ ${#PROFRAW_FILES[@]} -eq 0 ]; then
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
if [ ${#PROFRAW_FILES[@]} -gt 0 ]; then
  echo "Merging ${#PROFRAW_FILES[@]} profraw files into $PROFDATA"
  $LLVM_PROFDATA merge -sparse "${PROFRAW_FILES[@]}" -o "$PROFDATA"
fi

if [ ! -f "$PROFDATA" ]; then
  echo "No profdata found at $PROFDATA" >&2
  echo "Ensure unit tests ran with --enable-code-coverage and xcodebuild was able to produce profraw files." >&2
  exit 1
fi

# Locate the test executable for llvm-cov mapping
TEST_EXECUTABLE=""
SEARCH_DIR="$ROOT_DIR/.build"
if command -v find >/dev/null 2>&1; then
  TEST_EXECUTABLE=$(find "$SEARCH_DIR" -path '*/Contents/MacOS/*' -type f -perm -111 -print -quit 2>/dev/null || true)
  if [ -z "$TEST_EXECUTABLE" ]; then
    TEST_EXECUTABLE=$(find "$SEARCH_DIR" -type f -perm -111 \( ! -name '*.dylib' ! -name '*.so' ! -name '*.a' ! -name '*.o' ! -name '*.swiftmodule' \) -print -quit 2>/dev/null || true)
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
  /^[[:space:]]*0:[[:space:]]*([0-9]+)/ {
    if (match($0,/^[[:space:]]*0:[[:space:]]*([0-9]+)/,m)) {
      print file":"m[1]
    }
  }
' "$ANNOTATED_FILE" | sort -u || true

echo
echo "HTML report: $OUTPUT_DIR/index.html"

echo "Done."
