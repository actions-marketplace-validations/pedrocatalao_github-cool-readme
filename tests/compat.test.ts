// v1 promise: every settings file that ever worked keeps working, and looks the same.
// tests/compat/ holds every distinct settings example released with v1 (the README's examples
// and examples/cool-readme.yml, from each tag). Add new ones when the documented settings change.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterAll, describe, expect, it } from 'vitest';
import { compute } from '../src/compute.ts';
import { CARDS, parseConfig, type Config } from '../src/config.ts';
import { usesOldLayout } from '../src/legacy.ts';
import { renderAll } from '../src/render/index.ts';
import { yearFixture } from './fixtures/snapshot.ts';

const DIR = 'tests/compat';
const files = readdirSync(DIR).filter((f) => f.endsWith('.yml')).sort();
const read = (file: string) => readFileSync(join(DIR, file), 'utf8');
/** Every card, whatever the file shows, so all of them are compared. */
const render = (config: Config) => renderAll(compute(yearFixture(), config), { ...config, show: [...CARDS] });

describe('every released settings example', () => {
  it('is there', () => expect(files.length).toBeGreaterThan(20));

  it.each(files)('%s still parses and renders', (file) => {
    const config = parseConfig(read(file));
    const svgs = render(config);
    expect(Object.keys(svgs)).toHaveLength(CARDS.length * 2);
  });

  it('is read the same way as approved', async () => {
    const parsed = Object.fromEntries(
      files.map((file) => {
        const config = parseConfig(read(file));
        return [file, { oldLayout: usesOldLayout(config), ...config }];
      }),
    );
    await expect(
      `${JSON.stringify(parsed, null, 2)}\n`,
      'the settings are read differently: if that is intended, accept it with "npm run test:update"',
    ).toMatchFileSnapshot('./compat/parsed.json');
  });
});

// Setup moves settings in the layout from before v1.5 to the new one, in bash (setup needs
// nothing else). The action still reads both, so the cards must not change when setup moves them.
describe("setup's move to the new layout", () => {
  const temp = mkdtempSync(join(tmpdir(), 'cool-readme-compat-'));
  afterAll(() => rmSync(temp, { recursive: true, force: true }));

  /** The file after setup's migrate_config, and its exit status: 0 moved, 1 already new, 2 can't be moved. */
  const migrate = (text: string): { status: number; text: string } => {
    const path = join(temp, 'cool-readme.yml');
    writeFileSync(path, text);
    try {
      execFileSync('bash', ['-c', '. setup/migrate.sh; migrate_config "$1"', 'bash', path], { stdio: 'pipe' });
      return { status: 0, text: readFileSync(path, 'utf8') };
    } catch (err) {
      return { status: (err as { status: number }).status, text: readFileSync(path, 'utf8') };
    }
  };

  const old = files.filter((file) => usesOldLayout(parseConfig(read(file))));
  const current = files.filter((file) => !old.includes(file));

  it.each(old)('%s is moved, and makes the same cards', (file) => {
    const before = read(file);
    const { status, text } = migrate(before);
    expect(status, text).toBe(0);
    const moved = parseConfig(text);
    expect(usesOldLayout(moved), text).toBe(false);
    expect(render(moved)).toEqual(render(parseConfig(before)));
  });

  it.each(current)('%s is left as it is', (file) => {
    const { status, text } = migrate(read(file));
    expect(status).toBe(1);
    expect(text).toBe(read(file));
  });
});
