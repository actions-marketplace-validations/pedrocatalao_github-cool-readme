# shellcheck shell=bash
# Step: commit and push, after asking.

# ------------------------------------------------------------------ commit

commit_and_push() { # commit_and_push "message": asks first; d shows exactly what would be committed
  local answer question
  git add -A
  git diff --cached --quiet && ! $README_LATER && return 1
  if $DRY_RUN; then
    git --no-pager diff --cached --stat | sed "s/^/$INDENT/"
    git --no-pager diff --cached
    $README_LATER && cat "$WORK/readme.diff"
    report "dry run" "would commit \"$1\" and push"
    $README_LATER && report "dry run" "would commit the README once the cards exist"
    return 0
  fi
  if $NO_COMMIT; then
    git --no-pager diff --cached --stat | sed "s/^/$INDENT/"
    report skipped "commit \"$1\" and push (--no-commit)"
    return 0
  fi
  question="Commit \"$1\" and push?"
  if $README_LATER; then
    question="Commit \"$1\" and push, and the README once the cards exist?"
    git diff --cached --quiet && question="Commit the README once the cards exist?"
  fi
  while :; do
    answer=0
    yesno "$question" y d || answer=$?
    [ "$answer" = 2 ] || break
    git --no-pager -c color.ui="$($COLOUR && echo always || echo never)" diff --cached
    $README_LATER && cat "$WORK/readme.diff"
  done
  [ "$answer" = 0 ] || die "nothing was pushed" "run this again when you're ready"
  if ! git diff --cached --quiet; then
    git commit --quiet -m "$1"
    git push --quiet
    report pushed "$1"
  fi
}
# The message names what changed.
git add -A
parts=""
for f in "$WORKFLOW:workflow" "$CONFIG:settings" "README.md:README"; do
  git diff --cached --quiet -- "${f%%:*}" || parts="${parts:+$parts, }${f##*:}"
done
parts="$(printf '%s' "$parts" | sed 's/\(.*\), /\1 and /')"
if $NEW_SETUP; then msg="Add README cards: $parts"; else msg="Update README cards: $parts"; fi
$CARDS_OFF && ! $WAS_OFF && msg="Turn README cards off: $parts"
$WAS_OFF && ! $CARDS_OFF && msg="Turn README cards on: $parts"
if ! git diff --cached --quiet -- "$OUT"; then
  if [ -n "$parts" ]; then msg="$msg; the cards are on the $BRANCH branch now"; else msg="Remove $OUT/: the README cards are on the $BRANCH branch now"; fi
fi
commit_and_push "$msg" || true
