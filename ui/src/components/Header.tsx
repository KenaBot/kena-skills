import React from 'react';
import {Box, Text} from 'ink';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname, join, resolve} from 'node:path';

interface HeaderProps {
  source: string;
  screen: string;
}

/**
 * Resolve package.json relative to this compiled module, then read the
 * version. Works both in src/ and dist/ (the latter is what users run).
 */
function readVersion(): string {
  try {
    const __filename = fileURLToPath(import.meta.url);
    let dir = dirname(__filename);
    for (let i = 0; i < 6; i++) {
      const candidate = join(dir, 'package.json');
      try {
        const pkg = JSON.parse(readFileSync(candidate, 'utf8'));
        if (pkg.name === 'kena-skills-ui' && pkg.version) {
          return pkg.version;
        }
      } catch {
        // keep walking up
      }
      const parent = dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
  } catch {
    // ignore
  }
  return 'unknown';
}

const VERSION = `v${readVersion()}`;

export default function Header({source, screen}: HeaderProps) {
  return (
    <Box
      borderStyle="round"
      borderColor="cyan"
      paddingX={1}
      flexDirection="row"
      justifyContent="space-between"
    >
      <Text>
        <Text color="cyan" bold>
          kena-skills
        </Text>
        <Text dimColor>  {VERSION}  </Text>
        <Text color="yellow">[{screen}]</Text>
      </Text>
      <Text dimColor>source: {source}</Text>
    </Box>
  );
}
