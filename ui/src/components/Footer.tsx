import React from 'react';
import {Box, Text} from 'ink';

interface FooterProps {
  hints: string[];
}

export default function Footer({hints}: FooterProps) {
  return (
    <Box borderStyle="single" borderColor="gray" paddingX={1} marginTop={1}>
      {hints.map((hint, i) => (
        <Text key={i} dimColor>
          {hint}
          {i < hints.length - 1 ? '  ' : ''}
        </Text>
      ))}
    </Box>
  );
}
