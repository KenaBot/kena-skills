import {existsSync} from 'node:fs';
import {join, dirname, resolve, isAbsolute} from 'node:path';
import {fileURLToPath} from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Find the kena-skills bash entry point.
 *
 * Resolution order (priority high to low):
 *   1. KENA_SKILLS_BIN env var (explicit override)
 *   2. Walk up from this file to find installer/kena-skills (this checkout's
 *      own installer — the source of truth)
 *   3. REPO_ROOT env var + /installer/kena-skills
 *   4. kena-skills in $PATH (may be an OLDER version of the installer; we
 *      warn but use as last resort)
 *   5. Fallback: bare 'kena-skills' string (UI shows ENOENT)
 */
export function resolveBashEntrypoint(): string {
  // 1. Explicit override
  if (process.env.KENA_SKILLS_BIN && existsSync(process.env.KENA_SKILLS_BIN)) {
    return process.env.KENA_SKILLS_BIN;
  }

  // 2. Walk up from this file (preferred — uses THIS checkout's installer)
  let dir = __dirname;
  for (let i = 0; i < 8; i++) {
    const candidate = join(dir, 'installer', 'kena-skills');
    if (existsSync(candidate)) return candidate;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  // 3. REPO_ROOT env var
  if (process.env.REPO_ROOT) {
    const candidate = join(process.env.REPO_ROOT, 'installer', 'kena-skills');
    if (existsSync(candidate)) return candidate;
  }

  // 4. PATH fallback (may be older; last resort before string)
  const pathDirs = (process.env.PATH || '').split(':');
  for (const dir of pathDirs) {
    const candidate = join(dir, 'kena-skills');
    if (existsSync(candidate)) {
      // Warn so the user knows they may be using a stale binary
      if (process.stderr) {
        process.stderr.write(
          `[kena-skills] WARNING: using kena-skills from PATH: ${candidate}\n` +
            '         This may be a different version than the one in this checkout.\n' +
            '         Run "kena-skills --version" to compare, or set KENA_SKILLS_BIN to override.\n',
        );
      }
      return candidate;
    }
  }

  // 5. Fallback
  return 'kena-skills';
}
