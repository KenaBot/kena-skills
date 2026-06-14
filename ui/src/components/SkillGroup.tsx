import React from 'react';
import {Box, Text, useInput} from 'ink';
import type {Source, Agent} from '../types.js';
import {getVisibleSkills} from '../types.js';
import {getInstallState, type InstallState} from '../hooks/useInstallStatus.js';

interface SkillGroupProps {
  source: Source;
  agents: Agent[];
  selected: Set<string>;
  onChange: (next: Set<string>) => void;
  isFocused: boolean;
  globalCursor: number;
  onCursorChange: (idx: number) => void;
  startIndex: number;
}

export default function SkillGroup({
  source,
  agents,
  selected,
  onChange,
  isFocused,
  globalCursor,
  onCursorChange,
  startIndex,
}: SkillGroupProps) {
  const [collapsed, setCollapsed] = React.useState(false);
  const skills = getVisibleSkills(source);

  useInput(
    (input, key) => {
      if (!isFocused) return;
      // Cursor navigation
      if (key.upArrow || input === 'k') {
        if (globalCursor > 0) onCursorChange(globalCursor - 1);
      }
      if (key.downArrow || input === 'j') {
        // We don't know the global total here; App handles bounds.
        onCursorChange(globalCursor + 1);
      }
      // Space toggles skill at cursor within this group
      if (input === ' ') {
        const localIdx = globalCursor - startIndex;
        if (localIdx >= 0 && localIdx < skills.length) {
          const id = skills[localIdx];
          const next = new Set(selected);
          if (next.has(id)) next.delete(id);
          else next.add(id);
          onChange(next);
        }
      }
      // 'h' or left collapses group
      if (input === 'h' || key.leftArrow) {
        setCollapsed(true);
      }
      if (input === 'l' || key.rightArrow) {
        setCollapsed(false);
      }
    },
    {isActive: isFocused},
  );

  return (
    <Box flexDirection="column" marginTop={1}>
      <Box>
        <Text color={isFocused ? 'cyan' : undefined} bold={isFocused}>
          {collapsed ? '▶ ' : '▼ '}
          {source.id}
        </Text>
        <Text dimColor>
          {'  '}
          ({skills.length} skill{skills.length !== 1 ? 's' : ''}){' '}
          {collapsed ? '[h to expand]' : '[h to collapse]'}
        </Text>
      </Box>
      {!collapsed && (
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
      )}
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
