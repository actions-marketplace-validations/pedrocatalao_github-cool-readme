// Every card in every look in preview/*.yml, light and dark, on one page, to compare after a change:
//   npm run preview           ->  out/preview/index.html, from made-up data that's the same every run
//   npm run preview -- --real ->  the same from .cache/snapshot.json (your own data, from npm run dev)
// The made-up data is the tests' fixture with a year of daily contributions added, so the
// calendar cards have something to show: the same data the golden test renders, with five more
// starred repos so the top repos card is full, and their downloads and users for the downloads card.
import { mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { compute } from '../src/compute.ts';
import { CARDS, loadConfig } from '../src/config.ts';
import { renderAll } from '../src/render/index.ts';
import type { Snapshot } from '../src/types.ts';
import { yearFixture } from '../tests/fixtures/snapshot.ts';

/** The made-up data: the golden test's, and five more of octo's repos with stars. */
function madeUp(): Snapshot {
  const s = yearFixture();
  const more: [name: string, stars: number, recent: number, language: string | null, color: string | null][] = [
    ['dotfiles', 2480, 310, 'Shell', '#89e051'],
    ['terraform-modules', 860, 95, 'HCL', '#844FBA'],
    ['pixel-engine', 412, 0, 'C', '#555555'],
    ['notes', 57, 6, null, null],
    ['kart-timer', 9, 2, 'TypeScript', '#3178c6'],
  ];
  for (const [name, stars, recent, language, color] of more) {
    const key = `octo/${name}`;
    s.repos[key] = {
      nameWithOwner: key, owner: 'octo', ownerIsOrg: false, isPrivate: false, isFork: false, stars,
      languages: language ? [{ name: language, color, size: 1 }] : [],
    };
    s.ownedRepos.push(key);
    if (recent) s.recentStars[key] = recent;
  }
  // Release downloads, and an action others use, for the downloads card.
  Object.assign(s.downloads, { 'octo/pixel-engine': 3120, 'octo/kart-timer': 640, 'octo/dotfiles': 85 });
  Object.assign(s.actionUsers, { 'octo/terraform-modules': 212, 'octo/dotfiles': 41 });
  return s;
}

const real = process.argv.includes('--real');
const snapshot: Snapshot = real ? JSON.parse(readFileSync('.cache/snapshot.json', 'utf8')) : madeUp();
const looks = readdirSync('preview').filter((f) => f.endsWith('.yml')).sort();

rmSync('out/preview', { recursive: true, force: true });
const sections: string[] = [];
for (const file of looks) {
  const name = file.replace(/\.yml$/, '');
  // Every card, whatever the look's file says: a new card is in the preview without listing it.
  const config = { ...loadConfig(`preview/${file}`), show: [...CARDS] };
  const files = renderAll(compute(snapshot, config), config);
  mkdirSync(`out/preview/${name}`, { recursive: true });
  for (const [path, svg] of Object.entries(files)) writeFileSync(`out/preview/${name}/${path}`, svg);
  const cards = CARDS.filter((card) => files[`${card}-light.svg`]);
  const side = (mode: 'light' | 'dark') =>
    `<div class="${mode}">${cards.map((card) => `<img src="${name}/${card}-${mode}.svg" width="400" alt="${card}">`).join('')}</div>`;
  sections.push(`<h2>${name}</h2>\n<div class="pair">${side('light')}${side('dark')}</div>`);
}

writeFileSync(
  'out/preview/index.html',
  `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Card preview</title>
<style>
  body { margin: 0; padding: 16px; font: 14px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f6f8fa; color: #1f2328; }
  h2 { font-size: 15px; margin: 24px 0 8px; }
  .pair { display: flex; flex-wrap: wrap; gap: 12px; }
  .pair > div { flex: 1 1 820px; display: flex; flex-wrap: wrap; gap: 10px; padding: 16px; border-radius: 8px; }
  img { max-width: 100%; }
  .light { background: #ffffff; }
  .dark { background: #0d1117; }
</style>
</head>
<body>
<p>${real ? 'From .cache/snapshot.json' : 'From made-up data'}; press r to play the animations again.</p>
${sections.join('\n')}
<script>
  addEventListener('keydown', (e) => {
    if (e.key === 'r') document.querySelectorAll('img').forEach((i) => (i.src = i.src.split('?')[0] + '?' + Date.now()));
  });
</script>
</body>
</html>
`,
);
console.log(`Wrote ${looks.length} looks to out/preview/index.html`);
