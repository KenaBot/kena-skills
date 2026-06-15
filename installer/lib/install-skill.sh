#!/usr/bin/env bash
# install-skill.sh — multi-source skill installer with dispatch
#
# Public API:
#   install_skill_to_targets <skill> <targets_csv> <repo_root> <repo_name> <deps_auto> <dry_run> [source_id]
#   install_to_target <skill> <skill_path> <target> <repo_name> <dry_run>

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=platform.sh
source "$LIB_DIR/platform.sh"
# shellcheck source=json.sh
source "$LIB_DIR/json.sh"
# shellcheck source=source-npx.sh
source "$LIB_DIR/source-npx.sh"
# shellcheck source=source-curl.sh
source "$LIB_DIR/source-curl.sh"
# shellcheck source=source-local.sh
source "$LIB_DIR/source-local.sh"
# shellcheck source=mcp-install.sh
source "$LIB_DIR/mcp-install.sh"
# shellcheck source=check-deps.sh
source "$LIB_DIR/check-deps.sh"

SOURCES_JSON="$LIB_DIR/sources.json"

# Install a skill to one or more targets, dispatching by source
install_skill_to_targets() {
  local skill="$1"
  local targets_csv="$2"
  local repo_root="$3"
  local repo_name="$4"
  local deps_auto="$5"
  local dry_run="$6"
  local source_id="${7:-}"

  # Find source if not provided
  if [ -z "$source_id" ]; then
    source_id=$(find_skill_source "$skill")
    if [ -z "$source_id" ]; then
      err "Skill '$skill' not found in any enabled source"
      return 1
    fi
    info "  Found '$skill' in source: $source_id"
  fi

  local source_type
  source_type=$(get_source_type "$source_id")

  # For local source, check dependencies (deps are declared in package.json)
  if [ "$source_type" = "local" ]; then
    local path
    path=$(json_find_by_id "$SOURCES_JSON" "sources" "$source_id" "path")
    local skill_path="$repo_root/$path/$skill"
    if [ -d "$skill_path" ] && [ "$deps_auto" = "true" ]; then
      check_and_install_deps "$skill_path" "$deps_auto"
      check_skill_mcps "$skill_path" "$deps_auto"
    fi
  fi

  # For curl source, deps are auto-installed by the upstream installer
  if [ "$source_type" = "curl" ]; then
    install_from_curl "$source_id" "$dry_run"
    return $?
  fi

  # For npx source, deps are handled by the upstream skill
  # For local source, we iterate targets and call install_to_target
  IFS=',' read -ra TARGETS <<< "$targets_csv"
  local failed=0
  local succeeded=0
  for target in "${TARGETS[@]}"; do
    target="$(echo "$target" | xargs)"
    if [ -z "$target" ]; then continue; fi

    case "$source_type" in
      local)
        local path
        path=$(json_find_by_id "$SOURCES_JSON" "sources" "$source_id" "path")
        local skill_path="$repo_root/$path/$skill"
        if install_to_target "$skill" "$skill_path" "$target" "$repo_name" "$dry_run"; then
          succeeded=$((succeeded+1))
        else
          failed=$((failed+1))
        fi
        ;;
      npx)
        if install_from_npx "$source_id" "$skill" "$target" "$dry_run"; then
          succeeded=$((succeeded+1))
        else
          failed=$((failed+1))
        fi
        ;;
    esac
  done

  # Post-install template (only for local source)
  if [ "$source_type" = "local" ] && [ "$dry_run" = "false" ]; then
    local template="$LIB_DIR/../templates/${skill}-install.sh"
    if [ -f "$template" ]; then
      info "Running post-install template for $skill..."
      bash "$template" "${TARGETS[@]}" 2>&1 | sed 's/^/  /' || warn "Post-install template returned non-zero"
    fi
  fi

  echo ""
  if [ "$failed" -eq 0 ]; then
    ok "Installed '$skill' to $succeeded target(s) via $source_id ($source_type)"
  else
    err "$failed target(s) failed for skill '$skill'"
    return 1
  fi
}

# Install a single local skill to a single target (symlink fallback)
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

  local global_dir windows_global_dir project_dir
  global_dir=$(get_agent_global_dir "$target")
  windows_global_dir=$(json_find_by_id "$LIB_DIR/../lib/agents.json" "agents" "$target" "windows_global_dir")
  project_dir=$(json_find_by_id "$LIB_DIR/../lib/agents.json" "agents" "$target" "project_dir")

  info "  → Installing '$skill' to $target (local source)"

  if [ "$dry_run" = "true" ]; then
    echo "    [dry-run] npx skills add $repo_name --skill $skill -a $npx_flag -g -y"
    echo "    [dry-run] OR symlink fallback: $HOME/$(get_agent_global_dir "$target")/$skill -> $skill_path"
    return 0
  fi

  # Try npx first if .git exists
  if command -v npx >/dev/null 2>&1 && [ -d "$repo_root/.git" ]; then
    if npx --yes skills add "$repo_root" --skill "$skill" -a "$npx_flag" -g -y 2>&1 | sed 's/^/    /'; then
      ok "    Installed via npx skills add (local path)"
      return 0
    fi
  fi

  # Manual symlink fallback
  if [ -z "$global_dir" ]; then
    err "    No global_dir for target $target"
    return 1
  fi

  local target_dir link
  if [ "${SCOPE:-global}" = "local" ]; then
    target_dir="$REPO_ROOT/$project_dir"
  else
    target_dir=$(resolve_global_dir "$global_dir" "$windows_global_dir")
  fi
  mkdir -p "$target_dir"
  link="$target_dir/$skill"

  if [ -L "$link" ]; then
    rm -f "$link"
  elif [ -d "$link" ]; then
    echo "    [skip] $link exists as a directory; remove manually if you want to symlink"
    return 1
  fi
  make_symlink "$skill_path" "$link"
  ok "    Installed via symlink: $link -> $skill_path"
}

# Check and install dependencies (system deps, not MCPs)
check_and_install_deps() {
  local skill_path="$1"
  local deps_auto="$2"
  local pkg_json="$skill_path/package.json"
  [ -f "$pkg_json" ] || return 0

  info "  Checking dependencies for '$(basename "$skill_path")'..."

  local -a required=()
  local in_required=0
  local bracket_depth=0

  while IFS= read -r line; do
    if [[ "$in_required" -eq 0 ]] && [[ "$line" =~ \"required\"[[:space:]]*:[[:space:]]*\[ ]]; then
      in_required=1
      # Initialize depth from THIS line (handles inline arrays
      # and the elements on the same line as the opening bracket).
      local opens_first=$(echo "$line" | tr -cd '[' | wc -c)
      local closes_first=$(echo "$line" | tr -cd ']' | wc -c)
      bracket_depth=$((opens_first - closes_first))
      # Capture strings AFTER the opening "[" on the same line
      # (e.g. "required": ["x", "y"]). We can't use a single regex
      # here because the first match is the "required" key itself.
      local rest="${line#*\[}"
      while [[ "$rest" =~ \"([^\"]+)\" ]]; do
        required+=("${BASH_REMATCH[1]}")
        rest="${rest#*\"${BASH_REMATCH[1]}\"}"
      done
      [ "$bracket_depth" -le 0 ] && break
      continue
    fi
    [ "$in_required" -eq 0 ] && continue
    local opens=$(echo "$line" | tr -cd '[' | wc -c)
    local closes=$(echo "$line" | tr -cd ']' | wc -c)
    bracket_depth=$((bracket_depth + opens - closes))
    [ "$bracket_depth" -le 0 ] && break
    if [[ "$line" =~ \"([^\"]+)\" ]]; then
      required+=("${BASH_REMATCH[1]}")
    fi
  done < "$pkg_json"

  if [ ${#required[@]} -eq 0 ]; then
    return 0
  fi

  # Filter to system deps only (not MCPs)
  local -a all_mcps
  mapfile -t all_mcps < <(list_mcp_ids)
  local -a sys_deps=()
  for dep in "${required[@]}"; do
    local is_mcp=false
    for m in "${all_mcps[@]}"; do
      if [ "$m" = "$dep" ]; then is_mcp=true; break; fi
    done
    if [ "$is_mcp" = false ]; then
      sys_deps+=("$dep")
    fi
  done

  if [ ${#sys_deps[@]} -eq 0 ]; then return 0; fi

  local missing=()
  for dep in "${sys_deps[@]}"; do
    if ! check_dep "$dep"; then
      missing+=("$dep")
    fi
  done

  if [ ${#missing[@]} -eq 0 ]; then
    ok "  All system dependencies present"
    return 0
  fi

  warn "  Missing system dependencies: ${missing[*]}"
  if [ "$deps_auto" = "true" ]; then
    for dep in "${missing[@]}"; do
      if install_dep "$dep"; then
        ok "  Installed $dep"
      else
        err "  Failed to install $dep"
        return 1
      fi
    done
  fi
}
