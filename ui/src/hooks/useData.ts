import {readFileSync, existsSync} from 'node:fs';
import {join, dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {homedir} from 'node:os';
import type {SourcesRegistry, AgentsRegistry, MCPsRegistry} from '../types.js';

export interface Data {
  sources: SourcesRegistry;
  agents: AgentsRegistry;
  mcps: MCPsRegistry;
}

let cached: Data | null = null;

/**
 * Walk up from the current file's directory until we find installer/lib/sources.json.
 * Works regardless of whether this file lives in src/hooks/, dist/hooks/, or elsewhere.
 */
function findRepoRoot(): string {
  const __filename = fileURLToPath(import.meta.url);
  let dir = dirname(__filename);
  for (let i = 0; i < 8; i++) {
    const candidate = join(dir, 'installer', 'lib', 'sources.json');
    if (existsSync(candidate)) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  throw new Error(
    'Could not find installer/lib/sources.json by walking up from ' +
      fileURLToPath(import.meta.url) +
      '. Run kena-skills from a complete checkout.',
  );
}

export function loadData(): Data {
  if (cached) return cached;

  const repoRoot = findRepoRoot();
  const base = join(repoRoot, 'installer', 'lib');
  const sourcesPath = join(base, 'sources.json');
  const agentsPath = join(base, 'agents.json');
  const mcpsPath = join(base, 'mcps.json');

  cached = {
    sources: JSON.parse(readFileSync(sourcesPath, 'utf8')),
    agents: JSON.parse(readFileSync(agentsPath, 'utf8')),
    mcps: JSON.parse(readFileSync(mcpsPath, 'utf8')),
  };
  return cached;
}

export function listInstalledAgents(): string[] {
  const {agents} = loadData();
  const home = homedir();
  const detected: string[] = [];
  for (const agent of agents.agents) {
    const fullPath = join(home, agent.global_dir);
    const parent = dirname(fullPath);
    if (existsSync(parent)) {
      detected.push(agent.id);
    }
  }
  return detected;
}
