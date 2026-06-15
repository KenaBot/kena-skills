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

# Detect platform: when running under Git Bash on Windows, MSYSTEM is set.
# When running under WSL, WSL_DISTRO_NAME is set.
if [ -n "${MSYSTEM:-}" ]; then
  PLATFORM="windows-git-bash"
  # Git Bash on Windows: HOME is set, but ~/.local/bin may not be on PATH
  # Use LOCALAPPDATA if available, fall back to HOME/.local/bin
  if [ -n "${LOCALAPPDATA:-}" ]; then
    BIN_DIR="${BIN_DIR:-$LOCALAPPDATA/kena-skills/bin}"
    INSTALL_DIR="${INSTALL_DIR:-$LOCALAPPDATA/kena-skills}"
  fi
elif [ -n "${WSL_DISTRO_NAME:-}" ]; then
  PLATFORM="wsl"
  # WSL: standard Unix paths
else
  PLATFORM="unix"
fi

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

echo "  Detected platform: $PLATFORM"

# Create dirs
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# Copy installer files (only if SRC != INSTALL_DIR). We preserve the
# installer/ subdirectory structure so the file layout is identical
# whether the install runs from a fresh git clone OR a local copy.
# This guarantees the symlink target below is consistent across paths.
if [ "$SRC" != "$INSTALL_DIR" ]; then
  cp -r "$SRC/installer" "$INSTALL_DIR/"
  echo "  Copied installer files to $INSTALL_DIR/installer/"
else
  echo "  Using existing files in $INSTALL_DIR"
fi

# Symlink the binary. The actual entry point lives at
# $INSTALL_DIR/installer/kena-skills. This is consistent whether the
# install ran from a fresh git clone (where the repo already has
# installer/kena-skills) or a local copy (where install.sh copies
# the installer/ subdir preserving the structure).
TARGET="$INSTALL_DIR/installer/kena-skills"
ln -sf "$TARGET" "$BIN_DIR/kena-skills"
echo "  Linked $BIN_DIR/kena-skills -> $TARGET"

# Validate the symlink points to an actual executable. This catches drift
# between the repo structure and the installer's expectations.
if [ ! -x "$TARGET" ]; then
  echo ""
  echo "  ✗ ERROR: kena-skills binary missing or not executable at $TARGET" >&2
  echo "    The cloned repo may be incomplete. Try:" >&2
  echo "      rm -rf $INSTALL_DIR && curl ... | bash" >&2
  exit 1
fi

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

# ---- PATH auto-configuration ----
# Detect the user's shell, the corresponding rc file, and whether $BIN_DIR
# is already in PATH. If not, offer to add it (interactive: prompt; piped:
# just print). Always apply to the current shell via `export` so the
# `kena-skills` command works in the same terminal session.

detect_rc_file() {
  case "${SHELL:-}" in
    */zsh)  echo "$HOME/.zshrc" ;;
    */bash) echo "$HOME/.bashrc" ;;
    */fish) echo "$HOME/.config/fish/config.fish" ;;
    *)      echo "$HOME/.profile" ;;  # POSIX fallback (ksh, dash, etc.)
  esac
}

is_in_path() {
  case ":$PATH:" in
    *":$BIN_DIR:"*) return 0 ;;
    *) return 1 ;;
  esac
}

RC_FILE="$(detect_rc_file)"
PATH_LINE="export PATH=\"\$HOME/.local/bin:\$PATH\""
FISH_LINE="fish_add_path \$HOME/.local/bin"

echo ""
if is_in_path; then
  echo "✓ $BIN_DIR is in your PATH."
  if command -v kena-skills >/dev/null 2>&1; then
    echo ""
    echo "kena-skills is ready. Try it:"
    echo "  kena-skills --list"
    echo "  kena-skills --help"
    echo "  kena-skills ui                       # launch the Ink TUI"
  fi
  echo ""
  echo "Upstream: https://github.com/KenaBot/kena-skills"
else
  # Apply to current shell so the user can run kena-skills right away
  export PATH="$HOME/.local/bin:$PATH"
  if command -v kena-skills >/dev/null 2>&1; then
    echo "✓ kena-skills is now available in this session."
  fi
  echo ""
  echo "NOTE: $BIN_DIR is not in your shell's startup PATH."
  echo ""

  if [ -n "$RC_FILE" ] && [ -f "$RC_FILE" ] && grep -qF '$HOME/.local/bin' "$RC_FILE" 2>/dev/null; then
    # Already in rc file (idempotent)
    echo "  Found existing PATH config in $RC_FILE."
    echo "  Restart your shell (or run: source $RC_FILE) to enable kena-skills."
  elif [ -t 0 ]; then
    # Interactive: ask before adding
    printf "  Add kena-skills to %s? [y/N] " "$RC_FILE"
    read -r ans
    case "$ans" in
      y|yes|Y)
        # Detect fish (different syntax)
        if [ "${SHELL:-}" = */fish ]; then
          printf '\n# Added by kena-skills installer\n%s\n' "$FISH_LINE" >> "$RC_FILE"
        else
          printf '\n# Added by kena-skills installer\n%s\n' "$PATH_LINE" >> "$RC_FILE"
        fi
        echo "  ✓ Added to $RC_FILE"
        echo "  Restart your shell (or run: source $RC_FILE) to make it persistent."
        ;;
      *)
        echo "  Skipped. To enable later, add this to $RC_FILE:"
        if [ "${SHELL:-}" = */fish ]; then
          echo "    $FISH_LINE"
        else
          echo "    $PATH_LINE"
        fi
        ;;
    esac
  else
    # Non-interactive (piped): just print
    echo "  Add this to $RC_FILE to make it persistent:"
    if [ "${SHELL:-}" = */fish ]; then
      echo "    $FISH_LINE"
    else
      echo "    $PATH_LINE"
    fi
    echo ""
    echo "  Or run in this session only:"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
  echo ""
  echo "Then run: kena-skills --list"
  echo ""
  echo "Upstream: https://github.com/KenaBot/kena-skills"
fi
