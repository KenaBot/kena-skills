#!/usr/bin/env bash
# mattpocock-install.sh — post-install validation for mattpocock/skills
# The npx installer handles the heavy lifting; we verify a sample of skills.
set -euo pipefail

echo ""
echo "Validating mattpocock/skills installation..."
echo ""

# Check that the canonical skills landed somewhere
declare -a SAMPLE_SKILLS=("diagnosing-bugs" "grill-me")
found=0

for skill in "${SAMPLE_SKILLS[@]}"; do
  for dir in \
    "$HOME/.config/opencode/skills/$skill" \
    "$HOME/.claude/skills/$skill" \
    "$HOME/.copilot/skills/$skill" \
    "$HOME/.codex/skills/$skill" \
    "$HOME/.gemini/skills/$skill" \
    "$HOME/.agents/skills/$skill" \
    "/c/Users/$USER/.config/opencode/skills/$skill" \
    "/c/Users/$USER/.claude/skills/$skill" \
    "/c/Users/$USER/.copilot/skills/$skill" \
    "/c/Users/$USER/.codex/skills/$skill" \
    "/c/Users/$USER/.gemini/skills/$skill" \
    "/c/Users/$USER/.agents/skills/$skill"; do
    if [ -d "$dir" ] || [ -L "$dir" ]; then
      echo "  [OK] $skill: $dir"
      found=$((found+1))
      break
    fi
  done
done

if [ "$found" -eq 0 ]; then
  echo "  [WARN] No sample skills found"
  echo "         The npx installer may have used different paths or skipped some skills."
fi

echo ""
echo "mattpocock sample skills validated: $found"
echo ""
echo "More info: https://github.com/mattpocock/skills"
echo ""
