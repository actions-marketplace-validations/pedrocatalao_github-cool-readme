// Weekly rhythm as a pinball-style display, like the classic card: the seven days' bars on the left,
// facts about them on the right. The bars fill once, like an audio meter, each with a peak dot that
// overshoots and drops back; then the facts take turns, the bars each is about lit and the rest
// dimmed, the light gliding over from one fact's bars to the next's a dot column at a time.

import { weekdayFacts, type WeekdayItem } from './data.ts';
import { formatNumber } from '../../text.ts';
import { textCells, textWidth } from '../../display/font.ts';
import { H, PITCH, W, frame, keyframes, path, type Cell, type Style } from '../../display/dmd.ts';
import { fit, titleLine } from '../../display/text.ts';
import { HOLD, slideshow, type Item } from '../../display/slides.ts';

const SLOT = 12; // columns per day
const BAR_COLS = 8;
const BASE = 58; // the bars stand on this row
const MAX_ROWS = 43;
const LABEL_ROW = 61;
const STATS_COL = 4 + 7 * SLOT + 8;
const STATS = { col: STATS_COL, row: 12, cols: 150 - 4 - STATS_COL, rows: 46 };

// The entrance, in seconds: the bars fill one after another, the taller ones taking longer.
const FILL_START = 0.2;
const STAGGER = 0.07;
const FILL = (rows: number) => 0.15 + (0.45 * rows) / MAX_ROWS;
const OVER = 3; // rows the peak dot rises above its bar
const PEAK_UP = 0.12;
const PEAK_HOLD = 0.35;
const PEAK_DOWN = 0.3;
const DIMMED = 0.3; // the bars a fact isn't about
const COL_STEP = 0.012; // seconds the light takes to move one dot column

/** The columns a run of days covers: from the first's left edge to the last's right one. */
type Span = [left: number, right: number];
const leftOf = (k: number) => Math.round(4 + k * SLOT + SLOT / 2 - BAR_COLS / 2);
const spanOf = (bars: number[]): Span => [leftOf(Math.min(...bars)), leftOf(Math.max(...bars)) + BAR_COLS];

/**
 * One edge of the light, over the facts' loop: as a fact comes in, it moves a dot column at a time
 * from where the last fact had it to where this one does, the two edges arriving together. Before the
 * first fact, the last: the loop goes round.
 */
function edgeFrames(spans: Span[], edge: 0 | 1): { t: number; css: string; ease?: string }[] {
  const x = (col: number) => `transform: translateX(${col * PITCH}px);`;
  const frames: { t: number; css: string; ease?: string }[] = [];
  spans.forEach((to, i) => {
    const from = spans[(i + spans.length - 1) % spans.length];
    const moves = Math.max(Math.abs(to[0] - from[0]), Math.abs(to[1] - from[1]));
    const cols = Math.abs(to[edge] - from[edge]);
    frames.push({ t: i * HOLD, css: x(from[edge]), ease: cols ? `steps(${cols})` : undefined });
    frames.push({ t: i * HOLD + moves * COL_STEP, css: x(to[edge]) });
  });
  frames.push({ t: spans.length * HOLD, css: x(spans[spans.length - 1][edge]) });
  return frames;
}

export function renderDisplayWeekly(days: WeekdayItem[], title: string | null, style: Style): string {
  const { look } = style;
  const header = titleLine(title, style);
  const max = Math.max(0, ...days.map((d) => d.count));
  if (!max) {
    return frame({
      title: title ?? 'Weekly rhythm', desc: 'No contributions in the last 12 months.', ...style, css: '',
      body: header + path(style, textCells('NO ACTIVITY YET', 4, 32), look.lit),
    });
  }

  const facts = weekdayFacts(days);
  const busiest = days.indexOf(facts.busiest);
  const quietest = days.indexOf(facts.quietest);

  // The facts, each with the bars it's about.
  const slides: { label: string; value: string; detail: string; bars: number[] }[] = [
    { label: 'BUSIEST', value: days[busiest].day.toUpperCase(), detail: formatNumber(facts.busiest.count), bars: [busiest] },
    { label: 'QUIETEST', value: days[quietest].day.toUpperCase(), detail: formatNumber(facts.quietest.count), bars: [quietest] },
    { label: 'WEEKDAYS', value: `${facts.weekdays}%`, detail: 'MON-FRI', bars: [0, 1, 2, 3, 4] },
    { label: 'WEEKENDS', value: `${100 - facts.weekdays}%`, detail: 'SAT-SUN', bars: [5, 6] },
  ];
  const items: Item[][] = slides.map((s) => [
    { text: s.label, col: STATS.col, row: 16, dim: true },
    { text: fit(s.value, STATS.cols), col: STATS.col, row: 26, scale: 2, shine: true },
    { text: fit(s.detail, STATS.cols), col: STATS.col, row: 44, dim: true },
  ]);

  // The bars fill, then the facts start, as the last bar is full.
  const rowsOf = days.map((d) => (d.count ? Math.max(1, Math.round((d.count / max) * MAX_ROWS)) : 0));
  const filled = days.map((_, k) => FILL_START + k * STAGGER + FILL(rowsOf[k]));
  const factsAt = Math.max(...filled);
  const entry = factsAt + PEAK_UP + PEAK_HOLD + PEAK_DOWN;
  const show = slideshow('w', items, STATS, style, ['type', 'push', 'wipe', 'flash'], factsAt);
  const loop = show.total;

  let css = show.css;
  let defs = show.defs;
  const bars: string[] = [];
  const peaks: string[] = [];
  const labels: Cell[] = [];
  days.forEach((d, k) => {
    const center = 4 + k * SLOT + SLOT / 2;
    const left = leftOf(k);
    const label = d.day[0].toUpperCase();
    labels.push(...textCells(label, Math.round(center - textWidth(label) / 2), LABEL_ROW));
    const rows = rowsOf[k];
    if (!rows) return;

    const cells: Cell[] = [];
    for (let r = BASE - rows; r < BASE; r++) for (let c = 0; c < BAR_COLS; c++) cells.push([left + c, r]);
    const start = FILL_START + k * STAGGER;
    const end = filled[k];

    // Filling: revealed from the baseline up, a row at a time.
    defs += `<mask id="wf${k}" maskUnits="userSpaceOnUse" x="0" y="0" width="${W}" height="${H}">` +
      `<rect class="wf${k}" x="${left * PITCH}" y="${(BASE - rows) * PITCH}" width="${BAR_COLS * PITCH}" height="${rows * PITCH}" fill="#fff"/></mask>`;
    css += `\n  .wf${k} { transform-box: fill-box; transform-origin: bottom; animation: wf${k} ${entry}s both; }` + keyframes(`wf${k}`, entry, [
      { t: 0, css: 'transform: scaleY(0);' },
      { t: start, css: 'transform: scaleY(0);', ease: `steps(${rows})` },
      { t: end, css: 'transform: scaleY(1);' },
      { t: entry, css: 'transform: scaleY(1);' },
    ]);

    // The peak dot: drawn at its highest, OVER rows above the bar. It rides up on the bar, rises
    // OVER more, waits, drops back onto the bar and goes.
    const peak: Cell[] = [];
    for (let c = 0; c < BAR_COLS; c++) peak.push([left + c, BASE - rows - 1 - OVER]);
    const y = (r: number) => `transform: translateY(${r * PITCH}px);`;
    css += `\n  .wp${k} { animation: wp${k} ${entry}s both; }` + keyframes(`wp${k}`, entry, [
      { t: 0, css: `opacity: 0; ${y(rows + OVER)}` },
      { t: start - 0.001, css: `opacity: 0; ${y(rows + OVER)}` },
      { t: start, css: `opacity: 1; ${y(rows + OVER)}`, ease: `steps(${rows})` },
      { t: end, css: `opacity: 1; ${y(OVER)}`, ease: `steps(${OVER})` },
      { t: end + PEAK_UP, css: `opacity: 1; ${y(0)}` },
      { t: end + PEAK_UP + PEAK_HOLD, css: `opacity: 1; ${y(0)}`, ease: `steps(${OVER})` },
      { t: end + PEAK_UP + PEAK_HOLD + PEAK_DOWN, css: `opacity: 1; ${y(OVER)}` },
      { t: end + PEAK_UP + PEAK_HOLD + PEAK_DOWN + 0.001, css: `opacity: 0; ${y(OVER)}` },
      { t: entry, css: `opacity: 0; ${y(OVER)}` },
    ]);

    bars.push(`<g mask="url(#wf${k})">${path(style, cells, look.accent)}</g>`);
    peaks.push(path(style, peak, look.accent, `class="wp${k}" opacity="0"`));
  });

  // The light, over the facts: the bars drawn again, bright, through a window from its left edge (a
  // white area to the right of it) to its right edge (a black one to the right of that), each edge
  // moving on its own. Until the facts start, the window is the whole card: all bars bright.
  const spans = slides.map((sl) => spanOf(sl.bars));
  defs += `<mask id="wlight" maskUnits="userSpaceOnUse" x="0" y="0" width="${W}" height="${H}">` +
    `<rect class="wl0" x="0" y="0" width="${W}" height="${H}" fill="#fff"/>` +
    `<rect class="wl1" x="0" y="0" width="${W}" height="${H}" fill="#000" transform="translate(${W} 0)"/></mask>`;
  for (const edge of [0, 1] as const) {
    css += `\n  .wl${edge} { animation: wl${edge} ${loop}s ${factsAt}s infinite; }` + keyframes(`wl${edge}`, loop, edgeFrames(spans, edge));
  }

  // The facts show once the bars are up.
  css += `\n  .wfacts { animation: wfacts 0.001s ${factsAt}s both; }\n  @keyframes wfacts { from { opacity: 0; } to { opacity: 1; } }`;

  return frame({
    title: title ?? 'Weekly rhythm',
    desc:
      `Contributions per weekday over the last 12 months: ${days.map((d) => `${d.day} ${d.count}`).join(', ')}. ` +
      `Busiest: ${facts.busiest.day}. Quietest: ${facts.quietest.day}. On weekdays: ${facts.weekdays}%.`,
    ...style,
    css,
    body:
      `<defs>${defs}</defs>\n${header}\n<g opacity="${DIMMED}">${bars.join('')}</g>\n` +
      `<g mask="url(#wlight)">${bars.join('')}</g>\n${peaks.join('')}\n` +
      `${path(style, labels, look.lit, `fill-opacity="${look.dim}"`)}\n<g class="wfacts">${show.markup}</g>`,
  });
}
