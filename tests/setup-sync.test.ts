// Setup runs on users' machines with nothing but bash, so it keeps its own copies of a few
// things the TypeScript defines: the cards, styles and colours, the display panels' colours, the
// cards' titles. These tests read them out of its steps (setup/) and fail when the two drift apart.
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { CARD_DEFS } from '../src/cards/index.ts';
import { CARDS, COLORS, DEFAULT_CARDS, DEFAULT_CONFIG, NEW_KEYS, STYLES } from '../src/config.ts';
import { OLD_CARDS, OLD_KEYS } from '../src/legacy.ts';
import { look } from '../src/display/dmd.ts';
import { cardWidths } from '../src/render/index.ts';
import { THEMES } from '../src/palette.ts';

/** Every step of setup, in the order setup.sh runs them (its SETUP_BLOCKS). */
const blocks = readFileSync('setup.sh', 'utf8').match(/^SETUP_BLOCKS=\(\n([\s\S]*?)^\)$/m)?.[1];
if (!blocks) throw new Error('setup.sh no longer has SETUP_BLOCKS: update this test along with it');
const setup = blocks
  .split('\n')
  .map((line) => line.replace(/#.*/, '').trim())
  .filter(Boolean)
  .map((block) => readFileSync(`setup/${block}.sh`, 'utf8'))
  .join('\n');

/** The first group of `re` in setup's steps; fails, naming it, when they no longer have it. */
function find(re: RegExp): string {
  const m = setup.match(re);
  if (!m) throw new Error(`setup/ no longer has ${re}: update this test along with it`);
  return m[1];
}
const words = (re: RegExp) => find(re).split(' ');

describe('setup agrees with the TypeScript on', () => {
  it('the cards, and which are on by default', () => {
    expect(words(/^CARD_NAMES="([^"]+)"/m)).toEqual([...CARDS]);
    expect(words(/^DEFAULT_CARDS="([^"]+)"/m)).toEqual(DEFAULT_CARDS);
  });

  it('the styles and colours it offers', () => {
    expect(words(/style\) echo "([^"]+)"/)).toEqual([...STYLES]);
    expect(words(/color\) echo "([^"]+)"/)).toEqual([...COLORS]);
  });

  it('the keys that tell the old settings layout from the new one', () => {
    expect(words(/split\("(style matrix [^"]+)"/)).toEqual(OLD_KEYS);
    expect(words(/split\("(show [^"]+)"/)).toEqual(NEW_KEYS);
    // The migrator moves the cards there were before v1.5, whatever cards there are now.
    expect(words(/split\("([^"]+)", cc,/)).toEqual(OLD_CARDS);
  });

  it("each colour's dark panel, offered as a background", () => {
    const body = find(/^panel\(\) \{ case "\$1" in (.*?) esac; \}/m);
    const panels = Object.fromEntries([...body.matchAll(/(\S+)\) echo ([0-9a-f]{6}) ;;/g)].map((m) => [m[1], `#${m[2]}`]));
    const { '*': otherwise, ...byColour } = panels;
    const expected = Object.fromEntries(COLORS.filter((c) => c !== 'github').map((c) => [c, look(c, 'dark').panel]));
    expect(byColour).toEqual(expected);
    // GitHub's colours have no panel of their own: the dark page's colour.
    expect(otherwise).toBe(THEMES.dark.background);
  });

  it("the cards' titles and width in the README block", () => {
    const pictures = Object.fromEntries(
      [...setup.matchAll(/(\w+)\) picture \w+ "\$WIDTH" "([^"]+)"/g)].map((m) => [m[1], m[2]]),
    );
    expect(pictures).toEqual(Object.fromEntries(CARD_DEFS.map((card) => [card.name, card.alt])));
    const width = Number(find(/^WIDTH=(\d+)$/m));
    for (const w of Object.values(cardWidths(DEFAULT_CONFIG))) expect(w).toBe(width);
  });
});
