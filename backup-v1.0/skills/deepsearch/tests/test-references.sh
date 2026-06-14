#!/usr/bin/env bash
# test-references.sh — verify referenced files exist and no hardcoded paths
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_MD="$SKILL_DIR/SKILL.md"

pass=0
fail=0
errors=()

ok() { pass=$((pass+1)); echo "  [PASS] $1"; }
ko() { fail=$((fail+1)); errors+=("$1"); echo "  [FAIL] $1"; }

echo "=== test-references.sh ==="
echo ""

# Extract body (after second ---) using python
body=$(python3 -c "
with open('$SKILL_MD') as f:
    content = f.read()
parts = content.split('---', 2)
if len(parts) >= 3:
    print(parts[2])
" 2>/dev/null)

if [ -z "$body" ]; then
  ko "could not extract body from SKILL.md"
  exit 1
fi

# 1. Check all references/*.md referenced in body exist
referenced=$(echo "$body" | grep -oE 'references/[a-zA-Z0-9_-]+\.md' | sort -u)
if [ -n "$referenced" ]; then
  for ref in $referenced; do
    if [ -f "$SKILL_DIR/$ref" ]; then
      ok "reference exists: $ref"
    else
      ko "reference missing: $ref"
    fi
  done
else
  echo "  [INFO] no references/*.md links found in body"
  pass=$((pass+1))
fi

# 2. Check no hardcoded ~/.claude/ paths in body
if echo "$body" | grep -qE '~/\.claude/'; then
  ko "body contains hardcoded ~/.claude/ path"
else
  ok "no hardcoded ~/.claude/ paths in body"
fi

# 3. Check no hardcoded ~/.agents/skills/ paths in body
if echo "$body" | grep -qE '~/\.agents/skills/'; then
  ko "body contains hardcoded ~/.agents/skills/ path"
else
  ok "no hardcoded ~/.agents/skills/ paths in body"
fi

# 4. Check no hardcoded ~/.config/opencode/ paths in body
if echo "$body" | grep -qE '~/\.config/opencode/'; then
  ko "body contains hardcoded ~/.config/opencode/ path"
else
  ok "no hardcoded ~/.config/opencode/ paths in body"
fi

# 5. Same checks for all references/*.md
for ref in "$SKILL_DIR"/references/*.md; do
  refname=$(basename "$ref")
  if grep -qE '~/\.claude/' "$ref"; then
    ko "$refname contains hardcoded ~/.claude/ path"
  else
    ok "$refname: no hardcoded ~/.claude/ paths"
  fi
  if grep -qE '~/\.agents/skills/' "$ref"; then
    ko "$refname contains hardcoded ~/.agents/skills/ path"
  else
    ok "$refname: no hardcoded ~/.agents/skills/ paths"
  fi
done

echo ""
echo "=== Result: $pass passed, $fail failed ==="
if [ "$fail" -gt 0 ]; then
  echo "Errors:"
  for e in "${errors[@]}"; do echo "  - $e"; done
  exit 1
fi
exit 0
