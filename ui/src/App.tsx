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
  result: ['[Enter] back', '[q] quit'],
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

  // Clamp cursor when flatSkills shrinks
  useEffect(() => {
    if (cursor >= flatSkills.length && flatSkills.length > 0) {
      setCursor(flatSkills.length - 1);
    }
  }, [flatSkills.length, cursor]);

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

  // Wire useInstallQueue — but only initialize when we actually enter executing
  const queue = useInstallQueue(
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
  );

  // Watch queue completion
  useEffect(() => {
    if (queue.allDone && screen === 'executing') {
      setScreen('result');
    }
  }, [queue.allDone, screen]);

  // Global keybindings
  useInput((input, key) => {
    if (input === 'q') exit();
    if (key.ctrl && input === 'c' && screen === 'executing') {
      queue.cancel();
      setScreen('result');
    }
    if (screen === 'browse' && (input === 'i' || key.return)) {
      if (selectedSkills.size > 0) enterPhaseConfig();
    }
    if (screen === 'browse') {
      if (key.upArrow || input === 'k') {
        setCursor(c => Math.max(0, c - 1));
      }
      if (key.downArrow || input === 'j') {
        setCursor(c => Math.min(flatSkills.length - 1, c + 1));
      }
      if (input === ' ') {
        if (flatSkills.length === 0) return;
        const {skill} = flatSkills[cursor];
        const next = new Set(selectedSkills);
        if (next.has(skill)) next.delete(skill);
        else next.add(skill);
        setSelectedSkills(next);
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
          screen === 'browse' && flatSkills[cursor]
            ? flatSkills[cursor].sourceId
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
                isFocused={true}
                globalCursor={cursor}
                onCursorChange={setCursor}
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
        <ProgressView phases={queue.phases} currentIdx={queue.currentIdx} />
      )}

      {screen === 'result' && (
        <ResultView
          phases={queue.phases}
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
