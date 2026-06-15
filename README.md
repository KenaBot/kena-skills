# kena-skills

Install skills for any AI agent from one place. One command, any platform, any agent.

```bash
curl -fsSL https://raw.githubusercontent.com/KenaBot/kena-skills/main/installer/install.sh | bash
kena-skills --list
```

That's it. The installer puts `kena-skills` in your `PATH`, builds the interactive TUI, and you're ready to go.

---

## Quick start

### 1. Install

**macOS / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/KenaBot/kena-skills/main/installer/install.sh | bash
```

**Windows (PowerShell — auto-detects Git Bash or WSL):**
```powershell
iex (irm https://raw.githubusercontent.com/KenaBot/kena-skills/main/installer/install.ps1)
```

**Windows (Git Bash directly):**
```bash
curl -fsSL https://raw.githubusercontent.com/KenaBot/kena-skills/main/installer/install.sh | bash
```

**From a git clone (contributors):**
```bash
git clone https://github.com/KenaBot/kena-skills.git ~/kena-skills
cd ~/kena-skills
./installer/install.sh
```

The installer auto-detects your OS, installs to `~/.kena-skills/`, and symlinks the `kena-skills` command into `~/.local/bin/`. Add `~/.local/bin` to your `PATH` if it isn't already.

### 2. Use

**List available skills:**
```bash
kena-skills --list
```

**Launch the interactive TUI** (multi-select, live progress, install state badges):
```bash
kena-skills ui
```

**Install a specific skill to specific agents:**
```bash
kena-skills --skill deepsearch --target opencode,claude
kena-skills --all --target opencode --install-deps
kena-skills --mcp claude-mem --install-deps
```

---

## What it does

`kena-skills` aggregates skills from multiple sources and installs them into the right location for each agent runtime you use.

**5 supported agents:**

| ID | What it is | Install path (Unix) |
|---|---|---|
| `opencode` | OpenCode CLI / TUI | `~/.config/opencode/skills/` |
| `claude` | Claude Code CLI | `~/.claude/skills/` |
| `copilot` | GitHub Copilot agent | `~/.copilot/skills/` |
| `codex` | OpenAI Codex CLI | `~/.codex/skills/` |
| `gemini` | Google Gemini CLI | `~/.gemini/skills/` |

**3 bundled sources:**

| Source | Type | What you get |
|---|---|---|
| `kena-skills` | local | `deepsearch` and other skills shipped with this repo |
| `juliusbrussee-caveman` | curl | `caveman` — compressed-output mode, 30+ agents |
| `mattpocock-skills` | npx | `diagnose`, `grill-me`, `tdd`, `triage`, `to-prd`, … |

**MCPs managed as dependencies:**

| MCP | Why you need it |
|---|---|
| `claude-mem` | Required by `deepsearch` (cross-session memory) |

---

## Usage

### Common commands

```bash
kena-skills --list                                  # all skills from all sources
kena-skills --list --source mattpocock-skills       # filter by source
kena-skills --skill deepsearch --target opencode    # install one skill
kena-skills --all --target opencode                 # install all defaults
kena-skills --all --install-deps                    # also install system deps + MCPs
kena-skills --mcp claude-mem --install-deps         # install one MCP
kena-skills --scope local --skill deepsearch        # install to ./.opencode/skills/ (project-local)
kena-skills ui                                      # launch the TUI
kena-skills --help                                  # full flag reference
```

### The interactive TUI

```
┌─────────────────────────────────────────────┐
│  kena-skills — interactive installer        │
└─────────────────────────────────────────────┘

Select skills to install. State badges show installed status.
▾ kena-skills
   [not installed]  deepsearch
▾ mattpocock-skills
   [installed: global]  diagnose
   [installed: global]  grill-me
▾ juliusbrussee-caveman
   [not installed]  caveman

▸ Selected: 2 (deepsearch, caveman)
Press [i] or [Enter] to configure and install
```

Keybindings in the TUI:

| Key | Action |
|---|---|
| `↑` / `↓` / `j` / `k` | Move cursor |
| `Space` | Toggle skill selection |
| `i` / `Enter` | Configure and install selected |
| `h` | Collapse / expand source group |
| `s` | Cycle scope (global / local) |
| `d` | Toggle auto-install of deps |
| `q` | Quit |

Multi-phase installs run sequentially with continue-on-fail: every selected skill is tried, and the result screen shows per-skill pass/fail with exit codes.

---

## Platform support

| OS | Bash | PowerShell | Notes |
|---|---|---|---|
| Linux | ✅ | — | GNU userland |
| macOS | ✅ | — | BSD userland (uses python3 fallback for `readlink -f`) |
| Windows + Git Bash | ✅ | — | Auto-detected via `MSYSTEM` |
| Windows + WSL | ✅ | — | Auto-detected via `WSL_DISTRO_NAME` |
| Windows + PowerShell | — | ✅ | `install.ps1` auto-detects Git Bash / WSL |

The installer auto-adapts:
- `readlink -f` → `python3` fallback on macOS
- `ln -s` → `cmd /c mklink /D` on Windows (falls back to copy if no admin)
- `$HOME` → `%USERPROFILE%` on Windows native
- Path separators (`/` vs `\`)

`.gitattributes` enforces LF line endings on all shell scripts, so Git on Windows won't corrupt them.

---

## What gets installed with `--all --install-deps`

| Skill | Source | How it's installed |
|---|---|---|
| `deepsearch` | kena-skills | symlink to your discovery dir |
| `caveman` | juliusbrussee-caveman | upstream `curl \| bash` (handles 30+ agents) |
| `diagnose`, `grill-me` | mattpocock-skills | `npx skills@latest add` |
| MCP `claude-mem` | @thedotmack/claude-mem | `npx` plugin (required by `deepsearch`) |

---

## Repository structure

```
kena-skills/
├── README.md                          # this file
├── CHANGELOG.md
├── .gitattributes                     # LF line endings on .sh, .json, etc.
├── .github/
│   ├── workflows/test.yml             # CI (manual, see "Tests" below)
│   ├── dependabot.yml
│   └── ISSUE_TEMPLATE/bug_report.yml
├── installer/                         # bash CLI (source of truth)
│   ├── kena-skills                    # entry point
│   ├── install.sh                     # bash bootstrap (curl|bash, git clone, npx)
│   ├── install.ps1                    # Windows PowerShell wrapper
│   ├── install.cmd                    # Windows double-click entry
│   ├── lib/
│   │   ├── platform.sh                # OS detection, symlink helpers
│   │   ├── output.sh                  # info/ok/warn/err
│   │   ├── tui.sh                     # gum/dialog/whiptail/read fallback
│   │   ├── json.sh                    # bash-pure JSON parser
│   │   ├── detect-agents.sh
│   │   ├── list-skills.sh             # multi-source listing
│   │   ├── install-skill.sh           # dispatcher (source-aware)
│   │   ├── check-deps.sh
│   │   ├── source-npx.sh              # mattpocock
│   │   ├── source-curl.sh             # juliusbrussee
│   │   ├── source-local.sh            # kena-skills
│   │   ├── mcp-install.sh             # claude-mem
│   │   ├── sources.json
│   │   ├── agents.json
│   │   └── mcps.json
│   ├── templates/                     # per-source post-install validation
│   └── tests/                         # 34 bash tests, run-all.sh
├── ui/                                # Ink TUI (TypeScript, delegates to bash)
│   ├── package.json
│   ├── tsconfig.json
│   ├── src/                           # App, components, hooks
│   └── dist/                          # tsc output (gitignored)
└── skills/
    └── deepsearch/                    # local source: hunting skill
```

---

## Tests

34 bash tests + 5 lint checks. Run them locally:

```bash
bash installer/tests/run-all.sh
```

CI is manual — go to the [Actions tab](../../actions/workflows/test.yml) and click **Run workflow**. Inputs let you toggle bash tests, PowerShell wrapper, and shellcheck independently.

---

## License

MIT
