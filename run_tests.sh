#!/bin/bash
set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to cleanup on exit
# shellcheck disable=SC2317
cleanup() {
    echo "Cleaning up containers..."
    docker compose down -v
}

# Function to handle errors
handle_error() {
    echo -e "${RED}Error: Command failed with status $1${NC}"
    exit "$1"  # Quote $1 to prevent globbing and word splitting
}

# Register cleanup function to run on script exit
trap cleanup EXIT

echo "Building containers..."
docker compose build || handle_error $?

echo "Running tests..."
docker compose run --rm tests pytest -v
TEST_EXIT_CODE=$?

if [ "$TEST_EXIT_CODE" -eq 0 ]; then
    echo -e "${GREEN}All tests passed successfully!${NC}"
else
    echo -e "${RED}Tests failed with exit code $TEST_EXIT_CODE${NC}"
fi

exit "$TEST_EXIT_CODE"
