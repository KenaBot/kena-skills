#!/usr/bin/env bash
# list-skills.sh — list skills from ALL enabled sources (multi-source)
# Sources are loaded from installer/lib/sources.json.
# Each source type has its own listing strategy.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=json.sh
source "$LIB_DIR/json.sh"
# shellcheck source=source-npx.sh
source "$LIB_DIR/source-npx.sh"

SOURCES_JSON="$LIB_DIR/sources.json"
# Use parent of parent of LIB_DIR (installer/lib -> installer -> repo root)
# But only if REPO_ROOT not already set
REPO_ROOT="${REPO_ROOT:-}"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "$LIB_DIR/../.." && pwd)"
fi

# Get all enabled source ids
list_enabled_sources() {
  if [ ! -f "$SOURCES_JSON" ]; then return 1; fi
  json_array_ids "$SOURCES_JSON" "sources"
}

# Get the type of a source (local, npx, curl)
get_source_type() {
  local source_id="$1"
  json_find_by_id "$SOURCES_JSON" "sources" "$source_id" "type"
}

# Get the description of a source
get_source_description() {
  local source_id="$1"
  json_find_by_id "$SOURCES_JSON" "sources" "$source_id" "description"
}

# Find which source provides a skill
# Returns the source_id, or empty if not found
find_skill_source() {
  local skill_name="$1"
  local source_id

  while IFS= read -r source_id; do
    [ -z "$source_id" ] && continue
    local source_type
    source_type=$(get_source_type "$source_id")

    case "$source_type" in
      local)
        local path
        path=$(json_find_by_id "$SOURCES_JSON" "sources" "$source_id" "path")
        if [ -d "$REPO_ROOT/$path/$skill_name" ] && [ -f "$REPO_ROOT/$path/$skill_name/SKILL.md" ]; then
          echo "$source_id"
          return 0
        fi
        ;;
      npx)
        local npx_skills
        npx_skills=$(get_npx_available_skills "$source_id")
        if echo "$npx_skills" | grep -qx "$skill_name"; then
          echo "$source_id"
          return 0
        fi
        ;;
      curl)
        local curl_skills
        curl_skills=$(get_curl_skills "$source_id")
        if echo "$curl_skills" | grep -qx "$skill_name"; then
          echo "$source_id"
          return 0
        fi
        ;;
    esac
  done < <(list_enabled_sources)

  return 1
}

# Extract frontmatter from a SKILL.md file
_extract_frontmatter() {
  local file="$1"
  awk '/^---$/{c++; if(c==2){exit} next} c==1{print}' "$file"
}

# Get a top-level scalar from YAML frontmatter
yaml_get() {
  local file="$1"
  local key="$2"
  local fm
  fm=$(_extract_frontmatter "$file") || return 1
  local line
  line=$(echo "$fm" | grep -E "^${key}:" | head -1)
  if [ -z "$line" ]; then return 1; fi
  local val="${line#${key}:}"
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  if [[ "$val" == \"*\" ]]; then val="${val:1:-1}"; fi
  if [[ "$val" == \'*\' ]]; then val="${val:1:-1}"; fi
  if [ "$val" = ">" ] || [ "$val" = "|" ]; then
    val=$(echo "$fm" | awk "found && /^[^[:space:]]/ {exit} found {gsub(/^[[:space:]]+/,\"\"); print; exit} /^${key}:[[:space:]]*[>|]/ {found=1}")
  fi
  echo "$val"
}

# List local skills (from kena-skills source)
_list_local_skills() {
  local path
  path=$(json_find_by_id "$SOURCES_JSON" "sources" "kena-skills" "path")
  if [ -z "$path" ]; then return 0; fi
  local skills_dir="$REPO_ROOT/$path"
  [ -d "$skills_dir" ] || return 0

  for dir in "$skills_dir"/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    local name
    name=$(basename "$dir")
    # Skip directories starting with _ (preserved, rollback, hidden)
    [[ "$name" == _* ]] && continue
    printf "  %-22s\n" "$name"
  done
}

# List npx source skills
_list_npx_source_skills() {
  local source_id="$1"
  local desc
  desc=$(get_source_description "$source_id")
  desc=$(echo "$desc" | tr '\n' ' ' | tr -s ' ' | sed 's/^ //;s/ $//')
  if [ "${#desc}" -gt 60 ]; then desc="${desc:0:57}..."; fi
  echo ""
  echo "--- $source_id: $desc ---"
  while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    printf "  %-22s\n" "$skill"
  done < <(get_npx_visible_skills "$source_id")
}

# List curl source skills
_list_curl_source_skills() {
  local source_id="$1"
  local desc
  desc=$(get_source_description "$source_id")
  desc=$(echo "$desc" | tr '\n' ' ' | tr -s ' ' | sed 's/^ //;s/ $//')
  if [ "${#desc}" -gt 60 ]; then desc="${desc:0:57}..."; fi
  echo ""
  echo "--- $source_id: $desc ---"
  while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    printf "  %-22s\n" "$skill"
  done < <(get_curl_skills "$source_id")
}

# Main: list all skills from all enabled sources
list_skills_table() {
  # Local source uses the same header format as npx/curl sources
  local local_desc
  local_desc=$(get_source_description "kena-skills")
  local_desc=$(echo "$local_desc" | tr '\n' ' ' | tr -s ' ' | sed 's/^ //;s/ $//')
  if [ "${#local_desc}" -gt 60 ]; then local_desc="${local_desc:0:57}..."; fi
  echo ""
  echo "--- kena-skills: $local_desc ---"
  _list_local_skills

  # npx sources
  while IFS= read -r source_id; do
    [ -z "$source_id" ] && continue
    local source_type
    source_type=$(get_source_type "$source_id")
    if [ "$source_type" = "npx" ]; then
      _list_npx_source_skills "$source_id"
    fi
  done < <(list_enabled_sources)

  # curl sources
  while IFS= read -r source_id; do
    [ -z "$source_id" ] && continue
    local source_type
    source_type=$(get_source_type "$source_id")
    if [ "$source_type" = "curl" ]; then
      _list_curl_source_skills "$source_id"
    fi
  done < <(list_enabled_sources)
}

# Legacy: just local skill names
list_skill_names() {
  local skills_dir="${1:-$REPO_ROOT/skills}"
  for dir in "$skills_dir"/*/; do
    [ -f "$dir/SKILL.md" ] && basename "$dir"
  done
}
