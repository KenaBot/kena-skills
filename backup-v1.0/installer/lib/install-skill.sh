#!/usr/bin/env bash
# install-skill.sh — install a single skill to one or more targets
#
# install_skill_to_targets <skill> <targets_csv> <skills_dir> <repo_name> <deps_auto> <dry_run>

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

  # Step 1: check dependencies
  if [ "$deps_auto" = true ] || [ "${AUTO_INSTALL_DEPS:-false}" = true ]; then
    info "Checking dependencies for '$skill'..."
    local missing=()
    while IFS= read -r dep; do
      [ -n "$dep" ] && missing+=("$dep")
    done < <(check_skill_deps "$skill_path")

    if [ ${#missing[@]} -gt 0 ]; then
      warn "Missing dependencies: ${missing[*]}"
      for dep in "${missing[@]}"; do
        if [ "$deps_auto" = true ]; then
          if install_dep "$dep"; then
            ok "Installed $dep"
          else
            err "Failed to install $dep. Aborting."
            return 1
          fi
        else
          warn "  - $dep (not found, --install-deps not set)"
        fi
      done
    else
      ok "All required dependencies present"
    fi
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
  local template="$SCRIPT_DIR/../templates/${skill}-install.sh"
  if [ -f "$template" ] && [ "$dry_run" = false ]; then
    info "Running post-install template for $skill..."
    if bash "$template" "${TARGETS[@]}"; then
      ok "Post-install for $skill complete"
    else
      warn "Post-install template returned non-zero (continuing)"
    fi
  fi

  echo ""
  if [ $failed -eq 0 ]; then
    ok "Installed '$skill' to $succeeded target(s): $targets_csv"
  else
    err "$failed target(s) failed for skill '$skill'"
    return 1
  fi
}

# Install a single skill to a single target
# install_to_target <skill> <skill_path> <target_id> <repo_name> <dry_run>
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

  if [ "$dry_run" = true ]; then
    echo "    [dry-run] npx skills add $repo_name --skill $skill -a $npx_flag -g -y"
    return 0
  fi

  # Try npx skills add (standard method)
  if command -v npx >/dev/null 2>&1; then
    # Check if we have a local repo or need a remote
    if [ -d "$(cd "$SCRIPT_DIR/.." && pwd)/.git" ]; then
      # Local repo exists, use local path
      local local_path
      local_path="$(cd "$SCRIPT_DIR/.." && pwd)"
      if npx --yes skills add "$local_path" --skill "$skill" -a "$npx_flag" -g -y 2>&1 | sed 's/^/    /'; then
        ok "    Installed via npx skills add (local path)"
        return 0
      else
        warn "    npx skills add failed, falling back to manual symlink"
      fi
    else
      # No local .git, use repo name
      if npx --yes skills add "$repo_name" --skill "$skill" -a "$npx_flag" -g -y 2>&1 | sed 's/^/    /'; then
        ok "    Installed via npx skills add (remote)"
        return 0
      else
        warn "    npx skills add failed, falling back to manual symlink"
      fi
    fi
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

  if [ -L "$link" ] || [ -e "$link" ]; then
    rm -f "$link"
  fi
  ln -s "$skill_path" "$link"
  ok "    Installed via symlink: $link -> $skill_path"
}
