import type { Config } from '../../config.ts';
import type { DownloadedRepo } from './data.ts';
import { icon } from '../../render/icons.ts';
import { CONTENT_TOP, PAD, SMALL, TEXT, WIDTH, card, fadeIn, headerText, textWidth, truncate, type Theme } from '../../render/classic.ts';
import { esc, formatCompact } from '../../text.ts';

// Two columns of three rows, as on the top repos card: the most there can be, all in view.
const ROW = 46;
const TOP = CONTENT_TOP - 2;
const COL = (WIDTH - 2 * PAD) / 2;
const NAME_X = 16; // after the language's dot

const count = (n: number, word: string) => `${formatCompact(n)} ${word}${n === 1 ? '' : 's'}`;

/** What's under a repo's name: "709 downloads", "used in 67 repos", or both. */
export function describe(u: DownloadedRepo): string {
  return [u.downloads ? count(u.downloads, 'download') : '', u.users ? `used in ${count(u.users, 'repo')}` : ''].filter(Boolean).join(' · ');
}

/** Each in words, for the card's description. */
export function describeAll(items: DownloadedRepo[]): string {
  return items.map((u) => `${u.name}: ${describe(u)}`).join('. ');
}

/** Under the name: an icon and the words, or with both numbers, an icon and a number for each. */
function numbers(u: DownloadedRepo): string {
  const at = (x: number, name: 'download' | 'workflow', text: string) =>
    icon(name, x, 19, 14) + `<text x="${x + 18}" y="30" class="small secondary">${esc(text)}</text>`;
  if (!u.users) return at(NAME_X, 'download', count(u.downloads, 'download'));
  if (!u.downloads) return at(NAME_X, 'workflow', `used in ${count(u.users, 'repo')}`);
  const first = formatCompact(u.downloads);
  return at(NAME_X, 'download', first) + at(NAME_X + 18 + textWidth(first, SMALL) + 12, 'workflow', count(u.users, 'repo'));
}

export function renderDownloads(items: DownloadedRepo[], theme: Theme, config: Config): string {
  const title = config.cards.downloads.title;
  const header = title ? headerText(title, PAD) : '';
  if (!items.length) {
    return card({
      title: title ?? 'Most downloaded', desc: 'No downloads yet.', theme, config,
      body: header + `<text x="${PAD}" y="${CONTENT_TOP + 14}" class="label muted">No downloads yet</text>`,
    });
  }

  const rows = items
    .map((u, i) =>
      fadeIn(
        PAD + (i % 2) * COL,
        TOP + Math.floor(i / 2) * ROW,
        i,
        (u.language ? `<circle cx="5" cy="8" r="5" fill="${u.language.color ?? theme.neutral}"/>` : '') +
          `<text x="${NAME_X}" y="13" class="label" style="font-weight: 600;">${esc(truncate(u.name, COL - NAME_X - 12, TEXT, true))}</text>` +
          numbers(u),
        config,
        70,
      ),
    )
    .join('\n');

  return card({ title: title ?? 'Most downloaded', desc: describeAll(items), theme, config, body: header + '\n' + rows });
}
