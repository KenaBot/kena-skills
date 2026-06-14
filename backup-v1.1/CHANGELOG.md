# Changelog

All notable changes to `kena-skills` are documented here.

## [1.1.0] - 2026-06-14

### Added
- Skill `caveman` — ultra-compressed communication mode (no dependencies)
- `installer/lib/json.sh` — bash-pure JSON parser (no python dependency)
- `CHANGELOG.md` (this file)
- 5-agent registry: opencode, claude, copilot, codex, gemini

### Changed
- **Refactored installer to bash puro** (no python embebido). Removes env-var bugs and env-var-loss-across-subshells.
- Renamed registry id `claude-code` → `claude` (display) with `npx_flag=claude-code` (internal mapping for npx)
- Removed universal `agents` entry — only the 5 specific targets now
- README files updated to reflect 5-agent registry and 2 skills

### Fixed
- `KeyError: 'AGENTS_REGISTRY'` in `get_agent_npx_flag` (env vars lost in subshells)
- `agent_id` NameError in dry-run mode
- `--target claude` now correctly maps to `npx skills add ... -a claude-code` internally

## [1.0.0] - 2026-06-14

### Added
- Initial release with `deepsearch` skill
- TUI installer with gum/dialog/whiptail/read fallback
- Auto-detection of installed agents
- Hard-required dependency validation
- `npx skills add` wrapper with manual symlink fallback
- Symlinks in all standard discovery paths

[1.1.0]: #110----2026-06-14
[1.0.0]: #100----2026-06-14
