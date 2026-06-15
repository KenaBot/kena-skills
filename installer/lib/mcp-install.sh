#!/usr/bin/env bash
# mcp-install.sh — install and verify MCP (Model Context Protocol) servers
# MCP servers are dependencies, not skills. They are installed separately.
# Usage: install_mcp <mcp_id> <auto_install>
#        check_mcp <mcp_id>

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=json.sh
source "$LIB_DIR/json.sh"

MCPS_JSON="$LIB_DIR/mcps.json"

# Get the install_command for an MCP
get_mcp_install_command() {
  local mcp_id="$1"
  json_find_by_id "$MCPS_JSON" "servers" "$mcp_id" "install_command"
}

# Get the description for an MCP
get_mcp_description() {
  local mcp_id="$1"
  json_find_by_id "$MCPS_JSON" "servers" "$mcp_id" "description"
}

# Get the name for an MCP
get_mcp_name() {
  local mcp_id="$1"
  json_find_by_id "$MCPS_JSON" "servers" "$mcp_id" "name"
}

# List all MCP server ids
list_mcp_ids() {
  if [ ! -f "$MCPS_JSON" ]; then return 1; fi
  json_array_ids "$MCPS_JSON" "servers"
}

# Check if an MCP is installed (verifies via verify_paths glob expansion)
check_mcp() {
  local mcp_id="$1"
  if [ ! -f "$MCPS_JSON" ]; then return 1; fi

  # Read verify_paths from JSON
  local in_server=0
  local in_paths_array=0
  local server_match=0
  local paths_bracket_depth=0
  local -a paths=()

  while IFS= read -r line; do
    if [[ "$in_server" -eq 0 ]] && [[ "$line" =~ ^[[:space:]]*\{[[:space:]]*$ ]]; then
      in_server=1
      continue
    fi

    [ "$in_server" -eq 0 ] && continue

    if [[ "$line" =~ \"id\"[[:space:]]*:[[:space:]]*\"${mcp_id}\" ]]; then
      server_match=1
    fi

    if [[ "$server_match" -eq 1 ]] && [[ "$line" =~ \"verify_paths\"[[:space:]]*:[[:space:]]*\[ ]]; then
      in_paths_array=1
      paths_bracket_depth=1
      continue
    fi

    [ "$in_paths_array" -eq 0 ] && continue

    local opens=$(echo "$line" | tr -cd '[' | wc -c)
    local closes=$(echo "$line" | tr -cd ']' | wc -c)
    paths_bracket_depth=$((paths_bracket_depth + opens - closes))

    if [ "$paths_bracket_depth" -le 0 ]; then
      in_paths_array=0
      break
    fi

    if [[ "$line" =~ \"([^\"]+)\" ]]; then
      paths+=("${BASH_REMATCH[1]}")
    fi
  done < "$MCPS_JSON"

  # Test each path with glob expansion
  for pattern in "${paths[@]}"; do
    # Expand ~ and *
    local expanded
    expanded=$(eval echo "$pattern" 2>/dev/null)
    # shellcheck disable=SC2086
    for path in $expanded; do
      if [ -e "$path" ]; then
        return 0
      fi
    done
  done

  return 1
}

# Install an MCP server
install_mcp() {
  local mcp_id="$1"
  local auto_install="$2"

  local name
  name=$(get_mcp_name "$mcp_id")
  if [ -z "$name" ]; then name="$mcp_id"; fi

  if check_mcp "$mcp_id"; then
    ok "  MCP $mcp_id ($name): installed"
    return 0
  fi

  warn "  MCP $mcp_id ($name): NOT installed"

  if [ "$auto_install" != "true" ]; then
    local cmd
    cmd=$(get_mcp_install_command "$mcp_id")
    err "  Install with: $cmd"
    return 1
  fi

  local cmd
  cmd=$(get_mcp_install_command "$mcp_id")
  if [ -z "$cmd" ]; then
    err "  No install_command defined for $mcp_id"
    return 1
  fi

  info "  Installing MCP $mcp_id..."
  eval "$cmd"
  return $?
}

# Check and (optionally) install all MCPs required by a skill
check_skill_mcps() {
  local skill_dir="$1"
  local auto_install="$2"

  local pkg_json="$skill_dir/package.json"
  [ -f "$pkg_json" ] || return 0

  # Parse dependencies.required array
  local in_required=0
  local required_bracket=0
  local -a required=()

  while IFS= read -r line; do
    if [[ "$in_required" -eq 0 ]] && [[ "$line" =~ \"required\"[[:space:]]*:[[:space:]]*\[ ]]; then
      in_required=1
      # Initialize depth from THIS line so elements on the same line
      # as the opening bracket are captured.
      local opens_first=$(echo "$line" | tr -cd '[' | wc -c)
      local closes_first=$(echo "$line" | tr -cd ']' | wc -c)
      required_bracket=$((opens_first - closes_first))
      # Capture strings AFTER the opening "[" (e.g.
      # "required": ["x", "y"]). The first match in the regex above
      # is the "required" key itself, so we strip up to "[" first.
      local rest="${line#*\[}"
      while [[ "$rest" =~ \"([^\"]+)\" ]]; do
        required+=("${BASH_REMATCH[1]}")
        rest="${rest#*\"${BASH_REMATCH[1]}\"}"
      done
      [ "$required_bracket" -le 0 ] && break
      continue
    fi
    [ "$in_required" -eq 0 ] && continue

    local opens=$(echo "$line" | tr -cd '[' | wc -c)
    local closes=$(echo "$line" | tr -cd ']' | wc -c)
    required_bracket=$((required_bracket + opens - closes))
    [ "$required_bracket" -le 0 ] && break

    if [[ "$line" =~ \"([^\"]+)\" ]]; then
      required+=("${BASH_REMATCH[1]}")
    fi
  done < "$pkg_json"

  # For each required dep, check if it's an MCP and install/verify.
  # Read the MCP list ONCE (not per dep) and avoid 'mapfile' (bash 4+)
  # so this works on macOS's default bash 3.2.
  local -a all_mcps
  local _mcp_line
  while IFS= read -r _mcp_line; do
    all_mcps+=("$_mcp_line")
  done < <(list_mcp_ids)

  local failed=0
  for dep in "${required[@]}"; do
    if [ -z "$dep" ]; then continue; fi
    # Check if this dep is a known MCP
    local is_mcp=false
    for m in "${all_mcps[@]}"; do
      if [ "$m" = "$dep" ]; then
        is_mcp=true
        break
      fi
    done

    if [ "$is_mcp" = true ]; then
      if ! install_mcp "$dep" "$auto_install"; then
        failed=$((failed+1))
      fi
    else
      # Regular system dep (node, graphify, etc.)
      if ! check_dep "$dep"; then
        warn "  Missing dep: $dep"
        if [ "$auto_install" = "true" ]; then
          if install_dep "$dep"; then
            ok "  Installed $dep"
          else
            err "  Failed to install $dep"
            failed=$((failed+1))
          fi
        fi
      fi
    fi
  done

  return $failed
}
