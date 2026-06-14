#!/usr/bin/env bash
# run-all.sh — run all validation tests for the deepsearch skill
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========================================"
echo "  deepsearch — full validation suite"
echo "========================================"
echo ""

failed=0
for test in "$SCRIPT_DIR"/test-*.sh; do
  name=$(basename "$test")
  if bash "$test"; then
    echo ""
  else
    failed=$((failed+1))
    echo ""
  fi
done

echo "========================================"
if [ "$failed" -eq 0 ]; then
  echo "  All test suites passed."
  echo "========================================"
  exit 0
else
  echo "  $failed test suite(s) FAILED."
  echo "========================================"
  exit 1
fi
