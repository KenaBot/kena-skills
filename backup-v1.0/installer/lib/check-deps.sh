#!/usr/bin/env bash
# check-deps.sh — verify hard-required dependencies for a skill
# Reads dependencies.required from the skill's package.json.

# Get list of required deps for a skill
get_required_deps() {
  local skill_dir="$1"
  local pkg_json="$skill_dir/package.json"
  if [ ! -f "$pkg_json" ]; then
    return 0  # no deps
  fi
  python3 -c "
import json
try:
    with open('$pkg_json') as f:
        data = json.load(f)
    deps = data.get('dependencies', {})
    if isinstance(deps, dict):
        for d in deps.get('required', []):
            print(d)
    elif isinstance(deps, list):
        for d in deps:
            print(d)
except Exception:
    pass
"
}

# Check if a single dep is installed
# Returns 0 if installed, 1 if not
check_dep() {
  local dep="$1"
  case "$dep" in
    node)
      command -v node >/dev/null 2>&1 && return 0 || return 1
      ;;
    python3)
      command -v python3 >/dev/null 2>&1 && return 0 || return 1
      ;;
    uv)
      command -v uv >/dev/null 2>&1 && return 0 || return 1
      ;;
    pip)
      command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1 && return 0 || return 1
      ;;
    npm)
      command -v npm >/dev/null 2>&1 && return 0 || return 1
      ;;
    npx)
      command -v npx >/dev/null 2>&1 && return 0 || return 1
      ;;
    git)
      command -v git >/dev/null 2>&1 && return 0 || return 1
      ;;
    graphify)
      command -v graphify >/dev/null 2>&1 && return 0
      # Fallback: check pipx/uv installs
      [ -d "$HOME/.local/share/uv/tools/graphify" ] && return 0
      [ -d "$HOME/.local/pipx/venvs/graphify" ] && return 0
      return 1
      ;;
    claude-mem)
      # Check if claude-mem MCP server is installed via npx cache
      for dir in "$HOME"/.npm/_npx/*/node_modules/claude-mem; do
        [ -d "$dir" ] && return 0
      done
      # Check Claude plugins
      [ -d "$HOME/.claude/plugins/data/claude-mem-thedotmack" ] && return 0
      return 1
      ;;
    *)
      # Generic: try as command
      command -v "$dep" >/dev/null 2>&1 && return 0 || return 1
      ;;
  esac
}

# Check all required deps for a skill. Echoes names of MISSING deps.
check_skill_deps() {
  local skill_dir="$1"
  local missing=()
  while IFS= read -r dep; do
    if ! check_dep "$dep"; then
      missing+=("$dep")
    fi
  done < <(get_required_deps "$skill_dir")
  printf "%s\n" "${missing[@]}"
}

# Try to install a missing dep
# Returns 0 on success, 1 on failure
install_dep() {
  local dep="$1"
  case "$dep" in
    node|npm|npx)
      err "Cannot auto-install $dep. Install Node.js manually: https://nodejs.org"
      return 1
      ;;
    python3|pip)
      err "Cannot auto-install python3. Install via system package manager."
      return 1
      ;;
    uv)
      info "Installing uv..."
      if command -v curl >/dev/null; then
        curl -LsSf https://astral.sh/uv/install.sh | sh && return 0
      fi
      return 1
      ;;
    graphify)
      info "Installing graphify via uv..."
      if command -v uv >/dev/null 2>&1; then
        uv tool install graphifyy && return 0
      elif command -v pipx >/dev/null 2>&1; then
        pipx install graphifyy && return 0
      else
        err "Install uv or pipx first, then run: uv tool install graphifyy"
        return 1
      fi
      ;;
    claude-mem)
      info "claude-mem is an MCP server installed via Claude plugin marketplace."
      info "See: https://github.com/thedotmack/claude-mem"
      return 1
      ;;
    *)
      err "Don't know how to install '$dep' automatically. Install manually."
      return 1
      ;;
  esac
}
