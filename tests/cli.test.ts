// What a run on GitHub Actions says when it can't start: the error in the log, and again as an
// annotation, shown on the run's page and summary (at its line in the settings when it has one).
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { afterAll, describe, expect, it } from 'vitest';

const CLI = resolve('src/cli.ts');
const temp = mkdtempSync(join(tmpdir(), 'cool-readme-cli-'));
afterAll(() => rmSync(temp, { recursive: true, force: true }));

/** Runs the CLI as the action does, with no token, in a folder holding `settings` as cool-readme.yml. */
function inActions(settings: string) {
  const dir = mkdtempSync(join(temp, 'run-'));
  writeFileSync(join(dir, 'cool-readme.yml'), settings);
  const env = { ...process.env, GITHUB_ACTIONS: 'true', GITHUB_TOKEN: '', GH_TOKEN: '' };
  const r = spawnSync(process.execPath, [CLI, '--out', 'stats'], { cwd: dir, env, encoding: 'utf8' });
  return { status: r.status, log: r.stderr, annotation: r.stdout.trim() };
}

describe('on GitHub Actions', () => {
  it('names the missing secret, and both ways to add it', () => {
    const { status, log, annotation } = inActions('show: [summary]\n');
    expect(status).toBe(1);
    expect(log).toMatch(/^error: no token: .*missing the CARDS_TOKEN secret/);
    expect(log).toContain('Add it by hand');
    expect(log).toContain('run setup again');
    expect(annotation).toMatch(/^::error title=Cool README cards::no token: [^\n]*%0AAdd it by hand/);
  });

  it("points at the line that isn't YAML", () => {
    const { status, log, annotation } = inActions('cards:\n  about:\n    lines:\n      - "a <a href="x">link</a>"\n');
    expect(status).toBe(1);
    expect(log).toMatch(/^error: cool-readme.yml isn't valid YAML at line 4, column \d+/);
    expect(annotation).toMatch(/^::error file=cool-readme.yml,line=4,col=\d+,title=Cool README cards::cool-readme.yml isn't valid YAML/);
    expect(annotation).not.toContain('\n');
  });
});
