// Most downloaded as a pinball-style display: one repo at a time, its biggest number large.

import type { DownloadedRepo } from './data.ts';
import { describeAll } from './classic.ts';
import { formatCompact } from '../../text.ts';
import { textCells, textWidth } from '../../display/font.ts';
import { COLS, frame, path, type Style } from '../../display/dmd.ts';
import { fit, titleLine } from '../../display/text.ts';
import { slideshow, type Item } from '../../display/slides.ts';

/** The large number, and what's under the name: what it counts, then the other number. */
function numbers(u: DownloadedRepo): { big: number; details: string } {
  const downloads = u.downloads === 1 ? 'DOWNLOAD' : 'DOWNLOADS';
  const users = (n: number) => `${n === 1 ? 'REPO USES' : 'REPOS USE'} IT`;
  if (u.downloads >= u.users) {
    return { big: u.downloads, details: [downloads, u.users ? `${formatCompact(u.users).toUpperCase()} ${users(u.users)}` : ''].filter(Boolean).join(' · ') };
  }
  return { big: u.users, details: [users(u.users), u.downloads ? `${formatCompact(u.downloads).toUpperCase()} ${downloads}` : ''].filter(Boolean).join(' · ') };
}

export function renderDisplayDownloads(items: DownloadedRepo[], title: string | null, style: Style): string {
  const { look } = style;
  const header = titleLine(title, style);
  if (!items.length) {
    return frame({
      title: title ?? 'Most downloaded', desc: 'No downloads yet.', ...style, css: '',
      body: header + path(style, textCells('NO DOWNLOADS YET', 4, 24), look.lit),
    });
  }

  const slides: Item[][] = items.map((u, i) => {
    const counter = `${i + 1}/${items.length}`;
    const { big, details } = numbers(u);
    return [
      { text: formatCompact(big).toUpperCase(), col: 4, row: 18, scale: 2, shine: true },
      { text: counter, col: COLS - 4 - textWidth(counter), row: 18, dim: true },
      { text: fit(u.name.toUpperCase(), COLS - 8), col: 4, row: 40 },
      { text: fit(details, COLS - 8), col: 4, row: 51, dim: true },
    ];
  });
  const show = slideshow('d', slides, { col: 0, row: 16, cols: COLS, rows: 51 }, style, ['push', 'type', 'wipe']);

  return frame({
    title: title ?? 'Most downloaded',
    desc: describeAll(items),
    ...style,
    css: show.css,
    body: `<defs>${show.defs}</defs>\n${header}\n${show.markup}`,
  });
}
