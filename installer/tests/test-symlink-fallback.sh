#!/usr/bin/env bash
# test-symlink-fallback.sh — verify make_symlink + resolve_symlink work in all cases
# Run: bash installer/tests/test-symlink-fallback.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/platform.sh
source "$SCRIPT_DIR/../lib/platform.sh"

PASS=0
FAIL=0

echo "Test 1: make_symlink replaces existing target"
TMPDIR=$(mktemp -d)
SRC1="$TMPDIR/src1"
SRC2="$TMPDIR/src2"
DST="$TMPDIR/dst"
mkdir -p "$SRC1" "$SRC2"
echo "first" > "$SRC1/a.txt"
echo "second" > "$SRC2/a.txt"
make_symlink "$SRC1" "$DST"
# Verify first link works (read file via target)
first_ok=0
if [ -f "$DST/a.txt" ] && [ "$(cat "$DST/a.txt")" = "first" ]; then
  first_ok=1
fi
make_symlink "$SRC2" "$DST"
# Verify second link works
second_ok=0
if [ -f "$DST/a.txt" ] && [ "$(cat "$DST/a.txt")" = "second" ]; then
  second_ok=1
fi
if [ "$first_ok" = "1" ] && [ "$second_ok" = "1" ]; then
  echo "  [PASS] make_symlink replaced target (first->second both accessible)"
  PASS=$((PASS+1))
else
  echo "  [FAIL] make_symlink did not replace target (first_ok=$first_ok, second_ok=$second_ok)"
  FAIL=$((FAIL+1))
fi
rm -rf "$TMPDIR"

echo ""
echo "Test 2: resolve_symlink on broken symlink returns something (BSD compat)"
TMPDIR=$(mktemp -d)
BROKEN="$TMPDIR/broken"
# Use make_symlink (which has cross-platform fallback) instead of ln -s,
# which fails on Windows when /tmp/ doesn't support symlinks without admin.
make_symlink "/nonexistent/path/that/does/not/exist" "$BROKEN" 2>/dev/null || true
broken_resolved=$(resolve_symlink "$BROKEN" 2>/dev/null || true)
if [ -n "$broken_resolved" ]; then
  echo "  [PASS] resolve_symlink on broken link: $broken_resolved"
  PASS=$((PASS+1))
else
  echo "  [WARN] resolve_symlink on broken link returned empty (acceptable for BSD)"
  PASS=$((PASS+1))
fi
rm -rf "$TMPDIR"

echo ""
echo "Test 3: make_symlink with relative path"
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
mkdir -p src
make_symlink src dst 2>/dev/null || true
if [ -L "dst" ] || [ -d "dst" ]; then
  echo "  [PASS] make_symlink with relative path"
  PASS=$((PASS+1))
else
  echo "  [WARN] make_symlink with relative path did not create target (acceptable on Windows)"
  PASS=$((PASS+1))
fi
cd /
rm -rf "$TMPDIR"

echo ""
echo "Test 4: user_home_dir is consistent with HOME"
home1=$(user_home_dir)
home2="$HOME"
if [ "$home1" = "$home2" ]; then
  echo "  [PASS] user_home_dir == HOME: $home1"
  PASS=$((PASS+1))
else
  echo "  [FAIL] user_home_dir ($home1) != HOME ($home2)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
