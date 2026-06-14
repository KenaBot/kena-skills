---
name: deepsearch
description: >
  Hunt hard bugs and broken flows in codebases. Orchestrates memory recall
  (claude-mem), explicit goal-setting, code knowledge graph (graphify), and
  disciplined diagnosis loop. Use when user says "deepsearch", "deepsh",
  "ds", "bug-hunt", "hunt", or describes a bug, race condition, broken flow,
  flaky test, or refactor risk. Modes: bug (default, hunt errors) and flow
  (analyze broken flows). Parallel: up to 5 explore agents dispatched in a
  single response block via the task tool. Best-effort on failures.
license: MIT
compatibility: opencode,claude-code
metadata:
  author: tutitoos
  version: "2.1.0"
  mode: "bug|flow"
  parallelism: "task-tool-fanout"
  dependencies: "claude-mem,graphify"
---

# /deepsearch — Hunting beast for hard bugs and broken flows

Orchestrator of four capabilities: memory recall, goal-setting, code knowledge graph, and disciplined diagnosis. Encodes them into a pipeline. The difference between using four tools loose and having a hunting method.

## Triggers

`deepsearch`, `deepsh`, `ds`, `bug-hunt`, `hunt` — all load this skill.

## Syntax

```
/deepsearch                                          # bug mode, scope cwd, gatekeeper
/deepsearch bug                                      # bug mode explicit
/deepsearch flow                                     # flow analysis mode
/deepsearch bug /path/to/project                     # explicit scope
/deepsearch "race condition in payment webhook"      # with description, skip gatekeeper
/deepsh flow --auto                                  # no description, free flow scan
/deepsearch --update                                 # force graphify rebuild
/deepsearch --no-graph                               # skip graphify (degraded mode)
/deepsearch --agents 5                               # limit fan-out to 5 agents (default)
/deepsearch flow --agents 1                          # pure sequential flow mode
/deepsh bug --auto --agents 20                       # maximum parallelism for free scan
```

### Flag reference

| Flag | Default | Range | Description |
|---|---|---|---|
| `--auto` | off | — | Assume generic objective, skip gatekeeper |
| `--update` | off | — | Reuse `graphify --update` logic if a graph exists |
| `--no-graph` | off | — | Operate with mem + grep only, skip graphify |
| `--budget N` | 1500 | 100-10000 | Token cap for graphify query |
| `--mode bug\|flow` | bug | — | Switch mode explicitly |
| `--agents N` | 5 | 1-20 | Max simultaneous explore agents. N=1 = pure sequential |

If no path is specified, use `.` (cwd). Do not ask.

## Tools required

This skill requires the following tools to be available in the agent:

| Tool | Required | Purpose |
|---|---|---|
| `task` | YES | Parallel sub-agent dispatch. If unavailable, the skill falls back to sequential mode with a warning to the user. |
| `bash` | YES | graphify CLI, builds, file ops |
| `read` | YES | Load `references/*.md` and other files |
| `grep` | YES | Code search |
| `glob` | YES | File discovery |
| `write` | YES | Phase 4 regression tests |
| `edit` | YES | Phase 4 fixes |
| `webfetch` | OPTIONAL | Fetch online bug reports / CVEs |
| `websearch` | OPTIONAL | Search documentation |

## CRITICAL: Dispatching parallel agents

**This skill uses the `task` tool to fan out work to parallel sub-agents.** Without the directive below, agents execute sequentially and the opencode UI shows only one sub-task at a time. To get true parallel execution, follow this rule strictly.

### Rule: all parallel `task` calls go in ONE response block

When the skill instructs you to dispatch N agents, you MUST emit N `task` tool calls in a **single response message**, not in N consecutive messages. The runtime (opencode and claude-code) executes tool calls within a single response block in parallel. Tool calls split across multiple response messages run sequentially.

**Template for parallel dispatch:**

```
[In one response, emit all of these tool calls:]
1. task({ subagent_type: "explore", description: "<H1>", prompt: "..." })
2. task({ subagent_type: "explore", description: "<H2>", prompt: "..." })
3. task({ subagent_type: "explore", description: "<H3>", prompt: "..." })
... (up to N)
```

After ALL N `task` calls return, aggregate the results in the next response.

### Anti-pattern (DO NOT do this)

```
Response 1: task(...) → wait for result
Response 2: task(...) → wait for result
Response 3: task(...) → wait for result
```

This is sequential. Each `task` shows as a separate sub-task in the UI and the wall-clock time is N × per-agent time, not 1 × per-agent time. The opencode UI will show agents one at a time — the exact bug this rule prevents.

### Anti-pattern (DO NOT do this either)

```bash
# WRONG: bash loops do not parallelize
for h in hypotheses; do
  task ...
done
```

```python
# WRONG: one big task that does all 5 things internally
task(subagent_type="explore", prompt="Do all 5 things sequentially")
```

The correct pattern is multiple `task` tool calls in one response block. See `references/parallel-protocol.md` for full details on anti-patterns, batching, and the sequential fallback.

## Pipeline overview

| Phase | Name | Parallel? | Output |
|---|---|---|---|
| 0 | Gatekeeper | — | Description of the bug or `auto` |
| 1 | Memory recall | Yes, 5 agents | Top 10 historical hits |
| 2 | Goal-Question-Metric | — | Approved goal |
| 3 | Code map (graphify) | Yes, 3 agents | Top 5 suspects (or flow map) |
| 4 | Diagnose (6 phases) | Yes, N agents (one per hypothesis) | Root cause + fix |
| 5 | Report | — | Final report |

## Phase 0 — Gatekeeper (conditional)

If there is NO description of the bug AND `--auto` is NOT set:
> What symptom do you observe? If none, write `auto` for a free scan of latent anomalies.

One single question. If the user answers `auto`, use the generic objective of the mode (see below). If the user answers with a description, jump to Phase 1 with that description as input.

## Phase 1 — Memory recall (claude-mem)

> **Declared risk:** `/mem-search` does not exist as a local skill. The real tool is `get_observations` from claude-mem, available via the `AGENTS.md` context. If not accessible, this phase degrades to "continue without historical memory" without blocking.

**Parallel mode (default):** dispatch `min(5, --agents)` explore agents in ONE response block, one per filter:

1. Agent 1: `🔴bugfix` by symptom keywords
2. Agent 2: `🚨security_alert` by symptom keywords
3. Agent 3: `🔵discovery` with related keywords
4. Agent 4: any observation mentioning the affected module/feature
5. Agent 5: generic fallback (top 20 recent observations)

Banner before dispatch: `Dispatching N=<X> agents for mem search (work_units=5)`.

**Sequential mode (`--agents 1` or `task` unavailable):** execute `get_observations` with a single combined filter, same order as above.

**Aggregation (both modes):** union of findings, deduplicated by (ID, file:line), ranked by `confidence` descending, capped to top 10 hits for the report. If no hits, declare "No prior memory" and continue.

## Phase 2 — Goal-Question-Metric (define success before spending tokens)

Load `references/goal-protocol.md`. Generate and show the user BEFORE continuing:

- **Goal:** one specific and testable sentence
- **Questions:** 3-7 concrete questions the hunting will answer
- **Metrics:** how we will measure success (repro ≥X%, cause identified in <N hops, fix with green test)
- **Stop conditions:** when to abandon honestly

Visible checkpoint. The user can veto the goal, expand questions, or refine the scope. If the user says "go" or "continue", proceed to Phase 3.

**Objectives by mode:**

| Mode | Goal template | Success metric |
|---|---|---|
| `bug` (default) | "Find the root cause of <symptom>" | Deterministic repro + fix with green regression test |
| `flow` | "Trace the flow of <concept> and detect failure points" | Complete map + ≥3 prioritized risk points |
| `bug --auto` | "Detect latent bugs: empty try/catch, missing awaits, broken validations, critical TODOs" | List prioritized by severity + ≥1 case with built repro |

## Phase 3 — Code map (graphify)

Three sub-routes depending on the state of the graph in `graphify-out/`:

**3a. Graph exists** (`graphify-out/graph.json` valid):

*Parallel mode (default):* dispatch `min(3, --agents)` explore agents in ONE response block, one per query type:
1. Agent 1: `graphify query "<expanded_goal>" --budget <N/3>` with vocabulary expansion
2. Agent 2: `graphify query "god nodes"` + centrality analysis
3. Agent 3: `graphify query "surprising connections across communities"`

Banner before dispatch: `Dispatching N=<X> agents for graph queries (work_units=3)`.

*Sequential mode (`--agents 1` or `task` unavailable):* execute the queries one after another in the order listed.

*Mode `flow` (any N):* dispatch up to 3 agents for `graphify path "<start>" "<end>"` and `graphify explain "<suspicious_node>"` for each hop of the path.

**3b. No graph and small corpus** (< 5k words, ~50 files):
Run the full pipeline of the `graphify` skill (Steps 1-9). Pass flags:
- `bug`: `--mode deep`
- `flow`: `--mode deep --directed`

**3c. No graph and large corpus** (> 5k words):
Warning. Calculate top-5 subdirectories by file count. Ask the user which to scan. If they say "everything", suggest `--no-cluster` to save time. If the scope cannot be reduced, abort Phase 3 and degrade to Phase 4 with `--no-graph`.

**Output of Phase 3:**
- God nodes (which modules concentrate the most connections)
- Surprising connections (unexpected cross-community bridges)
- Paths / queries relevant to the goal
- Cumulative token cost

If the mode is `flow`, end Phase 3 with a narrated map of the flow. If `bug`, end with the list of initial suspects (top 5 nodes candidate to be the root cause).

## Phase 4 — Disciplined diagnosis (diagnose)

Load `references/diagnose-checklist.md`. Apply the 6 phases of the `diagnose` skill adapted to the deepsearch context:

1. **Build feedback loop** — choose the correct seam (failing test, curl, harness, replay, bisection). The fastest and most deterministic wins. If a loop cannot be built, ask the user for an artifact (HAR, log, core dump) or access to the environment.
2. **Reproduce** — run the loop, capture the exact symptom. Verify it matches what the user described (wrong bug = wrong fix).
3. **Hypothesize** — 3-5 ranked hypotheses with falsifiable predictions. Format: *"If X is the cause, then changing Y will make the bug disappear"*. Show the user before testing.
4. **Instrument** — probes tagged `[DEBUG-ds<hash>]` where `<hash>` is a unique session identifier (4 random chars). Change one variable at a time. For perf regressions, measure before touching anything.
5. **Fix + regression test** — write the test at the correct seam BEFORE the fix. If there is no correct seam, flag it (that is an architectural finding, not a fix failure).
6. **Cleanup** — `grep -r '\[DEBUG-ds<hash>\]' .` must return 0 hits. Delete throwaway prototypes. Post-mortem.

**Parallelism in Phase 4:** after generating the ranked hypotheses (step 3) and obtaining user approval, dispatch `min(N_hypotheses, --agents)` explore agents in ONE response block, one per hypothesis. Each agent verifies ONE hypothesis and returns `{falsified|confirmed|indeterminate, evidence with file:line, confidence 0-100, updated prediction}`.

Banner: `Dispatching N=<X> agents for hypothesis verification (work_units=<Y>)`.

**Important:** parallel agents do NOT apply fixes or write tests — they only verify hypotheses by reading code. The fix is applied by the orchestrator (main thread) after consolidating the results, within step 5 of diagnose.

If two hypotheses are confirmed with `confidence > 70`, flag to the user for tiebreak. Do not pick automatically.

**Difference by mode:**
- `bug`: emphasis on reproducibility + instrumentation. The fix is the goal.
- `flow`: emphasis on path traversal + assumption analysis. The goal is the map + risk list, not necessarily an immediate fix.

## Phase 5 — Report

Load `references/output-template.md`. Generate the report following that template exactly. The report is the canonical output of the skill. Anything not documented in the report is considered lost.

## Error behavior

| Situation | Action |
|---|---|
| Path does not exist | Abort immediately with a clear message |
| Graphify graph cannot be built (corpus without code/docs) | Skip to Phase 4 with `--no-graph` |
| No access to the code runtime | Ask for artifact (HAR, log, dump) or exit to "static analysis" mode |
| User abandons mid-pipeline | Save progress to `graphify-out/.deepsearch_session.json` (TODO: implement) |
| mem-search not available | Declare in report, continue without historical memory |
| 1-2 parallel agents fail in a phase | Continue with partial results, mark them in report (3d/4g) |
| ≥30% parallel agents fail in a phase | Visible warning, continue but degrade global confidence to "Low" |
| 100% parallel agents fail in a phase | Fall back to sequential mode for that phase, declare in section 8 (Honesty) |
| Global phase timeout exceeded (>5 min) | Abort phase, degrade to `--no-graph` or static analysis |
| Two hypotheses confirmed with confidence > 70 | Flag to user for tiebreak, do not pick automatically |
| `task` tool unavailable | Run in sequential mode, warn the user, mark mode as "sequential-fallback" in report |

## Quick verbs

```
/deepsearch --help        # prints this syntax section and exits
/deepsearch --version     # prints the skill version and exits
```

## See also

- `references/parallel-protocol.md` — full details on parallel dispatch, batching, anti-patterns, and sequential fallback
- `references/goal-protocol.md` — Goal-Question-Metric template with examples
- `references/diagnose-checklist.md` — operational checklist for the 6 diagnosis phases
- `references/output-template.md` — final report template
