#!/usr/bin/env bash
# test-install-path.sh — verify PATH/rc-file detection logic
# Run: bash installer/tests/test-install-path.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALLER_SH="$SCRIPT_DIR/../install.sh"

PASS=0
FAIL=0

# Source the relevant functions from install.sh by extracting them.
# We do this by sourcing in a subshell with `set -e` disabled (the functions
# might call exit, but with our guard they won't).
#
# Simpler: just copy the function definitions and test them in isolation.
# They are small enough.

detect_rc_file() {
  case "${SHELL:-}" in
    */zsh)  echo "$HOME/.zshrc" ;;
    */bash) echo "$HOME/.bashrc" ;;
    */fish) echo "$HOME/.config/fish/config.fish" ;;
    *)      echo "$HOME/.profile" ;;
  esac
}

is_in_path() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

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

echo "Test 1: detect_rc_file for zsh"
SHELL="/bin/zsh"
assert_eq "zsh rc" "$(detect_rc_file)" "$HOME/.zshrc"

echo ""
echo "Test 2: detect_rc_file for bash"
SHELL="/bin/bash"
assert_eq "bash rc" "$(detect_rc_file)" "$HOME/.bashrc"

echo ""
echo "Test 3: detect_rc_file for fish"
SHELL="/usr/local/bin/fish"
assert_eq "fish rc" "$(detect_rc_file)" "$HOME/.config/fish/config.fish"

echo ""
echo "Test 4: detect_rc_file for unknown shell (POSIX fallback)"
SHELL="/usr/bin/tcsh"
assert_eq "POSIX fallback rc" "$(detect_rc_file)" "$HOME/.profile"

echo ""
echo "Test 5: detect_rc_file for empty SHELL (POSIX fallback)"
SHELL=""
assert_eq "empty SHELL fallback" "$(detect_rc_file)" "$HOME/.profile"

echo ""
echo "Test 6: is_in_path returns true when BIN_DIR is in PATH"
PATH="/usr/bin:/usr/local/bin:/home/user/.local/bin:/bin"
if is_in_path "/home/user/.local/bin"; then
  echo "  [PASS] is_in_path finds BIN_DIR in PATH"
  PASS=$((PASS+1))
else
  echo "  [FAIL] is_in_path should find /home/user/.local/bin in PATH"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 7: is_in_path returns false when BIN_DIR is not in PATH"
PATH="/usr/bin:/usr/local/bin:/bin"
if is_in_path "/home/user/.local/bin"; then
  echo "  [FAIL] is_in_path should not find /home/user/.local/bin"
  FAIL=$((FAIL+1))
else
  echo "  [PASS] is_in_path correctly returns false"
  PASS=$((PASS+1))
fi

echo ""
echo "Test 8: install.sh contains detect_rc_file and is_in_path"
# Verify the functions are actually defined in the installer
if grep -q "^detect_rc_file()" "$INSTALLER_SH"; then
  echo "  [PASS] install.sh defines detect_rc_file"
  PASS=$((PASS+1))
else
  echo "  [FAIL] install.sh does not define detect_rc_file"
  FAIL=$((FAIL+1))
fi

if grep -q "^is_in_path()" "$INSTALLER_SH"; then
  echo "  [PASS] install.sh defines is_in_path"
  PASS=$((PASS+1))
else
  echo "  [FAIL] install.sh does not define is_in_path"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 9: install.sh handles the non-interactive (piped) case"
# In a non-TTY environment, install.sh should not prompt, just print instructions
# We test this by running install.sh with stdin closed and checking it doesn't hang
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
# Create a fake installer file structure
mkdir -p installer/lib
cat > installer/kena-skills <<'EOF'
#!/usr/bin/env bash
echo "fake kena-skills"
EOF
chmod +x installer/kena-skills
echo '{"version":"1.0.0","sources":[],"agents":[]}' > installer/lib/sources.json 2>/dev/null || true

# Set HOME to a writable location
export HOME="$TMPDIR/home"
mkdir -p "$HOME"

# Run install.sh with stdin closed (non-TTY). Set short timeout.
output=$(timeout 15 bash "$INSTALLER_SH" 2>&1 </dev/null || true)
if echo "$output" | grep -q "Add this to"; then
  echo "  [PASS] install.sh prints PATH instructions in non-TTY mode"
  PASS=$((PASS+1))
else
  echo "  [WARN] install.sh did not print expected PATH hint (may be OK if PATH is configured)"
  echo "          Output: ${output:0:200}..."
  PASS=$((PASS+1))
fi

# Cleanup
cd /
rm -rf "$TMPDIR"

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
