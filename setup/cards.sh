# shellcheck shell=bash
# Step: which cards, in what order. Clones the profile repo first: the steps from here work in it.

# ------------------------------------------------------------------ settings and workflow

WORK="$(mktemp -d)"
gh repo clone "$PROFILE" "$WORK/repo" -- --quiet --depth 1
cd "$WORK/repo"

# ------------------------------------------------------------------ cards

card_on() { case " $S_CARDS " in *" $1 "*) return 0 ;; esac; return 1; }
known() { # known "card card": the known cards among them, each once, in the order given
  local card out=""
  for card in $1; do
    case " $CARD_NAMES " in *" $card "*) ;; *) continue ;; esac
    case " $out " in *" $card "*) ;; *) out="${out:+$out }$card" ;; esac
  done
  echo "$out"
}
# The cards screen: one row per card, the ones that are on (S_CARDS, in README order) at the top,
# ● in green, the ones that are off (OFF) below them, ○ dim. Up and down move the ▸ (SEL); space
# turns its card off (it goes to the top of the off ones, and the ▸ stays on its row) or on (it
# goes to the bottom of the on ones, and the ▸ goes with it); Shift with up or down moves a card
# that's on among the others.
without() { printf ' %s ' "$1" | sed "s/ $2 / /; s/^ *//; s/ *$//"; } # without "list" card
pos() { # pos "list" card: where the card is in the list, from 0 (its length when it isn't there)
  local a i
  read -ra a <<< "$1"
  for ((i = 0; i < ${#a[@]}; i++)); do [ "${a[$i]}" = "$2" ] && break; done
  echo "$i"
}
move_card() { # move_card up|down: SEL one place up or down among the cards that are on
  local a i j t
  read -ra a <<< "$S_CARDS"
  i="$(pos "$S_CARDS" "$SEL")"
  if [ "$1" = up ]; then j=$((i - 1)); else j=$((i + 1)); fi
  { [ "$i" -lt "${#a[@]}" ] && [ "$j" -ge 0 ] && [ "$j" -lt "${#a[@]}" ]; } || return 0
  t="${a[$i]}"; a[i]="${a[$j]}"; a[j]="$t"
  S_CARDS="${a[*]}"
}
draw_cards() { # draw_cards hint: a row per card, ● on or ○ off, the selected one marked; then the hint if any
  local card mark name
  for card in $S_CARDS $OFF; do
    mark="  "; [ -n "$1" ] && [ "$card" = "$SEL" ] && mark="$(paint 1 '▸') "
    if card_on "$card"; then name="$(paint '1;32' "● $card")"; else name="$(paint 2 "○ $card")"; fi
    printf '%s%s%s\n' "${INDENT%  }" "$mark" "$name"
  done
  [ -z "$1" ] || printf '%s%s\n' "$INDENT" "$(paint 2 "$1")"
}

# Settings from before v1.5 move to the new layout first, so the rest of setup reads and writes that.
MOVED=false; OLD_KEPT=false
if [ -f "$CONFIG" ]; then
  moved=0; migrate_config "$CONFIG" || moved=$?
  case "$moved" in 0) MOVED=true ;; 2) OLD_KEPT=true; LIST=cards ;; esac
fi

section "Cards"
# With every card off ("show: []") the cards are off: out of the README, and the workflow runs
# only when you start it. The marked block stays in the README, so they come back in the same place.
WAS_OFF=false
[ -f "$CONFIG" ] && grep -Eq "^$LIST:[[:space:]]*\[[[:space:]]*\]" "$CONFIG" && WAS_OFF=true
cur_cards="$(known "$(cards_get "$CONFIG")")" # in the order they're listed: the README's
$WAS_OFF || cur_cards="${cur_cards:-$DEFAULT_CARDS}"
S_CARDS="$cur_cards"
OFF=""
for card in $CARD_NAMES; do card_on "$card" || OFF="${OFF:+$OFF }$card"; done
read -r SEL _ <<< "$S_CARDS $OFF" # the first card
cards_hint() {
  if [ -n "$S_CARDS" ]; then echo "↑↓ to choose, space for on/off, shift ↑↓ to move, Enter to continue"
  else echo "all off: out of your README, no schedule; space for on/off, Enter to continue"; fi
}
move_sel() { # move_sel up|down: the ▸ to the row above or below
  local a i
  read -ra a <<< "$S_CARDS $OFF"
  i="$(pos "$S_CARDS $OFF" "$SEL")"
  if [ "$1" = up ] && [ "$i" -gt 0 ]; then SEL="${a[$((i - 1))]}"; fi
  if [ "$1" = down ] && [ "$((i + 1))" -lt "${#a[@]}" ]; then SEL="${a[$((i + 1))]}"; fi
  return 0
}
if $FANCY; then
  quiet_keys on
  FRAME_H=0; paint_frame "$(draw_cards "$(cards_hint)")"
  while :; do
    read_key
    [ -n "$KEY" ] || break
    case "$KEY" in
      UP) move_sel up ;;
      DOWN) move_sel down ;;
      SHIFT_UP) card_on "$SEL" && move_card up ;;
      SHIFT_DOWN) card_on "$SEL" && move_card down ;;
      ' ')
        if card_on "$SEL"; then # the ▸ stays on its row, on the card that takes the place of this one
          row="$(pos "$S_CARDS $OFF" "$SEL")"
          S_CARDS="$(without "$S_CARDS" "$SEL")"; OFF="$SEL${OFF:+ $OFF}"
          read -ra all <<< "$S_CARDS $OFF"; SEL="${all[row]}"
        else OFF="$(without "$OFF" "$SEL")"; S_CARDS="${S_CARDS:+$S_CARDS }$SEL"; fi ;;
    esac
    paint_frame "$(draw_cards "$(cards_hint)")"
  done
  quiet_keys off
  paint_frame "$(draw_cards "")" # the cards stay, the hint and the ▸ go
elif [ -n "$S_CARDS" ]; then
  report ok "cards: $(printf '%s' "$S_CARDS" | sed 's/ /, /g')"
else
  report ok "cards: off"
fi
CARDS_OFF=false
[ -n "$S_CARDS" ] || CARDS_OFF=true
