#!/usr/bin/env bash
# json.sh — minimal bash JSON parser for kena-skills
# Limitations: only handles string values, objects, and arrays of strings/objects.
# No number parsing, no escape sequences, no comments. Sufficient for our small registry.
#
# Public API:
#   json_get <file> <key_path>
#     Get a top-level scalar value. Examples:
#       json_get agents.json "version"           -> "1.1.0"
#       json_get agents.json "description"       -> "Registry of supported..."
#
#   json_find_by_id <file> <array_key> <id_value> <field>
#     Find an object in an array by id, return specified field. Examples:
#       json_find_by_id agents.json "agents" "claude" "npx_flag"   -> "claude-code"
#       json_find_by_id agents.json "agents" "opencode" "global_dir" -> ".config/opencode/skills"
#
#   json_array_ids <file> <array_key>
#     Echoes the "id" field of every object in the array, one per line. Examples:
#       json_array_ids agents.json "agents" -> opencode\nclaude\ncopilot\ncodex\ngemini

# Internal: strip surrounding quotes from a JSON string value
_json_strip_quotes() {
  local v="$1"
  # Remove leading/trailing whitespace
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  # Strip surrounding " or '
  if [[ "$v" == \"*\" ]]; then v="${v:1:-1}"; fi
  if [[ "$v" == \'*\' ]]; then v="${v:1:-1}"; fi
  echo "$v"
}

# json_get <file> <key>
# Get a top-level scalar. Returns empty string if not found.
json_get() {
  local file="$1"
  local key="$2"
  if [ ! -f "$file" ]; then return 1; fi
  # Match "key": "value" or "key": value (no quotes for primitives)
  local val
  val=$(grep -E "^\s*\"${key}\"\s*:" "$file" | head -1 | sed -E "s/^\s*\"${key}\"\s*:\s*//" | tr -d ',')
  _json_strip_quotes "$val"
}

# json_find_by_id <file> <array_key> <id_value> <field>
# Returns the value of <field> in the object where id == <id_value>.
json_find_by_id() {
  local file="$1"
  local array_key="$2"
  local id_val="$3"
  local field="$4"
  if [ ! -f "$file" ]; then return 1; fi

  # Find the start of the array
  local in_array=0
  local in_object=0
  local brace_depth=0
  local bracket_depth=0
  local current_id=""
  local current_field=""
  local in_field=0
  local field_value=""

  while IFS= read -r line; do
    # Detect array start
    if [[ "$in_array" -eq 0 ]] && [[ "$line" =~ ^[[:space:]]*\"${array_key}\"[[:space:]]*:[[:space:]]*\[ ]]; then
      in_array=1
      bracket_depth=1
      continue
    fi

    [ "$in_array" -eq 0 ] && continue

    # Track brackets for the array
    local opens=$(echo "$line" | tr -cd '[' | wc -c)
    local closes=$(echo "$line" | tr -cd ']' | wc -c)
    bracket_depth=$((bracket_depth + opens - closes))

    if [ "$bracket_depth" -eq 0 ]; then
      # End of array
      break
    fi

    # Detect object start
    if [[ "$line" =~ \{[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*\{[[:space:]]*\" ]]; then
      in_object=1
      current_id=""
      current_field=""
      field_value=""
      in_field=0
    fi

    # Check for id field
    if [[ "$in_object" -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*\"id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      current_id="${BASH_REMATCH[1]}"
    fi

    # Check for the requested field
    if [[ "$in_object" -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*\"${field}\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
      field_value="${BASH_REMATCH[1]}"
    fi

    # Detect object end
    if [[ "$line" =~ \}[[:space:]]*(,|$) ]]; then
      if [ "$current_id" = "$id_val" ]; then
        echo "$field_value"
        return 0
      fi
      in_object=0
    fi
  done < "$file"

  return 1
}

# json_array_ids <file> <array_key>
# Echoes the "id" field of every object in the array.
json_array_ids() {
  local file="$1"
  local array_key="$2"
  if [ ! -f "$file" ]; then return 1; fi

  local in_array=0
  local bracket_depth=0

  while IFS= read -r line; do
    if [[ "$in_array" -eq 0 ]] && [[ "$line" =~ ^[[:space:]]*\"${array_key}\"[[:space:]]*:[[:space:]]*\[ ]]; then
      in_array=1
      bracket_depth=1
      continue
    fi

    [ "$in_array" -eq 0 ] && continue

    local opens=$(echo "$line" | tr -cd '[' | wc -c)
    local closes=$(echo "$line" | tr -cd ']' | wc -c)
    bracket_depth=$((bracket_depth + opens - closes))

    if [ "$bracket_depth" -eq 0 ]; then break; fi

    if [[ "$line" =~ ^[[:space:]]*\"id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  done < "$file"
}
