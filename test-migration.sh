#!/usr/bin/env bash
#
# Test script for PostgreSQL migration functionality
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Testing PostgreSQL migration components..."
echo

# Test 1: Check if all required files exist
echo "=== Test 1: File Existence ==="
files_to_check=(
  "lib/common.sh"
  "lib/database.sh"
  "lib/config.sh"
  "migrate-postgres.sh"
  "templates/selfhosted-postgres.yaml"
)

for file in "${files_to_check[@]}"; do
  if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
    echo "✓ $file exists"
  else
    echo "✗ $file missing"
  fi
done
echo

# Test 2: Syntax check
echo "=== Test 2: Syntax Validation ==="
scripts_to_check=(
  "lib/database.sh"
  "migrate-postgres.sh"
  "donetick.sh"
)

for script in "${scripts_to_check[@]}"; do
  if bash -n "${SCRIPT_DIR}/${script}" 2>/dev/null; then
    echo "✓ $script syntax OK"
  else
    echo "✗ $script syntax error"
    bash -n "${SCRIPT_DIR}/${script}"
  fi
done
echo

# Test 3: Help output test
echo "=== Test 3: Help Output ==="
echo "Main script help:"
bash "${SCRIPT_DIR}/donetick.sh" --help | head -10
echo

echo "Migration script help:"
bash "${SCRIPT_DIR}/migrate-postgres.sh" --help | head -10
echo

# Test 4: Dry run test
echo "=== Test 4: Migration Dry Run ==="
bash "${SCRIPT_DIR}/migrate-postgres.sh" --dry-run --host 192.168.86.31 --database donetick --username postgres
echo

echo "All tests completed!"
