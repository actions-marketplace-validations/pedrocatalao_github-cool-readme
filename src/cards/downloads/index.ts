import { ConfigError } from '../../shape.ts';
import type { CardDef } from '../card.ts';
import { downloadsData, type DownloadedRepo } from './data.ts';
import { renderDownloads } from './classic.ts';
import { renderDisplayDownloads } from './display.ts';

export interface DownloadsSettings {
  title: string | null;
  /** How many repos: up to MAX_DOWNLOADS, the rows that fit on the card. */
  count: number;
  /** Your repos left out, as "repo" or "owner/repo". */
  hide: string[];
}

export const MAX_DOWNLOADS = 6;

export const downloads: CardDef<'downloads', DownloadsSettings, DownloadedRepo[]> = {
  name: 'downloads',
  on: false,
  alt: 'Most downloaded',
  settings: { title: 'Most downloaded', count: 6, hide: [] },
  shape: { title: 'string?', count: 'number', hide: 'string[]' },
  check: (s) => {
    if (s.count > MAX_DOWNLOADS) throw new ConfigError(`"cards.downloads.count" must be at most ${MAX_DOWNLOADS}`);
  },
  data: downloadsData,
  classic: (data, theme, config) => renderDownloads(data, theme, config),
  display: (data, style, config) => renderDisplayDownloads(data, config.cards.downloads.title, style),
};
