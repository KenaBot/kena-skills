# kena-skills

Multi-source skill registry and installer for the kena ecosystem. Distributes skills from 3 sources to 5 agent runtimes, with an interactive Ink TUI for the user-friendly path and full CLI flags for scripts/CI.

**Upstream repo:** [github.com/KenaBot/kena-skills](https://github.com/KenaBot/kena-skills)

## Platform support

The installer is bash-based and runs on the three major platforms:

| OS | Bash | PowerShell wrapper | Tested in CI |
|---|---|---|---|
| Linux | ✅ native | — | ✅ |
| macOS | ✅ native (BSD userland) | — | ✅ |
| Windows + Git Bash | ✅ | — | ✅ |
| Windows + WSL | ✅ | — | ✅ |
| Windows + PowerShell (no bash) | — | ✅ (auto-detects Git Bash / WSL) | ✅ |

The installer auto-detects the runtime environment (GNU vs BSD userland, Windows vs Unix paths, Git Bash vs WSL) and adapts symlink creation, path resolution, and HOME lookup. The `.gitattributes` file enforces LF line endings on all shell scripts, so Git on Windows won't corrupt them.

## Supported agents (5)

| Display id | `npx skills` flag | Global path |
|---|---|---|
| `opencode` | `opencode` | `~/.config/opencode/skills/` |
| `claude` | `claude-code` | `~/.claude/skills/` |
| `copilot` | `github-copilot` | `~/.copilot/skills/` |
| `codex` | `codex` | `~/.codex/skills/` |
| `gemini` | `gemini-cli` | `~/.gemini/skills/` |

## Supported sources (3) + MCPs

| Source id | Type | What it provides |
|---|---|---|
| `kena-skills` | local | `deepsearch` and other skills hosted in this repo |
| `juliusbrussee-caveman` | curl | `caveman` by JuliusBrussee (72k stars, ~75% token savings) |
| `mattpocock-skills` | npx | `diagnose`, `grill-me`, `tdd`, `triage`, `to-prd`, etc. (128k stars) |

**MCP servers** (managed as dependencies, not skills):

| MCP id | Source | Required by |
|---|---|---|
| `claude-mem` | `@thedotmack/claude-mem` | `deepsearch` |

## Installation

### Option 1: `npx kena-skills` (once published to npm) — easiest

After publishing the package to npm, anyone can install and use kena-skills with zero setup:

```bash
# Run without installing (npx handles deps)
npx kena-skills@latest --list
npx kena-skills@latest --skill deepsearch --target opencode,claude
npx kena-skills@latest ui         # launch the Ink TUI

# Or install globally
npm install -g kena-skills
kena-skills ui
```

**How to publish:**

1. Create a new npm package `kena-skills` that wraps this repo. The recommended structure is:

   ```
   kena-skills-npm/                  # the published package
   ├── package.json                  # { "name": "kena-skills", "bin": { "kena-skills": "./bin.js" } }
   ├── bin.js                        # entry: spawns bash <repo>/installer/install.sh
   ├── README.md                     # points to github.com/KenaBot/kena-skills
   └── ...
   ```

2. The simplest `bin.js` (uses Node to fetch + run the installer):

   ```js
   #!/usr/bin/env node
   const {execSync} = require('node:child_process');
   const REPO = 'https://raw.githubusercontent.com/KenaBot/kena-skills/main';
   execSync(`curl -fsSL ${REPO}/installer/install.sh | bash`, { stdio: 'inherit' });
   ```

3. Publish:

   ```bash
   cd kena-skills-npm
   npm login
   npm publish
   ```

   Then `npx kena-skills@latest` works for anyone.

4. **Alternative (zero npm publish):** users can run the bootstrap directly:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/KenaBot/kena-skills/main/installer/install.sh | bash
   kena-skills --list
   ```

### Option 2: `git clone` + bootstrap (for contributors and self-hosters)

```bash
# Clone the repo
git clone https://github.com/KenaBot/kena-skills.git ~/kena-skills
cd ~/kena-skills

# Run the installer (creates symlinks in ~/.agents/skills, ~/.config/opencode/skills, etc.)
./installer/install.sh
# or: bash installer/kena-skills ui   # launches the TUI

# Build the UI (optional, but recommended for interactive use)
cd ui && npm install && npm run build && cd ..
```

The installer script:
- Creates symlinks from the checkout to your discovery dirs (`~/.config/opencode/skills/deepsearch`, `~/.claude/skills/deepsearch`, etc.)
- Optionally adds `~/kena-skills/installer` to your `PATH` as `kena-skills` via `~/.local/bin/`
- Builds the UI if Node is available
- Falls back gracefully if anything is missing

### Option 3: Ink TUI (recommended for interactive use)

The TUI lets you:
- Browse skills grouped by source with `[h]` to collapse groups
- See install state per skill: `[not installed]` / `[installed: global]` / `[installed: local]` / `[installed: global+local]`
- Multi-select with `Space`
- Configure per-skill (targets, scope, install-deps) in `phase-config` screen
- Run multi-phase installs sequentially (continue-on-fail)
- Stream live output with exit code per phase

The TUI is built with [Ink](https://github.com/vadimdemedes/ink) (React for CLIs).

If you run `kena-skills` with no args in a TTY and the UI is built, it auto-launches.

### Option 4: CLI flags (recommended for scripts/CI)

```bash
kena-skills --list                              # list all skills from all sources
kena-skills --list --source mattpocock-skills   # filter by source
kena-skills --skill deepsearch --target opencode,claude
kena-skills --skill caveman --target opencode   # juliusbrussee/caveman via curl
kena-skills --skill diagnose --target claude    # mattpocock via npx
kena-skills --mcp claude-mem --install-deps     # install MCP dependency
kena-skills --scope local --skill deepsearch    # install to .opencode/skills/ instead of global
kena-skills ui                                  # launch the TUI
kena-skills --all --target opencode --install-deps
```

For `npx` users (without global install):

```bash
npx --package=kena-skills kena-skills --list
npx --package=kena-skills kena-skills ui
```
kena-skills --all --target opencode --install-deps
```

### Option 3: `npx skills` (standard, partial coverage)

For skills from mattpocock or our local skills:

```bash
npx skills add kena/skills --skill deepsearch -a opencode -a claude -g
npx skills@latest add mattpocock/skills --skill diagnose -a opencode -g
```

For caveman from JuliusBrussee, use his curl installer:

```bash
curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash
```

The `kena-skills` installer wraps all three under one unified interface.

## What gets installed with `kena-skills --all --install-deps`

| Skill | Source | Method | Targets |
|---|---|---|---|
| `deepsearch` | kena-skills | symlink or npx skills add | opencode, claude, copilot, codex, gemini |
| `caveman` | juliusbrussee-caveman | curl-pipe (handles 30+ agents) | all detected |
| `diagnose` | mattpocock-skills | `npx skills@latest add` | opencode, claude, copilot, codex, gemini |
| `grill-me` | mattpocock-skills | `npx skills@latest add` | opencode, claude, copilot, codex, gemini |
| MCP `claude-mem` | @thedotmack/claude-mem | npx plugin | as required by Claude plugins |

## Repository structure

```
kena-skills/
├── README.md                          # this file
├── CHANGELOG.md
├── .gitignore
├── skills/                            # local skills (kena-skills source)
│   ├── deepsearch/                    # hunting beast for hard bugs
│   └── _caveman-ysm-dev-removed-v1.2/ # old caveman (ysm-dev) — kept for rollback
├── installer/                         # kena-skills CLI (bash, source of truth)
│   ├── kena-skills                     # entry point
│   ├── install.sh                     # bash bootstrap
│   ├── lib/
│   │   ├── output.sh                   # info/ok/warn/err helpers
│   │   ├── tui.sh                      # gum/dialog/whiptail/read fallback
│   │   ├── json.sh                     # bash-pure JSON parser
│   │   ├── detect-agents.sh
│   │   ├── list-skills.sh             # multi-source listing
│   │   ├── install-skill.sh           # dispatcher (source-aware)
│   │   ├── check-deps.sh
│   │   ├── source-npx.sh               # mattpocock
│   │   ├── source-curl.sh              # juliusbrussee
│   │   ├── source-local.sh             # kena-skills
│   │   ├── mcp-install.sh              # claude-mem
│   │   ├── sources.json                # registry of skill sources
│   │   ├── mcps.json                   # registry of MCP servers
│   │   └── agents.json                 # registry of supported agents
│   └── templates/
│       ├── deepsearch-install.sh
│       ├── juliusbrussee-caveman-install.sh
│       ├── mattpocock-install.sh
│       └── claude-mem-install.sh
├── ui/                                # Ink TUI (TypeScript, delegates to bash)
│   ├── package.json
│   ├── tsconfig.json
│   ├── src/
│   │   ├── cli.tsx
│   │   ├── App.tsx
│   │   ├── types.ts
│   │   ├── components/
│   │   │   ├── Header.tsx
│   │   │   ├── SourceSelector.tsx
│   │   │   ├── SkillList.tsx
│   │   │   ├── TargetSelector.tsx
│   │   │   ├── FlagsBar.tsx
│   │   │   ├── ProgressView.tsx
│   │   │   ├── ResultView.tsx
│   │   │   └── Footer.tsx
│   │   └── hooks/
│   │       ├── useData.ts
│   │       └── useInstall.ts
│   ├── dist/                           # tsc output (gitignored)
│   └── README.md
├── backup-v1.0/                        # snapshots pre-cambio
├── backup-v1.1/
└── backup-ui-v1.2/                     # (optional) snapshot of pre-UI state
```

## Why one skill, not per-agent variants?

The Agent Skills specification is shared across all runtimes. Diverging per agent would mean duplication, drift, and distribution friction. A single skill with:
- `compatibility: opencode,claude-code` (opencode-spec compliant)
- `allowed-tools` (claude-code picks it up; opencode ignores silently per spec)
- Universal executable directives (e.g. "emit N `task` calls in one response block" — works in all runtimes)

is 100% compatible with all of them. No tricks, no variants.

## License

MIT
