#!/usr/bin/env bash
# detect-agents.sh — auto-detect which agent runtimes are installed
# Reads installer/lib/agents.json for the registry of supported agents.

# Resolve the directory of this script (lib/)
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load agents registry
load_agents_registry() {
  AGENTS_REGISTRY="$LIB_DIR/agents.json"
  if [ ! -f "$AGENTS_REGISTRY" ]; then
    echo "ERROR: agents.json not found at $AGENTS_REGISTRY" >&2
    return 1
  fi
  return 0
}

# Read agent id from registry (one per line)
list_supported_agents() {
  load_agents_registry || return 1
  AGENTS_REGISTRY="$AGENTS_REGISTRY" python3 -c "
import json, os
with open(os.environ['AGENTS_REGISTRY']) as f:
    data = json.load(f)
for agent in data.get('agents', []):
    print(agent['id'])
"
}

# Read the global_dir for a given agent id
get_agent_global_dir() {
  local agent_id="$1"
  load_agents_registry || return 1
  AGENT_ID="$agent_id" python3 -c "
import json, os
with open(os.environ['AGENTS_REGISTRY']) as f:
    data = json.load(f)
for agent in data.get('agents', []):
    if agent['id'] == os.environ['AGENT_ID']:
        print(agent.get('global_dir', ''))
        break
"
}

# Read the npx_flag for a given agent id
get_agent_npx_flag() {
  local agent_id="$1"
  load_agents_registry || return 1
  AGENT_ID="$agent_id" python3 -c "
import json, os
with open(os.environ['AGENTS_REGISTRY']) as f:
    data = json.load(f)
for agent in data.get('agents', []):
    if agent['id'] == os.environ['AGENT_ID']:
        print(agent.get('npx_flag', agent_id))
        break
" agent_id="$agent_id"
}

# Detect which agents from the registry are installed on this system
# Echoes agent ids, one per line
detect_installed_agents() {
  load_agents_registry || return 1
  AGENTS_REGISTRY="$AGENTS_REGISTRY" python3 -c "
import json, os
with open(os.environ['AGENTS_REGISTRY']) as f:
    data = json.load(f)
home = os.path.expanduser('~')
for agent in data.get('agents', []):
    gdir = agent.get('global_dir', '')
    if gdir and gdir != '.agents/skills':
        full = os.path.join(home, gdir)
        if os.path.isdir(os.path.dirname(full)) or os.path.isdir(full):
            print(agent['id'])
    elif agent['id'] == 'agents':
        # 'agents' is the universal agents-compatible path; always offer it
        print('agents')
"
}
