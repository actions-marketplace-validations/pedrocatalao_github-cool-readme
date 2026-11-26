import { describe, expect, it } from 'vitest';
import { compute } from '../src/compute.ts';
import { DEFAULT_CONFIG, type Config } from '../src/config.ts';
import { fixture } from './fixtures/snapshot.ts';

const config = (patch: (c: Config) => void = () => {}): Config => {
  const c = structuredClone(DEFAULT_CONFIG);
  patch(c);
  return c;
};

const row = (m: ReturnType<typeof compute>, key: string) => {
  const r = m.summary.rows.find((r) => r.key === key)!;
  return [r.last12Months, r.allTime];
};

describe('summary', () => {
  it('counts everything with the default settings', () => {
    const m = compute(fixture(), config());
    expect(row(m, 'commits')).toEqual([160, 350]);
    expect(row(m, 'pullRequests')).toEqual([5, 9]);
    expect(row(m, 'issues')).toEqual([1, 2]);
    expect(row(m, 'reviews')).toEqual([1, 1]);
    expect(m.summary.stars).toEqual({ last12Months: 23, allTime: 123 }); // forks excluded
    expect(m.summary.activity).toEqual({ activeDays: 6, totalDays: 10, percent: 60 });
  });

  it('counts repos beyond the 100 GitHub lists, but only when nothing is filtered', () => {
    const s = fixture();
    s.last12Months.totals.commits += 7; // contributions in repos the per-repo lists left out
    expect(row(compute(s, config()), 'commits')[0]).toBe(167);
    expect(row(compute(s, config((c) => (c.count.orgs = false))), 'commits')[0]).toBe(60);
  });

  it('leaves out private repos when asked', () => {
    const m = compute(fixture(), config((c) => (c.count.private = false)));
    expect(row(m, 'commits')).toEqual([10, 100]);
    expect(row(m, 'pullRequests')).toEqual([3, 6]);
    expect(m.summary.stars).toEqual({ last12Months: 20, allTime: 120 });
  });

  it('leaves out organization repos when asked', () => {
    const m = compute(fixture(), config((c) => (c.count.orgs = false)));
    expect(row(m, 'commits')).toEqual([60, 150]);
    expect(row(m, 'issues')).toEqual([0, 1]);
    expect(row(m, 'reviews')).toEqual([0, 0]);
  });
});

describe('languages', () => {
  const shares = (m: ReturnType<typeof compute>) => Object.fromEntries(m.languages.map((l) => [l.name, Math.round(l.percent * 10) / 10]));

  it('weights each repo by your commits there', () => {
    expect(shares(compute(fixture(), config()))).toEqual({ Ruby: 34.3, C: 25.7, Batchfile: 22.9, Rust: 14.3, Python: 2.9 });
  });

  it('drops an excluded language, without handing its share to the repo\'s other languages', () => {
    const m = compute(fixture(), config((c) => (c.cards.languages.hide = ['batchfile'])));
    expect(shares(m)).toEqual({ Ruby: 44.4, C: 33.3, Rust: 18.5, Python: 3.7 });
  });

  it('applies repo weights, where 0 leaves a repo out', () => {
    const m = compute(fixture(), config((c) => (c.cards.languages.repos = { 'acme/platform': 0, game: 2 })));
    expect(shares(m)).toEqual({ C: 72, Rust: 20, Python: 8 });
  });

  it('excludes repos, by short name for your own', () => {
    const m = compute(fixture(), config((c) => (c.cards.languages.repos = { secret: 0 })));
    expect(m.languages.map((l) => l.name)).not.toContain('Rust');
  });

  it('shares 100% between the languages shown when Other is off', () => {
    const m = compute(fixture(), config((c) => { c.cards.languages.count = 2; c.cards.languages.other = false; }));
    expect(shares(m)).toEqual({ Ruby: 57.1, C: 42.9 });
  });

  it('folds the rest into Other, which counts as one of the entries', () => {
    const m = compute(fixture(), config((c) => (c.cards.languages.count = 3)));
    expect(shares(m)).toEqual({ Ruby: 34.3, C: 25.7, Other: 40 });
    expect(m.languages.at(-1)!.color).toBeNull();
    // With count 1, one language and Other.
    expect(shares(compute(fixture(), config((c) => (c.cards.languages.count = 1))))).toEqual({ Ruby: 34.3, Other: 65.7 });
  });

  it('has no Other when every language fits', () => {
    expect(shares(compute(fixture(), config((c) => (c.cards.languages.count = 5))))).toEqual({ Ruby: 34.3, C: 25.7, Batchfile: 22.9, Rust: 14.3, Python: 2.9 });
  });

  it('shows the next language instead of an Other under 0.5%', () => {
    // With game's weight down, its C and Python are together under 0.5%: C takes the last place.
    const m = compute(fixture(), config((c) => { c.cards.languages.count = 4; c.cards.languages.repos = { game: 0.01 }; }));
    expect(m.languages.map((l) => l.name)).toEqual(['Ruby', 'Batchfile', 'Rust', 'C']);
  });
});

describe('top repos', () => {
  /** The fixture, with more repos of octo's: `stars` per name. */
  const withRepos = (stars: Record<string, number>) => {
    const s = fixture();
    for (const [name, n] of Object.entries(stars)) {
      const key = `octo/${name}`;
      s.repos[key] = { nameWithOwner: key, owner: 'octo', ownerIsOrg: false, isPrivate: false, isFork: false, stars: n, languages: [] };
      s.ownedRepos.push(key);
    }
    return s;
  };
  const names = (m: ReturnType<typeof compute>) => m.repos.map((r) => r.name);

  it('lists your public repos by stars, with the stars of the last 12 months and the main language', () => {
    const m = compute(fixture(), config());
    // octo/secret is private and octo/fork a fork: never shown.
    expect(m.repos).toEqual([{ name: 'game', stars: 120, recent: 20, language: { name: 'C', color: '#555555' } }]);
  });

  it('shows at most count of them, most stars first, ties by name, none without stars', () => {
    const s = withRepos({ a: 5, b: 300, c: 5, d: 0, e: 1, f: 2, g: 3 });
    expect(names(compute(s, config()))).toEqual(['b', 'game', 'a', 'c', 'g', 'f']);
    expect(names(compute(s, config((c) => (c.cards.repos.count = 2))))).toEqual(['b', 'game']);
  });

  it('leaves out hidden ones, with a note for a name that matches nothing', () => {
    const m = compute(withRepos({ b: 300 }), config((c) => (c.cards.repos.hide = ['b', 'octo/nope'])));
    expect(names(m)).toEqual(['game']);
    expect(m.notes).toContain('cards.repos.hide: "octo/nope" matched no repository you contributed to');
  });

  it('never shows a private repo, even when private work counts', () => {
    const m = compute(fixture(), config((c) => (c.count.private = true)));
    expect(names(m)).not.toContain('secret');
  });
});

describe('downloads', () => {
  const names = (m: ReturnType<typeof compute>) => m.downloads.map((u) => u.name);

  it("lists your public repos by downloads, forks too: a fork's releases are its own", () => {
    const m = compute(fixture(), config());
    // octo/secret is private: never shown, downloads and users alike.
    expect(m.downloads).toEqual([
      { name: 'game', downloads: 340, users: 0, language: { name: 'C', color: '#555555' } },
      { name: 'fork', downloads: 12, users: 0, language: null },
    ]);
  });

  it("counts an action's users with its downloads, most first, ties by name, at most count", () => {
    const s = fixture();
    for (const name of ['act', 'tie']) {
      s.repos[`octo/${name}`] = { nameWithOwner: `octo/${name}`, owner: 'octo', ownerIsOrg: false, isPrivate: false, isFork: false, stars: 0, languages: [] };
      s.ownedRepos.push(`octo/${name}`);
    }
    s.actionUsers['octo/act'] = 400;
    s.downloads['octo/fork'] = 300;
    s.actionUsers['octo/fork'] = 40;
    s.downloads['octo/tie'] = 340; // fork 300 + 40, game and tie all 340: by name
    expect(names(compute(s, config()))).toEqual(['act', 'fork', 'game', 'tie']);
    expect(names(compute(s, config((c) => (c.cards.downloads.count = 2))))).toEqual(['act', 'fork']);
  });

  it('leaves out hidden ones, with a note for a name that matches nothing', () => {
    const m = compute(fixture(), config((c) => (c.cards.downloads.hide = ['game', 'octo/nope'])));
    expect(names(m)).toEqual(['fork']);
    expect(m.notes).toContain('cards.downloads.hide: "octo/nope" matched no repository you contributed to');
  });

  it('never shows a private repo, even when private work counts', () => {
    expect(names(compute(fixture(), config((c) => (c.count.private = true))))).not.toContain('secret');
  });
});

describe('weekly rhythm', () => {
  it('sums the calendar per weekday, Monday first', () => {
    // The fixture's calendar runs Thu 2026-10-01 to Sat 10-10: 0 for the first four days, then 4, 5, ... 9.
    const m = compute(fixture(), config());
    expect(m.weekly).toEqual([
      { day: 'Mon', count: 4 },
      { day: 'Tue', count: 5 },
      { day: 'Wed', count: 6 },
      { day: 'Thu', count: 0 + 7 },
      { day: 'Fri', count: 0 + 8 },
      { day: 'Sat', count: 0 + 9 },
      { day: 'Sun', count: 0 },
    ]);
  });
});

describe('notable contributions', () => {
  const repos = (m: ReturnType<typeof compute>) => m.contributions.map((c) => c.repo);

  it('lists merged and open pull requests to other public repos, by stars', () => {
    const m = compute(fixture(), config());
    expect(repos(m)).toEqual(['big/project', 'mid/project', 'tiny/project']);
    expect(m.contributions[0]).toMatchObject({ merged: 1, open: 0, lastDate: '2026-09-10T00:00:00Z', avatar: 'data:image/png;base64,AAAA' });
  });

  it('can leave open pull requests out', () => {
    expect(repos(compute(fixture(), config((c) => (c.cards.contributions.open = false))))).toEqual(['big/project', 'tiny/project']);
  });

  it('never shows pull requests closed without merging, even when pinned', () => {
    const m = compute(fixture(), config((c) => (c.cards.contributions.pin = ['old/archive'])));
    expect(repos(m)).toEqual(['big/project', 'mid/project', 'tiny/project']);
    expect(m.notes).toEqual(['cards.contributions.pin: "old/archive" has no merged or open pull requests of yours, so it is not shown']);
  });

  it('gives pinned repos their place before the most starred', () => {
    const m = compute(fixture(), config((c) => { c.cards.contributions.pin = ['tiny/project']; c.cards.contributions.count = 1; }));
    expect(repos(m)).toEqual(['tiny/project']);
  });

  it('hides repos', () => {
    expect(repos(compute(fixture(), config((c) => (c.cards.contributions.hide = ['BIG/Project']))))).toEqual(['mid/project', 'tiny/project']);
  });

  it('notes config entries that match nothing', () => {
    const m = compute(fixture(), config((c) => (c.cards.contributions.pin = ['nobody/nothing'])));
    expect(m.notes).toEqual(['cards.contributions.pin: "nobody/nothing" matched no repository you contributed to']);
  });
});
