# kena-skills

Registry of agent skills for the kena ecosystem. Distributable via `npx skills add kena/skills` and via a custom interactive installer (`kena-skills`).

## Compatibility

Each skill in this registry is **100% compatible** with the five supported agent runtimes. A single skill file works across all of them — no variants, no duplication. The Agent Skills specification is shared; the `kena-skills` installer lets you choose which targets to install to.

### Supported agents (5)

| Display id | `npx skills` flag | Global path | Notes |
|---|---|---|---|
| `opencode` | `opencode` | `~/.config/opencode/skills/` | OpenCode CLI and TUI |
| `claude` | `claude-code` | `~/.claude/skills/` | Anthropic Claude Code (id is "claude" for display, "claude-code" is the npx flag) |
| `copilot` | `github-copilot` | `~/.copilot/skills/` | GitHub Copilot agent |
| `codex` | `codex` | `~/.codex/skills/` | OpenAI Codex CLI |
| `gemini` | `gemini-cli` | `~/.gemini/skills/` | Google Gemini CLI |

## Available skills

| Skill | Description | Dependencies |
|---|---|---|
| `deepsearch` | Hunting beast for hard bugs and broken flows. Orchestrates memory recall, goal-setting, code graph, and disciplined diagnosis. | `claude-mem`, `graphify` |
| `caveman` | Ultra-compressed communication mode. Drops filler, articles, and pleasantries. Cuts token usage ~75%. | none |

## Installation

### Option 1: `npx skills` (standard)

```bash
# Install deepsearch to opencode and claude-code globally
npx skills add kena/skills --skill deepsearch -a opencode -a claude-code -g

# Install caveman to all five
npx skills add kena/skills --skill caveman -a opencode -a claude-code -a github-copilot -a codex -a gemini-cli -g
```

The `npx skills` CLI (maintained by Vercel Labs) handles symlink creation and multi-target installation natively.

### Option 2: `kena-skills` interactive installer

Custom installer with TUI, auto-detection of installed agents, and dependency management.

```bash
# Bootstrap (one-time)
curl -fsSL https://raw.githubusercontent.com/kena/skills/main/installer/install.sh | bash

# Then use it
kena-skills                          # interactive menu
kena-skills --list                   # list available skills
kena-skills --skill deepsearch       # install deepsearch (prompts for targets)
kena-skills --skill deepsearch \
  --target opencode,claude           # install to specific targets
kena-skills --all --target opencode  # install everything to opencode
kena-skills --no-tui --skill deepsearch \
  --target opencode --install-deps   # CI / script mode
```

The installer:
- Auto-detects which of the 5 agents are installed
- Lets you multi-select targets with space/enter (TUI)
- Verifies hard-required dependencies (e.g. `claude-mem`, `graphify` for deepsearch)
- Offers to install missing dependencies
- Falls back gracefully: gum > dialog > whiptail > read (always works)

## Repository structure

```
kena-skills/
├── README.md                          # this file
├── CHANGELOG.md
├── .gitignore
├── skills/                            # standard layout for npx skills
│   ├── deepsearch/                    # v2.1.0, hard-deps on claude-mem + graphify
│   │   ├── SKILL.md
│   │   ├── LICENSE
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── package.json
│   │   ├── references/
│   │   ├── scripts/
│   │   ├── tests/
│   │   └── backup/                    # snapshot of v2.0.0
│   └── caveman/                       # v1.0.0, no dependencies
│       ├── SKILL.md
│       ├── LICENSE
│       └── package.json
└── installer/                         # kena-skills CLI (separate from skills)
    ├── kena-skills                    # entry point
    ├── install.sh                     # bootstrap script
    ├── README.md
    ├── lib/
    │   ├── tui.sh                     # TUI abstraction (gum/dialog/whiptail/read)
    │   ├── json.sh                    # bash-pure JSON parser
    │   ├── detect-agents.sh           # auto-detect installed agents
    │   ├── list-skills.sh             # read skills/*/SKILL.md
    │   ├── check-deps.sh              # verify hard-required deps
    │   ├── install-skill.sh           # npx skills add wrapper
    │   └── agents.json                # registry of the 5 supported agents
    └── templates/
        ├── deepsearch-install.sh      # post-install validation for deepsearch
        └── caveman-install.sh         # post-install validation for caveman
```

## Why one skill, not per-agent variants?

The Agent Skills specification is shared across all runtimes. Diverging per agent would mean:

- Duplication (every fix applied to N copies → drift)
- Distribution friction (`npx skills` expects single `SKILL.md` per skill)
- Maintenance burden

A single skill with:
- `compatibility: opencode,claude-code` (opencode-spec compliant)
- `allowed-tools` (claude-code picks it up; opencode ignores silently per spec)
- Universal executable directives (e.g. "emit N `task` calls in one response block" — works in all runtimes)

…is 100% compatible with all of them. No tricks, no variants.

## Adding a new skill

1. Create `skills/<name>/SKILL.md` with valid frontmatter (`name`, `description` required)
2. Add references, scripts, tests as needed
3. Document dependencies in `package.json` under `dependencies.required` and `dependencies.optional`
4. (Optional) Add a post-install template at `installer/templates/<name>-install.sh`
5. Bump version and update CHANGELOG

## License

MIT
