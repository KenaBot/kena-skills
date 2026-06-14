#!/usr/bin/env bash
# test-triggers.sh — verify all aliases appear in description
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_MD="$SKILL_DIR/SKILL.md"

pass=0
fail=0
errors=()

ok() { pass=$((pass+1)); echo "  [PASS] $1"; }
ko() { fail=$((fail+1)); errors+=("$1"); echo "  [FAIL] $1"; }

# Trigger list
TRIGGERS=("deepsearch" "deepsh" "ds" "bug-hunt" "hunt")

# Extract description using python (handles multi-line > format)
desc=$(python3 -c "
import yaml
with open('$SKILL_MD') as f:
    content = f.read()
start = content.find('---')
end = content.find('---', start + 3)
data = yaml.safe_load(content[start+3:end])
print(data.get('description', ''))
" 2>/dev/null)

if [ -z "$desc" ]; then
  echo "=== test-triggers.sh ==="
  echo ""
  echo "  [FAIL] could not extract description"
  exit 1
fi

# Strip newlines for grep
desc_oneline=$(echo "$desc" | tr '\n' ' ' | tr -s ' ')

echo "=== test-triggers.sh ==="
echo ""
echo "Description: ${desc_oneline:0:200}..."
echo ""

for trig in "${TRIGGERS[@]}"; do
  if echo "$desc_oneline" | grep -qi -- "$trig"; then
    ok "trigger '$trig' found in description"
  else
    ko "trigger '$trig' NOT found in description"
  fi
done

# If metadata has triggers key, it must be a string (not array)
frontmatter=$(awk '/^---$/{c++; if(c==2) exit; next} c==1' "$SKILL_MD")
metadata_block=$(echo "$frontmatter" | awk '/^metadata:/{flag=1; next} flag && /^[^[:space:]]/{flag=0} flag')
triggers_value=$(echo "$metadata_block" | grep -E '^[[:space:]]+triggers:' | head -1)
if [ -n "$triggers_value" ]; then
  if echo "$triggers_value" | grep -qE ':[[:space:]]*\['; then
    ko "metadata.triggers is an array (must be string per opencode spec)"
  else
    ok "metadata.triggers is a string (opencode-spec compliant)"
  fi
else
  ok "metadata.triggers absent (acceptable: triggers in description only)"
fi

echo ""
echo "=== Result: $pass passed, $fail failed ==="
if [ "$fail" -gt 0 ]; then
  echo "Errors:"
  for e in "${errors[@]}"; do echo "  - $e"; done
  exit 1
fi
exit 0
