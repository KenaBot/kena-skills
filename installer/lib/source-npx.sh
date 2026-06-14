#!/usr/bin/env bash
# source-npx.sh — install skills from an npx source (e.g. mattpocock/skills)
# Usage: install_from_npx <source_id> <skill> <target> <dry_run>

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=json.sh
source "$LIB_DIR/json.sh"

SOURCES_JSON="$LIB_DIR/sources.json"

# Get the npx_args for a source
get_npx_args() {
  local source_id="$1"
  json_find_by_id "$SOURCES_JSON" "sources" "$source_id" "npx_args"
}

# Get the list of available skills for an npx source.
# Properly scopes the search to one source object.
get_npx_available_skills() {
  local source_id="$1"
  if [ ! -f "$SOURCES_JSON" ]; then return 1; fi

  # Find the line range for this source object
  local start_line=-1
  local end_line=-1
  local in_sources=0
  local obj_brace_depth=0
  local current_line=0

  while IFS= read -r line; do
    current_line=$((current_line+1))
    [[ "$line" =~ ^[[:space:]]*\"sources\"[[:space:]]*:[[:space:]]*\[ ]] && in_sources=1 && continue
    [ "$in_sources" -eq 0 ] && continue

    local opens=$(echo "$line" | tr -cd '{' | wc -c)
    local closes=$(echo "$line" | tr -cd '}' | wc -c)
    obj_brace_depth=$((obj_brace_depth + opens - closes))

    if [ "$start_line" -eq -1 ] && [[ "$line" =~ ^[[:space:]]+\{$ ]]; then
      start_line=$current_line
    fi

    if [ "$start_line" -ne -1 ] && [ "$obj_brace_depth" -eq 0 ] && [[ "$line" =~ ^[[:space:]]*\},?[[:space:]]*$ ]]; then
      end_line=$current_line
      if sed -n "${start_line},${end_line}p" "$SOURCES_JSON" | grep -q "\"id\":[[:space:]]*\"${source_id}\""; then
        break
      fi
      start_line=-1
      end_line=-1
    fi
  done < "$SOURCES_JSON"

  if [ "$start_line" -eq -1 ] || [ "$end_line" -eq -1 ]; then
    return 1
  fi

  # Extract "available_skills" array from this object
  local in_skills=0
  local skill_bracket=0
  while IFS= read -r line; do
    if [[ "$in_skills" -eq 0 ]] && [[ "$line" =~ \"available_skills\"[[:space:]]*:[[:space:]]*\[ ]]; then
      in_skills=1
      local opens_line=$(echo "$line" | tr -cd '[' | wc -c)
      local closes_line=$(echo "$line" | tr -cd ']' | wc -c)
      skill_bracket=$((opens_line - closes_line))
      # Extract ALL strings from this line (handles inline arrays)
      local _rest="${line#*\[}"
      while [[ "$_rest" =~ \"([a-zA-Z0-9_-]+)\" ]]; do
        echo "${BASH_REMATCH[1]}"
        _rest="${_rest#*\"${BASH_REMATCH[1]}\"}"
      done
      [ "$skill_bracket" -le 0 ] && in_skills=0
      continue
    fi
    [ "$in_skills" -eq 0 ] && continue

    local opens=$(echo "$line" | tr -cd '[' | wc -c)
    local closes=$(echo "$line" | tr -cd ']' | wc -c)
    skill_bracket=$((skill_bracket + opens - closes))
    [ "$skill_bracket" -le 0 ] && { in_skills=0; continue; }

    if [[ "$line" =~ ^[[:space:]]*\"([a-zA-Z0-9_-]+)\"[[:space:]]*,?[[:space:]]*$ ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  done < <(sed -n "${start_line},${end_line}p" "$SOURCES_JSON")
}

# Get the list of VISIBLE skills for an npx source.
# If "visible_skills" is defined in sources.json, returns that.
# Otherwise, returns all available_skills (legacy behavior).
get_npx_visible_skills() {
  local source_id="$1"
  if [ ! -f "$SOURCES_JSON" ]; then return 1; fi

  # Find the line range for this source object
  local start_line=-1
  local end_line=-1
  local in_sources=0
  local obj_brace_depth=0
  local current_line=0

  while IFS= read -r line; do
    current_line=$((current_line+1))
    [[ "$line" =~ ^[[:space:]]*\"sources\"[[:space:]]*:[[:space:]]*\[ ]] && in_sources=1 && continue
    [ "$in_sources" -eq 0 ] && continue

    local opens=$(echo "$line" | tr -cd '{' | wc -c)
    local closes=$(echo "$line" | tr -cd '}' | wc -c)
    obj_brace_depth=$((obj_brace_depth + opens - closes))

    if [ "$start_line" -eq -1 ] && [[ "$line" =~ ^[[:space:]]+\{$ ]]; then
      start_line=$current_line
    fi

    if [ "$start_line" -ne -1 ] && [ "$obj_brace_depth" -eq 0 ] && [[ "$line" =~ ^[[:space:]]*\},?[[:space:]]*$ ]]; then
      end_line=$current_line
      if sed -n "${start_line},${end_line}p" "$SOURCES_JSON" | grep -q "\"id\":[[:space:]]*\"${source_id}\""; then
        break
      fi
      start_line=-1
      end_line=-1
    fi
  done < "$SOURCES_JSON"

  if [ "$start_line" -eq -1 ] || [ "$end_line" -eq -1 ]; then
    return 1
  fi

  # Check if "visible_skills" exists for this source
  local has_visible
  has_visible=$(sed -n "${start_line},${end_line}p" "$SOURCES_JSON" | grep -c '"visible_skills"')

  local target_key="available_skills"
  if [ "$has_visible" -gt 0 ]; then
    target_key="visible_skills"
  fi

  # Extract the target array
  local in_skills=0
  local skill_bracket=0
  while IFS= read -r line; do
    if [[ "$in_skills" -eq 0 ]] && [[ "$line" =~ \"${target_key}\"[[:space:]]*:[[:space:]]*\[ ]]; then
      in_skills=1
      local opens_line=$(echo "$line" | tr -cd '[' | wc -c)
      local closes_line=$(echo "$line" | tr -cd ']' | wc -c)
      skill_bracket=$((opens_line - closes_line))
      # Extract ALL strings from this line (handles inline arrays)
      local _rest="${line#*\[}"
      while [[ "$_rest" =~ \"([a-zA-Z0-9_-]+)\" ]]; do
        echo "${BASH_REMATCH[1]}"
        _rest="${_rest#*\"${BASH_REMATCH[1]}\"}"
      done
      [ "$skill_bracket" -le 0 ] && in_skills=0
      continue
    fi
    [ "$in_skills" -eq 0 ] && continue

    local opens=$(echo "$line" | tr -cd '[' | wc -c)
    local closes=$(echo "$line" | tr -cd ']' | wc -c)
    skill_bracket=$((skill_bracket + opens - closes))
    [ "$skill_bracket" -le 0 ] && { in_skills=0; continue; }

    # Only capture if the line is JUST a string (optionally followed by comma),
    # NOT a field header like `"key":` (which would have `:`).
    if [[ "$line" =~ ^[[:space:]]*\"([a-zA-Z0-9_-]+)\"[[:space:]]*,?[[:space:]]*$ ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  done < <(sed -n "${start_line},${end_line}p" "$SOURCES_JSON")
}

# Install a single skill from an npx source to a target
install_from_npx() {
  local source_id="$1"
  local skill="$2"
  local target="$3"
  local dry_run="$4"

  local npx_args
  npx_args=$(get_npx_args "$source_id")
  if [ -z "$npx_args" ]; then
    err "Unknown npx source: $source_id"
    return 1
  fi

  local npx_flag
  npx_flag=$(get_agent_npx_flag "$target")
  if [ -z "$npx_flag" ]; then
    err "Unknown target: $target"
    return 1
  fi

  local cmd="npx --yes skills@latest add $npx_args --skill $skill -a $npx_flag -g -y"
  info "  → $cmd"

  if [ "$dry_run" = "true" ]; then
    echo "    [dry-run] $cmd"
    return 0
  fi

  if ! command -v npx >/dev/null 2>&1; then
    err "npx not found. Install Node.js."
    return 1
  fi

  npx --yes skills@latest add "$npx_args" --skill "$skill" -a "$npx_flag" -g -y 2>&1 | sed 's/^/    /'
  return ${PIPESTATUS[0]}
}
