#!/usr/bin/env bash
# caveman-install.sh — minimal post-install for caveman
# No dependencies, no validation. Just confirms the file is in place.
set -euo pipefail

SKILL_NAME="caveman"

echo ""
echo "Validating caveman installation..."
echo ""

# Search common target locations
found=0
for dir in \
  "$HOME/.config/opencode/skills/$SKILL_NAME" \
  "$HOME/.claude/skills/$SKILL_NAME" \
  "$HOME/.copilot/skills/$SKILL_NAME" \
  "$HOME/.codex/skills/$SKILL_NAME" \
  "$HOME/.gemini/skills/$SKILL_NAME" \
  "$HOME/.agents/skills/$SKILL_NAME"; do
  if [ -d "$dir" ]; then
    echo "  [OK] $dir"
    found=$((found+1))
  fi
done

if [ "$found" -eq 0 ]; then
  echo "  [FAIL] caveman not found in any target"
  exit 1
fi

echo ""
echo "Caveman installed in $found location(s)."
echo ""
echo "Usage:"
echo "  Trigger: type 'caveman mode' or '/caveman' to activate"
echo "  Disable: 'stop caveman' or 'normal mode'"
echo ""
