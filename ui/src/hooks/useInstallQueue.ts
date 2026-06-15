import {useState, useEffect, useRef, useCallback} from 'react';
import {spawn} from 'node:child_process';

export type PhaseStatus = 'pending' | 'running' | 'done' | 'error';

export interface InstallPhase {
  id: string;
  skillName: string;
  sourceId: string;
  scope: 'global' | 'local';
  installDeps: boolean;
  command: string;
  args: string[];
  status: PhaseStatus;
  output: string;
  code: number | null;
}

export interface InstallQueueResult {
  phases: InstallPhase[];
  currentIdx: number;
  isRunning: boolean;
  allDone: boolean;
  cancel: () => void;
}

/**
 * Run a queue of install phases sequentially. Each phase = one spawn.
 * Continue-on-fail: if a phase fails, the next one still runs.
 * Cancel: kill current child and mark remaining phases as 'error' (skipped).
 *
 * The queue is fully driven by changes to `initialPhases` and `enabled`:
 * - When `enabled` is false, the queue is idle (phases = []).
 * - When `enabled` flips true, the queue resets and starts running the
 *   current `initialPhases` snapshot.
 *
 * This avoids the classic "useState initializer only runs once" trap:
 * if the parent passes a non-empty array only after the user navigates
 * to 'executing', the queue would otherwise stay empty.
 */
export function useInstallQueue(
  initialPhases: InstallPhase[],
  enabled: boolean,
): InstallQueueResult {
  const [phases, setPhases] = useState<InstallPhase[]>([]);
  const [currentIdx, setCurrentIdx] = useState(0);
  const [allDone, setAllDone] = useState(false);
  const cancelledRef = useRef(false);
  const childRef = useRef<ReturnType<typeof spawn> | null>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const startedRef = useRef(false);
  // Keep the latest phases in a ref so the runNextPhase callback
  // (which we want to keep stable) can read them without being a dep.
  const phasesRef = useRef<InstallPhase[]>([]);

  const updatePhase = useCallback((idx: number, patch: Partial<InstallPhase>) => {
    setPhases(prev => {
      const next = prev.map((p, i) => (i === idx ? {...p, ...patch} : p));
      phasesRef.current = next;
      return next;
    });
  }, []);

  const appendOutput = useCallback((idx: number, text: string) => {
    setPhases(prev => {
      const next = prev.map((p, i) => (i === idx ? {...p, output: p.output + text} : p));
      phasesRef.current = next;
      return next;
    });
  }, []);

  const markRemainingAsError = useCallback((fromIdx: number) => {
    setPhases(prev => {
      const next = prev.map((p, i) =>
        i >= fromIdx ? {...p, status: 'error' as PhaseStatus, code: -2} : p,
      );
      phasesRef.current = next;
      return next;
    });
  }, []);

  const runNextPhase = useCallback(
    (idx: number) => {
      if (cancelledRef.current) return;
      const currentPhases = phasesRef.current;
      if (idx >= currentPhases.length) {
        setAllDone(true);
        return;
      }
      setCurrentIdx(idx);
      const phase = currentPhases[idx];
      updatePhase(idx, {status: 'running', output: '', code: null});

      const child = spawn(phase.command, phase.args, {
        env: {...process.env, FORCE_COLOR: '0', NO_COLOR: '1'},
      });
      childRef.current = child;

      child.stdout?.on('data', d => appendOutput(idx, d.toString()));
      child.stderr?.on('data', d => appendOutput(idx, d.toString()));

      child.on('close', exitCode => {
        childRef.current = null;
        if (cancelledRef.current) return;
        updatePhase(idx, {
          status: exitCode === 0 ? 'done' : 'error',
          code: exitCode ?? 1,
        });
        timerRef.current = setTimeout(() => {
          timerRef.current = null;
          runNextPhase(idx + 1);
        }, 100);
      });

      child.on('error', err => {
        childRef.current = null;
        if (cancelledRef.current) return;
        appendOutput(idx, `\n[spawn error] ${err.message}\n`);
        updatePhase(idx, {status: 'error', code: -1});
        timerRef.current = setTimeout(() => {
          timerRef.current = null;
          runNextPhase(idx + 1);
        }, 100);
      });
    },
    [updatePhase, appendOutput],
  );

  // Start the queue whenever enabled becomes true. Idempotent on re-renders.
  useEffect(() => {
    if (!enabled) {
      // Disabled: cancel any in-flight work and reset for next time.
      cancelledRef.current = true;
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
      if (childRef.current) {
        try {
          childRef.current.kill();
        } catch {
          // ignore
        }
        childRef.current = null;
      }
      startedRef.current = false;
      setAllDone(false);
      setCurrentIdx(0);
      // Note: we do NOT clear phases here. The user may have navigated
      // back from 'executing' to 'browse' to fix something; on the next
      // enable, runNextPhase picks up phasesRef.
      return;
    }

    if (startedRef.current) return; // already running

    if (initialPhases.length === 0) {
      setAllDone(true);
      return;
    }

    // Sync the queue's state to the parent's snapshot.
    const initial = initialPhases.map(p => ({
      ...p,
      status: p.status ?? 'pending',
      output: p.output ?? '',
      code: p.code ?? null,
    }));
    setPhases(initial);
    phasesRef.current = initial;
    setCurrentIdx(0);
    startedRef.current = true;
    cancelledRef.current = false;
    setAllDone(false);

    // Defer to next tick so state setters are flushed before we read
    // them in the spawn callbacks.
    timerRef.current = setTimeout(() => {
      timerRef.current = null;
      runNextPhase(0);
    }, 0);
  }, [enabled, initialPhases, runNextPhase]);

  // Cleanup on unmount: cancel any in-flight child, clear pending timers.
  useEffect(() => {
    return () => {
      cancelledRef.current = true;
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
      if (childRef.current) {
        try {
          childRef.current.kill();
        } catch {
          // ignore
        }
        childRef.current = null;
      }
    };
  }, []);

  const cancel = useCallback(() => {
    cancelledRef.current = true;
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
    if (childRef.current) {
      try {
        childRef.current.kill();
      } catch {
        // ignore
      }
      childRef.current = null;
    }
    markRemainingAsError(currentIdx);
    setAllDone(true);
  }, [currentIdx, markRemainingAsError]);

  const isRunning = enabled && currentIdx < phases.length && !allDone;

  return {phases, currentIdx, isRunning, allDone, cancel};
}
