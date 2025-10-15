#!/usr/bin/env bash
set -euo pipefail

fail_trap() {
  rc=$?
  echo "Error: CI step failed with exit code ${rc}" >&2
  exit ${rc}
}
trap fail_trap EXIT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

echo "Cleaning existing build directory..."
rm -rf build

echo "Creating build directory..."
mkdir build
cd build

echo "Configuring project with CMake..."
cmake ..

echo "Building project..."
cmake --build .

echo "Running tests..."
ctest --output-on-failure

echo "CI script completed successfully."
trap - EXIT
exit 0
