#!/usr/bin/env bash
# test-pkgjson-parser.sh — verify bash-pure package.json parser doesn't
# leak strings from sibling keys into the 'required' array.
# Run: bash installer/tests/test-pkgjson-parser.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

PASS=0
FAIL=0

# Test the parser in isolation by copying the relevant function.
test_parse_required() {
  local pkg_json="$1"
  local -a required=()
  local in_required=0
  local bracket_depth=0

  while IFS= read -r line; do
    if [[ "$in_required" -eq 0 ]] && [[ "$line" =~ \"required\"[[:space:]]*:[[:space:]]*\[ ]]; then
      in_required=1
      local opens_first=$(echo "$line" | tr -cd '[' | wc -c)
      local closes_first=$(echo "$line" | tr -cd ']' | wc -c)
      bracket_depth=$((opens_first - closes_first))
      local rest="${line#*\[}"
      while [[ "$rest" =~ \"([^\"]+)\" ]]; do
        required+=("${BASH_REMATCH[1]}")
        rest="${rest#*\"${BASH_REMATCH[1]}\"}"
      done
      [ "$bracket_depth" -le 0 ] && break
      continue
    fi
    [ "$in_required" -eq 0 ] && continue
    local opens=$(echo "$line" | tr -cd '[' | wc -c)
    local closes=$(echo "$line" | tr -cd ']' | wc -c)
    bracket_depth=$((bracket_depth + opens - closes))
    [ "$bracket_depth" -le 0 ] && break
    if [[ "$line" =~ \"([^\"]+)\" ]]; then
      required+=("${BASH_REMATCH[1]}")
    fi
  done < "$pkg_json"

  printf '%s\n' "${required[@]}"
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

assert_not_contains() {
  local name="$1"
  local actual="$2"
  local forbidden="$3"
  if [[ "$actual" != *"$forbidden"* ]]; then
    echo "  [PASS] $name: '$actual' does NOT contain '$forbidden'"
    PASS=$((PASS+1))
  else
    echo "  [FAIL] $name: '$actual' contains forbidden '$forbidden'"
    FAIL=$((FAIL+1))
  fi
}

echo "Test 1: real skills/deepsearch/package.json"
result=$(test_parse_required "$REPO_ROOT/skills/deepsearch/package.json")
echo "  result: $result"
assert_contains "deepsearch has claude-mem" "$result" "claude-mem"
assert_contains "deepsearch has graphify" "$result" "graphify"
assert_not_contains "no leak from optional" "$result" "node"
assert_not_contains "no leak from optional" "$result" "python3"
assert_not_contains "no leak from optional" "$result" "uv"
assert_not_contains "no leak from parallelism" "$result" "default_agents"
assert_not_contains "no leak from parallelism" "$result" "max_agents"
assert_not_contains "no leak from parallelism" "$result" "min_agents"
assert_not_contains "no leak from parallelism" "$result" "subagent_type"
assert_not_contains "no leak from parallelism" "$result" "strategy"

echo ""
echo "Test 2: synthetic single-line array"
TMPDIR=$(mktemp -d)
cat > "$TMPDIR/single.json" <<'EOF'
{
  "dependencies": {
    "required": ["a", "b", "c"]
  }
}
EOF
result=$(test_parse_required "$TMPDIR/single.json")
assert_contains "single-line a" "$result" "a"
assert_contains "single-line b" "$result" "b"
assert_contains "single-line c" "$result" "c"

echo ""
echo "Test 3: synthetic multi-line array"
cat > "$TMPDIR/multi.json" <<'EOF'
{
  "dependencies": {
    "required": [
      "alpha",
      "beta",
      "gamma"
    ]
  }
}
EOF
result=$(test_parse_required "$TMPDIR/multi.json")
assert_contains "multi-line alpha" "$result" "alpha"
assert_contains "multi-line beta" "$result" "beta"
assert_contains "multi-line gamma" "$result" "gamma"

echo ""
echo "Test 4: synthetic with siblings (the original bug)"
cat > "$TMPDIR/siblings.json" <<'EOF'
{
  "dependencies": {
    "required": ["x", "y"],
    "optional": ["foo", "bar"]
  },
  "parallelism": {
    "default_agents": 5,
    "subagent_type": "explore"
  }
}
EOF
result=$(test_parse_required "$TMPDIR/siblings.json")
assert_contains "siblings x" "$result" "x"
assert_contains "siblings y" "$result" "y"
assert_not_contains "no leak foo" "$result" "foo"
assert_not_contains "no leak bar" "$result" "bar"
assert_not_contains "no leak default_agents" "$result" "default_agents"
assert_not_contains "no leak subagent_type" "$result" "subagent_type"

echo ""
echo "Test 5: empty required array"
cat > "$TMPDIR/empty.json" <<'EOF'
{
  "dependencies": {
    "required": []
  }
}
EOF
result=$(test_parse_required "$TMPDIR/empty.json")
if [ -z "$result" ]; then
  echo "  [PASS] empty array: no items captured"
  PASS=$((PASS+1))
else
  echo "  [FAIL] empty array should produce no items, got: $result"
  FAIL=$((FAIL+1))
fi

echo ""
echo "Test 6: no required key at all"
cat > "$TMPDIR/none.json" <<'EOF'
{
  "name": "foo",
  "version": "1.0.0"
}
EOF
result=$(test_parse_required "$TMPDIR/none.json")
if [ -z "$result" ]; then
  echo "  [PASS] no required key: no items captured"
  PASS=$((PASS+1))
else
  echo "  [FAIL] expected empty, got: $result"
  FAIL=$((FAIL+1))
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
