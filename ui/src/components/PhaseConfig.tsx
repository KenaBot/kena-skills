import React from 'react';
import {Box, Text, useInput} from 'ink';
import type {Agent, Source} from '../types.js';
import {resolveBashEntrypoint} from '../hooks/useBashPath.js';

export interface PhaseConfig {
  id: string;
  skillName: string;
  sourceId: string;
  targets: string[];
  scope: 'global' | 'local';
  installDeps: boolean;
}

interface PhaseConfigProps {
  configs: PhaseConfig[];
  agents: Agent[];
  sources: Source[];
  onChange: (next: PhaseConfig[]) => void;
  onConfirm: () => void;
  onBack: () => void;
}

export default function PhaseConfig({
  configs,
  agents,
  sources,
  onChange,
  onConfirm,
  onBack,
}: PhaseConfigProps) {
  const [cursor, setCursor] = React.useState(0);

  useInput((input, key) => {
    if (key.upArrow || input === 'k') {
      setCursor(c => Math.max(0, c - 1));
    }
    if (key.downArrow || input === 'j') {
      setCursor(c => Math.min(configs.length - 1, c + 1));
    }
    if (key.return) onConfirm();
    if (key.escape) onBack();
    // Space toggles all targets for the focused config
    if (input === ' ') {
      const cfg = configs[cursor];
      const allIds = agents.map(a => a.id);
      const allSelected = cfg.targets.length === allIds.length;
      updateConfig(cursor, {
        targets: allSelected ? [] : allIds,
      });
    }
    // 's' cycles scope (global<->local) unless forced
    if (input === 's') {
      const cfg = configs[cursor];
      const src = sources.find(s => s.id === cfg.sourceId);
      if (src?.force_scope) return;
      updateConfig(cursor, {
        scope: cfg.scope === 'global' ? 'local' : 'global',
      });
    }
    // 'd' toggles install-deps
    if (input === 'd') {
      const cfg = configs[cursor];
      updateConfig(cursor, {installDeps: !cfg.installDeps});
    }
    // 't' opens target multi-select (next phase)
  });

  function updateConfig(idx: number, patch: Partial<PhaseConfig>) {
    const next = configs.map((c, i) => (i === idx ? {...c, ...patch} : c));
    onChange(next);
  }

  return (
    <Box flexDirection="column" marginY={1}>
      <Text dimColor>
        Configure each phase. <Text color="cyan">[Space]</Text> toggle all targets ·{' '}
        <Text color="cyan">[s]</Text> cycle scope · <Text color="cyan">[d]</Text> toggle deps ·{' '}
        <Text color="cyan">[Enter]</Text> install · <Text color="cyan">[Esc]</Text> back
      </Text>
      {configs.map((cfg, i) => {
        const isCursor = i === cursor;
        const src = sources.find(s => s.id === cfg.sourceId);
        const scopeForced = !!src?.force_scope;
        const detected = resolveBashEntrypoint();
        return (
          <Box
            key={cfg.id}
            flexDirection="column"
            marginY={1}
            borderStyle="round"
            borderColor={isCursor ? 'cyan' : 'gray'}
            paddingX={1}
          >
            <Text color={isCursor ? 'cyan' : undefined} bold>
              {isCursor ? '▸ ' : '  '}Phase {i + 1}/{configs.length}: {cfg.skillName}{' '}
              <Text dimColor>({cfg.sourceId})</Text>
            </Text>
            <Box marginLeft={2} marginTop={0} flexDirection="column">
              <Box>
                <Text>Targets: </Text>
                {cfg.targets.length === 0 ? (
                  <Text color="red">[none selected — Space to add all]</Text>
                ) : (
                  cfg.targets.map(t => (
                    <Text key={t} color="green">
                      [{t}]{' '}
                    </Text>
                  ))
                )}
              </Box>
              <Box>
                <Text>Scope: </Text>
                <Text
                  color={cfg.scope === 'global' ? 'cyan' : 'gray'}
                  bold={cfg.scope === 'global'}
                >
                  [{cfg.scope === 'global' ? '●' : ' '}] global
                </Text>
                <Text> </Text>
                <Text
                  color={cfg.scope === 'local' ? 'cyan' : 'gray'}
                  bold={cfg.scope === 'local'}
                >
                  [{cfg.scope === 'local' ? '●' : ' '}] local
                </Text>
                {scopeForced && (
                  <Text dimColor> (forced by source: {src!.force_scope})</Text>
                )}
              </Box>
              <Box>
                <Text>Install-deps: </Text>
                <Text color={cfg.installDeps ? 'green' : 'gray'} bold={cfg.installDeps}>
                  [{cfg.installDeps ? '✓' : ' '}]
                </Text>
              </Box>
              <Box>
                <Text dimColor>
                  → {detected} --skill {cfg.skillName} --source {cfg.sourceId} --target {cfg.targets.join(',') || 'NONE'}{' '}
                  {cfg.installDeps ? '--install-deps ' : ''}--scope {cfg.scope} --no-tui
                </Text>
              </Box>
            </Box>
          </Box>
        );
      })}
    </Box>
  );
}

/** Convert a list of PhaseConfigs into a queue of install phases with resolved commands. */
export function configsToPhases(
  configs: PhaseConfig[],
  sources: Source[],
): {command: string; args: string[]}[] {
  void sources;
  const bash = resolveBashEntrypoint();
  return configs.map(cfg => {
    const args: string[] = [
      '--skill',
      cfg.skillName,
      '--source',
      cfg.sourceId,
      '--target',
      cfg.targets.join(','),
      '--scope',
      cfg.scope,
    ];
    if (cfg.installDeps) args.push('--install-deps');
    args.push('--no-tui');
    return {command: bash, args};
  });
}
