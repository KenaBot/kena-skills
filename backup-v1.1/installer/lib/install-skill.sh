#!/usr/bin/env bash
# install-skill.sh — install a single skill to one or more targets
# Bash-pure implementation. No python. Uses installer/lib/json.sh for registry access.
#
# Public API:
#   install_skill_to_targets <skill> <targets_csv> <skills_dir> <repo_name> <deps_auto> <dry_run>

# Install to all targets specified in CSV
install_skill_to_targets() {
  local skill="$1"
  local targets_csv="$2"
  local skills_dir="$3"
  local repo_name="$4"
  local deps_auto="$5"
  local dry_run="$6"

  local skill_path="$skills_dir/$skill"
  if [ ! -d "$skill_path" ]; then
    err "Skill not found: $skill_path"
    return 1
  fi

  # Step 1: check dependencies (only if --install-deps or via prompt)
  if [ "$deps_auto" = "true" ]; then
    check_and_install_deps "$skill_path"
  fi

  # Step 2: install to each target
  IFS=',' read -ra TARGETS <<< "$targets_csv"
  local failed=0
  local succeeded=0
  for target in "${TARGETS[@]}"; do
    target="$(echo "$target" | xargs)"  # trim whitespace
    if [ -z "$target" ]; then continue; fi

    if install_to_target "$skill" "$skill_path" "$target" "$repo_name" "$dry_run"; then
      succeeded=$((succeeded+1))
    else
      failed=$((failed+1))
    fi
  done

  # Step 3: post-install template
  local template
  template="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates/${skill}-install.sh"
  if [ -f "$template" ] && [ "$dry_run" = "false" ]; then
    info "Running post-install template for $skill..."
    if bash "$template" "${TARGETS[@]}" 2>&1; then
      ok "Post-install for $skill complete"
    else
      warn "Post-install template returned non-zero (continuing)"
    fi
  fi

  echo ""
  if [ "$failed" -eq 0 ]; then
    ok "Installed '$skill' to $succeeded target(s): $targets_csv"
  else
    err "$failed target(s) failed for skill '$skill'"
    return 1
  fi
}

# Check and (optionally) install dependencies for a skill
# Reads dependencies.required from package.json using simple JSON parsing
check_and_install_deps() {
  local skill_path="$1"
  local pkg_json="$skill_path/package.json"
  [ -f "$pkg_json" ] || return 0

  info "Checking dependencies for '$(basename "$skill_path")'..."

  # Extract "required" array values from package.json
  # Simple parser: find "required": [ ... ] and extract string values
  local in_required=0
  local bracket_depth=0
  local missing=()

  while IFS= read -r line; do
    if [[ "$in_required" -eq 0 ]] && [[ "$line" =~ \"required\"[[:space:]]*:[[:space:]]*\[ ]]; then
      in_required=1
      bracket_depth=1
      local opens=$(echo "$line" | tr -cd '[' | wc -c)
      local closes=$(echo "$line" | tr -cd ']' | wc -c)
      bracket_depth=$((bracket_depth + opens - closes))
      continue
    fi
    [ "$in_required" -eq 0 ] && continue

    local opens=$(echo "$line" | tr -cd '[' | wc -c)
    local closes=$(echo "$line" | tr -cd ']' | wc -c)
    bracket_depth=$((bracket_depth + opens - closes))
    [ "$bracket_depth" -le 0 ] && break

    if [[ "$line" =~ \"([^\"]+)\" ]]; then
      local dep="${BASH_REMATCH[1]}"
      if ! check_dep "$dep"; then
        missing+=("$dep")
      fi
    fi
  done < "$pkg_json"

  if [ ${#missing[@]} -eq 0 ]; then
    ok "All required dependencies present"
    return 0
  fi

  warn "Missing dependencies: ${missing[*]}"
  for dep in "${missing[@]}"; do
    if install_dep "$dep"; then
      ok "Installed $dep"
    else
      err "Failed to install $dep. Aborting."
      return 1
    fi
  done
}

# Check if a dep is installed
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
      return 1
      ;;
    claude-mem)
      for d in "$HOME"/.npm/_npx/*/node_modules/claude-mem; do
        [ -d "$d" ] && return 0
      done
      [ -d "$HOME/.claude/plugins/data/claude-mem-thedotmack" ] && return 0
      return 1
      ;;
    *)
      command -v "$dep" >/dev/null 2>&1 && return 0 || return 1
      ;;
  esac
}

# Try to install a missing dep
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
    claude-mem)
      err "claude-mem is installed via the Claude plugin marketplace."
      err "See: https://github.com/thedotmack/claude-mem"
      return 1
      ;;
    *)
      err "Don't know how to auto-install '$dep'."
      return 1
      ;;
  esac
}

# Install a single skill to a single target
install_to_target() {
  local skill="$1"
  local skill_path="$2"
  local target="$3"
  local repo_name="$4"
  local dry_run="$5"

  local npx_flag
  npx_flag=$(get_agent_npx_flag "$target")
  if [ -z "$npx_flag" ]; then
    err "Unknown target: $target"
    return 1
  fi

  info "  → Installing '$skill' to $target (npx flag: $npx_flag)"

  if [ "$dry_run" = "true" ]; then
    echo "    [dry-run] npx skills add $repo_name --skill $skill -a $npx_flag -g -y"
    return 0
  fi

  # Try npx skills add (standard method)
  if command -v npx >/dev/null 2>&1; then
    local repo_path
    repo_path="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
    if [ -d "$repo_path/.git" ]; then
      if npx --yes skills add "$repo_path" --skill "$skill" -a "$npx_flag" -g -y 2>&1 | sed 's/^/    /'; then
        ok "    Installed via npx skills add (local path)"
        return 0
      fi
    else
      if npx --yes skills add "$repo_name" --skill "$skill" -a "$npx_flag" -g -y 2>&1 | sed 's/^/    /'; then
        ok "    Installed via npx skills add (remote)"
        return 0
      fi
    fi
    warn "    npx skills add failed, falling back to manual symlink"
  fi

  # Fallback: manual symlink
  local global_dir
  global_dir=$(get_agent_global_dir "$target")
  if [ -z "$global_dir" ]; then
    err "    No global_dir for target $target"
    return 1
  fi

  local target_dir="$HOME/$global_dir"
  mkdir -p "$target_dir"
  local link="$target_dir/$skill"

  if [ -L "$link" ]; then
    rm -f "$link"
  elif [ -d "$link" ]; then
    echo "    [skip] $link exists as a directory; remove manually if you want to symlink"
    return 1
  fi
  ln -s "$skill_path" "$link"
  ok "    Installed via symlink: $link -> $skill_path"
}
