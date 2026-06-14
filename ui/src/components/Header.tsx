import React from 'react';
import {Box, Text} from 'ink';

interface HeaderProps {
  source: string;
  screen: string;
}

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
        <Text dimColor>  v1.3.0  </Text>
        <Text color="yellow">[{screen}]</Text>
      </Text>
      <Text dimColor>source: {source}</Text>
    </Box>
  );
}
