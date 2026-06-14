# Parallel Protocol for `/deepsearch`

Operational procedure for parallel sub-agent dispatch. Any reference to "agent" in this protocol means a `task` tool call with `subagent_type: "explore"` (read-only, no Write/Edit).

## How opencode and claude-code execute parallel tool calls

Both runtimes execute **all tool calls within a single response message in parallel**. Tool calls split across multiple response messages run sequentially. This is a hard runtime property, not a convention. The previous version of this skill described parallelism in natural language but did not instruct the LLM to emit N `task` calls in a single response block — result: agents ran sequentially and the opencode UI showed them one at a time. The fix in v2.0.0 is the explicit directive in `SKILL.md`'s **CRITICAL: Dispatching parallel agents** section. This document provides the operational details.

## Hard rules

1. **Use `subagent_type: "explore"` only.** Read-only agents. All mutations are made by the orchestrator (main thread).
2. **N never exceeds 20.** Practical limit of simultaneous dispatch. If the user asks for more, cap to 20 with a warning.
3. **N=1 is pure sequential mode.** Behavior identical to pre-parallelism skill. Universal fallback.
4. **Default N=5.** If the user does not pass `--agents`, use 5.
5. **Each agent receives isolated context.** The prompt of each agent includes: goal, mode, scope (path), and its specific task. They do not share state.
6. **Agents do NOT communicate with each other.** All aggregation is done by the orchestrator after collecting results.
7. **Effective N = min(work_units, --agents).** Never launch empty agents.
8. **Emit all parallel `task` calls in ONE response block.** The runtime executes them concurrently. Sequential dispatch across multiple response messages defeats the entire purpose.

## Batching

```
work_units = number of independent tasks in the phase
N = --agents (default 5)
N_effective = min(work_units, N)
batches = ceil(work_units / N_effective)
```

- **work_units > N_effective:** split into batches of N_effective. Batch N+1 starts when batch N ends. Wall-clock = batches × per-agent time.
- **work_units < N_effective:** use `work_units` agents. Remaining slots are ignored (do not invent tasks).
- **work_units == N_effective:** ideal case, single batch, maximum parallelism.

**Mandatory banner before each dispatch:**

```
Dispatching N=<X> agents for <phase> (work_units=<Y>, batches=<Z>)
```

## Wall-clock time

- **Per explore agent:** ~30-60s typical (can rise to 120s in large corpora).
- **Estimated wall-clock per phase:** `ceil(work_units / N_effective) * 60s`.
- **Total pipeline wall-clock:** sum of the 3 parallel phases (Phase 1, 3a, 4).
- Print estimate to the user before each dispatch. If total estimated wall-clock exceeds 10 minutes, ask for confirmation.

## Prompt template per agent

```markdown
You are a read-only research agent inside the /deepsearch skill.

## Context
- **Goal:** {goal}
- **Mode:** {bug|flow}
- **Scope:** {absolute path}
- **Phase:** {1|3|4}

## Your task
{specific description of ONE unit of work. Example: "Find all observations of type bugfix that mention 'payment webhook' in the history"}

## Restrictions
- Read-only. DO NOT write files, DO NOT modify code.
- Do not invent evidence. If not found, say "not found" and return empty fields.
- Be concise. Your output will be merged with other agents' output.

## Output format (strict)
Return a JSON-like object with these exact fields:
{
  "task_id": "<unique task id>",
  "status": "ok|partial|failed",
  "findings": [<list of relevant findings with file:line and short snippet>],
  "evidence_count": <integer>,
  "confidence": <0-100>,
  "notes": "<short string with caveats or additional context>"
}
```

## Anti-patterns (DO NOT do these)

### Anti-pattern 1: sequential dispatch across messages

WRONG:
```
Response 1: task(...) → wait for result
Response 2: task(...) → wait for result
Response 3: task(...) → wait for result
```

This is sequential. Each `task` shows as a separate sub-task in the UI and the wall-clock time is N × per-agent time.

### Anti-pattern 2: bash loop pretending to be parallel

WRONG:
```bash
for h in hypotheses; do
  task ...   # still sequential, bash does not parallelize
done
```

### Anti-pattern 3: serial `task` with internal parallelism

WRONG:
```
One big task() call that does all 5 things internally
```

This shows as 1 agent in the UI, not 5. Loses the parallelism visibility benefit.

### Correct pattern

CORRECT:
```
In response block N: emit task(...), task(...), task(...), task(...), task(...)
                   (5 separate tool calls in one message)
Then wait for all 5 results.
In response block N+1: aggregate and continue.
```

The runtime executes the 5 `task` calls concurrently. The opencode UI shows 5 sub-tasks running in parallel. Wall-clock time is ~1× per-agent time, not 5×.

## Aggregation

By phase, with a specific merge function. The orchestrator (main thread) is the only one responsible for aggregation.

### Phase 1 (memory)

```
results = [agent.output for agent in phase_1_agents]
hits = union of results.findings, deduplicated by (ID, file:line)
hits = sorted by confidence desc, capped to top 10
```

Conflicts: two agents report same observation with different confidence → keep the higher, mark the other as "also reported by agent X with confidence Y".

### Phase 3a (graph queries)

```
results = [agent.output for agent in phase_3a_agents]
suspects = union of mentioned nodes, ranked by (frequency, avg_confidence)
suspects = capped to top 5
```

Conflicts: two agents point to different nodes for the same goal → flag to user, do not auto-resolve.

### Phase 4 (hypotheses)

```
results = [(hypothesis_id, agent.output) for agent in phase_4_agents]
winner = argmax(agent.confidence for agent in results if status == "ok")
```

Conflicts: two hypotheses confirmed with confidence > 70 → flag to user for tiebreak. Do not pick "the first" or "the fastest".

## Best-effort policy

| Situation | Action |
|---|---|
| 1-2 agents fail in a phase | Continue with partial results. Mark them in report (section 3d/4g). |
| ≥30% agents fail in a phase | Visible warning to user. Continue but degrade global confidence to "Low". |
| 100% agents fail in a phase | Fall back to sequential mode for that phase (re-run tasks in main thread). Declare in section 8 (Honesty) of the report. |
| Global phase timeout exceeded (>5 min) | Abort phase, degrade to `--no-graph` or static analysis, continue with remaining phases. |
| Agent returns `status: "failed"` with rate limit error | Retry once after 5s sleep. If it fails again, count as failure. |
| Agent returns `status: "failed"` with timeout error | Retry once. If it fails, count as failure. |
| `task` tool not available in current agent | Skill runs in sequential mode. Warn the user that parallelism is disabled. Effective behavior is `--agents 1`. |

**Absolute rule:** a parallel agent **never aborts the entire pipeline**. Hunting continues with whatever it has.

## Sequential fallback (when `task` is unavailable)

If the `task` tool is not in the agent's available tools:

1. Log a warning: `[WARN] task tool unavailable — running in sequential mode (--agents 1 equivalent)`
2. Execute each unit of work in the main thread using `bash`, `read`, `grep`, `glob`
3. The wall-clock time is N × per-unit time
4. The report's section 3d/4g should record "Mode: sequential (task tool unavailable)"
5. Suggest the user upgrade their runtime or run in a context where `task` is available

This fallback is automatic and does not require user intervention.

## Cleanup

- `explore` agents do not leave artifacts on disk.
- If an agent returns paths to generated files, log them in section 8 of the report (Honesty) as "artifacts to review manually".
- Do not auto-delete anything at the end of the pipeline — the user decides.

## Minimum telemetry

For each dispatch, record:
- Phase
- N requested vs N effective
- work_units
- Actual wall-clock
- Number of agents that returned `status: "ok"`
- Number that returned `status: "partial"` or `"failed"`

This telemetry goes in section 3d/4g of the report so the user sees the real cost of parallelism.
