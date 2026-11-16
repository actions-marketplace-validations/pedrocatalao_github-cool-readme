# shellcheck shell=bash
# Step: the workflow, from the template of the version it uses.

section "Workflow"
# The template runs on a schedule and on demand; with the cards off, the schedule comes out.
scheduled="$(mktemp)"; unscheduled="$(mktemp)"
gh api "repos/$TOOL_REPO/contents/examples/profile-workflow.yml?ref=$REF" -H "Accept: application/vnd.github.raw" \
  | sed "s#$TOOL_REPO@[A-Za-z0-9._-]*#$TOOL_REPO@$REF#" > "$scheduled"
awk '/^  schedule:/ { print "  # No schedule: the cards are off. Turn one on with setup to bring it back."; next }
  /^    - cron:/ { next } { print }' "$scheduled" > "$unscheduled"
if $CARDS_OFF; then wanted="$unscheduled" other="$scheduled" runs_when="runs only when you start it, the cards are off"
else wanted="$scheduled" other="$unscheduled" runs_when="runs every 2 hours, and on demand"; fi
mkdir -p "$(dirname "$WORKFLOW")"
NEW_SETUP=false
if [ ! -f "$WORKFLOW" ]; then
  NEW_SETUP=true
  cp "$wanted" "$WORKFLOW"
  report added "$WORKFLOW, on $REF: $runs_when"
elif cmp -s "$wanted" "$WORKFLOW"; then
  report ok "$WORKFLOW, on $REF"
elif cmp -s "$other" "$WORKFLOW"; then # the cards were turned on or off: the schedule follows
  cp "$wanted" "$WORKFLOW"
  report updated "$WORKFLOW: $runs_when"
else
  report differs "$WORKFLOW differs from the template for $REF"
  if yesno "Update it?" y; then cp "$wanted" "$WORKFLOW"; report updated "$WORKFLOW, on $REF"; else report kept "your $WORKFLOW"; fi
fi
