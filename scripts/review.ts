// The cards that changed, before and after, side by side: for when the golden test fails.
//   npm run review                      ->  out/review/index.html: your working tree against HEAD
//   npm run review -- --base origin/main  ->  against another commit, branch or tag
// Every look in tests/golden/matrix.ts is rendered twice from the same made-up data: with the
// renderer as it is at the base (taken out of git into a temporary folder) and as it is now. Only
// the cards that differ are shown, as images, the way GitHub shows them, so they animate.
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';
import { compute } from '../src/compute.ts';
import { renderAll } from '../src/render/index.ts';
import { yearFixture } from '../tests/fixtures/snapshot.ts';
import { looks } from '../tests/golden/matrix.ts';

const { values } = parseArgs({ options: { base: { type: 'string', default: 'HEAD' } } });
const base = values.base;
const OUT = 'out/review';

type Render = typeof renderAll;
type Compute = typeof compute;

/** The renderer as it is at `ref`, loaded from a copy of its src/ outside the repo. */
async function rendererAt(ref: string, dir: string): Promise<{ compute: Compute; renderAll: Render }> {
  const tar = execFileSync('git', ['archive', '--format=tar', ref, 'src', 'package.json'], { maxBuffer: 1 << 28 });
  execFileSync('tar', ['-x', '-C', dir], { input: tar });
  symlinkSync(resolve('node_modules'), join(dir, 'node_modules'), 'dir');
  const load = (file: string) => import(pathToFileURL(join(dir, file)).href);
  return { compute: (await load('src/compute.ts')).compute, renderAll: (await load('src/render/index.ts')).renderAll };
}

interface Change {
  look: string;
  /** e.g. "weekly-dark" */
  card: string;
  before: string | null;
}

const temp = mkdtempSync(join(tmpdir(), 'cool-readme-review-'));
try {
  const old = await rendererAt(base, temp);
  const snapshot = yearFixture();
  rmSync(OUT, { recursive: true, force: true });
  mkdirSync(OUT, { recursive: true });

  const changes: Change[] = [];
  let total = 0;
  for (const { id, config } of looks()) {
    const after = renderAll(compute(snapshot, config), config);
    let before: Record<string, string> = {};
    try {
      before = old.renderAll(old.compute(snapshot, structuredClone(config)), structuredClone(config));
    } catch {
      // The base can't render this look (a setting it didn't have yet): every card counts as new.
    }
    for (const [file, svg] of Object.entries(after)) {
      total++;
      if (before[file] === svg) continue;
      const card = file.replace(/\.svg$/, '');
      changes.push({ look: id, card, before: before[file] ?? null });
      const write = (side: string, content: string) => {
        const path = join(OUT, side, id, file);
        mkdirSync(dirname(path), { recursive: true });
        writeFileSync(path, content);
      };
      write('after', svg);
      if (before[file] !== undefined) write('before', before[file]);
    }
  }

  writeFileSync(join(OUT, 'index.html'), page(changes, total));
  console.log(
    changes.length
      ? `${changes.length} of ${total} cards changed against ${base}: open ${OUT}/index.html`
      : `No card changed against ${base} (${total} compared)`,
  );
} finally {
  rmSync(temp, { recursive: true, force: true });
}

function page(changes: Change[], total: number): string {
  const esc = (s: string) => s.replace(/[&<>"]/g, (c) => `&#${c.charCodeAt(0)};`);
  const byLook = new Map<string, Change[]>();
  for (const c of changes) byLook.set(c.look, [...(byLook.get(c.look) ?? []), c]);
  const img = (side: string, c: Change) => `<img src="${side}/${c.look}/${c.card}.svg" width="400" alt="${esc(`${c.card} ${side}`)}" loading="lazy">`;
  const sections = [...byLook].map(([look, list]) => `
<section>
<h2>${esc(look)}</h2>
${list
  .map(
    (c) => `<div class="row ${c.card.endsWith('-dark') ? 'dark' : 'light'}">
  <div class="name">${esc(c.card)}</div>
  <figure>${c.before === null ? '<p class="new">new: not at the base</p>' : img('before', c)}<figcaption>before</figcaption></figure>
  <figure>${img('after', c)}<figcaption>after</figcaption></figure>
</div>`,
  )
  .join('\n')}
</section>`);
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Card review</title>
<style>
  body { margin: 0; padding: 16px; font: 14px -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f6f8fa; color: #1f2328; }
  h1 { font-size: 18px; } h2 { font-size: 15px; margin: 28px 0 8px; font-family: ui-monospace, monospace; }
  .row { display: flex; flex-wrap: wrap; align-items: flex-start; gap: 16px; padding: 12px 16px; border-radius: 8px; margin-bottom: 8px; }
  .light { background: #ffffff; } .dark { background: #0d1117; color: #f0f6fc; }
  .name { width: 140px; font-family: ui-monospace, monospace; }
  figure { margin: 0; } figcaption { font-size: 12px; opacity: 0.6; margin-top: 4px; }
  img { max-width: 100%; display: block; }
  .new { width: 400px; margin: 0; opacity: 0.6; }
</style>
</head>
<body>
<h1>${changes.length ? `${changes.length} of ${total} cards changed` : `No card changed (${total} compared)`} against ${esc(base)}</h1>
<p>Press r to play the animations again. Accept the changes with npm run test:update.</p>
${sections.join('\n')}
<script>
  addEventListener('keydown', (e) => {
    if (e.key === 'r') document.querySelectorAll('img').forEach((i) => (i.src = i.src.split('?')[0] + '?' + Date.now()));
  });
</script>
</body>
</html>
`;
}
