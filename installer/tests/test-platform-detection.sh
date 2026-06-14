#!/usr/bin/env bash
# test-platform-detection.sh — verify platform.sh helpers
# Run: bash installer/tests/test-platform-detection.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/platform.sh
source "$SCRIPT_DIR/../lib/platform.sh"

PASS=0
FAIL=0

assert_eq() {
  local name="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  [PASS] $name: $actual"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] $name: got '$actual', expected '$expected'"
    FAIL=$((FAIL+1))
  fi
}

assert_in() {
  local name="$1"
  local actual="$2"
  shift 2
  local item
  for item in "$@"; do
    if [ "$actual" = "$item" ]; then
      echo "  [PASS] $name: $actual"
      PASS=$((PASS+1))
      return 0
    fi
  done
  echo "  [FAIL] $name: got '$actual', expected one of: $*"
  FAIL=$((FAIL+1))
}

echo "Test 1: detect_os returns a known value"
detect_os
assert_in "KENA_OS" "$KENA_OS" "linux" "macos" "wsl" "windows" "unknown"

echo ""
echo "Test 2: detect_shell returns a known value"
detect_shell
assert_in "KENA_SHELL" "$KENA_SHELL" "bash" "zsh" "sh" "unknown"

echo ""
echo "Test 3: ensure_home populates HOME"
unset HOME
ensure_home
if [ -n "$HOME" ]; then
  echo "  [PASS] HOME is set: $HOME"
  PASS=$((PASS+1))
else
  echo "  [FAIL] HOME is still empty"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 4: user_home_dir echoes HOME"
local_home=$(user_home_dir)
assert_eq "user_home_dir" "$local_home" "$HOME"

echo ""
echo "Test 5: resolve_symlink on a regular file"
TMPFILE=$(mktemp)
echo "test" > "$TMPFILE"
resolved=$(resolve_symlink "$TMPFILE")
if [ -n "$resolved" ] && [ -f "$resolved" ]; then
  echo "  [PASS] resolve_symlink: $TMPFILE -> $resolved"
  PASS=$((PASS+1))
else
  echo "  [FAIL] resolve_symlink failed for $TMPFILE"
  FAIL=$((FAIL+1))
fi
rm -f "$TMPFILE"

echo ""
echo "Test 6: resolve_symlink on a symlink"
TMPFILE=$(mktemp)
TMPLINK=$(mktemp -u)
ln -s "$TMPFILE" "$TMPLINK"
resolved=$(resolve_symlink "$TMPLINK")
if [ -n "$resolved" ] && [ -f "$resolved" ]; then
  echo "  [PASS] resolve_symlink (symlink): $TMPLINK -> $resolved"
  PASS=$((PASS+1))
else
  echo "  [FAIL] resolve_symlink failed for symlink $TMPLINK"
  FAIL=$((FAIL+1))
fi
rm -f "$TMPFILE" "$TMPLINK"

echo ""
echo "Test 7: make_symlink creates a working symlink"
TMPDIR=$(mktemp -d)
SRC="$TMPDIR/src"
DST="$TMPDIR/dst"
mkdir -p "$SRC"
echo "data" > "$SRC/file.txt"
make_symlink "$SRC" "$DST"
if [ -L "$DST" ] || [ -d "$DST" ]; then
  echo "  [PASS] make_symlink created target at $DST"
  PASS=$((PASS+1))
else
  echo "  [FAIL] make_symlink failed to create target"
  FAIL=$((FAIL+1))
fi
rm -rf "$TMPDIR"

echo ""
echo "Test 8: path_join uses / on Unix and \\ on Windows"
if [ "$KENA_OS" = "windows" ]; then
  joined=$(path_join "a" "b" "c")
  assert_eq "path_join windows" "$joined" "a\b\c"
else
  joined=$(path_join "a" "b" "c")
  assert_eq "path_join unix" "$joined" "a/b/c"
fi

echo ""
echo "Test 9: path_join handles trailing/leading separators"
joined=$(path_join "a/" "/b" "c")
if [ "$KENA_OS" = "windows" ]; then
  assert_eq "path_join trim" "$joined" "a\b\c"
else
  assert_eq "path_join trim" "$joined" "a/b/c"
fi

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
