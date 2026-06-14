#!/usr/bin/env bash
# source-curl.sh — install skills from a curl-pipe source (e.g. juliusbrussee/caveman)
# Usage: install_from_curl <source_id> <dry_run>

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=json.sh
source "$LIB_DIR/json.sh"

SOURCES_JSON="$LIB_DIR/sources.json"

# Get the URL for a curl source
get_curl_url() {
  local source_id="$1"
  json_find_by_id "$SOURCES_JSON" "sources" "$source_id" "url"
}

# Get the skills provided by a curl source.
# Properly tracks brace depth at the array level to isolate one source.
get_curl_skills() {
  local source_id="$1"
  if [ ! -f "$SOURCES_JSON" ]; then return 1; fi

  # Find the line range for this source in the sources array
  local start_line
  local end_line
  local in_sources=0
  local in_obj=0
  local obj_brace_depth=0
  local target_match=0
  local current_line=0

  # First pass: find start and end of the matching object
  start_line=-1
  end_line=-1
  obj_brace_depth=0
  in_sources=0

  while IFS= read -r line; do
    current_line=$((current_line+1))
    [[ "$line" =~ ^[[:space:]]*\"sources\"[[:space:]]*:[[:space:]]*\[ ]] && in_sources=1 && continue
    [ "$in_sources" -eq 0 ] && continue

    # Track top-level brace depth inside the sources array
    local opens=$(echo "$line" | tr -cd '{' | wc -c)
    local closes=$(echo "$line" | tr -cd '}' | wc -c)
    obj_brace_depth=$((obj_brace_depth + opens - closes))

    # Find the start of an object: line that begins (with indent) with just `{`
    # (i.e. the opening brace of a top-level object, not a sub-object)
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

  # Now extract the "skills" array from lines [start_line, end_line]
  local in_skills_array=0
  local skills_bracket=0
  while IFS= read -r line; do
    # Detect array start on the same line (may contain the first value)
    if [[ "$in_skills_array" -eq 0 ]] && [[ "$line" =~ \"skills\"[[:space:]]*:[[:space:]]*\[ ]]; then
      in_skills_array=1
      # Count opens/closes on the SAME line
      local opens_line=$(echo "$line" | tr -cd '[' | wc -c)
      local closes_line=$(echo "$line" | tr -cd ']' | wc -c)
      skills_bracket=$((opens_line - closes_line))
      # If the line has the array opening and the first value, extract it
      # Pattern: "key": ["value", ...] OR "key": [
      if [[ "$line" =~ \[\"([a-zA-Z0-9_-]+)\" ]]; then
        echo "${BASH_REMATCH[1]}"
      fi
      # If bracket already closed, end
      [ "$skills_bracket" -le 0 ] && in_skills_array=0
      continue
    fi
    [ "$in_skills_array" -eq 0 ] && continue

    local opens=$(echo "$line" | tr -cd '[' | wc -c)
    local closes=$(echo "$line" | tr -cd ']' | wc -c)
    skills_bracket=$((skills_bracket + opens - closes))
    [ "$skills_bracket" -le 0 ] && { in_skills_array=0; continue; }

    if [[ "$line" =~ ^[[:space:]]*\"([a-zA-Z0-9_-]+)\"[[:space:]]*,?[[:space:]]*$ ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  done < <(sed -n "${start_line},${end_line}p" "$SOURCES_JSON")
}

# Install a curl source (typically installs to many agents at once)
install_from_curl() {
  local source_id="$1"
  local dry_run="$2"

  local url
  url=$(get_curl_url "$source_id")
  if [ -z "$url" ]; then
    err "Unknown curl source: $source_id"
    return 1
  fi

  local cmd="curl -fsSL $url | bash"
  info "  → $cmd"
  warn "  Note: curl-pipe installers typically detect and install to 30+ agents automatically."
  warn "  The --target flag is informational for curl sources."

  if [ "$dry_run" = "true" ]; then
    echo "    [dry-run] $cmd"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    err "curl not found"
    return 1
  fi

  curl -fsSL "$url" | bash 2>&1 | sed 's/^/    /'
  return ${PIPESTATUS[0]}
}
