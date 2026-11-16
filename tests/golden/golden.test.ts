// Golden test: every card in every look (tests/golden/matrix.ts), rendered from the same made-up
// data, hashed and compared with hashes.txt. Any change to any card fails it, naming the cards.
//   npm run review       -> see what changed: before and after, side by side
//   npm run test:update  -> accept the change (commit the new hashes.txt with it)
import { createHash } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { compute } from '../../src/compute.ts';
import { renderAll } from '../../src/render/index.ts';
import { yearFixture } from '../fixtures/snapshot.ts';
import { looks } from './matrix.ts';

describe('golden cards', () => {
  it('render exactly as approved', async () => {
    const snapshot = yearFixture();
    const lines: string[] = [];
    for (const { id, config } of looks()) {
      for (const [file, svg] of Object.entries(renderAll(compute(snapshot, config), config))) {
        lines.push(`${id}/${file.replace(/\.svg$/, '')} ${createHash('sha256').update(svg).digest('hex').slice(0, 16)}`);
      }
    }
    await expect(
      `${lines.sort().join('\n')}\n`,
      'cards changed: run "npm run review" to see them, and "npm run test:update" to accept them',
    ).toMatchFileSnapshot('./hashes.txt');
  });
});
