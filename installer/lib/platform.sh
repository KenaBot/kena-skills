#!/usr/bin/env bash
# platform.sh — cross-platform detection and helpers for kena-skills
# Provides:
#   KENA_OS                   "linux" | "macos" | "wsl" | "windows" | "unknown"
#   KENA_SHELL                "bash" | "zsh" | "sh" | "unknown"
#   KENA_HAS_GIT_BASH         "true" | "false"
#   KENA_HAS_WSL              "true" | "false"
#   detect_os                 populates KENA_OS
#   detect_shell              populates KENA_SHELL
#   detect_windows_runtime    populates KENA_HAS_GIT_BASH / KENA_HAS_WSL
#   ensure_home               exports HOME if unset (Windows native)
#   resolve_symlink <path>    cross-platform realpath
#   make_symlink <src> <dst>  cross-platform symlink (copies on Windows without admin)
#   path_join <parts...>      cross-platform path joiner
#   user_home_dir             returns user home (Windows-aware)
#   config_dir                returns user config dir (Windows-aware)

# Detect the operating system.
# Sets KENA_OS to one of: linux, macos, wsl, windows, unknown
detect_os() {
  if [ -n "${KENA_OS:-}" ]; then return 0; fi

  local uname_s
  uname_s="$(uname -s 2>/dev/null || echo unknown)"
  # POSIX-portable lowercase (works on bash 3.2 / macOS default)
  uname_s=$(echo "$uname_s" | tr '[:upper:]' '[:lower:]')

  # WSL detection: /proc/version contains "Microsoft" or "WSL"
  if [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSLENV:-}" ]; then
    KENA_OS="wsl"
    return 0
  fi
  if [ -r /proc/version ] && grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then
    KENA_OS="wsl"
    return 0
  fi

  case "$uname_s" in
    linux)          KENA_OS="linux" ;;
    darwin)         KENA_OS="macos" ;;
    mingw*|msys*|cygwin*)
                     KENA_OS="windows" ;;
    *)              KENA_OS="unknown" ;;
  esac
  return 0
}

# Detect the shell currently running this script.
# Sets KENA_SHELL to one of: bash, zsh, sh, unknown
detect_shell() {
  if [ -n "${KENA_SHELL:-}" ]; then return 0; fi

  local shell_path
  shell_path="${BASH_SOURCE[0]:-$0}"
  if [ -n "${BASH_VERSION:-}" ]; then
    KENA_SHELL="bash"
  elif [ -n "${ZSH_VERSION:-}" ]; then
    KENA_SHELL="zsh"
  else
    KENA_SHELL="sh"
  fi
  return 0
}

# Detect whether Git Bash and/or WSL are available.
# Only relevant on Windows; on other OS, both stay false.
detect_windows_runtime() {
  KENA_HAS_GIT_BASH="false"
  KENA_HAS_WSL="false"

  if [ "${KENA_OS:-}" != "windows" ] && [ "${KENA_OS:-}" != "wsl" ]; then
    return 0
  fi

  if command -v bash.exe >/dev/null 2>&1; then
    KENA_HAS_GIT_BASH="true"
  fi
  if command -v wsl.exe >/dev/null 2>&1; then
    KENA_HAS_WSL="true"
  fi
  return 0
}

# Ensure $HOME is defined. On Windows native shells (cmd.exe),
# $HOME is not set. Fall back to %USERPROFILE% or %HOMEDRIVE%%HOMEPATH%.
# On Unix, if HOME is unset, try getent passwd $USER.
ensure_home() {
  if [ -n "${HOME:-}" ] && [ "$HOME" != "~" ]; then return 0; fi

  if [ -n "${USERPROFILE:-}" ]; then
    export HOME="$USERPROFILE"
    return 0
  fi
  if [ -n "${HOMEDRIVE:-}" ] && [ -n "${HOMEPATH:-}" ]; then
    export HOME="${HOMEDRIVE}${HOMEPATH}"
    return 0
  fi
  if [ -n "${USER:-}" ] && command -v getent >/dev/null 2>&1; then
    local pw_home
    pw_home=$(getent passwd "$USER" 2>/dev/null | cut -d: -f6)
    if [ -n "$pw_home" ] && [ -d "$pw_home" ]; then
      export HOME="$pw_home"
      return 0
    fi
  fi
  # Last resort: keep as ~ (test envs may have HOME unset intentionally)
  export HOME="~"
  return 0
}

# Return the user home directory as a resolved path.
user_home_dir() {
  ensure_home
  echo "$HOME"
}

# Return the user config directory.
# On Unix: $XDG_CONFIG_HOME or $HOME/.config
# On Windows: %APPDATA% or $HOME
config_dir() {
  ensure_home
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    echo "$XDG_CONFIG_HOME"
    return 0
  fi
  if [ -n "${APPDATA:-}" ]; then
    echo "$APPDATA"
    return 0
  fi
  echo "$HOME/.config"
}

# Cross-platform path joiner.
# Joins parts with the OS-appropriate separator.
path_join() {
  local sep="/"
  if [ "${KENA_OS:-}" = "windows" ]; then sep="\\"; fi
  local result=""
  local part
  for part in "$@"; do
    if [ -z "$part" ]; then continue; fi
    # Strip trailing separator from existing result
    result="${result%/}"
    result="${result%\\}"
    # Strip leading separator from part
    part="${part#/}"
    part="${part#\\}"
    if [ -z "$result" ]; then
      result="$part"
    else
      result="${result}${sep}${part}"
    fi
  done
  echo "$result"
}

# Cross-platform realpath.
# GNU: readlink -f
# BSD (macOS): no -f flag, fallback to python3 or cd+pwd
resolve_symlink() {
  local target="$1"
  if [ -z "$target" ]; then return 1; fi
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then return 1; fi

  # GNU readlink
  if readlink -f "$target" >/dev/null 2>&1; then
    readlink -f "$target"
    return 0
  fi

  # BSD readlink (macOS) — readlink works but no -f
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$target"
    return $?
  fi

  # Pure bash fallback: cd into dir and use pwd
  local dir
  dir=$(dirname "$target")
  if [ -d "$dir" ]; then
    (cd "$dir" && pwd)
    return 0
  fi

  return 1
}

# Cross-platform symlink creator.
# Unix: ln -sfn <src> <dst>
# Windows: tries cmd /c mklink /D, falls back to copy.
make_symlink() {
  local src="$1"
  local dst="$2"

  if [ -z "$src" ] || [ -z "$dst" ]; then return 1; fi

  detect_os

  # Remove existing link (if symlink) so we can recreate
  if [ -L "$dst" ]; then
    rm -f "$dst"
  fi

  case "${KENA_OS:-}" in
    linux|macos|wsl)
      ln -sfn "$src" "$dst"
      return $?
      ;;
    windows)
      # Strategy 1: try cmd /c mklink /D using bash-style paths directly
      # (Git Bash translates /c/foo to C:\foo automatically in cmd.exe context)
      if cmd.exe //c "mklink /D \"$(cygpath -w "$dst" 2>/dev/null || echo "$dst")\" \"$(cygpath -w "$src" 2>/dev/null || echo "$src")\"" >/dev/null 2>&1; then
        return 0
      fi
      # Strategy 2: try native cmd /c mklink with paths translated to Windows format
      local src_win dst_win
      src_win=$(echo "$src" | sed 's|^/\([a-zA-Z]\)/|\1:/|; s|/|\\|g' 2>/dev/null)
      dst_win=$(echo "$dst" | sed 's|^/\([a-zA-Z]\)/|\1:/|; s|/|\\|g' 2>/dev/null)
      if [ -n "$src_win" ] && [ -n "$dst_win" ]; then
        if cmd.exe //c "mklink /D \"$dst_win\" \"$src_win\"" >/dev/null 2>&1; then
          return 0
        fi
      fi
      # Strategy 3: recursive copy (always works, no symlink but functional)
      mkdir -p "$(dirname "$dst")" 2>/dev/null || return 1
      if cp -r "$src" "$dst" 2>/dev/null; then
        return 0
      fi
      return 1
      ;;
    *)
      ln -sfn "$src" "$dst"
      return $?
      ;;
  esac
}

# Resolve a relative path (e.g. ".config/opencode/skills") to an absolute
# user-level path, with Windows-aware override.
#
# Usage: resolve_global_dir <relative_path> [windows_path]
#   - On Unix: returns $HOME/<relative_path>
#   - On Windows: returns expanded <windows_path> (e.g. C:\Users\foo\.config\opencode\skills)
#   - If windows_path is empty or omitted, falls back to $HOME/<relative_path>
#
# %USERPROFILE% expansion: we read USERPROFILE directly to avoid eval.
resolve_global_dir() {
  local relative_path="$1"
  local windows_path="${2:-}"

  ensure_home
  detect_os

  if [ "${KENA_OS:-}" = "windows" ] && [ -n "$windows_path" ]; then
    # Expand %USERPROFILE% to actual value. Handle both %VAR% and $VAR style.
    local expanded="$windows_path"
    if [ -n "${USERPROFILE:-}" ]; then
      expanded="${expanded//%USERPROFILE%/$USERPROFILE}"
    elif [ -n "${HOME:-}" ]; then
      expanded="${expanded//%USERPROFILE%/$HOME}"
    fi
    # Convert backslashes to forward slashes for Git Bash compat
    expanded="${expanded//\\//}"
    echo "$expanded"
    return 0
  fi
  echo "$HOME/$relative_path"
}

# Auto-detect everything when sourced.
detect_os
detect_shell
detect_windows_runtime
ensure_home
export KENA_OS KENA_SHELL KENA_HAS_GIT_BASH KENA_HAS_WSL
