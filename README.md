# kena-skills

Multi-source skill registry and installer for the kena ecosystem. Distributes skills from 3 sources to 5 agent runtimes, with an interactive Ink TUI for the user-friendly path and full CLI flags for scripts/CI.

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

### Option 1: Ink TUI (recommended for interactive use)

```bash
# One-time: build the UI
cd ui && npm install && npm run build && cd ..

# Launch
kena-skills ui
```

The TUI lets you:
- Switch between sources (`←/→`)
- Pick a skill (`↑/↓`, `Enter`)
- Multi-select target agents (`Space`)
- Toggle `--dry-run` (`d`) and `--install-deps` (`a`)
- Watch the install stream in real time
- See success/failure with exit code

The TUI is built with [Ink](https://github.com/vadimdemedes/ink) (React for CLIs).

If you run `kena-skills` with no args in a TTY and the UI is built, it auto-launches.

### Option 2: CLI flags (recommended for scripts/CI)

```bash
kena-skills --list                              # list all skills from all sources
kena-skills --list --source mattpocock-skills   # filter by source
kena-skills --skill deepsearch --target opencode,claude
kena-skills --skill caveman --target opencode   # juliusbrussee/caveman via curl
kena-skills --skill diagnose --target claude    # mattpocock via npx
kena-skills --mcp claude-mem --install-deps     # install MCP dependency
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
