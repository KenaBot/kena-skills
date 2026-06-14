import {readdirSync, existsSync} from 'node:fs';
import {join, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

export interface Source {
  id: string;
  type: 'local' | 'npx' | 'curl';
  description: string;
  path?: string;
  npx_args?: string;
  url?: string;
  available_skills?: string[];
  visible_skills?: string[];
  default_skills?: string[];
  skills?: string[];
  force_scope?: 'global' | 'local';
  enabled: boolean;
}

export interface Agent {
  id: string;
  npx_flag: string;
  global_dir: string;
  project_dir: string;
  description: string;
}

export interface MCP {
  id: string;
  name: string;
  description: string;
  install_command: string;
  verify_paths: string[];
  required_by: string[];
  enabled: boolean;
}

export interface SourcesRegistry {
  version: string;
  description: string;
  sources: Source[];
}

export interface AgentsRegistry {
  version: string;
  description: string;
  agents: Agent[];
}

export interface MCPsRegistry {
  version: string;
  description: string;
  servers: MCP[];
}

/**
 * Resolve the local skills directory for a source.
 * Uses REPO_ROOT env var if set (set by kena-skills bash entry),
 * otherwise walks up to find the repo root.
 */
function resolveLocalPath(source: Source): string | null {
  if (!source.path) return null;
  const repoRoot = process.env.REPO_ROOT;
  if (repoRoot) {
    return resolve(repoRoot, source.path);
  }
  return null;
}

function listLocalSkills(source: Source): string[] {
  const dir = resolveLocalPath(source);
  if (!dir || !existsSync(dir)) return [];
  try {
    return readdirSync(dir, {withFileTypes: true})
      .filter((d) => d.isDirectory() && !d.name.startsWith('_'))
      .filter((d) => existsSync(join(dir, d.name, 'SKILL.md')))
      .map((d) => d.name)
      .sort();
  } catch {
    return [];
  }
}

export function getVisibleSkills(source: Source): string[] {
  if (source.visible_skills && source.visible_skills.length > 0) {
    return source.visible_skills;
  }
  if (source.available_skills && source.available_skills.length > 0) {
    return source.available_skills;
  }
  if (source.skills && source.skills.length > 0) {
    return source.skills;
  }
  if (source.type === 'local' && source.path) {
    return listLocalSkills(source);
  }
  return [];
}

export function getDefaultSkills(source: Source): string[] {
  return source.default_skills ?? getVisibleSkills(source);
}
