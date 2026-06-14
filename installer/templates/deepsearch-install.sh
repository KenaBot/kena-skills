#!/usr/bin/env bash
# deepsearch-install.sh — post-install validation for deepsearch skill
# Run after the skill is copied/symlinked to a target directory.
# Args: list of target agent ids that were installed to
set -euo pipefail

SKILL_DIR="${DEEPSEARCH_DIR:-$HOME/.agents/skills/deepsearch}"
TARGETS=("$@")

echo ""
echo "Validating deepsearch installation..."
echo ""

# Locate the skill directory
if [ ! -d "$SKILL_DIR" ]; then
  # Search common locations (Unix + Git Bash on Windows with /c/Users/...)
  for candidate in \
    "$HOME/.config/opencode/skills/deepsearch" \
    "$HOME/.claude/skills/deepsearch" \
    "$HOME/.codex/skills/deepsearch" \
    "$HOME/.agents/skills/deepsearch" \
    "/c/Users/$USER/.config/opencode/skills/deepsearch" \
    "/c/Users/$USER/.claude/skills/deepsearch" \
    "/c/Users/$USER/.codex/skills/deepsearch" \
    "/c/Users/$USER/.agents/skills/deepsearch"; do
    if [ -d "$candidate" ]; then
      SKILL_DIR="$candidate"
      break
    fi
  done
fi

if [ ! -d "$SKILL_DIR" ]; then
  echo "  [FAIL] Could not locate deepsearch in any target directory"
  exit 1
fi
echo "  [OK] Found deepsearch at: $SKILL_DIR"

# Check dependencies
echo ""
echo "Checking dependencies:"

# claude-mem
if for d in "$HOME"/.npm/_npx/*/node_modules/claude-mem; do
     [ -d "$d" ] && exit 0
   done; [ -d "$HOME/.claude/plugins/data/claude-mem-thedotmack" ]; then
  echo "  [OK] claude-mem: found"
else
  echo "  [WARN] claude-mem: not found"
  echo "         Phase 1 (memory recall) will run in degraded mode."
  echo "         Install: see https://github.com/thedotmack/claude-mem"
fi

# graphify
if command -v graphify >/dev/null 2>&1; then
  echo "  [OK] graphify: found (PATH)"
elif [ -d "$HOME/.local/share/uv/tools/graphify" ]; then
  echo "  [OK] graphify: found (uv tool)"
elif [ -d "$HOME/AppData/Roaming/uv/tools/graphify" ] || [ -d "/c/Users/$USER/AppData/Roaming/uv/tools/graphify" ]; then
  echo "  [OK] graphify: found (uv tool, Windows)"
else
  echo "  [WARN] graphify: not found"
  echo "         Phase 3 (code map) will use --no-graph fallback."
  echo "         Install: uv tool install graphifyy"
fi

# python3 (needed by graphify and tests)
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import yaml" 2>/dev/null; then
    echo "  [OK] python3 + pyyaml: found"
  else
    echo "  [WARN] python3 found but pyyaml missing"
    echo "         Install: pip install pyyaml"
  fi
else
  echo "  [WARN] python3: not found (needed for graphify and tests)"
fi

# Verify symlinks in target dirs
echo ""
echo "Verifying target installations:"
for target in "${TARGETS[@]}"; do
  case "$target" in
    opencode)      link="$HOME/.config/opencode/skills/deepsearch";;
    claude-code)   link="$HOME/.claude/skills/deepsearch";;
    codex)         link="$HOME/.codex/skills/deepsearch";;
    agents)        link="$HOME/.agents/skills/deepsearch";;
    *)
                  # Windows fallback (Git Bash style /c/Users/...)
                  if [ -n "${MSYSTEM:-}" ] && [ -n "${USER:-}" ]; then
                    link="/c/Users/$USER/.agents/skills/deepsearch"
                  else
                    link="$HOME/.agents/skills/deepsearch"
                  fi
                  ;;
  esac

  if [ -L "$link" ] && [ -d "$link" ]; then
    local_target=$(resolve_symlink "$link")
    echo "  [OK] $target: $link -> $local_target"
  elif [ -d "$link" ]; then
    echo "  [OK] $target: $link (real directory)"
  else
    echo "  [FAIL] $target: $link missing"
  fi
done

# Run validation tests if available
echo ""
if [ -d "$SKILL_DIR/tests" ] && [ -f "$SKILL_DIR/tests/run-all.sh" ]; then
  echo "Running validation tests..."
  if bash "$SKILL_DIR/tests/run-all.sh" 2>&1 | tail -5; then
    echo "  [OK] Tests passed"
  else
    echo "  [WARN] Some tests failed (non-blocking)"
  fi
else
  echo "  [INFO] No tests directory found, skipping validation"
fi

echo ""
echo "Deepsearch installation validated."
echo ""
echo "Quick start:"
echo "  deepsearch --help"
echo "  deepsearch bug . --auto"
echo "  deepsearch flow --agents 1"
echo ""
