#!/usr/bin/env bash
# test-windows-detection.sh — verify Windows path resolution helpers
# Run: bash installer/tests/test-windows-detection.sh

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

echo "Test 1: resolve_global_dir on Unix uses HOME"
# Simulate Unix OS
KENA_OS="linux"
ensure_home
HOME="/home/testuser"
result=$(resolve_global_dir ".config/opencode/skills" "%USERPROFILE%\\.config\\opencode\\skills")
assert_eq "Unix path" "$result" "/home/testuser/.config/opencode/skills"

echo ""
echo "Test 2: resolve_global_dir on Windows expands USERPROFILE"
# Simulate Windows OS with USERPROFILE set
KENA_OS="windows"
USERPROFILE="C:\\Users\\TestUser"
HOME="/c/Users/TestUser"  # Git Bash may have already set HOME
result=$(resolve_global_dir ".config/opencode/skills" "%USERPROFILE%\\.config\\opencode\\skills")
if [[ "$result" == *"TestUser"* ]] && [[ "$result" == *".config"* ]] && [[ "$result" == *"opencode"* ]]; then
  echo "  [PASS] Windows path: $result"
  PASS=$((PASS+1))
else
  echo "  [FAIL] Windows path missing components: $result"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 3: resolve_global_dir on Windows without USERPROFILE falls back to HOME"
unset USERPROFILE
KENA_OS="windows"
HOME="/c/Users/TestUser"
result=$(resolve_global_dir ".config/opencode/skills" "%USERPROFILE%\\.config\\opencode\\skills")
assert_eq "Windows fallback" "$result" "/c/Users/TestUser/.config/opencode/skills"

echo ""
echo "Test 4: resolve_global_dir with empty windows_path always uses HOME"
KENA_OS="linux"
HOME="/home/testuser"
result=$(resolve_global_dir ".claude/skills" "")
assert_eq "Empty windows path" "$result" "/home/testuser/.claude/skills"

echo ""
echo "Test 5: KENA_HAS_GIT_BASH is a valid boolean"
detect_windows_runtime
if [ "$KENA_HAS_GIT_BASH" = "true" ] || [ "$KENA_HAS_GIT_BASH" = "false" ]; then
  echo "  [PASS] KENA_HAS_GIT_BASH: $KENA_HAS_GIT_BASH"
  PASS=$((PASS+1))
else
  echo "  [FAIL] KENA_HAS_GIT_BASH invalid: $KENA_HAS_GIT_BASH"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 6: KENA_HAS_WSL is a valid boolean"
if [ "$KENA_HAS_WSL" = "true" ] || [ "$KENA_HAS_WSL" = "false" ]; then
  echo "  [PASS] KENA_HAS_WSL: $KENA_HAS_WSL"
  PASS=$((PASS+1))
else
  echo "  [FAIL] KENA_HAS_WSL invalid: $KENA_HAS_WSL"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 7: agents.json has windows_global_dir for all 5 agents"
# Source json.sh
# shellcheck source=../lib/json.sh
source "$SCRIPT_DIR/../lib/json.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
all_have=true
for agent in opencode claude copilot codex gemini; do
  val=$(json_find_by_id "$REPO_ROOT/installer/lib/agents.json" "agents" "$agent" "windows_global_dir")
  if [ -z "$val" ]; then
    all_have=false
    echo "  [FAIL] Missing windows_global_dir for $agent"
    FAIL=$((FAIL+1))
  fi
done
if [ "$all_have" = true ]; then
  echo "  [PASS] All 5 agents have windows_global_dir"
  PASS=$((PASS+1))
fi

echo ""
echo "Test 8: windows_global_dir values are non-empty and start with %USERPROFILE%"
all_valid=true
for agent in opencode claude copilot codex gemini; do
  val=$(json_find_by_id "$REPO_ROOT/installer/lib/agents.json" "agents" "$agent" "windows_global_dir")
  if [[ ! "$val" == *"USERPROFILE"* ]]; then
    all_valid=false
    echo "  [FAIL] $agent windows_global_dir doesn't contain USERPROFILE: $val"
    FAIL=$((FAIL+1))
  fi
done
if [ "$all_valid" = true ]; then
  echo "  [PASS] All windows_global_dir values contain USERPROFILE"
  PASS=$((PASS+1))
fi

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
