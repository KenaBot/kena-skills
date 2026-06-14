#!/usr/bin/env bash
# output.sh — output helpers (info, ok, warn, err, log, color setup)
# Loaded first by kena-skills entry point so all other libs can use these.

# Color setup (only when stdout is a TTY)
if [ -t 1 ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[0;33m'
  C_RED=$'\033[0;31m'
  C_CYAN=$'\033[0;36m'
  C_DIM=$'\033[2m'
else
  C_RESET=""
  C_BOLD=""
  C_GREEN=""
  C_YELLOW=""
  C_RED=""
  C_CYAN=""
  C_DIM=""
fi

log() { [ "${VERBOSE:-false}" = "true" ] && echo "${C_DIM}[debug]${C_RESET} $*" >&2 || true; }
info() { echo "${C_CYAN}==>${C_RESET} $*" >&2; }
ok() { echo "${C_GREEN}✓${C_RESET} $*" >&2; }
warn() { echo "${C_YELLOW}!${C_RESET} $*" >&2; }
err() { echo "${C_RED}✗${C_RESET} $*" >&2; }
