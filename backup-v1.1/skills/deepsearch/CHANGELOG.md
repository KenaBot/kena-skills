# Changelog

All notable changes to `deepsearch` are documented here. This project follows [Semantic Versioning](https://semver.org/).

## [2.0.0] - 2026-06-14

### Breaking
- Frontmatter: removed `trigger:` field (ignored by opencode loader)
- Frontmatter: removed `allowed-tools:` field (not in opencode spec; tools now declared in body)
- Frontmatter: `description` rewritten in English, multi-line, ≤ 1024 chars
- Frontmatter: `metadata` now string-to-string map (opencode spec compliance)
- Removed hardcoded `~/.claude/...` and `~/.agents/skills/...` paths from body and references
- All triggers moved into `description` as a string (not a metadata array)

### Added
- **CRITICAL: Dispatching parallel agents** section with explicit `task`-tool directive
- Sequential fallback when `task` tool is unavailable
- Anti-patterns section: explicit "do not do this" examples
- `LICENSE` (MIT)
- `README.md` with installation and usage
- `package.json` for `npx skills` distribution
- `scripts/install.sh` for symlink management
- `tests/` directory with 4 validation scripts (frontmatter, triggers, references, run-all)
- `CHANGELOG.md` (this file)
- Symlink in `~/.config/opencode/skills/deepsearch` (opencode canonical path)
- Up to 5 parallel explore agents by default (configurable via `--agents N`)

### Fixed
- **Parallelism directive is now explicit and executable.** Previously, the skill described parallelism in natural language but did not instruct the LLM to emit N `task` calls in a single response block. Result: opencode UI showed agents running sequentially. Now, with the explicit "all in ONE response block" directive, the runtime executes tool calls in parallel and the UI shows them concurrently.

## [1.0.0] - 2026-06-14

### Added
- Initial release
- 5-phase pipeline: gatekeeper, memory, goal, graph, diagnose, report
- Dual mode: `bug` (default) and `flow`
- Aliases: `/deepsearch`, `/deepsh`, `/ds`, `/bug-hunt`, `/hunt`
- Up to 5 parallel explore agents (configurable via `--agents N`)
- References: `goal-protocol.md`, `diagnose-checklist.md`, `output-template.md`, `parallel-protocol.md`

[2.0.0]: #200----2026-06-14
[1.0.0]: #100----2026-06-14
