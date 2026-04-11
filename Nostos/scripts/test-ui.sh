#!/usr/bin/env bash
set -euo pipefail

# Run the macOS UI test target from Xcode.
# Usage:
#   ./scripts/test-ui.sh
#   ./scripts/test-ui.sh testClicksPrimaryButtonsAcrossTheApp
#   ./scripts/test-ui.sh testClicksPrimaryButtonsAcrossTheApp testSetupScreenChooseVaultButton

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEME="Nostos"
DESTINATION="platform=macOS"
TEST_TARGET="NostosUITests"

cd "$ROOT_DIR"

ARGS=(test -scheme "$SCHEME" -destination "$DESTINATION")

if [ "$#" -eq 0 ]; then
  ARGS+=("-only-testing:${TEST_TARGET}")
else
  for test_name in "$@"; do
    ARGS+=("-only-testing:${TEST_TARGET}/${TEST_TARGET}/${test_name}")
  done
fi

echo "Running UI tests: xcodebuild ${ARGS[*]}"
exec xcodebuild "${ARGS[@]}"
