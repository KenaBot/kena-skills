# kena-skills

Registry of agent skills for the kena ecosystem. Distributable via `npx skills add kena/skills` and via a custom interactive installer (`kena-skills`).

## Compatibility

Each skill in this registry is **100% compatible** with all major agent runtimes that follow the [Agent Skills specification](https://agentskills.io):

- opencode
- claude-code
- codex
- agents-compatible runtimes (cline, cursor, zed, etc.)

A single skill file works across all of them. No variants, no duplication. The `kena-skills` installer lets you choose which targets to install to.

## Available skills

| Skill | Description | Dependencies |
|---|---|---|
| `deepsearch` | Hunting beast for hard bugs and broken flows. Orchestrates memory recall, goal-setting, code graph, and disciplined diagnosis. | `claude-mem`, `graphify` |

## Installation

### Option 1: `npx skills` (standard)

```bash
# Install deepsearch to opencode and claude-code globally
npx skills add kena/skills --skill deepsearch -a opencode -a claude-code -g

# Or pick a specific agent
npx skills add kena/skills --skill deepsearch -a opencode -g
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
  --target opencode,claude-code      # install to specific targets
kena-skills --all                    # install everything
kena-skills --no-tui --skill deepsearch \
  --target opencode                  # non-interactive (CI/script friendly)
```

The installer:
- Auto-detects which agents are installed (opencode, claude-code, codex, etc.)
- Lets you multi-select targets with space/enter
- Verifies hard-required dependencies (`claude-mem`, `graphify` for deepsearch)
- Offers to install missing dependencies
- Falls back gracefully: gum > dialog > whiptail > read (always works)

## Repository structure

```
kena-skills/
├── README.md                          # this file
├── .gitignore
├── skills/                            # standard layout for npx skills
│   └── deepsearch/                    # each skill in its own directory
│       ├── SKILL.md
│       ├── LICENSE
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── package.json
│       ├── references/                # loaded on demand
│       ├── scripts/
│       ├── tests/
│       └── backup/                    # snapshot of original v2.0.0
└── installer/                         # kena-skills CLI (separate from skills)
    ├── kena-skills                    # entry point
    ├── install.sh                     # bootstrap script
    ├── README.md
    ├── lib/
    │   ├── tui.sh                     # TUI abstraction (gum/dialog/whiptail/read)
    │   ├── detect-agents.sh           # auto-detect installed agents
    │   ├── list-skills.sh             # read skills/*/SKILL.md
    │   ├── check-deps.sh              # verify hard-required deps
    │   ├── install-skill.sh           # npx skills add wrapper
    │   └── agents.json                # supported agents registry
    └── templates/
        └── deepsearch-install.sh      # post-install validation
```

## Why one skill, not per-agent variants?

The Agent Skills specification is shared across all runtimes. Diverging per agent would mean:

- Duplication (every fix applied to N copies → drift)
- Distribution friction (`npx skills` expects single `SKILL.md` per skill)
- Maintenance burden (high)

A single skill with:
- `compatibility: opencode,claude-code` (opencode-spec compliant)
- `allowed-tools` (claude-code picks it up; opencode ignores silently per spec)
- Universal executable directives (e.g. "emit N `task` calls in one response block" — works in both runtimes because both execute tool calls within a single response block in parallel)

…is 100% compatible with all of them. No tricks, no variants.

## Adding a new skill

1. Create `skills/<name>/SKILL.md` with valid frontmatter (`name`, `description` required)
2. Add references, scripts, tests as needed
3. Document dependencies in `package.json` under `dependencies.required` and `dependencies.optional`
4. (Optional) Add a post-install template at `installer/templates/<name>-install.sh`
5. Bump version and update CHANGELOG

## License

MIT
