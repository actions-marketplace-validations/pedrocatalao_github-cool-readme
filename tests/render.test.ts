import { describe, expect, it } from 'vitest';
import { weekdayFacts } from '../src/cards/weekly/data.ts';
import { compute } from '../src/compute.ts';
import { CARDS, DEFAULT_CARDS, DEFAULT_CONFIG, STYLES, type Config } from '../src/config.ts';
import { describe as describeItem, pageOffsets, renderContributions } from '../src/cards/contributions/classic.ts';
import { renderAll } from '../src/render/index.ts';
import { THEMES } from '../src/palette.ts';
import { CARD_HEIGHT, PAD, truncate } from '../src/render/classic.ts';
import { formatCompact } from '../src/text.ts';
import { renderLanguages } from '../src/cards/languages/classic.ts';
import { MAX_LANGUAGES } from '../src/cards/languages/index.ts';
import { renderRepos } from '../src/cards/repos/classic.ts';
import { MAX_REPOS } from '../src/cards/repos/index.ts';
import { fixture } from './fixtures/snapshot.ts';

/** Minimal well-formedness check: every opened tag is closed in order. */
function assertWellFormed(svg: string): void {
  const stack: string[] = [];
  for (const m of svg.matchAll(/<(\/?)([a-zA-Z][\w:-]*)[^>]*?(\/?)>/g)) {
    const [, closing, name, selfClosing] = m;
    if (selfClosing) continue;
    if (closing) expect(stack.pop(), `closing </${name}>`).toBe(name);
    else stack.push(name);
  }
  expect(stack).toEqual([]);
}

const render = (patch: (c: Config) => void = () => {}) => {
  const c = structuredClone(DEFAULT_CONFIG);
  patch(c);
  return renderAll(compute(fixture(), c), c);
};

describe('cards', () => {
  // Every card, so a new one is checked here without being listed.
  const everyCard = (c: Config) => (c.show = [...CARDS]);
  const names = (cards: readonly string[]) => cards.flatMap((card) => [`${card}-dark.svg`, `${card}-light.svg`]).sort();

  it('writes a light and a dark variant of each card', () => {
    expect(Object.keys(render()).sort()).toEqual(names(DEFAULT_CARDS));
    expect(Object.keys(render(everyCard)).sort()).toEqual(names(CARDS));
  });

  it('makes only the cards in the show setting, in every style', () => {
    for (const style of STYLES) {
      const files = render((c) => { c.look.style = style; c.show = ['weekly', 'summary']; });
      expect(Object.keys(files).sort()).toEqual(['summary-dark.svg', 'summary-light.svg', 'weekly-dark.svg', 'weekly-light.svg']);
      // The same cards as when all are made: leaving some out changes nothing in the others.
      const all = render((c) => (c.look.style = style));
      expect(files['summary-dark.svg']).toBe(all['summary-dark.svg']);
    }
  });

  it('produces well-formed SVG with no missing values, every card in every style', () => {
    for (const style of STYLES) {
      for (const [name, svg] of Object.entries(render((c) => { everyCard(c); c.look.style = style; }))) {
        assertWellFormed(svg);
        expect(svg, `${style} ${name}`).not.toMatch(/NaN|undefined|null|Infinity/);
      }
    }
  });

  it('makes every card one size, 450 x 219, in every style', () => {
    const size = (svg: string) => svg.match(/<svg [^>]*width="(\d+)" height="(\d+)"/)!.slice(1).join('x');
    for (const style of STYLES) {
      const files = render((c) => { everyCard(c); c.look.style = style; });
      for (const card of CARDS) expect(size(files[`${card}-light.svg`]), `${style} ${card}`).toBe('450x219');
    }
  });

  it('fits the most languages there can be, Other included, with room below them', () => {
    const items = Array.from({ length: MAX_LANGUAGES }, (_, i) => ({ name: i ? `Language ${i}` : 'Other', color: null, percent: 100 / MAX_LANGUAGES }));
    const svg = renderLanguages(items, THEMES.light, DEFAULT_CONFIG);
    // Each entry is a dot and a line of text, 12px tall, at its row's y; below the last, the card's padding.
    const rows = [...svg.matchAll(/<g transform="translate\(\d+(?:\.\d+)? (\d+(?:\.\d+)?)\)"><g class="fade"/g)].map((m) => Number(m[1]));
    expect(rows).toHaveLength(MAX_LANGUAGES);
    expect(Math.max(...rows) + 12).toBeLessThanOrEqual(CARD_HEIGHT - PAD);
  });

  it('fits the most repos there can be, with room below them', () => {
    const items = Array.from({ length: MAX_REPOS }, (_, i) => ({ name: `repo-${i}`, stars: 1000 - i, recent: 10, language: null }));
    const svg = renderRepos(items, THEMES.light, DEFAULT_CONFIG);
    // Each entry is a name and a line under it, 34px tall, at its row's y; below the last, the card's padding.
    const rows = [...svg.matchAll(/<g transform="translate\(\d+(?:\.\d+)? (\d+(?:\.\d+)?)\)"><g class="fade"/g)].map((m) => Number(m[1]));
    expect(rows).toHaveLength(MAX_REPOS);
    expect(Math.max(...rows) + 34).toBeLessThanOrEqual(CARD_HEIGHT - PAD);
  });

  it('draws every display card in dots, with no text set in a font', () => {
    for (const style of STYLES.filter((s) => s !== 'classic')) {
      const files = render((c) => { everyCard(c); c.look.style = style; });
      for (const card of CARDS) expect(files[`${card}-light.svg`], `${style} ${card}`).not.toContain('<text');
    }
  });

  it('shows the summary numbers for the year and all time in turn, or all time without animations', () => {
    const files = render();
    expect(files['summary-light.svg']).toContain('<g class="year"');
    expect(files['summary-light.svg']).toContain('@keyframes all');
    const still = render((c) => { c.look.animations = false; })['summary-light.svg'];
    expect(still).not.toContain('class="year"');
    expect(still).toContain('ALL TIME');
    expect(still).not.toContain('>YEAR<');
  });

  it('scrolls the contributions in a loop when more than 3 are shown', () => {
    const c = structuredClone(DEFAULT_CONFIG);
    const item = (n: number) => ({ repo: `o${n}/r${n}`, owner: `o${n}`, stars: 10 - n, avatar: null, merged: 1, open: 0, lastDate: '2026-01-01T00:00:00Z' });
    const three = renderContributions([1, 2, 3].map(item), THEMES.light, c);
    expect(three).not.toContain('@keyframes scroll');
    const six = renderContributions([1, 2, 3, 4, 5, 6].map(item), THEMES.light, c);
    expect(six).toContain('class="scroll"');
    expect(six).toMatch(/@keyframes scroll \{.*translateY\(-138px\).*100% \{ transform: translateY\(0\); \} \}/);
    assertWellFormed(six);
    c.look.animations = false;
    expect(renderContributions([1, 2, 3, 4, 5, 6].map(item), THEMES.light, c)).not.toContain('class="scroll"');
  });

  it('pages the contributions 3 at a time, with a full last page', () => {
    expect(pageOffsets(3)).toEqual([0]);
    expect(pageOffsets(6)).toEqual([0, 138]);
    expect(pageOffsets(7)).toEqual([0, 138, 184]);
  });

  it('puts card titles on the header line, and hides them with null', () => {
    const files = render();
    expect(files['languages-light.svg']).toContain('>MOST USED LANGUAGES<');
    expect(files['contributions-light.svg']).toContain('>NOTABLE CONTRIBUTIONS<');
    expect(files['weekly-light.svg']).toContain('>WEEKLY RHYTHM<');
    const untitled = render((c) => { c.cards.languages.title = null; c.cards.contributions.title = null; });
    expect(untitled['languages-light.svg']).not.toContain('class="col"');
    expect(untitled['contributions-light.svg']).not.toContain('class="col"');
  });

  it('escapes text', () => {
    const svg = render((c) => (c.cards.summary.title = 'Tom & <Jerry>'))['summary-light.svg'];
    expect(svg).toContain('Tom &#38; &#60;Jerry&#62;');
    assertWellFormed(svg);
  });

  it('puts the numbers in the summary', () => {
    const svg = render()['summary-light.svg'];
    for (const n of ['160', '350', '23', '123', '60%']) expect(svg).toContain(`>${n}<`);
  });

  it('can put the GitHub logo in the ring and the percentage below it', () => {
    const svg = render((c) => (c.cards.summary.ring = 'github'))['summary-dark.svg'];
    expect(svg).toContain('class="logo"');
    expect(svg).toContain('>60% ACTIVE DAYS<');
    expect(svg).not.toContain('>60%<');
    assertWellFormed(svg);
  });

  it('drops all animation when disabled', () => {
    for (const svg of Object.values(render((c) => (c.look.animations = false)))) {
      expect(svg).not.toContain('@keyframes');
      expect(svg).not.toContain('animation-delay');
    }
  });

  it('puts the busiest and quietest day and the weekdays share beside the weekly bars, in every style', () => {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day, i) => ({ day, count: [4, 5, 6, 7, 8, 9, 1][i] }));
    expect(weekdayFacts(days)).toMatchObject({ busiest: { day: 'Sat' }, quietest: { day: 'Sun' }, weekdays: 75 }); // 30 of 40
    expect(weekdayFacts(days.map((d) => ({ ...d, count: 0 }))).weekdays).toBe(0);
    const svg = render()['weekly-light.svg']; // the fixture: Mon 4 to Sat 9, Sun 0
    expect(svg).toContain('>Saturday<');
    expect(svg).toContain('>Busiest day · 9<');
    expect(svg).toContain('>On weekdays<');
    for (const style of ['oled', 'dotmatrix'] as const) {
      const display = render((c) => (c.look.style = style))['weekly-dark.svg'];
      expect(display).toContain('Busiest: Sat.');
      assertWellFormed(display);
    }
  });

  it('renders empty states', () => {
    const c = structuredClone(DEFAULT_CONFIG);
    const model = compute({ ...fixture(), allTime: [], pullRequests: [] }, c);
    const files = renderAll(model, c);
    expect(files['languages-light.svg']).toContain('No language data yet');
    expect(files['contributions-light.svg']).toContain('No contributions to other projects yet');
    const quiet = renderAll(compute({ ...fixture(), calendar: [] }, c), c);
    expect(quiet['weekly-light.svg']).toContain('No contributions in the last 12 months');
  });
});

describe('formatting', () => {
  it('describes a contribution', () => {
    const base = { repo: 'a/b', owner: 'a', stars: 1, avatar: null, merged: 0, open: 0, lastDate: '2026-09-10T00:00:00Z' };
    expect(describeItem({ ...base, merged: 1 })).toBe('1 PR merged · Sep 2026');
    expect(describeItem({ ...base, merged: 3, open: 1 })).toBe('3 PRs merged, 1 open · Sep 2026');
    expect(describeItem({ ...base, open: 2 })).toBe('2 PRs open · Sep 2026');
  });

  it('shortens numbers and names', () => {
    expect([999, 1000, 1834, 27570, 1_250_000].map(formatCompact)).toEqual(['999', '1k', '1.8k', '28k', '1.3M']);
    expect(truncate('short', 100, 13)).toBe('short');
    expect(truncate('a-really-long-repository-name', 80, 13)).toMatch(/…$/);
  });
});
