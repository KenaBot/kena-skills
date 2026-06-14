#!/usr/bin/env bash
# list-skills.sh — read skills from a skills directory using bash-pure YAML/JSON parsing
# No python, no env vars. Each skill is a subdirectory with a SKILL.md file.

# Extract frontmatter from a SKILL.md file
# Echoes content between the first --- and second ---
_extract_frontmatter() {
  local file="$1"
  awk '/^---$/{c++; if(c==2){exit} next} c==1{print}' "$file"
}

# Get a top-level scalar from YAML frontmatter
# Handles:
#   key: value
#   key: "value"
#   key: 'value'
#   key: >  (folded scalar, multi-line; only first line used for simplicity)
#   key: |  (literal scalar; only first line used for simplicity)
yaml_get() {
  local file="$1"
  local key="$2"
  local fm
  fm=$(_extract_frontmatter "$file") || return 1
  # Match the key followed by colon. Capture value.
  local line
  line=$(echo "$fm" | grep -E "^${key}:" | head -1)
  if [ -z "$line" ]; then return 1; fi
  # Strip "key:" prefix
  local val="${line#${key}:}"
  # Strip leading whitespace
  val="${val#"${val%%[![:space:]]*}"}"
  # Strip trailing whitespace
  val="${val%"${val##*[![:space:]]}"}"
  # Strip surrounding quotes
  if [[ "$val" == \"*\" ]]; then val="${val:1:-1}"; fi
  if [[ "$val" == \'*\' ]]; then val="${val:1:-1}"; fi
  # Handle folded/literal scalar markers (">" or "|")
  if [ "$val" = ">" ] || [ "$val" = "|" ]; then
    # Multi-line: take the next non-empty indented line
    val=$(echo "$fm" | awk "found && /^[^[:space:]]/ {exit} found {gsub(/^[[:space:]]+/,\"\"); print; exit} /^${key}:[[:space:]]*[>|]/ {found=1}")
  fi
  echo "$val"
}

# List skill names (one per line)
list_skill_names() {
  local skills_dir="$1"
  if [ ! -d "$skills_dir" ]; then
    return 1
  fi
  for dir in "$skills_dir"/*/; do
    [ -f "$dir/SKILL.md" ] && basename "$dir"
  done
}

# List skills as a formatted table: <name> | <description>
list_skills_table() {
  local skills_dir="$1"
  if [ ! -d "$skills_dir" ]; then
    echo "ERROR: skills directory not found: $skills_dir" >&2
    return 1
  fi

  local found=0
  local -a names=()
  local -a descs=()

  for dir in "$skills_dir"/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    local skill_name
    skill_name=$(basename "$dir")
    local desc
    desc=$(yaml_get "$dir/SKILL.md" "description" 2>/dev/null) || desc=""
    # Collapse multi-line descriptions to single line
    desc=$(echo "$desc" | tr '\n' ' ' | tr -s ' ' | sed 's/^ //;s/ $//')
    # Truncate
    if [ "${#desc}" -gt 100 ]; then
      desc="${desc:0:97}..."
    fi
    names+=("$skill_name")
    descs+=("$desc")
    found=$((found+1))
  done

  if [ "$found" -eq 0 ]; then
    echo "No skills found."
    return 0
  fi

  printf "%-20s %s\n" "NAME" "DESCRIPTION"
  printf "%.0s-" {1..80}; echo
  for i in "${!names[@]}"; do
    printf "%-20s %s\n" "${names[$i]}" "${descs[$i]}"
  done
}
