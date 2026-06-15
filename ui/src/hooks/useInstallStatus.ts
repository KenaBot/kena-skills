import {existsSync} from 'node:fs';
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
 *
 * existsSync follows symlinks: a valid symlink to an existing target
 * returns true, a broken symlink returns false. That matches the
 * intent (we want to know if the user can use the skill, not whether
 * the symlink file itself is present).
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
    global: existsSync(globalPath),
    local: existsSync(localPath),
    globalPath,
    localPath,
  };
}
