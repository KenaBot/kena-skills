#!/usr/bin/env bash
# install.sh — bootstrap kena-skills installer
# Install: $ curl -fsSL https://raw.githubusercontent.com/KenaBot/kena-skills/main/installer/install.sh | bash
# Or from a local clone: $ ./installer/install.sh
# Or via npx (once published): $ npx kena-skills ui
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.kena-skills}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
REPO_URL="${KENA_SKILLS_REPO:-https://github.com/KenaBot/kena-skills.git}"
RAW_URL="${KENA_SKILLS_RAW:-https://raw.githubusercontent.com/KenaBot/kena-skills/main}"

# Determine source
if [ -f "./installer/kena-skills" ] && [ -d "./installer/lib" ]; then
  SRC="$(pwd)"
  echo "Installing from local clone: $SRC"
elif [ -d "$INSTALL_DIR/.git" ]; then
  echo "Found existing kena-skills repo at $INSTALL_DIR — pulling latest..."
  git -C "$INSTALL_DIR" pull --ff-only || echo "  (pull failed, using existing checkout)"
  SRC="$INSTALL_DIR"
elif [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/kena-skills" ]; then
  echo "Using existing install at $INSTALL_DIR"
  SRC="$INSTALL_DIR"
else
  echo "Cloning $REPO_URL ..."
  git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
  SRC="$INSTALL_DIR"
fi

# Create dirs
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# Copy installer files (only if SRC != INSTALL_DIR)
if [ "$SRC" != "$INSTALL_DIR" ]; then
  cp -r "$SRC/installer/"* "$INSTALL_DIR/"
  echo "  Copied installer files to $INSTALL_DIR"
fi

# Symlink the binary
ln -sf "$INSTALL_DIR/kena-skills" "$BIN_DIR/kena-skills"
echo "  Linked $BIN_DIR/kena-skills -> $INSTALL_DIR/kena-skills"

# Build the UI (best-effort, only if Node is available and ui/ exists)
if command -v node >/dev/null 2>&1; then
  if [ -d "$INSTALL_DIR/ui" ] && [ ! -d "$INSTALL_DIR/ui/node_modules" ]; then
    echo "  Installing UI dependencies (npm install in ui/)..."
    (cd "$INSTALL_DIR/ui" && npm install --silent --no-audit --no-fund 2>&1 | sed 's/^/    /') || echo "    (npm install failed, UI won't be available)"
  fi
  if [ -d "$INSTALL_DIR/ui" ] && [ -f "$INSTALL_DIR/ui/package.json" ]; then
    echo "  Building UI (tsc)..."
    (cd "$INSTALL_DIR/ui" && npm run build 2>&1 | sed 's/^/    /') || echo "    (UI build failed, falling back to bash TUI)"
  fi
fi

# PATH check
echo ""
if command -v kena-skills >/dev/null 2>&1; then
  echo "kena-skills is now available in your PATH."
  echo ""
  echo "Try it:"
  echo "  kena-skills --list"
  echo "  kena-skills --help"
  echo "  kena-skills ui                       # launch the Ink TUI"
  echo ""
  echo "Upstream: https://github.com/KenaBot/kena-skills"
else
  echo "NOTE: $BIN_DIR is not in your PATH."
  echo "Add this to your ~/.bashrc or ~/.zshrc:"
  echo ""
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
  echo "Then run: kena-skills --list"
  echo ""
  echo "Or use npx (if published to npm):"
  echo "  npx --yes $RAW_URL/installer/install.sh | bash"
  echo ""
  echo "Upstream: https://github.com/KenaBot/kena-skills"
fi
