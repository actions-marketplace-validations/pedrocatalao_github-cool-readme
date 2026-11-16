# shellcheck shell=bash
# Step: the first run, and what to do next.

# ------------------------------------------------------------------ first run

if ! $CARDS_OFF; then if $NEW_SETUP; then section "First run"; else section "Run"; fi; fi # with the cards off there is nothing to run
wait_with_timer() { # wait_with_timer pid label: a spinner and the time taken, until pid ends; its exit status
  local pid="$1" start="$SECONDS" i=0 s
  if $FANCY; then
    while kill -0 "$pid" 2>/dev/null; do
      s=$((SECONDS - start))
      printf '\r  %s %s %d:%02d\033[K' "$(spinner_frame "$i")" "$2" $((s / 60)) $((s % 60))
      i=$((i + 1))
      sleep 0.2
    done
    printf '\r\033[K'
  fi
  wait "$pid"
}
if $CARDS_OFF; then
  :
elif $DRY_RUN; then
  report "dry run" "would run the workflow and wait for the cards"
elif $NO_COMMIT; then
  report skipped "the first run (--no-commit)"
else
  wf="$(basename "$WORKFLOW")"
  runs() { gh run list -R "$PROFILE" -w "$wf" -L 20 --json databaseId --jq '.[].databaseId' 2>/dev/null || true; }
  start_run() {
    # GitHub needs a moment to register a new workflow before it can be started; the run, to show up.
    local id
    for _ in 1 2 3 4 5 6; do gh workflow run "$wf" -R "$PROFILE" >/dev/null 2>&1 && break; sleep 5; done
    for _ in $(seq 1 20); do
      sleep 3
      for id in $(runs); do printf '%s\n' "$before" | grep -qx "$id" || { echo "$id" > "$WORK/run"; return 0; }; done
    done
    return 1
  }
  while :; do # again with a new token, if the run fails on the one that's set
    before="$(runs)" # earlier runs, so the one started below can be told apart from them
    start_run & pid=$!
    wait_with_timer "$pid" "starting the workflow" \
      || die "the workflow didn't start" "start it from the Actions tab of $PROFILE"
    run_id="$(cat "$WORK/run")"
    report started "the workflow"
    gh run watch "$run_id" -R "$PROFILE" --exit-status >/dev/null 2>&1 & pid=$!
    wait_with_timer "$pid" "generating the cards, usually 30-60 seconds" && break
    token_rejected "$run_id" || die "the workflow failed" "see: gh run view $run_id -R $PROFILE --log-failed"
    report failed "the workflow couldn't use your token: it expired, was revoked or lacks a scope"
    yesno "Replace it?" y || die "the cards can't be made with that token" "run this again when you have a new one"
    ask_token
  done
  git pull --quiet
  if $ON_BRANCH; then report generated "the cards, on the $BRANCH branch"; else report generated "the cards, in $OUT/"; fi
  if $README_LATER; then
    # Already agreed to above: the cards exist now, so the README can show them.
    cp "$WORK/README.next" README.md
    git add README.md
    later="Show README cards"
    if $OLD_STATS; then git rm -r --quiet "$OUT"; later="Show README cards from the $BRANCH branch, remove $OUT/"; fi
    git commit --quiet -m "$later"
    git push --quiet
    report pushed "$later"
  fi
fi

# ------------------------------------------------------------------ done

if $DRY_RUN; then
  framed 33 "Dry run: nothing was changed."
elif $NO_COMMIT; then
  framed 33 "No commit: nothing was committed, pushed or run."
elif $CARDS_OFF; then
  framed 32 "Done: the cards are off" \
    "They're out of your README, and the workflow runs only when you start it." \
    "To bring them back: run this again and turn a card on."
else
  framed 32 "Done: https://github.com/$LOGIN" \
    "The cards update every 2 hours; run this again to change the settings." \
    "To refresh now: gh workflow run $(basename "$WORKFLOW") -R $PROFILE"
fi
