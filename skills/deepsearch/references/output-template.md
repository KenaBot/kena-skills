# Output Template for `/deepsearch`

The report is the canonical output of the skill. Anything not documented in the report is considered lost. Fill in every section; if a section does not apply, write "N/A — <reason>" instead of omitting it.

---

```markdown
# Deepsearch Report

**Mode:** <bug|flow>
**Date:** <YYYY-MM-DD HH:MM TZ>
**Scope:** <absolute path>
**Instrumentation tag:** [DEBUG-ds<hash>]
**Parallelism mode:** <parallel --agents N | sequential --agents 1 | sequential-fallback task-unavailable>
**Tokens consumed (graphify):** <input>/<output>

---

## 1. Goal

<exact copy of the Goal from references/goal-protocol.md>

**Questions:**
1. ...
2. ...

**Metrics:**
- ...
- ...

**Stop conditions:**
- ...
- ...

---

## 2. Memory recall (claude-mem)

<list of relevant observations found, or "No prior memory">

| ID | Type | Summary | Relevance |
|----|------|---------|-----------|
| 2236 | 🔵discovery | <title> | <why it applies> |
| 2447 | 🔴bugfix | <title> | <why it applies> |

If no hits: "No prior memory. This is the first analysis of this area in recent sessions."

**Dispatch details:**
- Agents: <N>
- Work units: <5 (default) | N (--agents)>
- Wall-clock: <seconds>
- Status counts: ok=<n>, partial=<n>, failed=<n>

---

## 3. Code map (graphify)

### 3a. Graph state
- Was there a prior graph? <yes/no>
- If not, was one built in this session? <yes/no, with reason if not>
- Corpus: <N files, ~M words>

### 3b. Graph findings

**God nodes** (modules with most connections):
- <name>: <degree> edges, <communities it connects>
- ...

**Surprising connections** (cross-community bridges):
- <node A> ↔ <node B>: <why surprising>
- ...

**Paths / queries relevant:**
- <path or query executed>
- <summarized output>

### 3d. Phase 3 fan-out

- Agents dispatched: <N>
- Work units: <3 (bug mode) | variable (flow mode)>
- Wall-clock: <seconds>
- Queries executed in parallel:
  - <query 1> → <summary of N hits>
  - <query 2> → <summary of N hits>
  - <query 3> → <summary of N hits>
- Agents that returned `status: ok`: <count>
- Agents that returned `status: partial`: <count>
- Agents that returned `status: failed`: <count or "none">
- Consolidated suspects (top 5):
  1. <node> — confidence <X>% — cited by agents <list of task_ids>
  2. ...
- Conflicts between agents: <list or "none">

### 3c. Token cost
- Input: <N> tokens
- Output: <M> tokens
- Cumulative cost: <running total from cost.json if it exists>

---

## 4. Diagnosis

### 4a. Feedback loop built
- **Type:** <failing test|curl|CLI|browser|replay|harness|property|bisection|differential|HITL>
- **Path to the loop:** <absolute path to the test/script file>
- **Determinism:** <% repro observed>
- **Loop execution time:** <N seconds>

### 4b. Reproduction
- **Exact symptom:** <literal error message, wrong output, or broken flow description>
- **Matches what the user reported:** <yes/no, explain if not>
- **Captured in:** <commit SHA, timestamp, log file>

### 4c. Ranked hypotheses
1. **<hypothesis 1>** — prediction: "If X, then changing Y will <outcome>"
2. **<hypothesis 2>** — prediction: ...
3. **<hypothesis 3>** — prediction: ...
4. **<hypothesis 4>** — prediction: ...
5. **<hypothesis 5>** — prediction: ...

**User vetoed/confirmed:** <notes or N/A>

### 4d. Instrumentation
- **Tag used:** `[DEBUG-ds<hash>]`
- **Probes deployed:**
  - <probe 1>: <what it measures, which hypothesis it falsifies>
  - <probe 2>: ...
- **Variables changed one at a time:** <yes/no>

### 4e. Fix + regression test
- **Correct seam identified:** <yes/no>
- **If not, reason:** <architecture does not allow testing at the right level>
- **Test written:** <path to file, framework, key assertion>
- **Fails before fix:** <test output>
- **Fix applied:** <summarized diff or commit SHA>
- **Passes after fix:** <test output>
- **Re-run against original (non-minimized) scenario:** <yes/no>

### 4f. Cleanup
- [ ] Original repro no longer reproduces
- [ ] Regression test passes
- [ ] `grep -r '[DEBUG-ds<hash>]' .` returns 0 hits
- [ ] Throwaway prototypes deleted or moved
- [ ] Post-mortem included in commit message

### 4g. Phase 4 parallel agent results

- Agents dispatched: <N>
- Work units (ranked hypotheses): <N>
- Wall-clock: <seconds>
- Dispatch mode: <parallel | sequential (--agents 1) | sequential-fallback (task unavailable)>

| # | Hypothesis | Agent task_id | Result | Confidence | Evidence |
|---|-----------|----------------|-----------|-----------|-----------|
| 1 | <text> | <id> | confirmed/falsified/indeterminate | <0-100> | <file:line> |
| 2 | ... | ... | ... | ... | ... |

- Winning hypothesis: <#>
- Tied hypotheses (>70 confidence): <list or "none">
- Conflicts between agents: <list or "none">
- Agents that returned `status: ok`: <count>
- Agents that returned `status: partial`: <count>
- Agents that returned `status: failed`: <count or "none">
- Global confidence level: <High/Medium/Low>

---

## 5. Additional findings (flow mode)

<only if mode == flow>

### 5a. Flow map
<mermaid or ASCII map of the traced flow, with each hop numbered>

### 5b. Prioritized risk points

| # | Hop | Risk | Probability | Impact | Suggested mitigation |
|---|-----|------|--------------|---------|---------------------|
| 1 | <hop> | <description> | <High/Medium/Low> | <Critical/High/Medium/Low> | <action> |
| 2 | ... | ... | ... | ... | ... |

### 5c. Fragile assumptions under change
- <assumption 1>: <what would break it>
- <assumption 2>: ...

---

## 6. Final metrics vs goal

| Metric defined in Goal | Result | Pass/Fail |
|--------------------------|-----------|------------|
| <metric 1> | <result> | ✅/❌ |
| <metric 2> | <result> | ✅/❌ |
| <metric 3> | <result> | ✅/❌ |

**Score:** <N>/<total> metrics met.

---

## 7. Next steps

### Immediate
- [ ] <action 1>
- [ ] <action 2>

### Recommended handoff
- [ ] <skill or person> — <reason>

### Open questions
- <question 1>
- <question 2>

### What would have prevented this bug
<one sentence: architectural change, better test seam, missing validation, etc.>

---

## 8. Honesty of the report

- [ ] I did not invent graph edges
- [ ] I did not invent symptoms — I only reported what the repro produced
- [ ] I did not attribute cause without a probe that confirmed it
- [ ] Each listed hypothesis has its explicit prediction
- [ ] If I could not build the loop or reproduce, I said so clearly
- [ ] I reported ALL agents that failed or disagreed, not only the successful ones
- [ ] I reported actual wall-clock vs estimated if the difference was > 50%
- [ ] I noted the parallelism mode used (parallel / sequential / fallback)

**Signed:** /deepsearch v2.0.0
**Session ID:** <id or unique timestamp>
```

---

## Usage instructions

1. Copy the complete markdown block
2. Fill in each section with real data
3. DO NOT omit sections; use "N/A — <reason>" if it does not apply
4. Section 8 (Honesty) is ALWAYS filled in, even to declare what you could not do
5. The report is printed to the user and saved to `graphify-out/.deepsearch_report_<timestamp>.md`
