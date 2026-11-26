#!/usr/bin/env bash
# Releases a version: the GitHub release vX.Y.Z of what's on main, then v1 moved to it, then the
# project page rebuilt, for setup.sh. In that order: setup downloads its steps from v1 and names the
# newest v1 release, and the action runs v1.
#
#   npm run release -- 1.6.4 notes.md "what's in it, in a line"
#   npm run release -- --dry-run 1.6.4 notes.md "..."     # checks, and says what it would do
#
# notes.md is the release notes (see the earlier releases). The line is the tag's message. It
# checks first: main, the same as on GitHub, CI passed on it, a version newer than the last. Then it
# asks, and at the end checks that setup picks the new release.
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="pedrocatalao/github-cool-readme"
MAJOR="v1"

DRY_RUN=false
args=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) args+=("$arg") ;;
  esac
done
if [ "${#args[@]}" -ne 3 ]; then
  echo 'Usage: npm run release -- [--dry-run] <version> <notes.md> "<what is in it, in a line>"' >&2
  exit 2
fi
version="${args[0]#v}"; notes="${args[1]}"; summary="${args[2]}"
tag="v$version"

fail() { printf 'release: %s\n' "$1" >&2; exit 1; }
ok() { printf '  ok  %s\n' "$1"; }

# ------------------------------------------------------------------ checks

[[ "$version" =~ ^${MAJOR#v}\.[0-9]+\.[0-9]+$ ]] || fail "$version is not a $MAJOR version like ${MAJOR#v}.6.4"
[ -f "$notes" ] || fail "no notes file: $notes"
grep -q '[^[:space:]]' "$notes" || fail "the notes in $notes are empty" # blank lines and spaces count as empty
[ -n "$summary" ] || fail "the line for the tag is empty"
gh auth status >/dev/null 2>&1 || fail "gh is not logged in: gh auth login"

[ "$(git branch --show-current)" = main ] || fail "not on main"
[ -z "$(git status --porcelain --untracked-files=no)" ] || fail "main has uncommitted changes"
git fetch --quiet --tags --force origin
sha="$(git rev-parse HEAD)"
[ "$sha" = "$(git rev-parse origin/main)" ] || fail "main differs from GitHub's: pull or push first"
ok "main at ${sha:0:7}, the same as on GitHub"

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then fail "$tag exists already"; fi
last="$(gh api "repos/$REPO/releases" --jq "[.[] | select(.draft or .prerelease | not) \
  | select(.tag_name | startswith(\"$MAJOR.\"))][0].tag_name // empty")"
newer() { # newer a b: version a after version b
  local IFS=. a b i
  read -ra a <<< "$1"; read -ra b <<< "$2"
  for i in 0 1 2; do
    [ "${a[i]}" -gt "${b[i]}" ] && return 0
    [ "${a[i]}" -lt "${b[i]}" ] && return 1
  done
  return 1
}
[ -z "$last" ] || newer "$version" "${last#v}" || fail "$tag is not after the last release, $last"
[ -z "$last" ] || [ "$(git rev-parse "$last^{commit}")" != "$sha" ] || fail "nothing on main since $last"
ok "$tag, after ${last:-no release yet}"

checks="$(gh api "repos/$REPO/commits/$sha/check-runs" --jq '.check_runs[] | "\(.status) \(.conclusion) \(.name)"')"
[ -n "$checks" ] || fail "CI hasn't run on ${sha:0:7} yet: try again once it has"
if printf '%s\n' "$checks" | grep -qv '^completed success '; then
  printf '%s\n' "$checks" | grep -v '^completed success ' | sed 's/^/      /' >&2
  fail "CI hasn't passed on ${sha:0:7}"
fi
ok "CI passed on ${sha:0:7}"

# ------------------------------------------------------------------ release

echo
echo "  tag      $tag: $summary"
echo "  release  $tag, notes from $notes:"
sed 's/^/           | /' "$notes"
echo "  move     $MAJOR to $tag (was ${last:-nothing})"
echo "  rebuild  the project page, from main, for $tag's setup.sh"
echo
if $DRY_RUN; then echo "Dry run: nothing changed."; exit 0; fi
printf 'Release %s? [y/N] ' "$tag"
read -r answer
case "$answer" in y | Y | yes) ;; *) echo "Nothing changed."; exit 1 ;; esac

git tag -a "$tag" -m "$tag: $summary" "$sha"
git push --quiet origin "$tag"
ok "tag $tag pushed"
gh release create "$tag" --verify-tag --latest --title "$tag" --notes-file "$notes" >/dev/null
ok "release $tag published"
# Only now: so v1, where setup downloads its steps from, is always a published release.
git tag -fa "$MAJOR" -m "$MAJOR: latest ${MAJOR#v}.x ($tag)" "$sha" >/dev/null
git push --quiet --force origin "$MAJOR"
ok "$MAJOR moved to $tag"
# The project page serves setup.sh from v1: built again, from main, the only branch that may deploy it.
gh workflow run pages.yml --repo "$REPO" --ref main
ok "project page rebuilding with $tag's setup.sh"

# ------------------------------------------------------------------ after

[ "$(git ls-remote origin "refs/tags/$MAJOR^{}" | cut -f1)" = "$sha" ] || fail "$MAJOR on GitHub isn't at ${sha:0:7}"
picked="$(gh api "repos/$REPO/releases" --jq "[.[] | select(.draft or .prerelease | not) \
  | select(.tag_name | startswith(\"$MAJOR.\"))][0].tag_name // empty")"
[ "$picked" = "$tag" ] || fail "setup would pick $picked, not $tag"
ok "setup picks $tag"
echo
echo "Released: https://github.com/$REPO/releases/tag/$tag"
