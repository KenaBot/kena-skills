#!/usr/bin/env bash
# test-install-symlink.sh — verify the symlink points to a real executable
# Run: bash installer/tests/test-install-symlink.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER_SH="$SCRIPT_DIR/../install.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

assert_contains() {
  local name="$1"
  local actual="$2"
  local expected="$3"
  if [[ "$actual" == *"$expected"* ]]; then
    echo "  [PASS] $name: contains '$expected'"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] $name: '$actual' does not contain '$expected'"
    FAIL=$((FAIL+1))
  fi
}

echo "Test 1: real installer/kena-skills exists in this repo"
if [ -x "$REPO_ROOT/installer/kena-skills" ]; then
  echo "  [PASS] $REPO_ROOT/installer/kena-skills exists and is executable"
  PASS=$((PASS+1))
else
  echo "  [FAIL] $REPO_ROOT/installer/kena-skills missing or not executable"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 2: install.sh links to \$INSTALL_DIR/installer/kena-skills"
# Extract the TARGET= line from install.sh
target_line=$(grep -E '^TARGET=' "$INSTALLER_SH" || true)
if [ -n "$target_line" ]; then
  assert_contains "install.sh TARGET" "$target_line" "installer/kena-skills"
  # Should NOT just be "\$INSTALL_DIR/kena-skills" (without /installer/)
  if [[ "$target_line" == *'INSTALL_DIR/kena-skills"'* ]] && [[ "$target_line" != *"installer/"* ]]; then
    echo "  [FAIL] install.sh TARGET points to \$INSTALL_DIR/kena-skills (broken symlink bug)"
    FAIL=$((FAIL+1))
  else
    echo "  [PASS] install.sh TARGET does not have the broken pattern"
    PASS=$((PASS+1))
  fi
else
  echo "  [FAIL] install.sh does not define TARGET"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 3: install.sh validates symlink target is executable"
if grep -qF 'if [ ! -x "$TARGET"' "$INSTALLER_SH"; then
  echo "  [PASS] install.sh has post-symlink validation"
  PASS=$((PASS+1))
else
  echo "  [FAIL] install.sh missing -x check on TARGET"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 4: install.sh logs 'Using existing files' for fresh clones"
if grep -q "Using existing files" "$INSTALLER_SH"; then
  echo "  [PASS] install.sh has 'Using existing files' message"
  PASS=$((PASS+1))
else
  echo "  [FAIL] install.sh missing 'Using existing files' log"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 5: simulate fresh install and verify symlink target exists"
# Create a minimal mock repo: installer/kena-skills in a tmp dir
TMPDIR=$(mktemp -d)
INSTALL_DIR="$TMPDIR/.kena-skills"
BIN_DIR="$TMPDIR/.local/bin"
mkdir -p "$INSTALL_DIR/installer" "$BIN_DIR"
cat > "$INSTALL_DIR/installer/kena-skills" <<'EOF'
#!/usr/bin/env bash
echo "fake kena-skills"
EOF
chmod +x "$INSTALL_DIR/installer/kena-skills"

# Simulate the install.sh symlink logic
TARGET="$INSTALL_DIR/installer/kena-skills"
ln -sf "$TARGET" "$BIN_DIR/kena-skills"
echo "  Linked $BIN_DIR/kena-skills -> $TARGET"

# Validate
if [ -x "$TARGET" ] && [ -e "$BIN_DIR/kena-skills" ]; then
  echo "  [PASS] symlink target is executable AND symlink resolves"
  PASS=$((PASS+1))
else
  echo "  [FAIL] symlink or target is broken"
  FAIL=$((FAIL+1))
fi

# Try to execute via the symlink
output=$("$BIN_DIR/kena-skills" 2>&1 || true)
if [ "$output" = "fake kena-skills" ]; then
  echo "  [PASS] symlinked command executes correctly"
  PASS=$((PASS+1))
else
  echo "  [FAIL] symlinked command output: '$output'"
  FAIL=$((FAIL+1))
fi

rm -rf "$TMPDIR"

echo ""
echo "Test 6: simulate the OLD broken symlink (regression check)"
# Make sure the OLD pattern (target = $INSTALL_DIR/kena-skills, not installer/kena-skills)
# would be detected as broken.
TMPDIR=$(mktemp -d)
INSTALL_DIR="$TMPDIR/.kena-skills"
BIN_DIR="$TMPDIR/.local/bin"
mkdir -p "$INSTALL_DIR/installer" "$BIN_DIR"
cat > "$INSTALL_DIR/installer/kena-skills" <<'EOF'
#!/usr/bin/env bash
echo "fake"
EOF
chmod +x "$INSTALL_DIR/installer/kena-skills"

# This is the OLD broken pattern: target = $INSTALL_DIR/kena-skills (no /installer/)
BROKEN_TARGET="$INSTALL_DIR/kena-skills"
ln -sf "$BROKEN_TARGET" "$BIN_DIR/kena-skills"
if [ -e "$BIN_DIR/kena-skills" ]; then
  echo "  [FAIL] old broken pattern unexpectedly worked"
  FAIL=$((FAIL+1))
else
  echo "  [PASS] old broken pattern correctly detected as broken"
  PASS=$((PASS+1))
fi
rm -rf "$TMPDIR"

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
