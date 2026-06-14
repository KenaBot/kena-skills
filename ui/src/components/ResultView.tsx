import React from 'react';
import {Box, Text, useInput} from 'ink';
import type {InstallPhase} from '../hooks/useInstallQueue.js';

interface ResultViewProps {
  phases: InstallPhase[];
  onBack: () => void;
  onQuit: () => void;
}

export default function ResultView({phases, onBack, onQuit}: ResultViewProps) {
  useInput((input, key) => {
    if (key.return) onBack();
    if (input === 'q' || key.escape) onQuit();
  });

  const succeeded = phases.filter(p => p.status === 'done').length;
  const failed = phases.filter(p => p.status === 'error').length;

  return (
    <Box flexDirection="column" marginY={1}>
      <Box borderStyle="round" borderColor={failed === 0 ? 'green' : 'yellow'} paddingX={1}>
        <Box flexDirection="column">
          <Text bold color={failed === 0 ? 'green' : 'yellow'}>
            {failed === 0 ? '✓ All phases complete' : '⚠ Partial success'}
          </Text>
          <Text dimColor>
            {succeeded} passed · {failed} failed · {phases.length} total
          </Text>
        </Box>
      </Box>
      {phases.map((phase, i) => {
        const isOk = phase.status === 'done';
        return (
          <Box
            key={phase.id}
            flexDirection="column"
            marginY={1}
            borderStyle="round"
            borderColor={isOk ? 'green' : 'red'}
            paddingX={1}
          >
            <Box>
              <Text color={isOk ? 'green' : 'red'} bold>
                {isOk ? '✓' : '✗'} {phase.skillName}
              </Text>
              <Text dimColor>  ({phase.sourceId}, {phase.scope})</Text>
            </Box>
            <Box marginLeft={2}>
              <Text dimColor>Exit code: {phase.code ?? '?'}</Text>
            </Box>
            <Box marginLeft={2} flexDirection="column" marginTop={0}>
              {phase.output
                .split('\n')
                .filter(line => line.length > 0)
                .slice(-6)
                .map((line, j) => (
                  <Text key={j} dimColor>
                    {line.length > 130 ? line.slice(0, 127) + '...' : line}
                  </Text>
                ))}
            </Box>
          </Box>
        );
      })}
      <Box marginTop={1}>
        <Text dimColor>[Enter] back to browse  [q] quit</Text>
      </Box>
    </Box>
  );
}
