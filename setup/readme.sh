# shellcheck shell=bash
# Step: the cards in README.md, between the cool-readme markers.

# ------------------------------------------------------------------ README

# Prepared here, before the commit, so every question is answered before the long wait for the
# first run. Until the cards exist the README would show broken images, so on a new setup the
# README is committed by itself once the first run has made them.
section "Update"
# The workflow publishes the cards on their own branch; one kept from before commits them to stats/.
ON_BRANCH=false
grep -q "origin $BRANCH" "$WORKFLOW" && ON_BRANCH=true
if $ON_BRANCH; then
  BASE="https://raw.githubusercontent.com/$PROFILE/$BRANCH"
  git fetch --quiet --depth 1 origin "$BRANCH:refs/remotes/origin/$BRANCH" 2>/dev/null || true
  made() { git cat-file -e "refs/remotes/origin/$BRANCH:$1" 2>/dev/null; } # made file: on the branch?
else
  BASE="$OUT"
  made() { [ -f "$OUT/$1" ]; }
fi
picture() { # picture card width alt
  printf '<picture>\n  <source media="(prefers-color-scheme: dark)" srcset="%s/%s-dark.svg">\n  <img src="%s/%s-light.svg" width="%s" alt="%s">\n</picture>\n' \
    "$BASE" "$1" "$BASE" "$1" "$2" "$3"
}
card_picture() { # card_picture card
  case "$1" in
    summary) picture summary "$WIDTH" "GitHub stats" ;;
    languages) picture languages "$WIDTH" "Most used languages" ;;
    contributions) picture contributions "$WIDTH" "Notable contributions" ;;
    weekly) picture weekly "$WIDTH" "Weekly rhythm" ;;
    streaks) picture streaks "$WIDTH" "Streaks" ;;
    about) picture about "$WIDTH" "About" ;;
    repos) picture repos "$WIDTH" "Top repos" ;;
  esac
}
block="$(mktemp)"
{
  echo "$START"
  echo "<!-- Cards by github-cool-readme: https://github.com/$TOOL_REPO -->" # in the source only, not shown
  n=0
  for card in $S_CARDS; do # two cards per row
    [ $((n % 2)) = 0 ] && echo '<p align="center">'
    card_picture "$card"
    [ $((n % 2)) = 1 ] && echo '</p>'
    n=$((n + 1))
  done
  [ $((n % 2)) = 1 ] && echo '</p>'
  echo "$END"
} > "$block"
shown="the cards"; $CARDS_OFF && shown="no cards (they're off)"
missing_cards=false # a card that's on but not made yet: the README waits for the first run
for card in $S_CARDS; do made "$card-light.svg" || missing_cards=true; done

HAD_README=false
[ -f README.md ] && HAD_README=true
touch README.md
readme_put "$block"
git add -N README.md # so a new README shows in the diff too
# With the cards on their branch, the stats/ folder of before is no longer used once the README
# points at the branch: it goes with the README change.
OLD_STATS=false
$ON_BRANCH && [ -n "$(git ls-files "$OUT")" ] && OLD_STATS=true
README_LATER=false # true: the README change waits for the first run's cards
if git diff --quiet README.md && ! $OLD_STATS; then
  report ok "$shown $where"
elif $CARDS_OFF; then
  if [ "$where" = "between the cool-readme markers" ]; then
    git diff --quiet README.md || report updated "the cards taken out; the markers stay, so they come back in the same place"
  else
    report added "the cool-readme markers $where; the cards go there when you turn them on"
  fi
  if $OLD_STATS; then git rm -r --quiet "$OUT"; report removed "$OUT/: no longer used"; fi
elif ! $missing_cards; then
  git diff --quiet README.md || report updated "the cards $where"
  if $OLD_STATS; then git rm -r --quiet "$OUT"; report removed "$OUT/: the cards are on the $BRANCH branch now"; fi
else
  README_LATER=true
  git --no-pager -c color.ui="$($COLOUR && echo always || echo never)" diff README.md > "$WORK/readme.diff"
  cp README.md "$WORK/README.next"
  git reset --quiet README.md
  if $HAD_README; then git checkout --quiet -- README.md; else rm -f README.md; fi
  report updated "the cards $where"
  if $OLD_STATS; then
    report removed "$OUT/: the cards will be on the $BRANCH branch"
    printf '%s\n' "and $OUT/ is removed ($(git ls-files "$OUT" | wc -l | tr -d ' ') files)" >> "$WORK/readme.diff"
  fi
  note "$(paint 2 'committed by itself once the first run has made the cards')"
fi
if grep -q 'github-readme-stats' README.md "$WORK/README.next" 2>/dev/null; then
  note "$(paint 33 'README.md still has github-readme-stats images; remove them if these cards replace them')"
fi
