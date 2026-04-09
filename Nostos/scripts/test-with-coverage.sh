#!/usr/bin/env bash
set -euo pipefail

# Run Swift tests with code coverage enabled and generate an HTML report.
# Usage: ./scripts/test-with-coverage.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_CODECOV_DIR="$ROOT_DIR/.build/debug/codecov"
OUTPUT_DIR="$ROOT_DIR/coverage"

# Regex to ignore files under the build directory when generating reports
# Match any path containing ".build/" (covers both relative and absolute paths)
IGNORE_REGEX='\.build(/|$)'

echo "Running tests with code coverage..."
swift test --enable-code-coverage

mkdir -p "$BUILD_CODECOV_DIR"
mkdir -p "$OUTPUT_DIR"

# Temp files cleanup
RAW_REPORT_FILE=""
FILTERED_REPORT_FILE=""
cleanup() {
  if [ -n "$RAW_REPORT_FILE" ] && [ -f "$RAW_REPORT_FILE" ]; then
    rm -f "$RAW_REPORT_FILE" || true
  fi
  if [ -n "$FILTERED_REPORT_FILE" ] && [ -f "$FILTERED_REPORT_FILE" ]; then
    rm -f "$FILTERED_REPORT_FILE" || true
  fi
}
trap cleanup EXIT

# Merge any .profraw files into a single .profdata (if llvm-profdata exists)
PROFRAW_FILES=("$BUILD_CODECOV_DIR"/*.profraw)
if command -v xcrun >/dev/null 2>&1; then
  LLVM_PROFDATA="xcrun llvm-profdata"
  LLVM_COV="xcrun llvm-cov"
else
  LLVM_PROFDATA="llvm-profdata"
  LLVM_COV="llvm-cov"
fi

if compgen -G "${BUILD_CODECOV_DIR}/*.profraw" >/dev/null; then
  echo "Merging profraw files to default.profdata"
  $LLVM_PROFDATA merge -sparse "${BUILD_CODECOV_DIR}"/*.profraw -o "$BUILD_CODECOV_DIR/default.profdata"
fi

PROFDATA="$BUILD_CODECOV_DIR/default.profdata"
if [ ! -f "$PROFDATA" ]; then
  echo "No profdata found at $PROFDATA"
  echo "Ensure tests ran with --enable-code-coverage and that llvm-profdata is available." >&2
  exit 1
fi

# Locate the test executable
TEST_EXECUTABLE="$(ls -1 "$ROOT_DIR/.build/x86_64-apple-macosx/debug"/*Tests*.xctest/Contents/MacOS/* 2>/dev/null | head -n1 || true)"
if [ -z "$TEST_EXECUTABLE" ]; then
  echo "Unable to locate test executable in .build; attempting generic binary list..."
  TEST_EXECUTABLE="$(ls -1 "$ROOT_DIR/.build/x86_64-apple-macosx/debug"/* 2>/dev/null | head -n1 || true)"
fi

if [ -z "$TEST_EXECUTABLE" ] || [ ! -f "$TEST_EXECUTABLE" ]; then
  echo "Test executable not found. Looked for .xctest bundles in .build/x86_64-apple-macosx/debug" >&2
  exit 1
fi

echo "Using test executable: $TEST_EXECUTABLE"

echo "Generating HTML coverage report in $OUTPUT_DIR"
# Generate HTML output; suppress verbose stdout (per-file rows) so report parsing isn't polluted
$LLVM_COV show \
  --format=html \
  --Xdemangler=swift \
  --instr-profile="$PROFDATA" \
  "$TEST_EXECUTABLE" \
  --ignore-filename-regex="$IGNORE_REGEX" \
  --output-dir="$OUTPUT_DIR" > /dev/null 2>&1

echo "Generating text summary"

# Generate text report robustly:
# 1) capture both stdout and stderr to a raw temp file
# 2) filter out any lines that reference files under .build into a filtered file
# 3) print and parse the filtered file for the TOTAL percentage
RAW_REPORT_FILE="$(mktemp "$BUILD_CODECOV_DIR/coverage_raw.XXXXXX" )"
FILTERED_REPORT_FILE="$(mktemp "$BUILD_CODECOV_DIR/coverage_filtered.XXXXXX" )"

# Run llvm-cov report capturing all output (stdout+stderr)
$LLVM_COV report --instr-profile="$PROFDATA" --ignore-filename-regex="$IGNORE_REGEX" "$TEST_EXECUTABLE" >"$RAW_REPORT_FILE" 2>&1 || true

# Remove ANSI escape sequences (colors) which can break simple substring matching,
# then filter out any paths that include .build/ (remove third-party sources)
CLEANED_REPORT_FILE="$(mktemp "$BUILD_CODECOV_DIR/coverage_cleaned.XXXXXX" )"
sed -E 's/\x1B\[[0-9;]*[a-zA-Z]//g' "$RAW_REPORT_FILE" > "$CLEANED_REPORT_FILE" || cp "$RAW_REPORT_FILE" "$CLEANED_REPORT_FILE" || true
grep -F -v ".build/" "$CLEANED_REPORT_FILE" > "$FILTERED_REPORT_FILE" || true

# remove intermediate cleaned file
rm -f "$CLEANED_REPORT_FILE" || true

# Show filtered report to the terminal (this is what we parse)
cat "$FILTERED_REPORT_FILE"

# Load REPORT_OUT from the filtered file for downstream parsing
REPORT_OUT="$(cat "$FILTERED_REPORT_FILE")"

echo "Coverage report generated: $OUTPUT_DIR/index.html"

# Enforce threshold if provided (default 50%)
THRESHOLD="${COVERAGE_THRESHOLD:-50}"
# Try to find a percentage token on the TOTAL line (any % token on that line)
TOTAL_PCT="$(printf "%s" "$REPORT_OUT" | awk '/TOTAL/ { for(i=1;i<=NF;i++) if($i ~ /%$/) {gsub(/%/,"",$i); print $i; exit} }')"
if [ -z "$TOTAL_PCT" ]; then
  # Fallback: find the last percentage-like token anywhere in the report
  TOTAL_PCT="$(printf "%s" "$REPORT_OUT" | grep -oE '[0-9]+(\.[0-9]+)?%' | tail -n1 | tr -d '%')" || true
fi

if [ -z "$TOTAL_PCT" ]; then
  # Fallback 2: parse codecov JSON produced by swift test
  JSON_FILE="$(ls -1 "$BUILD_CODECOV_DIR"/*.json 2>/dev/null | head -n1 || true)"
  if [ -n "$JSON_FILE" ]; then
  TOTAL_PCT="$(python3 - "$JSON_FILE" <<'PY'
import json,sys
try:
  j=json.load(open(sys.argv[1]))
  # navigate to totals.lines.percent if present
  if isinstance(j, dict) and 'totals' in j and isinstance(j['totals'], dict):
    lp=j['totals'].get('lines')
    if isinstance(lp, dict) and 'percent' in lp:
      print(lp['percent'])
      sys.exit(0)
  # recursive search
  def find_percent(x):
    if isinstance(x, dict):
      if 'lines' in x and isinstance(x['lines'], dict) and 'percent' in x['lines']:
        return x['lines']['percent']
      for v in x.values():
        r=find_percent(v)
        if r is not None:
          return r
    if isinstance(x, list):
      for it in x:
        r=find_percent(it)
        if r is not None:
          return r
    return None
  p=find_percent(j)
  if p is not None:
    print(p)
except Exception:
  pass
PY
)" || true
  fi
fi
if [ -z "$TOTAL_PCT" ]; then
  echo "Unable to parse total coverage percentage from llvm-cov report." >&2
  exit 1
fi

# Compare as floating point
below=$(awk -v t="$TOTAL_PCT" -v th="$THRESHOLD" 'BEGIN { if (t+0 < th+0) print 1; else print 0 }')
if [ "$below" -eq 1 ]; then
  echo "Coverage $TOTAL_PCT% is below threshold ${THRESHOLD}%" >&2
  exit 2
else
  echo "Coverage $TOTAL_PCT% meets threshold ${THRESHOLD}%"
fi
