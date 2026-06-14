#!/usr/bin/env bash
# run-all.sh — execute all kena-skills installer tests
# Run: bash installer/tests/run-all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "═══════════════════════════════════════"
echo "  kena-skills installer test suite"
echo "═══════════════════════════════════════"
echo ""

FAILED=0

for test in "$SCRIPT_DIR"/test-*.sh; do
  if [ ! -f "$test" ]; then continue; fi
  name=$(basename "$test")
  echo ""
  echo "▶ Running $name"
  echo "─────────────────────────────────────"
  if bash "$test"; then
    echo "✓ $name"
  else
    echo "✗ $name FAILED"
    FAILED=$((FAILED+1))
  fi
done

echo ""
echo "═══════════════════════════════════════"
if [ "$FAILED" -eq 0 ]; then
  echo "  ✓ All tests passed"
  echo "═══════════════════════════════════════"
  exit 0
else
  echo "  ✗ $FAILED test file(s) failed"
  echo "═══════════════════════════════════════"
  exit 1
fi
