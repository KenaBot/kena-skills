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
 * The hook only starts the queue when `enabled` is true. Until then it
 * does nothing — no spawn, no effect side effects. This lets the parent
 * gate execution on a screen transition (e.g. "executing" only).
 */
export function useInstallQueue(
  initialPhases: InstallPhase[],
  enabled: boolean,
): InstallQueueResult {
  const [phases, setPhases] = useState<InstallPhase[]>(() =>
    initialPhases.map(p => ({
      ...p,
      status: p.status ?? 'pending',
      output: p.output ?? '',
      code: p.code ?? null,
    })),
  );
  const [currentIdx, setCurrentIdx] = useState(0);
  const [allDone, setAllDone] = useState(false);
  const cancelledRef = useRef(false);
  const childRef = useRef<ReturnType<typeof spawn> | null>(null);
  const startedRef = useRef(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const updatePhase = useCallback((idx: number, patch: Partial<InstallPhase>) => {
    setPhases(prev => prev.map((p, i) => (i === idx ? {...p, ...patch} : p)));
  }, []);

  const appendOutput = useCallback((idx: number, text: string) => {
    setPhases(prev =>
      prev.map((p, i) => (i === idx ? {...p, output: p.output + text} : p)),
    );
  }, []);

  const markRemainingAsError = useCallback((fromIdx: number) => {
    setPhases(prev =>
      prev.map((p, i) =>
        i >= fromIdx ? {...p, status: 'error' as PhaseStatus, code: -2} : p,
      ),
    );
  }, []);

  const startNextPhase = useCallback(
    (idx: number) => {
      if (cancelledRef.current) return;
      if (idx >= phases.length) {
        setAllDone(true);
        return;
      }
      setCurrentIdx(idx);
      const phase = phases[idx];
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
        // Continue with next phase (continue-on-fail). 100ms gap so
        // React can paint the result before the next phase starts.
        timerRef.current = setTimeout(() => startNextPhase(idx + 1), 100);
      });

      child.on('error', err => {
        childRef.current = null;
        if (cancelledRef.current) return;
        appendOutput(idx, `\n[spawn error] ${err.message}\n`);
        updatePhase(idx, {status: 'error', code: -1});
        timerRef.current = setTimeout(() => startNextPhase(idx + 1), 100);
      });
    },
    [phases, updatePhase, appendOutput],
  );

  // Start the queue when enabled flips true. Idempotent: only once per
  // mount, even if `enabled` toggles.
  useEffect(() => {
    if (!enabled) return;
    if (startedRef.current) return;
    if (initialPhases.length === 0) {
      setAllDone(true);
      return;
    }
    startedRef.current = true;
    cancelledRef.current = false;
    setAllDone(false);
    startNextPhase(0);
  }, [enabled, initialPhases.length, startNextPhase]);

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
