// Every look the cards can take, for the golden test (tests/golden/golden.test.ts) and the review
// page (npm run review). Built from the lists in config.ts, so a new card, style or colour is
// covered without touching this file.
import { CARDS, COLORS, DEFAULT_CONFIG, STYLES, type Config } from '../../src/config.ts';

/** One set of settings; each renders every card, light and dark. */
export interface Look {
  /** Path-like name, e.g. "dotmatrix/amber/none" or "classic/github/none/still". */
  id: string;
  config: Config;
}

/** The background kinds: none, a dark and a light colour of your own, and the old layout's "solid". */
const BACKGROUNDS: Record<string, string> = { none: 'none', dark: '#0d1117', light: '#f6f8fa', solid: 'solid' };

/** The about card has no text by default: some here, with marked words and more lines than fit, so it scrolls. */
const ABOUT: Config['cards']['about'] = {
  title: 'About',
  headline: "Hi, I'm *Octo*",
  lines: [
    'I build *cloud* infrastructure and backends.',
    'Mostly *Go* and Rust, some TypeScript.',
    'Open source on weekends.',
    'Currently learning *Zig*.',
    'Coffee, climbing and old synths.',
  ],
  facts: { 'Based in': 'Lisbon', Pronouns: 'they/them' },
};

function config(patch: (c: Config) => void): Config {
  const c = structuredClone(DEFAULT_CONFIG);
  c.show = [...CARDS];
  c.cards.about = structuredClone(ABOUT);
  patch(c);
  return c;
}

export function looks(): Look[] {
  const out: Look[] = [];
  for (const style of STYLES) {
    for (const color of COLORS) {
      for (const [bg, background] of Object.entries(BACKGROUNDS)) {
        out.push({ id: `${style}/${color}/${bg}`, config: config((c) => (c.look = { ...c.look, style, color, background })) });
      }
      // Still: what users get with animations: false.
      out.push({ id: `${style}/${color}/none/still`, config: config((c) => (c.look = { ...c.look, style, color, animations: false })) });
    }
    // Options that change how a card is drawn, not only what it says.
    out.push({ id: `${style}/github/none/ring-github`, config: config((c) => { c.look.style = style; c.cards.summary.ring = 'github'; }) });
    out.push({ id: `${style}/github/none/border`, config: config((c) => { c.look.style = style; c.look.border = true; }) });
  }
  return out;
}
