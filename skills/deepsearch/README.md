# deepsearch

Hunting beast for hard bugs and broken flows. Orchestrates memory recall, goal-setting, code graph, and disciplined diagnosis into a single pipeline.

## What it does

`/deepsearch` runs a 5-phase hunting pipeline:

1. **Memory recall** — searches past observations (claude-mem) for related bugs/fixes
2. **Goal-setting** — defines what success looks like (Goal-Question-Metric)
3. **Code map** — builds or queries a knowledge graph of the codebase (graphify)
4. **Diagnose** — runs the disciplined diagnosis loop (reproduce → hypothesize → instrument → fix)
5. **Report** — produces a structured report with findings, evidence, and next steps

Two modes:

- `bug` (default) — hunt errors, exceptions, race conditions, flaky tests
- `flow` — trace broken flows, analyze refactor risk, document assumptions

Parallel execution: up to 5 explore agents by default, dispatched in a single response block via the `task` tool. Configurable via `--agents N` (range 1-20).

## Triggers

`/deepsearch`, `/deepsh`, `/ds`, `/bug-hunt`, `/hunt` — all load this skill.

## Installation

### One-liner (recommended)

```bash
./scripts/install.sh
```

This creates symlinks in all three standard discovery paths:

- `~/.config/opencode/skills/deepsearch` (opencode canonical)
- `~/.claude/skills/deepsearch` (claude-code)
- `~/.agents/skills/deepsearch` (agents-compatible)

### Manual

```bash
ln -s /path/to/deepsearch ~/.config/opencode/skills/deepsearch
ln -s /path/to/deepsearch ~/.claude/skills/deepsearch
ln -s /path/to/deepsearch ~/.agents/skills/deepsearch
```

### `npx skills` (when published)

```bash
npx skills add deepsearch
```

## Usage

```bash
# Hunt a specific bug with description
/deepsearch "race condition in payment webhook"

# Free scan of latent bugs
/deepsh bug --auto

# Flow analysis with maximum parallelism
/deepsearch flow --agents 20

# Pure sequential mode (one agent at a time)
/deepsearch --agents 1

# Degraded mode (skip graphify)
/deepsearch --no-graph

# Force graphify rebuild
/deepsearch --update
```

### Flags

| Flag | Default | Description |
|---|---|---|
| `--auto` | off | Skip gatekeeper, use generic objective |
| `--update` | off | Rebuild graphify graph |
| `--no-graph` | off | Skip graphify, use mem + grep only |
| `--budget N` | 1500 | Token cap for graphify query |
| `--mode bug\|flow` | bug | Switch mode |
| `--agents N` | 5 | Max simultaneous explore agents (1-20) |

## Architecture

```
/deepsearch
├── SKILL.md                          # main skill definition
├── LICENSE                           # MIT
├── README.md                         # this file
├── CHANGELOG.md                      # version history
├── package.json                      # npx skills manifest
├── references/                       # loaded on demand
│   ├── parallel-protocol.md          # parallelism rules + anti-patterns
│   ├── goal-protocol.md              # Goal-Question-Metric template
│   ├── diagnose-checklist.md         # 6 phases of diagnose, operational
│   └── output-template.md            # final report template
├── scripts/
│   └── install.sh                    # symlink management
└── tests/
    ├── test-frontmatter.sh           # validate frontmatter spec
    ├── test-triggers.sh              # verify aliases in description
    ├── test-references.sh            # check referenced files + paths
    └── run-all.sh                    # run all tests
```

## Testing

```bash
./tests/run-all.sh
```

Validates that the skill meets the opencode spec (frontmatter), all aliases appear in the description, all referenced files exist, and no hardcoded paths leak into the body.

## Parallelism — read this if `--agents N` does not work

If you invoke `/deepsearch --agents 5` and the opencode UI still shows only one agent at a time, the issue is **not** with the flag. The runtime executes tool calls within a single response message in parallel. If the orchestrator (the LLM driving the skill) emits one `task` call per response, the work is sequential even with `--agents 5`.

The skill's `SKILL.md` contains a **CRITICAL: Dispatching parallel agents** section that explicitly directs the LLM to emit all N `task` calls in ONE response block. If you see sequential behavior, check that:

1. The `task` tool is available in the agent's toolset (see `SKILL.md` → "Tools required")
2. The skill's directive is being followed — it may be in a different position in your context

Fallback: if `task` is unavailable, the skill runs in sequential mode and reports it as "sequential-fallback" in the final report.

## Contributing

- Frontmatter must follow opencode spec: only `name`, `description`, `license`, `compatibility`, `metadata` are recognized
- `metadata` must be a string-to-string map (no arrays, no objects)
- `description` must be in English, 50-1024 chars
- All aliases (`deepsearch`, `deepsh`, `ds`, `bug-hunt`, `hunt`) must appear literally in `description`
- No hardcoded `~/.claude/`, `~/.agents/skills/`, or `~/.config/opencode/` paths in the body or references
- Run `./tests/run-all.sh` before committing

## Compatibility

- **opencode**: full support (canonical path `~/.config/opencode/skills/`)
- **claude-code**: full support (path `~/.claude/skills/`)
- **agents-compatible**: full support (path `~/.agents/skills/`)

## License

MIT — see [LICENSE](LICENSE).
