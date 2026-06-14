# Changelog

All notable changes to `kena-skills` are documented here.

## [1.4.0] - 2026-06-14

### Added
- **Hierarchical browse screen** — skills grouped by source with collapsable groups
- **State badges** — each skill shows `[not installed]` / `[installed: global]` / `[installed: local]` / `[installed: global+local]`
- **Phase-based installation** — per-skill configuration in a dedicated `phase-config` screen (targets, scope, install-deps)
- **Install queue** — multiple skills run sequentially with **continue-on-fail** behavior
- **`--scope <global|local>` flag** in bash installer (default: global)
- **`force_scope` field in sources.json** — sources like juliusbrussee-caveman can force a scope
- New components: `SkillGroup`, `PhaseConfig`
- Refactored: `ProgressView` (multi-phase), `ResultView` (per-skill)
- Removed: `SkillList`, `TargetSelector`, `FlagsBar`, `useInstall` (replaced by `useInstallQueue`)

### Changed
- Screen flow: `browse → phase-config → executing → result` (was: `browse → targets → flags → executing → result`)
- Each phase shows live spinner + streaming output + exit code
- `useInstallQueue` runs phases sequentially, marking errors but continuing

## [1.3.0] - 2026-06-14

### Added
- **`kena-skills ui` — interactive Ink TUI** built with TypeScript + Ink + React
  - Switch sources with `←/→`
  - Pick a skill with `↑/↓` + `Enter`
  - Multi-select target agents with `Space`
  - Toggle `--dry-run` with `d`, `--install-deps` with `a`
  - Stream install output in real time
  - See success/failure result with exit code
- **Auto-launch:** running `kena-skills` with no args in a TTY + Node + built UI auto-starts the Ink TUI
- **Explicit launch:** `kena-skills ui [args...]` opens the TUI directly
- **Graceful fallback:** if Node 18+ missing or UI not built, prints a clear error and exits non-zero
- **Bash installer is source of truth:** the UI spawns the bash CLI via `child_process.spawn` and streams stdout
- New `ui/` directory: 16 TypeScript/TSX files (~800 lines), 8 components, 2 hooks
- 4 new dependencies: `ink`, `ink-spinner`, `ink-text-input`, `react` (peer)

### Changed
- `installer/kena-skills` defines `launch_ui()` and `UI_DIST` at top, before the parse loop, so `ui)` case can dispatch
- Help text now shows `kena-skills ui` as a primary entry point

## [1.2.0] - 2026-06-14

### Added
- Multi-source registry (`installer/lib/sources.json`): 3 sources (kena-local, juliusbrussee-caveman, mattpocock-skills)
- MCP servers registry (`installer/lib/mcps.json`): extensible registry starting with `claude-mem`
- New dispatchers: `source-npx.sh`, `source-curl.sh`, `source-local.sh`, `mcp-install.sh`
- New flag `--source <id>` to limit skill search to a specific source
- New flag `--mcp <id>` to install/verify a specific MCP server
- New templates: `juliusbrussee-caveman-install.sh`, `mattpocock-install.sh`, `claude-mem-install.sh`
- Default skills from mattpocock: `diagnose`, `grill-me`
- caveman is now sourced from `JuliusBrussee/caveman` (72k stars) via curl-pipe
- `lib/output.sh` (helpers info/ok/warn/err extracted from entry point to fix env-var scope bugs)
- `lib/json.sh` — bash-pure JSON parser

### Changed
- Replaced `caveman` (ysm-dev) with `caveman` (JuliusBrussee)
- `install-skill.sh` now dispatches by source type (local/npx/curl)
- `list-skills.sh` now lists skills from all enabled sources with unified format
- `kena-skills` entry point supports `--source`, `--mcp`, `--all` flags
- Renamed `claude-code` registry id to `claude` (display) with `npx_flag=claude-code` (internal)

## [1.1.0] - 2026-06-14

### Added
- Skill `caveman` (ysm-dev version, since replaced)
- 5-agent registry: opencode, claude, copilot, codex, gemini

### Fixed
- `KeyError: 'AGENTS_REGISTRY'` in `get_agent_npx_flag`
- `agent_id` NameError in dry-run mode
- `--target claude` now correctly maps to `npx skills add ... -a claude-code`

## [1.0.0] - 2026-06-14

### Added
- Initial release with `deepsearch` skill
- TUI installer with gum/dialog/whiptail/read fallback
- Auto-detection of installed agents
- Hard-required dependency validation
- `npx skills add` wrapper with manual symlink fallback

[1.4.0]: #140----2026-06-14
[1.3.0]: #130----2026-06-14
[1.2.0]: #120----2026-06-14
[1.1.0]: #110----2026-06-14
[1.0.0]: #100----2026-06-14
