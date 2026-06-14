# kena-skills UI

Interactive TUI for the [KenaBot/kena-skills](https://github.com/KenaBot/kena-skills) registry. Built with [Ink](https://github.com/vadimdemedes/ink) (React for CLIs).

## What it does

Instead of remembering CLI flags, you get a navigable TUI:

- Switch sources with `←/→` (kena-skills, mattpocock-skills, juliusbrussee-caveman)
- Pick a skill with `↑/↓` + `Enter`
- Multi-select target agents with `Space`
- Toggle `--dry-run` with `d`, `--install-deps` with `a`
- Watch the install stream in real time
- See the result with exit code

The UI **delegates** all installation work to the bash `kena-skills` CLI via `child_process.spawn`. The bash installer is still the source of truth.

## Requirements

- Node ≥18
- npm (or pnpm/yarn)

## Build

```bash
cd ui
npm install
npm run build
```

Output goes to `ui/dist/cli.js`. The `kena-skills` bash entry point auto-detects this and uses it.

## Run

From the repo root:

```bash
# Explicit
kena-skills ui

# Auto-detect (when in a TTY and UI is built)
kena-skills
```

## Development

```bash
cd ui
npm run dev   # tsx watch
```

This watches `src/` and rebuilds on change. Run `kena-skills ui` from another terminal to see the updates.

## Architecture

```
ui/
├── package.json
├── tsconfig.json
├── src/
│   ├── cli.tsx               # entry point: <App /> into ink
│   ├── App.tsx               # root component, screen state machine
│   ├── types.ts              # TS interfaces for JSON registries
│   ├── components/
│   │   ├── Header.tsx
│   │   ├── SourceSelector.tsx
│   │   ├── SkillList.tsx
│   │   ├── TargetSelector.tsx
│   │   ├── FlagsBar.tsx
│   │   ├── ProgressView.tsx
│   │   ├── ResultView.tsx
│   │   └── Footer.tsx
│   └── hooks/
│       ├── useData.ts        # loadData() + listInstalledAgents()
│       └── useInstall.ts     # spawn() wrapper with stdout streaming
└── dist/                      # tsc output (gitignored)
```

## Screens

| Screen | Description | Keybindings |
|---|---|---|
| `browse` | Pick a source and skill | `←/→` source, `↑/↓` skill, `Enter` select |
| `targets` | Multi-select target agents | `Space` toggle, `Enter` confirm, `Esc` back |
| `flags` | Toggle dry-run / install-deps | `d` dry-run, `a` install-deps, `Enter` run |
| `executing` | Streaming install output | `Ctrl+C` cancel |
| `result` | Success/failure with exit code | `Enter` back, `q` quit |

## Fallback behavior

If `node` is not in PATH **or** `ui/dist/cli.js` does not exist, `kena-skills ui` falls back to an informative error. The bash installer itself is unaffected — you can always use `kena-skills --list`, `kena-skills --skill X --target Y`, etc.

## Why Ink?

- **Same mental model as web React.** Components, hooks, state, props.
- **Cross-platform.** macOS, Linux, Windows (via WSL or Git Bash).
- **Tiny footprint.** ~10MB including deps (ink + react).
- **Used by big tools.** Vercel CLI, npm (in some subcommands), Supabase, TikTok's internal tools.

Alternatives considered: `blessed` (older, less idiomatic), `blessed-contrib`, `gum` (Go binary, requires install), `dialog` (legacy C tool). Ink wins on developer experience.

## License

MIT
