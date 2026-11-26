// The downloads card's entries: your public repos most downloaded, by release downloads and, for an
// action, the other people's repos whose workflows use it. Both count as one each.
import type { Counted } from '../../compute.ts';

export interface DownloadedRepo {
  /** Its name, without your login. */
  name: string;
  /** Its release assets' downloads, all time. */
  downloads: number;
  /** Other people's public repos that use it in a workflow, when it's an action. */
  users: number;
  /** Its main language, when known: only for repos you committed to. */
  language: { name: string; color: string | null } | null;
}

export function downloadsData({ snapshot, config, known }: Counted): DownloadedRepo[] {
  const s = config.cards.downloads;
  const hidden = known(s.hide, 'cards.downloads.hide');
  const total = (u: DownloadedRepo) => u.downloads + u.users;
  // Public ones only, whatever the count settings say: the card would put a private repo's name on
  // your profile.
  return snapshot.ownedRepos
    .filter((key) => {
      const r = snapshot.repos[key];
      return r && !r.isPrivate && !hidden.has(key) && (snapshot.downloads[key] || snapshot.actionUsers[key]);
    })
    .map((key): DownloadedRepo => {
      const r = snapshot.repos[key];
      const main = [...r.languages].sort((a, b) => b.size - a.size)[0];
      return {
        name: r.nameWithOwner.split('/')[1],
        downloads: snapshot.downloads[key] ?? 0,
        users: snapshot.actionUsers[key] ?? 0,
        language: main ? { name: main.name, color: main.color } : null,
      };
    })
    .sort((a, b) => total(b) - total(a) || a.name.localeCompare(b.name))
    .slice(0, s.count);
}

