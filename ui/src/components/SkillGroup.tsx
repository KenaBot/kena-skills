import React from 'react';
import {Box, Text} from 'ink';
import type {Source, Agent} from '../types.js';
import {getVisibleSkills} from '../types.js';
import {getInstallState, type InstallState} from '../hooks/useInstallStatus.js';

interface SkillGroupProps {
  source: Source;
  agents: Agent[];
  selected: Set<string>;
  onChange: (next: Set<string>) => void;
  globalCursor: number;
  startIndex: number;
}

/**
 * Pure renderer. Keybindings are handled by App.tsx (single useInput
 * filtered by screen) to avoid the double-fire bug.
 */
export default function SkillGroup({
  source,
  agents,
  selected,
  globalCursor,
  startIndex,
}: SkillGroupProps) {
  const skills = getVisibleSkills(source);

  return (
    <Box flexDirection="column" marginTop={1}>
      <Box>
        <Text color="cyan" bold>
          ▼ {source.id}
        </Text>
        <Text dimColor>
          {'  '}
          ({skills.length} skill{skills.length !== 1 ? 's' : ''})
        </Text>
      </Box>
      <Box flexDirection="column" marginLeft={2}>
        {skills.map((skill, i) => {
          const globalIdx = startIndex + i;
          const isCursor = globalCursor === globalIdx;
          const isSelected = selected.has(skill);
          // Aggregate install state across all agents
          const states = agents.map(a => getInstallState(skill, a));
          const bestState = states.includes('installed-both')
            ? 'installed-both'
            : states.includes('installed-global')
            ? 'installed-global'
            : states.includes('installed-local')
            ? 'installed-local'
            : 'not-installed';

          return (
            <Box key={skill}>
              <Text color={isCursor ? 'cyan' : undefined} bold={isCursor}>
                {isCursor ? '▸ ' : '  '}
              </Text>
              <Text color={isSelected ? 'green' : undefined} bold={isSelected}>
                {isSelected ? '[✓]' : '[ ]'}
              </Text>
              <Text color={isCursor ? 'cyan' : undefined}> {skill} </Text>
              <StateBadge state={bestState} />
            </Box>
          );
        })}
      </Box>
    </Box>
  );
}

function StateBadge({state}: {state: InstallState}) {
  if (state === 'not-installed') {
    return <Text dimColor>[not installed]</Text>;
  }
  if (state === 'installed-global') {
    return <Text color="green">[installed: global]</Text>;
  }
  if (state === 'installed-local') {
    return <Text color="green">[installed: local]</Text>;
  }
  if (state === 'installed-both') {
    return <Text color="green">[installed: global+local]</Text>;
  }
  return null;
}
