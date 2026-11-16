#!/usr/bin/env bash
# shellcheck on setup: setup.sh and its steps, joined in the order setup.sh runs them, as bash
# sees them (one shell, so what one step sets the next one uses). Each finding is reported at its
# line in its own file. Exits 1 when there's any.
set -euo pipefail
cd "$(dirname "$0")/.."

# SETUP_BLOCKS, as setup.sh defines it.
eval "$(sed -n '/^SETUP_BLOCKS=(/,/^)/p' setup.sh)"
files=(setup.sh)
for block in "${SETUP_BLOCKS[@]}"; do files+=("setup/$block.sh"); done

joined="$(mktemp)"; map="$(mktemp)"
trap 'rm -f "$joined" "$map"' EXIT
for f in "${files[@]}"; do
  printf '%s %s\n' "$(($(wc -l < "$joined") + 1))" "$f" >> "$map" # where each file starts in the joined one
  cat "$f" >> "$joined"
done

# gcc format: "-:line:column: level: message [SCcode]"
if out="$(shellcheck -s bash -f gcc - < "$joined")"; then
  echo "shellcheck: no findings in ${#files[@]} files"
  exit 0
fi
printf '%s\n' "$out" | awk -v map="$map" '
  BEGIN { while ((getline l < map) > 0) { n++; split(l, p, " "); start[n] = p[1]; file[n] = p[2] } }
  {
    split($0, p, ":"); line = p[2]
    for (i = n; i > 1 && start[i] > line; i--) ;
    sub(/^-:[0-9]+:/, file[i] ":" (line - start[i] + 1) ":"); print
  }'
exit 1
