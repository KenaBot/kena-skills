import {existsSync, realpathSync} from 'node:fs';
import {join} from 'node:path';
import {homedir} from 'node:os';
import type {Agent} from '../types.js';

export type InstallState =
  | 'not-installed'
  | 'installed-global'
  | 'installed-local'
  | 'installed-both';

export interface InstallLocation {
  global: boolean;
  local: boolean;
  globalPath?: string;
  localPath?: string;
}

/**
 * Detect the install status of a single skill for a single agent.
 * Returns 'not-installed' | 'installed-global' | 'installed-local' | 'installed-both'.
 *
 * "global" = `~/.config/opencode/skills/<skill>` (user home, applies to all projects)
 * "local"  = `./.opencode/skills/<skill>` (cwd, project-specific)
 */
export function getInstallState(skillName: string, agent: Agent): InstallState {
  const loc = getInstallLocation(skillName, agent);
  if (loc.global && loc.local) return 'installed-both';
  if (loc.global) return 'installed-global';
  if (loc.local) return 'installed-local';
  return 'not-installed';
}

export function getInstallLocation(skillName: string, agent: Agent): InstallLocation {
  const home = homedir();
  const cwd = process.cwd();
  const globalPath = join(home, agent.global_dir, skillName);
  const localPath = join(cwd, agent.project_dir, skillName);

  return {
    global: pathExistsOrIsLink(globalPath),
    local: pathExistsOrIsLink(localPath),
    globalPath,
    localPath,
  };
}

function pathExistsOrIsLink(p: string): boolean {
  if (existsSync(p)) return true;
  // existsSync follows symlinks; if the symlink is broken, it returns false.
  // Try realpath which also follows but might succeed if the target exists.
  try {
    realpathSync(p);
    return true;
  } catch {
    return false;
  }
}

/**
 * Compute install state for a skill across all agents.
 * Returns the first non-'not-installed' state found.
 */
export function getAggregateInstallState(
  skillName: string,
  agents: Agent[],
): {state: InstallState; agentId?: string} {
  for (const agent of agents) {
    const state = getInstallState(skillName, agent);
    if (state !== 'not-installed') {
      return {state, agentId: agent.id};
    }
  }
  return {state: 'not-installed'};
}
