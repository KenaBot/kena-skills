#!/usr/bin/env bash
# detect-agents.sh — auto-detect which agent runtimes are installed
# Bash-pure implementation using installer/lib/json.sh. No python, no env vars lost in subshells.

# Resolve the directory of this script (lib/)
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the json parser
# shellcheck source=json.sh
source "$LIB_DIR/json.sh"

# Path to the agents registry
AGENTS_REGISTRY="$LIB_DIR/agents.json"

# Read agent id from registry (one per line)
list_supported_agents() {
  json_array_ids "$AGENTS_REGISTRY" "agents"
}

# Read the global_dir for a given agent id
get_agent_global_dir() {
  local agent_id="$1"
  json_find_by_id "$AGENTS_REGISTRY" "agents" "$agent_id" "global_dir"
}

# Read the npx_flag for a given agent id
get_agent_npx_flag() {
  local agent_id="$1"
  json_find_by_id "$AGENTS_REGISTRY" "agents" "$agent_id" "npx_flag"
}

# Read the description for a given agent id (for display in UI)
get_agent_description() {
  local agent_id="$1"
  json_find_by_id "$AGENTS_REGISTRY" "agents" "$agent_id" "description"
}

# Detect which agents from the registry are installed on this system.
# Echoes agent ids, one per line.
# A target is considered "installed" if the parent of its global_dir exists
# (e.g. ~/.claude/ for global_dir=.claude/skills).
detect_installed_agents() {
  if [ ! -f "$AGENTS_REGISTRY" ]; then
    echo "ERROR: agents.json not found at $AGENTS_REGISTRY" >&2
    return 1
  fi

  local agent_id
  while IFS= read -r agent_id; do
    [ -z "$agent_id" ] && continue
    local global_dir
    global_dir=$(get_agent_global_dir "$agent_id")
    if [ -z "$global_dir" ]; then continue; fi
    local full_path="$HOME/$global_dir"
    local parent
    parent=$(dirname "$full_path")
    if [ -d "$parent" ]; then
      echo "$agent_id"
    fi
  done < <(list_supported_agents)
}
