# shellcheck shell=bash
# Step: what's counted and the look, written to cool-readme.yml; the about card's text.

# The settings screen: one row per setting; its number cycles the value, Enter continues.
# Values are kept in S_PRIVATE, S_ORGS, S_STYLE, S_COLOR and S_BG: none, dark (the colour's own dark
# panel), or a colour of your own from cool-readme.yml (S_BG_OWN), shown as it is.
ROWS=(private orgs style color background)
row_name() { case "$1" in color) echo colour ;; private) echo "private repos" ;; orgs) echo "org repos" ;; *) echo "$1" ;; esac; }
row_values() {
  case "$1" in
    style) echo "classic oled dotmatrix floating" ;; color) echo "github amber green purple cyan red blue" ;;
    background) echo "none ${S_BG_OWN:+$S_BG_OWN }dark" ;; *) echo "true false" ;;
  esac
}
row_label() { # row_label row value: what the value is called on screen
  case "$1:$2" in
    background:none) echo transparent ;;
    private:true | orgs:true) echo counted ;; private:false | orgs:false) echo "not counted" ;;
    *) echo "$2" ;;
  esac
}
get_row() { case "$1" in style) echo "$S_STYLE" ;; color) echo "$S_COLOR" ;; background) echo "$S_BG" ;; private) echo "$S_PRIVATE" ;; orgs) echo "$S_ORGS" ;; esac; }
set_row() { case "$1" in style) S_STYLE="$2" ;; color) S_COLOR="$2" ;; background) S_BG="$2" ;; private) S_PRIVATE="$2" ;; orgs) S_ORGS="$2" ;; esac; }
panel() { case "$1" in amber) echo 0d0b07 ;; green) echo 070d09 ;; purple) echo 0c0710 ;; cyan) echo 050c0d ;; red) echo 0d0606 ;; blue) echo 05080d ;; *) echo 0d1117 ;; esac; } # panel color: the dark background
bg_value() { case "$S_BG" in dark) panel "$S_COLOR" ;; *) echo "$S_BG" ;; esac; } # what background: says
cycle_row() { # cycle_row row [back]: the next value of a row, or the one before, wrapping around
  local cur v prev="" first="" last="" next="" found=false
  cur="$(get_row "$1")"
  for v in $(row_values "$1"); do
    [ -n "$first" ] || first="$v"
    if $found && [ -z "$next" ]; then next="$v"; fi
    [ "$v" = "$cur" ] && { found=true; [ -n "$last" ] && prev="$last"; }
    last="$v"
  done
  if [ "${2:-}" = back ]; then set_row "$1" "${prev:-$last}"; else set_row "$1" "${next:-$first}"; fi
}
SROW=1   # the row ▸ is on
draw_settings() { paint_frame "$(settings_frame "${1:-}")"; } # draw_settings [done]: the settings screen
settings_frame() { # settings_frame [done]: the settings screen's lines
  local n=1 row v line mark
  for row in "${ROWS[@]}"; do
    line=""
    for v in $(row_values "$row"); do
      if [ "$v" = "$(get_row "$row")" ]; then line="$line  $(paint '1;32' "● $(row_label "$row" "$v")")"
      else line="$line  $(paint 2 "○ $(row_label "$row" "$v")")"
      fi
    done
    mark="  "; [ "${1:-}" != "done" ] && [ "$n" = "$SROW" ] && mark="$(paint 1 '▸') "
    printf '%s%s%s%s\n' "${INDENT%  }" "$mark" "$(printf '%-13s' "$(row_name "$row")")" "$line"
    n=$((n + 1))
  done
  [ "${1:-}" = "done" ] || printf '%s%s\n' "$INDENT" "$(paint 2 "↑↓ to choose, space to change, Enter to continue")"
}
settings_screen() {
  local row n count
  if ! $FANCY; then
    for row in "${ROWS[@]}"; do note "$(printf '%-13s %s' "$(row_name "$row")" "$(row_label "$row" "$(get_row "$row")")")"; done
    return
  fi
  count=${#ROWS[@]}
  quiet_keys on
  FRAME_H=0; draw_settings
  while :; do
    read_key
    [ -n "$KEY" ] || break
    row="${ROWS[SROW - 1]}"
    case "$KEY" in
      UP) [ "$SROW" -gt 1 ] && SROW=$((SROW - 1)) ;;
      DOWN) [ "$SROW" -lt "$count" ] && SROW=$((SROW + 1)) ;;
      ' ' | RIGHT) cycle_row "$row" ;;
      LEFT) cycle_row "$row" back ;;
    esac
    draw_settings
  done
  quiet_keys off
  draw_settings "done" # the settings stay, the hint goes
}

if $CARDS_OFF; then
  # With the cards off the other settings don't matter: they're not asked, and stay as they are
  # for when the cards are back.
  $MOVED && report updated "$CONFIG: moved to the settings layout of v1.5, the same settings"
  if [ ! -f "$CONFIG" ]; then
    printf '# Settings: https://github.com/%s#settings\nuser: %s\nshow: []\n' "$TOOL_REPO" "$LOGIN" > "$CONFIG"
    report added "$CONFIG, with the cards off"
  elif [ "$S_CARDS" != "$cur_cards" ]; then
    cards_set "$CONFIG" ""
    report updated "$CONFIG: cards off"
  else
    report ok "$CONFIG: cards off"
  fi
else
  section "Settings"
  $MOVED && report updated "$CONFIG: moved to the settings layout of v1.5, the same settings"
  if $OLD_KEPT; then
    # Something setup can't move: the file stays as it is (the action still reads it), and only the cards change.
    if [ "$S_CARDS" != "$cur_cards" ]; then cards_set "$CONFIG" "$S_CARDS"; report updated "cards: $(printf '%s' "$S_CARDS" | sed 's/ /, /g')"; fi
    note "$(paint 2 "$CONFIG is in the settings layout from before v1.5, and setup couldn't move it: it still works;")"
    note "$(paint 2 "to change the look, move it by hand: see github.com/$TOOL_REPO#settings")"
  else
  if [ -f "$CONFIG" ]; then
    cur_private="$(yaml_get "$CONFIG" count.private)"; cur_orgs="$(yaml_get "$CONFIG" count.orgs)"
    cur_style="$(yaml_get "$CONFIG" look.style)"; cur_color="$(yaml_get "$CONFIG" look.color)"
    cur_bg="$(yaml_get "$CONFIG" look.background | tr -d "\"'#" | tr 'A-F' 'a-f')"
  else
    cur_private=""; cur_orgs=""; cur_style=""; cur_color=""; cur_bg=""
  fi
  cur_bg="${cur_bg:-none}"
  S_PRIVATE="${cur_private:-true}"; S_ORGS="${cur_orgs:-true}"; S_STYLE="${cur_style:-classic}"; S_COLOR="${cur_color:-github}"
  S_BG_OWN=""
  case "$cur_bg" in
    none) S_BG=none ;;
    "$(panel "$S_COLOR")") S_BG=dark ;;
    *) S_BG="$cur_bg"; S_BG_OWN="$cur_bg" ;;
  esac
  settings_screen

  changes=""
  change() { # change key current new label: write the setting if it changed, and note it
    if [ "$3" != "$2" ]; then
      yaml_set "$CONFIG" "$1" "$3"
      changes="${changes:+$changes, }$4: $(row_label "${1#*.}" "$3")"
    fi
  }
  if [ -f "$CONFIG" ]; then
    change count.private "${cur_private:-true}" "$S_PRIVATE" "private repos"
    change count.orgs "${cur_orgs:-true}" "$S_ORGS" "org repos"
    change look.style "${cur_style:-classic}" "$S_STYLE" style
    change look.color "${cur_color:-github}" "$S_COLOR" colour
    if [ "$(bg_value)" != "$cur_bg" ]; then
      yaml_set "$CONFIG" look.background "$(bg_value)"
      changes="${changes:+$changes, }background: $(row_label background "$S_BG")"
    fi
    if [ "$S_CARDS" != "$cur_cards" ]; then
      cards_set "$CONFIG" "$S_CARDS"
      changes="${changes:+$changes, }cards: $(printf '%s' "$S_CARDS" | sed 's/ /, /g')"
    fi
    if [ -n "$changes" ]; then report updated "$changes"; elif ! $MOVED; then report ok "$CONFIG unchanged"; fi
  else
    {
      echo "# Settings: https://github.com/$TOOL_REPO#settings"
      echo "user: $LOGIN"
      [ "$S_CARDS" = "$DEFAULT_CARDS" ] || echo "show: [$(printf '%s' "$S_CARDS" | sed 's/ /, /g')]"
      echo "count:"
      echo "  private: $S_PRIVATE"
      echo "  orgs: $S_ORGS"
      echo "look:"
      echo "  style: $S_STYLE"
      echo "  color: $S_COLOR"
      echo "  background: $(bg_value)"
    } > "$CONFIG"
    report added "$CONFIG"
  fi
  fi
  # The about card's text is yours to write: an empty section to fill in, the first time it's on.
  if card_on about && $OLD_KEPT && ! grep -q '^about:' "$CONFIG"; then
    {
      echo "about:                  # the about card's text"
      echo "  headline: null        # shown large, e.g. \"Hi, I'm *$LOGIN*\"; *words* in the accent colour"
      echo "  lines: []             # a line each, e.g. [\"I build developer tools.\"]"
      echo "  facts: {}             # label: text, e.g. { Focus: Rust, Based in: Lisbon }"
    } >> "$CONFIG"
    report added "an about: section to $CONFIG; write the about card's text there"
  fi
  note "$(paint 2 "more settings (languages, titles, ...): edit $CONFIG; see github.com/$TOOL_REPO#settings")"

  # A card that's nothing without your settings: the about card is empty until it has your text.
  if card_on about && ! $OLD_KEPT && about_empty "$CONFIG"; then
    section "About card"
    note "it's empty: it shows a headline, lines and facts of your own"
    if $HAVE_TTY && yesno "Write them now?" y; then
      write_about
    elif awk '/^[^[:space:]#]/ { c = ($0 ~ /^cards:/) } c && /^[[:space:]]+about:/ { f = 1 } END { exit !f }' "$CONFIG"; then
      report skipped "write the about card's text under cards: about: in $CONFIG"
    else
      about_set "$CONFIG" "$(about_placeholder)"
      report added "an empty about section under cards: in $CONFIG; write the about card's text there"
    fi
  # With text, it's kept, unless you'd rather type it again: what setup writes is always valid, so
  # this also mends text edited by hand that the action can't read (the error says so).
  elif card_on about && ! $OLD_KEPT && $HAVE_TTY; then
    section "About card"
    note "it has your text; to change it, type it again here or edit $CONFIG"
    if yesno "Keep it?" y; then report kept "the about card's text"; else write_about; fi
  fi
fi
