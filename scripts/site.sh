#!/usr/bin/env bash
# Builds the GitHub Pages site into a folder: the page from site/, the README's example cards, and
# setup.sh as released, from the v1 tag, so the short setup URL gives what the raw v1 URL gives.
#   bash scripts/site.sh _site
set -euo pipefail
out="${1:?usage: site.sh <folder>}"
MAJOR="v1"
cd "$(dirname "$0")/.."
case "$out" in "" | . | / | site | examples) echo "site.sh: not building into $out" >&2; exit 2 ;; esac
rm -rf "$out"
mkdir -p "$out"
cp -R site/. "$out/"
cp -R examples "$out/examples"
find "$out/examples" -type f ! -name '*.svg' -delete
git show "$MAJOR:setup.sh" > "$out/setup.sh"
echo "Built $out: $(find "$out" -type f | wc -l | tr -d ' ') files, setup.sh from $MAJOR ($(git rev-parse --short "$MAJOR^{commit}"))"
