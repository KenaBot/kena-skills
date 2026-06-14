#!/usr/bin/env bash
# juliusbrussee-caveman-install.sh — post-install validation for JuliusBrussee/caveman
# The upstream installer already does all the work; we just confirm it landed.
set -euo pipefail

SKILL_NAME="caveman"

echo ""
echo "Validating JuliusBrussee/caveman installation..."
echo ""

# The upstream installer handles 30+ agents. We just sample-check a few.
found=0
for dir in \
  "$HOME/.config/opencode/skills/$SKILL_NAME" \
  "$HOME/.claude/skills/$SKILL_NAME" \
  "$HOME/.copilot/skills/$SKILL_NAME" \
  "$HOME/.codex/skills/$SKILL_NAME" \
  "$HOME/.gemini/skills/$SKILL_NAME" \
  "$HOME/.agents/skills/$SKILL_NAME" \
  "/c/Users/$USER/.config/opencode/skills/$SKILL_NAME" \
  "/c/Users/$USER/.claude/skills/$SKILL_NAME" \
  "/c/Users/$USER/.copilot/skills/$SKILL_NAME" \
  "/c/Users/$USER/.codex/skills/$SKILL_NAME" \
  "/c/Users/$USER/.gemini/skills/$SKILL_NAME" \
  "/c/Users/$USER/.agents/skills/$SKILL_NAME"; do
  if [ -d "$dir" ]; then
    echo "  [OK] $dir"
    found=$((found+1))
  fi
done

if [ "$found" -eq 0 ]; then
  echo "  [WARN] caveman not found in any sampled target"
  echo "         The upstream installer may have used different paths."
  echo "         Check: ls -la ~/.config/opencode/skills/ | grep caveman"
fi

echo ""
echo "caveman validated in $found sampled location(s)."
echo ""
echo "Usage:"
echo "  Trigger: /caveman or 'caveman mode' or 'talk like caveman'"
echo "  Levels:  /caveman lite|full|ultra|wenyan"
echo "  Disable: 'normal mode'"
echo ""
echo "More info: https://github.com/JuliusBrussee/caveman"
echo ""
