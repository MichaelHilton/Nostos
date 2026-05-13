#!/bin/bash
# Script to run Maestro UI tests for Nostos
# Usage: ./scripts/test-maestro.sh [flow-name]
# If flow-name is provided, runs only that flow, otherwise runs all flows

set -e

# Ensure Maestro is in PATH
export PATH="$PATH:$HOME/.maestro/bin"

# Check if Maestro is installed
if ! command -v maestro &> /dev/null; then
    echo "Error: Maestro is not installed or not in PATH"
    echo "Install with: curl -fsSL https://get.maestro.mobile.dev | bash"
    exit 1
fi

# Get the project root directory (parent of scripts/)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAESTRO_DIR="$PROJECT_ROOT/.maestro"

# Check if .maestro directory exists
if [ ! -d "$MAESTRO_DIR" ]; then
    echo "Error: .maestro directory not found at $MAESTRO_DIR"
    exit 1
fi

# Build the app first
echo "Building Nostos..."
cd "$PROJECT_ROOT"
swift build

# If a specific flow is provided, run only that flow
if [ $# -eq 1 ]; then
    FLOW_NAME="$1"
    FLOW_FILE="$MAESTRO_DIR/$FLOW_NAME.yaml"

    if [ ! -f "$FLOW_FILE" ]; then
        echo "Error: Flow file not found: $FLOW_FILE"
        echo "Available flows:"
        ls -1 "$MAESTRO_DIR"/*.yaml | xargs -n1 basename
        exit 1
    fi

    echo "Running Maestro flow: $FLOW_NAME"
    maestro test "$FLOW_FILE"
else
    # Run all flows in the .maestro directory
    echo "Running all Maestro flows..."
    maestro test "$MAESTRO_DIR"
fi

echo "Maestro tests completed!"
