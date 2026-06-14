#!/usr/bin/env bash
# source-local.sh — install skills from a local repo (e.g. kena/skills)
# Usage: install_from_local <source_id> <skill> <target> <repo_name> <dry_run> [REPO_ROOT]

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=json.sh
source "$LIB_DIR/json.sh"

SOURCES_JSON="$LIB_DIR/sources.json"

# Get the local path for a local source
get_local_path() {
  local source_id="$1"
  json_find_by_id "$SOURCES_JSON" "sources" "$source_id" "path"
}

# Install a single skill from a local source to a target
# Uses the symlink fallback from install-skill.sh
install_from_local() {
  local source_id="$1"
  local skill="$2"
  local target="$3"
  local repo_name="$4"
  local dry_run="$5"
  local repo_root="${6:-$REPO_ROOT}"

  local rel_path
  rel_path=$(get_local_path "$source_id")
  if [ -z "$rel_path" ]; then
    err "Unknown local source: $source_id"
    return 1
  fi

  local skill_path="$repo_root/$rel_path/$skill"
  if [ ! -d "$skill_path" ]; then
    err "Skill not found: $skill_path"
    return 1
  fi

  # Delegate to install_to_target in install-skill.sh
  install_to_target "$skill" "$skill_path" "$target" "$repo_name" "$dry_run"
}
