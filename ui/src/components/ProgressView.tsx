import React from 'react';
import {Box, Text} from 'ink';
import Spinner from 'ink-spinner';
import type {InstallPhase} from '../hooks/useInstallQueue.js';

interface ProgressViewProps {
  phases: InstallPhase[];
  currentIdx: number;
}

export default function ProgressView({phases, currentIdx}: ProgressViewProps) {
  return (
    <Box flexDirection="column" marginY={1}>
      <Text dimColor>
        Running {phases.length} phase{phases.length !== 1 ? 's' : ''} sequentially (continue-on-fail). Press [Ctrl+C] to cancel.
      </Text>
      {phases.map((phase, i) => {
        const isCurrent = i === currentIdx;
        const isPast = i < currentIdx;
        const lines = phase.output
          .split('\n')
          .filter(line => line.length > 0)
          .slice(-15);

        return (
          <Box
            key={phase.id}
            flexDirection="column"
            marginY={1}
            borderStyle="round"
            borderColor={
              phase.status === 'error'
                ? 'red'
                : phase.status === 'done'
                ? 'green'
                : isCurrent
                ? 'cyan'
                : 'gray'
            }
            paddingX={1}
          >
            <Box>
              <Text
                color={
                  phase.status === 'done'
                    ? 'green'
                    : phase.status === 'error'
                    ? 'red'
                    : isCurrent
                    ? 'cyan'
                    : 'gray'
                }
              >
                {isCurrent && phase.status === 'running' ? (
                  <Spinner type="dots" />
                ) : phase.status === 'done' ? (
                  '✓ '
                ) : phase.status === 'error' ? (
                  '✗ '
                ) : (
                  '○ '
                )}
              </Text>
              <Text bold>
                Phase {i + 1}/{phases.length}: {phase.skillName}
              </Text>
              <Text dimColor>  ({phase.sourceId}, {phase.scope})</Text>
            </Box>
            <Box marginLeft={2}>
              <Text dimColor>{phase.command}</Text>
            </Box>
            {(isCurrent || isPast) && lines.length > 0 && (
              <Box marginTop={0} marginLeft={2} flexDirection="column">
                {lines.map((line, j) => (
                  <Text key={j} dimColor>
                    {line.length > 130 ? line.slice(0, 127) + '...' : line}
                  </Text>
                ))}
              </Box>
            )}
            {isCurrent && phase.status === 'running' && lines.length === 0 && (
              <Box marginLeft={2}>
                <Text dimColor>Waiting for output...</Text>
              </Box>
            )}
            {phase.status === 'done' && phase.code !== null && (
              <Box marginLeft={2}>
                <Text color="green">Exit code: {phase.code}</Text>
              </Box>
            )}
            {phase.status === 'error' && phase.code !== null && (
              <Box marginLeft={2}>
                <Text color="red">Exit code: {phase.code}</Text>
              </Box>
            )}
          </Box>
        );
      })}
    </Box>
  );
}
