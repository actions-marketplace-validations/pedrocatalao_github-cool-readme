// Setup changes people's own files: cool-readme.yml (one setting, the list of cards, the about card's
// text) and README.md (the cards block). These run setup's own functions, from setup/edit.sh, in
// bash on sample files, and check what comes out: the rest of the file as it was, and what the
// action reads from it as intended.
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { afterAll, describe, expect, it } from 'vitest';
import { parseConfig } from '../src/config.ts';

// The bash that ships with macOS when there is one: the oldest setup has to work with.
const BASH = existsSync('/bin/bash') ? '/bin/bash' : 'bash';
const SETUP = resolve('setup');
const temp = mkdtempSync(join(tmpdir(), 'cool-readme-edit-'));
afterAll(() => rmSync(temp, { recursive: true, force: true }));

/** Runs `script` with setup's names and file functions loaded, in a folder holding `files`, with `args` as $1...; its output and the files after. */
function run(script: string, files: Record<string, string>, args: string[] = []) {
  const dir = mkdtempSync(join(temp, 'case-'));
  for (const [name, text] of Object.entries(files)) writeFileSync(join(dir, name), text);
  const load = ['config', 'edit', 'about'].map((block) => `. '${SETUP}/${block}.sh'`).join('; ');
  const out = execFileSync(BASH, ['-c', `set -euo pipefail; ${load}; ${script}`, 'bash', ...args], { cwd: dir, encoding: 'utf8' });
  const read = (name: string) => readFileSync(join(dir, name), 'utf8');
  return { out: out.replace(/\n$/, ''), read };
}
const lines = (...l: string[]) => `${l.join('\n')}\n`;

describe('yaml_get', () => {
  const file = lines(
    'user: someone   # the login',
    'look:',
    '  style: "oled"',
    "  color: 'amber' # the accent",
    '  background: 030506',
    '# a comment',
    'count:',
    '  private: false',
  );
  const get = (key: string) => run(`yaml_get c.yml ${key}`, { 'c.yml': file }).out;

  it('reads a top-level setting and one under a parent, without comments or quotes', () => {
    expect(get('user')).toBe('someone');
    expect(get('look.style')).toBe('oled');
    expect(get('look.color')).toBe('amber');
    expect(get('look.background')).toBe('030506');
    expect(get('count.private')).toBe('false');
  });

  it('is empty for a setting that is not there', () => {
    expect(get('look.border')).toBe('');
    expect(get('show')).toBe('');
  });

  it('reads a colour with # as a value, not a comment', () => {
    expect(run('yaml_get c.yml look.background', { 'c.yml': lines('look:', '  background: "#0d1117"') }).out).toBe('#0d1117');
  });
});

describe('yaml_set', () => {
  it('changes only that line, keeping its comment', () => {
    const before = lines('# Settings', 'user: someone', 'look:', '  style: classic   # or oled', '  color: github', 'count:', '  orgs: true');
    const { read } = run('yaml_set c.yml look.style oled', { 'c.yml': before });
    expect(read('c.yml')).toBe(before.replace('  style: classic   # or oled', '  style: oled   # or oled'));
  });

  it("adds a missing one at the end of its parent, above the next key's comments", () => {
    const { read } = run('yaml_set c.yml look.color amber', {
      'c.yml': lines('look:', '  style: oled', '', "# what's counted", 'count:', '  private: true'),
    });
    expect(read('c.yml')).toBe(lines('look:', '  style: oled', '  color: amber', '', "# what's counted", 'count:', '  private: true'));
  });

  it('adds the parent when it is missing, and a top-level setting', () => {
    const { read } = run('yaml_set c.yml look.color amber; yaml_set c.yml user someone', { 'c.yml': lines('show: [summary]') });
    expect(read('c.yml')).toBe(lines('show: [summary]', 'look:', '  color: amber', 'user: someone'));
  });

  it('writes what the action reads', () => {
    const { read } = run(
      'yaml_set c.yml count.private false; yaml_set c.yml look.style dotmatrix; yaml_set c.yml look.background 0d0b07',
      { 'c.yml': lines('show: [summary, weekly]', 'look:', '  color: amber  # the accent', '', '# the rest', 'cards:', '  weekly:', '    title: Week') },
    );
    const config = parseConfig(read('c.yml'));
    expect(config.count.private).toBe(false);
    expect(config.look).toMatchObject({ style: 'dotmatrix', color: 'amber', background: '#0d0b07' });
    expect(config.cards.weekly.title).toBe('Week');
  });
});

describe('cards_get', () => {
  const get = (text: string, list = 'show') => run(`LIST=${list}; cards_get c.yml`, { 'c.yml': text }).out;

  it('reads a list on one line, with quotes and a comment', () => {
    expect(get(lines(`show: ["summary", 'weekly', languages]   # in README order`))).toBe('summary weekly languages');
  });

  it('reads a list a card per line, past comments and blank lines', () => {
    expect(get(lines('show:', '  - summary', '  # - weekly', '  - languages  # mine', '', '  - streaks', 'look:', '  style: oled'))).toBe(
      'summary languages streaks',
    );
  });

  it('is empty for none, and for no list', () => {
    expect(get(lines('show: []'))).toBe('');
    expect(get(lines('look:', '  style: oled'))).toBe('');
  });

  it('reads the key of settings from before v1.5', () => {
    expect(get(lines('cards: [summary, streaks]', 'style: oled'), 'cards')).toBe('summary streaks');
  });
});

describe('cards_set', () => {
  it('replaces a list on one line', () => {
    const { read } = run('cards_set c.yml "weekly summary"', { 'c.yml': lines('user: me', 'show: [summary]', 'look:', '  style: oled') });
    expect(read('c.yml')).toBe(lines('user: me', 'show: [weekly, summary]', 'look:', '  style: oled'));
  });

  it('replaces a list a card per line, every card of it, keeping its comments', () => {
    const { read } = run('cards_set c.yml "summary about"', {
      'c.yml': lines('show:', '  - summary', '  # - weekly', '  - languages', '', '  - streaks', 'look:', '  style: oled'),
    });
    expect(read('c.yml')).toBe(lines('show: [summary, about]', '  # - weekly', '', 'look:', '  style: oled'));
    expect(parseConfig(read('c.yml')).show).toEqual(['summary', 'about']);
  });

  it('adds the list when there is none, and writes none as []', () => {
    expect(run('cards_set c.yml "summary"', { 'c.yml': lines('user: me') }).read('c.yml')).toBe(lines('user: me', 'show: [summary]'));
    expect(parseConfig(run('cards_set c.yml ""', { 'c.yml': lines('show: [summary]') }).read('c.yml')).show).toEqual([]);
  });
});

describe("the about card's text", () => {
  it('replaces the about section, keeping the other cards', () => {
    const { read } = run(`about_set c.yml "    headline: $(quoted 'new')"`, {
      'c.yml': lines(
        'cards:',
        '  summary:',
        '    ring: github',
        '  about:',
        '    headline: old',
        '    lines:',
        '      - one',
        '',
        '  weekly:',
        '    title: Week',
        'look:',
        '  style: oled',
      ),
    });
    const config = parseConfig(read('c.yml'));
    expect(config.cards.about).toMatchObject({ headline: 'new', lines: [], facts: {} });
    expect(config.cards.summary.ring).toBe('github');
    expect(config.cards.weekly.title).toBe('Week');
    expect(config.look.style).toBe('oled');
  });

  it('adds cards: when there is none', () => {
    const { read } = run(`about_set c.yml "    headline: $(quoted 'hi')"`, { 'c.yml': lines('look:', '  style: oled') });
    expect(parseConfig(read('c.yml')).cards.about.headline).toBe('hi');
  });

  it('writes any text as typed: quotes, backslashes, # and :', () => {
    const headline = String.raw`Hi, I'm *Pedro* # "really" C:\dev`;
    const line = String.raw`a \ b`;
    const fact = ['Based in', 'Lisbon: the "best" #1'];
    // As write_about puts it together.
    const { read } = run(
      String.raw`n=$'\n'; about_set c.yml "    headline: $(quoted "$1")$n    lines:$n      - $(quoted "$2")$n    facts:$n      $(quoted "$3"): $(quoted "$4")"`,
      { 'c.yml': lines('show: [about]') },
      [headline, line, ...fact],
    );
    expect(parseConfig(read('c.yml')).cards.about).toMatchObject({ headline, lines: [line], facts: { [fact[0]]: fact[1] } });
  });

  it('replaces text the action cannot read, as typing it again in setup does', () => {
    const broken = lines('cards:', '  about:', '    lines:', '      - "I work at <a href="https://example.com/">Example</a>"', 'look:', '  style: oled');
    expect(() => parseConfig(broken)).toThrow("isn't valid YAML");
    const link = '<a href="https://example.com/">Example</a>';
    const { read } = run(String.raw`about_set c.yml "    lines:"$'\n'"      - $(quoted "$1")"`, { 'c.yml': broken }, [`I work at ${link}`]);
    expect(parseConfig(read('c.yml')).cards.about.lines).toEqual([`I work at ${link}`]);
    expect(parseConfig(read('c.yml')).look.style).toBe('oled');
  });

  it('is empty with the placeholder, and not once it has text', () => {
    const empty = (text: string) => run('if about_empty c.yml; then echo empty; else echo text; fi', { 'c.yml': text }).out;
    expect(empty(lines('show: [about]'))).toBe('empty');
    expect(empty(run('LOGIN=me; about_set c.yml "$(about_placeholder)"', { 'c.yml': lines('show: [about]') }).read('c.yml'))).toBe('empty');
    expect(empty(lines('cards:', '  about:', '    lines:', '      - hello'))).toBe('text');
  });
});

describe('the cards block in README.md', () => {
  const block = lines('<!-- cool-readme:start -->', 'new cards', '<!-- cool-readme:end -->');

  it('replaces what is between the markers, and nothing else', () => {
    const { out, read } = run('readme_put block; echo "$where"', {
      block,
      'README.md': lines('# Me', '', '<!-- cool-readme:start -->', 'old cards', '<!-- cool-readme:end -->', '', 'More about me'),
    });
    expect(read('README.md')).toBe(lines('# Me', '', '<!-- cool-readme:start -->', 'new cards', '<!-- cool-readme:end -->', '', 'More about me'));
    expect(out).toBe('between the cool-readme markers');
  });

  it('goes at the end without markers, after a blank line', () => {
    const { out, read } = run('readme_put block; echo "$where"', { block, 'README.md': lines('# Me') });
    expect(read('README.md')).toBe(lines('# Me', '') + block);
    expect(out).toMatch(/^at the end/);
  });

  it('is all there is in an empty README', () => {
    expect(run('readme_put block', { block, 'README.md': '' }).read('README.md')).toBe(block);
  });
});
