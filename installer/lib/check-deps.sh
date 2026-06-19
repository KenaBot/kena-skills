#!/usr/bin/env bash
# check-deps.sh — verify dependencies (system + MCP)
# MCPs are checked via installer/lib/mcps.json
# System deps are checked via case-statement heuristics

# shellcheck source=platform.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/platform.sh"

# Check if a system dep is installed
check_dep() {
  local dep="$1"
  case "$dep" in
    node|npm|npx|git|python3|pip|uv)
      command -v "$dep" >/dev/null 2>&1 && return 0 || return 1
      ;;
    graphify)
      command -v graphify >/dev/null 2>&1 && return 0
      [ -d "$HOME/.local/share/uv/tools/graphify" ] && return 0
      [ -d "$HOME/.local/pipx/venvs/graphify" ] && return 0
      # Windows paths (Git Bash with /c/Users/... style)
      [ -d "/c/Users/$USER/AppData/Roaming/uv/tools/graphify" ] && return 0
      [ -d "/c/Users/$USER/.local/bin/graphify.exe" ] && return 0
      [ -n "${USERPROFILE:-}" ] && [ -d "$USERPROFILE/AppData/Roaming/uv/tools/graphify" ] && return 0
      return 1
      ;;
    *)
      command -v "$dep" >/dev/null 2>&1 && return 0 || return 1
      ;;
  esac
}

# Try to install a missing system dep
install_dep() {
  local dep="$1"
  case "$dep" in
    node|npm|npx|git)
      err "Cannot auto-install $dep. Install manually."
      return 1
      ;;
    python3|pip)
      err "Cannot auto-install $dep. Install via system package manager."
      return 1
      ;;
    uv)
      info "Installing uv..."
      if command -v curl >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
        return $?
      fi
      return 1
      ;;
    graphify)
      info "Installing graphify via uv..."
      if command -v uv >/dev/null 2>&1; then
        uv tool install graphifyy
        return $?
      elif command -v pipx >/dev/null 2>&1; then
        pipx install graphifyy
        return $?
      fi
      err "Install uv or pipx first, then: uv tool install graphifyy"
      return 1
      ;;
    *)
      err "Don't know how to auto-install '$dep'."
      return 1
      ;;
  esac
}
