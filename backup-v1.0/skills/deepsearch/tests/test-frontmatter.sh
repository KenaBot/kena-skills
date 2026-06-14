#!/usr/bin/env bash
# test-frontmatter.sh — validate SKILL.md frontmatter against opencode spec
set -uo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_MD="$SKILL_DIR/SKILL.md"

pass=0
fail=0
errors=()

ok() { pass=$((pass+1)); echo "  [PASS] $1"; }
ko() { fail=$((fail+1)); errors+=("$1"); echo "  [FAIL] $1"; }

echo "=== test-frontmatter.sh ==="
echo ""

# Extract frontmatter using python (more reliable than awk for multi-line YAML)
extract_yaml() {
  python3 -c "
import sys
with open('$SKILL_MD') as f:
    content = f.read()
start = content.find('---')
end = content.find('---', start + 3)
if start == -1 or end == -1:
    sys.exit(1)
print(content[start+3:end].strip())
"
}

frontmatter=$(extract_yaml) || { ko "could not extract frontmatter"; exit 1; }

# Extract description (handles multi-line > format)
extract_description() {
  python3 -c "
import yaml, sys
with open('$SKILL_MD') as f:
    content = f.read()
start = content.find('---')
end = content.find('---', start + 3)
data = yaml.safe_load(content[start+3:end])
print(data.get('description', ''))
"
}

# Check name field
if name=$(echo "$frontmatter" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//'); then
  if [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    ok "name is valid lowercase-hyphen: '$name'"
  else
    ko "name '$name' does not match ^[a-z0-9]+(-[a-z0-9]+)*\$"
  fi
else
  ko "name field missing"
fi

# Check description field exists and length
if desc=$(extract_description 2>/dev/null) && [ -n "$desc" ]; then
  desc_len=${#desc}
  if [ "$desc_len" -le 1024 ] && [ "$desc_len" -ge 50 ]; then
    ok "description length ok: $desc_len chars (50-1024)"
  else
    ko "description length $desc_len out of range [50, 1024]"
  fi
else
  ko "description field missing or could not parse"
fi

# Check description is in English (heuristic: no common Spanish stopwords)
if command -v extract_description &>/dev/null; then
  desc_for_check="$desc"
else
  desc_for_check=$(extract_description 2>/dev/null || echo "")
fi
spanish_pattern='\b(para|con|qué|cómo|este|esta|esto|ese|esa|eso|aquel|aquella)\b'
if echo "$desc_for_check" | grep -iEq "$spanish_pattern"; then
  ko "description contains Spanish stopwords (heuristic)"
else
  ok "description appears to be English (no Spanish stopwords detected)"
fi

# Check FORBIDDEN fields are absent
for forbidden in "trigger:" "allowed-tools:"; do
  if echo "$frontmatter" | grep -qE "^${forbidden}"; then
    ko "forbidden field present: $forbidden (opencode ignores this)"
  else
    ok "forbidden field absent: $forbidden"
  fi
done

# Check RECOMMENDED fields are present
for required in "license:" "compatibility:" "metadata:"; do
  if echo "$frontmatter" | grep -qE "^${required}"; then
    ok "recommended field present: ${required%:}"
  else
    ko "recommended field missing: ${required%:}"
  fi
done

# Check metadata is string-to-string (no array brackets in values)
metadata_block=$(echo "$frontmatter" | awk '/^metadata:/{flag=1; next} flag && /^[^[:space:]]/{flag=0} flag')
if [ -n "$metadata_block" ]; then
  if echo "$metadata_block" | grep -qE ':[[:space:]]*\[|\]:[[:space:]]*$'; then
    ko "metadata contains array values (must be string-to-string)"
  else
    ok "metadata is string-to-string map"
  fi
  # Check version follows semver
  version=$(echo "$metadata_block" | grep -E '^[[:space:]]+version:' | head -1 | sed 's/^[[:space:]]*version:[[:space:]]*//; s/^"//; s/"$//')
  if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
    ok "metadata.version is semver: '$version'"
  else
    ko "metadata.version '$version' is not semver"
  fi
fi

echo ""
echo "=== Result: $pass passed, $fail failed ==="
if [ "$fail" -gt 0 ]; then
  echo "Errors:"
  for e in "${errors[@]}"; do echo "  - $e"; done
  exit 1
fi
exit 0
