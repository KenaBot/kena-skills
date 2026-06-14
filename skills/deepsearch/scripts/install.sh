#!/usr/bin/env bash
# install.sh — install deepsearch as a discoverable skill
# Creates symlinks in all standard skill discovery paths.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_NAME="deepsearch"

SKILL_DIR_REAL="$(cd "$(dirname "$0")/.." && pwd)"

# All standard discovery paths (opencode + claude-code + agents)
# Skip the path that already contains the source
TARGETS=(
  "$HOME/.config/opencode/skills"
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
)

echo "Installing $SKILL_NAME from: $SKILL_DIR_REAL"
echo ""

for parent in "${TARGETS[@]}"; do
  mkdir -p "$parent"
  link="$parent/$SKILL_NAME"
  # Resolve the link target (if it exists) to compare with source
  link_target=""
  if [ -L "$link" ]; then
    link_target="$(readlink -f "$link" 2>/dev/null || true)"
  fi
  # Skip if this link already points to our source (avoid recursive symlink)
  if [ "$link_target" = "$SKILL_DIR_REAL" ]; then
    echo "  [exists] $link (already points to source)"
    continue
  fi
  # Skip if the link is the source directory itself
  link_real="$(readlink -f "$link" 2>/dev/null || true)"
  if [ "$link_real" = "$SKILL_DIR_REAL" ] && [ ! -L "$link" ]; then
    echo "  [skip] $link (is the source directory)"
    continue
  fi
  # Remove existing entry (symlink, file, or empty dir)
  if [ -L "$link" ]; then
    rm -f "$link"
  elif [ -d "$link" ] && [ -z "$(ls -A "$link" 2>/dev/null)" ]; then
    rmdir "$link" 2>/dev/null || rm -rf "$link"
  elif [ -e "$link" ]; then
    echo "  [ERROR] $link exists and is not empty/symlink. Skipping."
    continue
  fi
  ln -s "$SKILL_DIR_REAL" "$link"
  echo "  $link -> $SKILL_DIR_REAL"
done

echo ""
echo "Installation complete."
echo ""
echo "Verify with:"
echo "  ls -la $HOME/.config/opencode/skills/$SKILL_NAME \\"
echo "        $HOME/.claude/skills/$SKILL_NAME \\"
echo "        $HOME/.agents/skills/$SKILL_NAME"
echo ""
echo "Run tests with:"
echo "  $SKILL_DIR/tests/run-all.sh"
