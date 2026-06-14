# Goal-Question-Metric Protocol for `/deepsearch`

Before spending tokens on graphify or diagnose, fix the goal. Without a goal, every finding looks interesting and none close the case.

## Template

```markdown
## Goal
<one sentence: what we will find or demonstrate>

## Questions
1. <concrete question 1>
2. <concrete question 2>
3. <concrete question 3>
4. <concrete question 4> (optional)
5. <concrete question 5> (optional)
6. <concrete question 6> (optional)
7. <concrete question 7> (optional)

## Metrics
- <observable metric 1: e.g. "Bug reproduces in ≥80% of executions">
- <observable metric 2: e.g. "Root cause identified in ≤3 hops of the graph">
- <observable metric 3: e.g. "Regression test green in CI">

## Stop conditions
- <when to abandon honestly: e.g. "If after 3 hours there is no repro, ask the user for HAR/log">
- <when to degrade: e.g. "If corpus >50k words and scope cannot be reduced, switch to --no-graph">
- <when to abort: e.g. "If the reported symptom is not reproducible even in theory, exit with 'not investigable in this context' report">
```

## Examples by mode

### Mode `bug` with reported symptom

```markdown
## Goal
Find the root cause of the intermittent crash in POST /premiums/claim when the body contains a duplicated `guild_id`.

## Questions
1. Does the schema validator reject duplicates or process them in order?
2. Does the Mongo query use upsert and trigger a duplicate key error?
3. Does the auth middleware run before or after the body parser?
4. Is there a race condition between the "already has premium" check and the insert?
5. Does the error log expose enough context (request ID, user ID)?

## Metrics
- Crash reproduces in ≥3 of 5 attempts with the same body
- Root cause identified in ≤2 hops of the path "HTTP request → controller → service → db"
- Regression test green that covers the duplicated body case

## Stop conditions
- If after Phase 4 there is no deterministic repro, ask the user for a HAR file
- If the code cannot be run locally, abort Phase 4 and report static analysis only
```

### Mode `flow` with explicit scope

```markdown
## Goal
Trace the complete flow of a Discord message from when it arrives at the bot until it is enqueued in Lavalink, identifying failure points.

## Questions
1. How many modules does a message pass through before reaching Lavalink?
2. What guards/permissions are evaluated at each hop?
3. Where is the track serialized and what assumptions are made about its shape?
4. What happens if Lavalink is down when an enqueue is attempted?
5. Are timeouts configured and are they reasonable for the expected latency?
6. Does the system handle Discord WebSocket reconnection without losing messages?

## Metrics
- Complete path traced with ≥6 documented hops
- ≥3 risk points prioritized (criticality × probability)
- ASCII or mermaid flow map attached to the report

## Stop conditions
- If the graph has <10 nodes in the flow, the corpus probably lacks the relevant code — abort
- If there are no E2E tests covering the flow, declare "flow map based on static analysis, without runtime validation"
```

### Mode `bug --auto` (free scan)

```markdown
## Goal
Detect latent bugs in the codebase: missing error handling, broken validations, race conditions, unreleased resources.

## Questions
1. Are there empty try/catch blocks or ones that only log without propagating?
2. Are there missing awaits in async functions?
3. Are there silenced console.log/error calls in production?
4. Are there critical TODOs/FIXMEs without an associated issue?
5. Are there input validations that get skipped in some branch?
6. Are there race conditions in concurrent operations (locks, transactions)?

## Metrics
- List prioritized by severity (P0/P1/P2)
- ≥1 case with repro built in Phase 4
- All findings with file:line and snippet

## Stop conditions
- If the corpus has <5 files, abort (not enough surface to scan)
- If ≥20 P0/P1 findings, divide the scope and report per submodule
```

## Hard rules

1. **The goal MUST be one sentence**, not a paragraph. If it needs more than 25 words, it is not a goal.
2. **Questions MUST be falsifiable.** If the answer is "it depends", it is not a question, it is an opinion.
3. **Metrics MUST be observable.** "Find the bug" is not a metric. "Repro 3/5 times" is.
4. **Stop conditions ALWAYS include an honest abort point.** Do not chase ghosts.
5. **Show the goal to the user BEFORE Phase 3.** If they veto it, adjust. If they say "go", freeze the goal and do not change it mid-pipeline.

## Expected output

Print the template filled in with markdown code blocks. The user sees the goal, approves it, and the rest of the pipeline works toward that concrete objective.
