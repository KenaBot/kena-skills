import React, {useState, useMemo, useEffect, useCallback} from 'react';
import {Box, Text, useApp, useInput} from 'ink';
import Header from './components/Header.js';
import SkillGroup from './components/SkillGroup.js';
import PhaseConfig, {type PhaseConfig as PC, configsToPhases} from './components/PhaseConfig.js';
import ProgressView from './components/ProgressView.js';
import ResultView from './components/ResultView.js';
import Footer from './components/Footer.js';
import {loadData, listInstalledAgents} from './hooks/useData.js';
import {resolveBashEntrypoint} from './hooks/useBashPath.js';
import {useInstallQueue, type InstallPhase} from './hooks/useInstallQueue.js';
import {getVisibleSkills} from './types.js';

type Screen = 'browse' | 'phase-config' | 'executing' | 'result';

const FOOTER_HINTS: Record<Screen, string[]> = {
  browse: ['[Space] toggle', '[i/Enter] install', '[h] collapse', '[q] quit'],
  'phase-config': ['[Space] targets', '[s] scope', '[d] deps', '[Enter] run', '[Esc] back'],
  executing: ['[Ctrl+C] cancel'],
  result: ['[Enter] back', '[Esc] back', '[q] quit'],
};

export default function App() {
  const {exit} = useApp();
  const data = useMemo(() => {
    try {
      return loadData();
    } catch {
      return null;
    }
  }, []);

  const installedAgents = useMemo(() => {
    try {
      return listInstalledAgents();
    } catch {
      return [];
    }
  }, []);

  const [screen, setScreen] = useState<Screen>('browse');
  const [selectedSkills, setSelectedSkills] = useState<Set<string>>(new Set());
  const [cursor, setCursor] = useState(0);
  const [configs, setConfigs] = useState<PC[]>([]);
  const [installPhases, setInstallPhases] = useState<
    {command: string; args: string[]}[]
  >([]);

  const sources = data?.sources.sources ?? [];
  const agents = data?.agents.agents ?? [];

  // Compute a flat list of (sourceId, skillName) pairs in order, for global cursor
  const flatSkills = useMemo(() => {
    const out: Array<{sourceId: string; skill: string}> = [];
    for (const src of sources) {
      if (!src.enabled) continue;
      for (const skill of getVisibleSkills(src)) {
        out.push({sourceId: src.id, skill});
      }
    }
    return out;
  }, [sources]);

  // Compute startIndex for each source (for SkillGroup rendering)
  const sourceStartIdx = useMemo(() => {
    const map = new Map<string, number>();
    for (let i = 0; i < flatSkills.length; i++) {
      const {sourceId} = flatSkills[i];
      if (!map.has(sourceId)) map.set(sourceId, i);
    }
    return map;
  }, [flatSkills]);

  // Clamp cursor inside the render so children always see a valid index.
  const safeCursor =
    flatSkills.length === 0
      ? 0
      : Math.max(0, Math.min(cursor, flatSkills.length - 1));

  // When entering phase-config, build default configs from selectedSkills
  const enterPhaseConfig = useCallback(() => {
    if (selectedSkills.size === 0) return;
    const newConfigs: PC[] = [];
    for (const {sourceId, skill} of flatSkills) {
      if (selectedSkills.has(skill)) {
        const src = sources.find(s => s.id === sourceId);
        const forcedScope = src?.force_scope;
        newConfigs.push({
          id: `${sourceId}:${skill}`,
          skillName: skill,
          sourceId,
          targets: installedAgents.length > 0 ? [...installedAgents] : ['opencode'],
          scope: (forcedScope as 'global' | 'local' | undefined) ?? 'global',
          installDeps: true,
        });
      }
    }
    setConfigs(newConfigs);
    setScreen('phase-config');
  }, [selectedSkills, flatSkills, sources, installedAgents]);

  // Build install phases from configs (resolve commands and args)
  const buildInstallPhases = useCallback(() => {
    return configsToPhases(configs, sources);
  }, [configs, sources]);

  // Wire useInstallQueue. The hook only starts when `enabled` is true.
  const installQueue = useInstallQueue(
    installPhases.map((p, i) => {
      const cfg = configs[i];
      return {
        id: cfg?.id ?? `phase-${i}`,
        skillName: cfg?.skillName ?? 'unknown',
        sourceId: cfg?.sourceId ?? 'unknown',
        scope: cfg?.scope ?? 'global',
        installDeps: cfg?.installDeps ?? false,
        command: p.command,
        args: p.args,
        status: 'pending' as const,
        output: '',
        code: null,
      } as InstallPhase;
    }),
    screen === 'executing',
  );

  // Watch queue completion
  useEffect(() => {
    if (installQueue.allDone && screen === 'executing') {
      setScreen('result');
    }
  }, [installQueue.allDone, screen]);

  // Single global useInput. Each branch filters by current screen.
  // - browse: arrow keys / jk / Space / i / Enter / q
  // - executing: Ctrl+C
  // - result: Enter / Esc -> back, q -> quit
  // - phase-config: PhaseConfig owns its own useInput (we skip here)
  useInput((input, key) => {
    if (screen === 'browse') {
      if (key.upArrow || input === 'k') {
        setCursor(c => Math.max(0, c - 1));
      }
      if (key.downArrow || input === 'j') {
        setCursor(c => Math.min(flatSkills.length - 1, c + 1));
      }
      if (input === ' ') {
        if (flatSkills.length === 0) return;
        const {skill} = flatSkills[safeCursor];
        if (!skill) return;
        const next = new Set(selectedSkills);
        if (next.has(skill)) next.delete(skill);
        else next.add(skill);
        setSelectedSkills(next);
      }
      if (input === 'i' || key.return) {
        if (selectedSkills.size > 0) enterPhaseConfig();
      }
      if (input === 'q') {
        exit();
        return;
      }
    }

    if (screen === 'executing') {
      if (key.ctrl && input === 'c') {
        installQueue.cancel();
        setScreen('result');
        return;
      }
    }

    if (screen === 'result') {
      if (key.return || key.escape) {
        setScreen('browse');
        setSelectedSkills(new Set());
        setConfigs([]);
        return;
      }
      if (input === 'q') {
        exit();
        return;
      }
    }
  });

  if (!data) {
    return (
      <Box flexDirection="column" paddingX={1}>
        <Header screen="error" source="—" />
        <Box marginY={1}>
          <Text color="red">Failed to load registry data.</Text>
        </Box>
        <Text dimColor>Check that installer/lib/*.json exist and are valid JSON.</Text>
        <Text dimColor>[q] quit</Text>
      </Box>
    );
  }

  if (sources.length === 0) {
    return (
      <Box flexDirection="column" paddingX={1}>
        <Header screen="error" source="—" />
        <Text color="red">No enabled sources in registry.</Text>
        <Text dimColor>[q] quit</Text>
      </Box>
    );
  }

  return (
    <Box flexDirection="column" paddingX={1}>
      <Header
        screen={screen}
        source={
          screen === 'browse' && flatSkills[safeCursor]
            ? flatSkills[safeCursor].sourceId
            : '—'
        }
      />

      {screen === 'browse' && (
        <>
          <Box marginY={0}>
            <Text dimColor>
              Select skills to install. State badges show installed (global / local) or not-installed.
            </Text>
          </Box>
          {sources.map(src => {
            if (!src.enabled) return null;
            return (
              <SkillGroup
                key={src.id}
                source={src}
                agents={agents}
                selected={selectedSkills}
                onChange={setSelectedSkills}
                globalCursor={safeCursor}
                startIndex={sourceStartIdx.get(src.id) ?? 0}
              />
            );
          })}
          {selectedSkills.size > 0 && (
            <Box marginTop={1} flexDirection="column">
              <Text color="green">
                ▸ Selected: {selectedSkills.size} ({Array.from(selectedSkills).join(', ')})
              </Text>
              <Text dimColor>Press [i] or [Enter] to configure and install</Text>
            </Box>
          )}
        </>
      )}

      {screen === 'phase-config' && (
        <PhaseConfig
          configs={configs}
          agents={agents}
          sources={sources}
          onChange={setConfigs}
          onConfirm={() => {
            setInstallPhases(buildInstallPhases());
            setScreen('executing');
          }}
          onBack={() => setScreen('browse')}
        />
      )}

      {screen === 'executing' && (
        <ProgressView
          phases={installQueue.phases}
          currentIdx={installQueue.currentIdx}
        />
      )}

      {screen === 'result' && (
        <ResultView
          phases={installQueue.phases}
          onBack={() => {
            setScreen('browse');
            setSelectedSkills(new Set());
            setConfigs([]);
          }}
          onQuit={() => exit()}
        />
      )}

      <Footer hints={FOOTER_HINTS[screen]} />
    </Box>
  );
}
