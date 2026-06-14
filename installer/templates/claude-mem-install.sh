#!/usr/bin/env bash
# claude-mem-install.sh — post-install validation for the claude-mem MCP server
# MCP servers are not skills; they run as background services and are
# connected to agents via MCP protocol.
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
# shellcheck source=../lib/json.sh
source "$LIB_DIR/json.sh"
# shellcheck source=../lib/mcp-install.sh
source "$LIB_DIR/mcp-install.sh"

echo ""
echo "Validating claude-mem MCP server..."
echo ""

if check_mcp "claude-mem"; then
  echo "  [OK] claude-mem is installed"
  # Find installation path
  for d in "$HOME"/.npm/_npx/*/node_modules/claude-mem; do
    if [ -d "$d" ]; then
      echo "  [INFO] npx cache: $d"
      break
    fi
  done
  if [ -d "$HOME/.claude/plugins/data/claude-mem-thedotmack" ]; then
    echo "  [INFO] Claude plugin data: $HOME/.claude/plugins/data/claude-mem-thedotmack"
  fi
else
  echo "  [MISSING] claude-mem is NOT installed"
  echo "  Install with: npx -y @thedotmack/claude-mem install"
  echo "  Or: kena-skills --mcp claude-mem --install-deps"
fi

echo ""
echo "Note: claude-mem is an MCP server, not a skill. It's invoked by agents via"
echo "the Model Context Protocol. See https://github.com/thedotmack/claude-mem"
echo ""
