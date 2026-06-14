# Diagnose Checklist for `/deepsearch`

Recap of the 6 phases from the `diagnose` skill applied to the deepsearch context. Use this checklist as an operational guide, not as a replacement for the original skill (load it if you need depth in any phase).

## Instrumentation tag prefix

Generate a unique 4-char hash at the start of Phase 4:

```bash
DEBUG_TAG="[DEBUG-ds$(od -An -N2 -tx1 /dev/urandom | tr -d ' \n')]"
echo "Instrumentation tag: $DEBUG_TAG"
```

Use this tag on ALL logs, prints, conditional breakpoints. Cleanup at the end: `grep -r "$DEBUG_TAG" .` must return 0 hits.

---

## Phase 1 — Build feedback loop

**Rule:** if you do not have a deterministic loop, you do not have debugging, you have guessing.

Choose the seam in this order of preference:

- [ ] **Failing test** at the seam closest to the bug. Unit if possible, integration if the bug crosses layers, e2e if it reproduces the reported symptom.
- [ ] **Curl/HTTP script** against a running dev server. Capture complete request (headers, body, query params) and complete response (status, headers, body).
- [ ] **CLI invocation** with fixture input, diffing stdout against known-good snapshot.
- [ ] **Headless browser script** (Playwright/Puppeteer) if the bug is UI. Assert on DOM/console/network.
- [ ] **Replay captured trace**: HAR file, log dump, network capture. Reproduce in isolation.
- [ ] **Throwaway harness**: minimum subset of the system that exercises the code path with a single function call.
- [ ] **Property/fuzz loop**: 1000 random inputs if the bug is "sometimes wrong output".
- [ ] **Bisection harness**: if the bug appeared between two known states, automate `git bisect run`.
- [ ] **Differential loop**: same input in old vs new version, diff outputs.
- [ ] **HITL bash script**: last resort, a human must click. Use the `diagnose` skill's HITL template script.

**Iterate on the loop:**
- Faster? (cache setup, skip init, narrow scope)
- Sharper signal? (assert on the specific symptom, not "did not crash")
- More deterministic? (pin time, seed RNG, isolate FS, freeze network)

**Non-deterministic bugs:** the goal is not a clean repro but a **higher repro rate**. Loop the trigger 100×, parallelize, add stress, narrow timing windows. A 50%-flake bug is debuggable; 1% is not.

**If you genuinely cannot build a loop:**
- Stop. Say what you tried.
- Ask the user for: (a) access to the environment, (b) captured artifact, (c) permission to add temporary instrumentation to production.
- **DO NOT proceed to Phase 2 without a loop.**

---

## Phase 2 — Reproduce

Run the loop. Watch the bug appear.

Verify:

- [ ] The loop produces the failure mode the **user** described, not a different nearby failure. Wrong bug = wrong fix.
- [ ] The failure is reproducible across multiple runs (or, for non-deterministic bugs, at a high enough rate to debug).
- [ ] You captured the exact symptom (error message, wrong output, anomalous timing) so later phases can verify the fix addresses it.

**Do not proceed until you reproduce the bug.**

---

## Phase 3 — Hypothesize

Generate 3-5 ranked hypotheses BEFORE testing any. Single-hypothesis generation anchors on the first plausible idea.

**Each hypothesis must be falsifiable.** Format:
> "If <X> is the cause, then changing <Y> will make the bug disappear / changing <Z> will make it worse."

If you cannot state the prediction, the hypothesis is a vibe — discard or sharpen.

**Show the ranking to the user before testing.** They often have domain knowledge that re-ranks instantly ("we just deployed a change to #3"). Do not block — proceed if they are AFK.

---

## Phase 4 — Instrument

**Each probe must map to a specific prediction from Phase 3. Change one variable at a time.**

Tool preference:

1. **Debugger/REPL** if the env supports it. One breakpoint > ten logs.
2. **Targeted logs** at the boundaries that distinguish hypotheses.
3. **Never** "log everything and grep".

**Tag every debug log** with `$DEBUG_TAG`. Cleanup becomes a single grep. Untagged logs survive; tagged logs die.

**Perf branch:** for performance regressions, logs are usually wrong. Instead: establish a baseline measurement (timing harness, `performance.now()`, profiler, query plan), then bisect. Measure first, fix second.

---

## Phase 5 — Fix + regression test

**Write the regression test BEFORE the fix** — but only if there is a **correct seam** for it.

A correct seam is one where the test exercises the **real pattern of the bug** as it occurs at the call site. If the only available seam is too shallow (single-caller test when the bug needs multiple callers, unit test that cannot replicate the chain that triggered the bug), a test there gives false confidence.

**If no correct seam exists, that itself is the finding.** Note it. The codebase architecture is preventing the bug from being locked down. Flag for handoff in the report's architecture section.

If a correct seam exists:

1. Turn the minimized repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 loop against the original (non-minimized) scenario.

---

## Phase 6 — Cleanup + post-mortem

Required before declaring done:

- [ ] Original repro no longer reproduces (re-run Phase 1 loop)
- [ ] Regression test passes (or absence of seam documented)
- [ ] All `[DEBUG-ds<hash>]` instrumentation removed (`grep` the tag)
- [ ] Throwaway prototypes deleted (or moved to a clearly-marked debug location)
- [ ] The hypothesis that turned out correct is stated in the commit/PR message — so the next debugger learns

**Then ask: what would have prevented this bug?** If the answer involves architectural change (no good test seam, tangled callers, hidden coupling) → handoff to an architecture-improvement skill with the specifics. **After** the fix is in, not before — you have more information now than when you started.

---

## Differences by deepsearch mode

| Aspect | `bug` | `flow` |
|---|---|---|
| Phase 1 emphasis | Failing test that reproduces | Path traversal with assertion of invariants |
| Phase 2 emphasis | Deterministic crash repro | Confirm that the flow follows the documented pattern |
| Phase 3 emphasis | "What assumption is breaking?" | "What assumption is fragile under change?" |
| Phase 4 emphasis | Probes at error boundaries | Probes at control flow boundaries |
| Phase 5 emphasis | Minimum fix + test | Risk-prioritized map, fix optional |
| Phase 6 emphasis | Cleanup + fix post-mortem | Flow map documentation + assumptions to monitor |
