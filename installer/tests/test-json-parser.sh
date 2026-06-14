#!/usr/bin/env bash
# test-json-parser.sh — verify json.sh parses agents.json, sources.json, mcps.json
# Run: bash installer/tests/test-json-parser.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/json.sh
source "$SCRIPT_DIR/../lib/json.sh"

PASS=0
FAIL=0

REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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
    echo "  [PASS] $name: $actual contains '$expected'"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] $name: '$actual' does not contain '$expected'"
    FAIL=$((FAIL+1))
fi
}

echo "Test 1: json_array_ids on agents.json"
ids=$(json_array_ids "$REPO_ROOT/installer/lib/agents.json" "agents")
expected=("opencode" "claude" "copilot" "codex" "gemini")
all_found=true
for exp in "${expected[@]}"; do
  if ! echo "$ids" | grep -qx "$exp"; then
    all_found=false
    echo "  [FAIL] Missing agent: $exp"
    FAIL=$((FAIL+1))
  fi
done
if [ "$all_found" = true ]; then
  echo "  [PASS] All 5 agents found: opencode, claude, copilot, codex, gemini"
  PASS=$((PASS+1))
fi

echo ""
echo "Test 2: json_find_by_id for opencode npx_flag"
val=$(json_find_by_id "$REPO_ROOT/installer/lib/agents.json" "agents" "opencode" "npx_flag")
assert_eq "opencode npx_flag" "$val" "opencode"

echo ""
echo "Test 3: json_find_by_id for claude npx_flag"
val=$(json_find_by_id "$REPO_ROOT/installer/lib/agents.json" "agents" "claude" "npx_flag")
assert_eq "claude npx_flag" "$val" "claude-code"

echo ""
echo "Test 4: json_find_by_id for copilot npx_flag"
val=$(json_find_by_id "$REPO_ROOT/installer/lib/agents.json" "agents" "copilot" "npx_flag")
assert_eq "copilot npx_flag" "$val" "github-copilot"

echo ""
echo "Test 5: json_find_by_id for codex npx_flag"
val=$(json_find_by_id "$REPO_ROOT/installer/lib/agents.json" "agents" "codex" "npx_flag")
assert_eq "codex npx_flag" "$val" "codex"

echo ""
echo "Test 6: json_find_by_id for gemini npx_flag"
val=$(json_find_by_id "$REPO_ROOT/installer/lib/agents.json" "agents" "gemini" "npx_flag")
assert_eq "gemini npx_flag" "$val" "gemini-cli"

echo ""
echo "Test 7: json_find_by_id for global_dir"
val=$(json_find_by_id "$REPO_ROOT/installer/lib/agents.json" "agents" "opencode" "global_dir")
assert_eq "opencode global_dir" "$val" ".config/opencode/skills"

echo ""
echo "Test 8: json_array_ids on sources.json"
ids=$(json_array_ids "$REPO_ROOT/installer/lib/sources.json" "sources")
expected_sources=("kena-skills" "juliusbrussee-caveman" "mattpocock-skills")
all_found=true
for exp in "${expected_sources[@]}"; do
  if ! echo "$ids" | grep -qx "$exp"; then
    all_found=false
    echo "  [FAIL] Missing source: $exp"
    FAIL=$((FAIL+1))
  fi
done
if [ "$all_found" = true ]; then
  echo "  [PASS] All 3 sources found"
  PASS=$((PASS+1))
fi

echo ""
echo "Test 9: json_find_by_id for source type"
val=$(json_find_by_id "$REPO_ROOT/installer/lib/sources.json" "sources" "kena-skills" "type")
assert_eq "kena-skills type" "$val" "local"
val=$(json_find_by_id "$REPO_ROOT/installer/lib/sources.json" "sources" "juliusbrussee-caveman" "type")
assert_eq "juliusbrussee-caveman type" "$val" "curl"
val=$(json_find_by_id "$REPO_ROOT/installer/lib/sources.json" "sources" "mattpocock-skills" "type")
assert_eq "mattpocock-skills type" "$val" "npx"

echo ""
echo "Test 10: json_array_ids on mcps.json"
ids=$(json_array_ids "$REPO_ROOT/installer/lib/mcps.json" "servers")
if echo "$ids" | grep -qx "claude-mem"; then
  echo "  [PASS] claude-mem MCP found"
  PASS=$((PASS+1))
else
  echo "  [FAIL] claude-mem MCP missing"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 11: json_find_by_id for MCP install_command"
val=$(json_find_by_id "$REPO_ROOT/installer/lib/mcps.json" "servers" "claude-mem" "install_command")
assert_contains "claude-mem install_command" "$val" "claude-mem install"

echo ""
echo "================================"
echo "Results: $PASS passed, $FAIL failed"
echo "================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
