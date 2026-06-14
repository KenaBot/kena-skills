#!/usr/bin/env bash
# install.sh — bootstrap kena-skills installer
# Install: $ curl -fsSL https://raw.githubusercontent.com/kena/skills/main/installer/install.sh | bash
# Or from a local clone: $ ./installer/install.sh
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.kena-skills}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

# Determine source
if [ -f "./installer/kena-skills" ] && [ -d "./installer/lib" ]; then
  SRC="$(pwd)"
  echo "Installing from local clone: $SRC"
elif [ -n "${KENA_SKILLS_REPO:-}" ]; then
  echo "Cloning $KENA_SKILLS_REPO..."
  git clone --depth 1 "$KENA_SKILLS_REPO" "$INSTALL_DIR"
  SRC="$INSTALL_DIR"
elif [ -d "$INSTALL_DIR" ]; then
  echo "Using existing install at $INSTALL_DIR"
  SRC="$INSTALL_DIR"
else
  echo "ERROR: Cannot determine source." >&2
  echo "Run from a cloned repo, set KENA_SKILLS_REPO, or install manually." >&2
  exit 1
fi

# Create dirs
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# Copy installer files
if [ "$SRC" != "$INSTALL_DIR" ]; then
  cp -r "$SRC/installer/"* "$INSTALL_DIR/"
  echo "  Copied installer files to $INSTALL_DIR"
fi

# Symlink the binary
ln -sf "$INSTALL_DIR/kena-skills" "$BIN_DIR/kena-skills"
echo "  Linked $BIN_DIR/kena-skills -> $INSTALL_DIR/kena-skills"

# PATH check
echo ""
if command -v kena-skills >/dev/null 2>&1; then
  echo "kena-skills is now available in your PATH."
  echo ""
  echo "Try it:"
  echo "  kena-skills --list"
  echo "  kena-skills --help"
else
  echo "NOTE: $BIN_DIR is not in your PATH."
  echo "Add this to your ~/.bashrc or ~/.zshrc:"
  echo ""
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo ""
  echo "Then run: kena-skills --list"
fi
