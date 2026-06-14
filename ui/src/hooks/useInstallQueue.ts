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
 */
export function useInstallQueue(initialPhases: InstallPhase[]): InstallQueueResult {
  const [phases, setPhases] = useState<InstallPhase[]>(() =>
    initialPhases.map(p => ({...p, status: 'pending', output: '', code: null})),
  );
  const [currentIdx, setCurrentIdx] = useState(0);
  const [allDone, setAllDone] = useState(false);
  const cancelledRef = useRef(false);
  const childRef = useRef<ReturnType<typeof spawn> | null>(null);
  const startedRef = useRef(false);

  const updatePhase = useCallback((idx: number, patch: Partial<InstallPhase>) => {
    setPhases(prev => prev.map((p, i) => (i === idx ? {...p, ...patch} : p)));
  }, []);

  const appendOutput = useCallback((idx: number, text: string) => {
    setPhases(prev =>
      prev.map((p, i) => (i === idx ? {...p, output: p.output + text} : p)),
    );
  }, []);

  const runNextPhase = useCallback(
    (idx: number) => {
      if (cancelledRef.current) {
        return;
      }
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
        updatePhase(idx, {
          status: exitCode === 0 ? 'done' : 'error',
          code: exitCode ?? 1,
        });
        // Continue with next phase (continue-on-fail)
        setTimeout(() => runNextPhase(idx + 1), 100);
      });

      child.on('error', err => {
        appendOutput(idx, `\n[spawn error] ${err.message}\n`);
        updatePhase(idx, {status: 'error', code: -1});
        setTimeout(() => runNextPhase(idx + 1), 100);
      });
    },
    [phases, updatePhase, appendOutput],
  );

  useEffect(() => {
    if (startedRef.current) return;
    startedRef.current = true;
    cancelledRef.current = false;
    setAllDone(false);
    runNextPhase(0);
    return () => {
      cancelledRef.current = true;
      if (childRef.current) {
        try {
          childRef.current.kill();
        } catch {
          // ignore
        }
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const cancel = useCallback(() => {
    cancelledRef.current = true;
    if (childRef.current) {
      try {
        childRef.current.kill();
      } catch {
        // ignore
      }
    }
    // Mark remaining phases as error
    setPhases(prev =>
      prev.map((p, i) =>
        i >= currentIdx ? {...p, status: 'error' as PhaseStatus, code: -2} : p,
      ),
    );
    setAllDone(true);
  }, [currentIdx]);

  const isRunning = currentIdx < phases.length && !allDone && !cancelledRef.current;

  return {phases, currentIdx, isRunning, allDone, cancel};
}
