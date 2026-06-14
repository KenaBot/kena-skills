# kena-skills installer

Custom interactive installer for the `kena/skills` registry. Sits alongside the standard `npx skills` workflow — you can use either.

## What it does

`kena-skills` is a bash CLI that:

1. **Auto-detects** which agent runtimes are installed (opencode, claude-code, codex, agents-compatible)
2. **Lists** available skills from the `skills/` directory
3. **Lets you multi-select** target agents (with TUI if available, CLI flags otherwise)
4. **Validates hard-required dependencies** (e.g. `claude-mem`, `graphify` for deepsearch)
5. **Optionally installs** missing dependencies
6. **Calls `npx skills add`** (or falls back to manual symlink) for each target
7. **Runs a post-install template** that validates the setup

## Installation

### One-liner (curl-pipeable)

```bash
curl -fsSL https://raw.githubusercontent.com/kena/skills/main/installer/install.sh | bash
```

This installs to `~/.kena-skills/` and creates a symlink at `~/.local/bin/kena-skills`.

### From a local clone

```bash
git clone https://github.com/kena/skills ~/kena-skills
cd ~/kena-skills
./installer/install.sh
```

### Custom paths

```bash
INSTALL_DIR=/opt/kena-skills BIN_DIR=/usr/local/bin ./installer/install.sh
```

## Usage

### Interactive mode (default)

```bash
kena-skills
```

Walks you through:

1. Detects installed agents
2. Multi-select targets (TUI checklist)
3. Selects a skill to install
4. Confirms and installs

### Non-interactive mode

```bash
# List available skills
kena-skills --list

# Install a specific skill
kena-skills --skill deepsearch

# Install to specific targets
kena-skills --skill deepsearch --target opencode,claude-code

# Install all skills
kena-skills --all --target opencode

# Auto-install missing dependencies
kena-skills --skill deepsearch --target opencode --install-deps

# Dry run (show what would be done)
kena-skills --skill deepsearch --target opencode --dry-run

# CI / script mode (no TUI, no prompts)
kena-skills --no-tui --skill deepsearch --target opencode --install-deps
```

### Flags

| Flag | Description |
|---|---|
| `--list` | List available skills without installing |
| `--skill <name>` | Install a specific skill |
| `--all` | Install all skills |
| `--target <list>` | Comma-separated target agents: `opencode,claude-code,codex,agents` |
| `--install-deps` | Auto-install missing hard-required dependencies |
| `--no-tui` | Disable TUI, use CLI flags only |
| `--dry-run` | Show what would be done without doing it |
| `--verbose` | Verbose output |
| `--repo <name>` | Override repo name (default `kena/skills`) |
| `--skills-dir <path>` | Override skills directory |
| `--help`, `-h` | Show help |

## TUI backends

The installer auto-detects the best TUI tool available, in this order:

1. **gum** (Charmbracelet) — modern, beautiful
2. **dialog** — legacy classic
3. **whiptail** — newt-based
4. **read** (bash builtin) — always works, no TUI

If none of gum/dialog/whiptail is installed, the installer falls back to `read` and works fine (just less visual). To install gum:

```bash
# macOS
brew install gum

# Linux
echo 'deb [trusted=yes] https://repo.charm.sh/apt/ /' | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum
```

## Architecture

```
installer/
├── kena-skills              # entry point bash script
├── install.sh               # bootstrap (curl | bash)
├── lib/
│   ├── tui.sh               # TUI abstraction
│   ├── detect-agents.sh     # auto-detect installed agents
│   ├── list-skills.sh       # read skills/*/SKILL.md
│   ├── check-deps.sh        # verify hard-required deps
│   ├── install-skill.sh     # npx skills add wrapper
│   └── agents.json          # registry of supported agents
└── templates/
    └── <skill>-install.sh   # post-install validation per skill
```

The installer delegates to `npx skills add` when possible, with a manual-symlink fallback if `npx` is unavailable or fails.

## Compatibility

`kena-skills` runs on any system with bash 4+ and python3. It works on macOS, Linux, and Windows (via WSL or Git Bash).

## License

MIT
