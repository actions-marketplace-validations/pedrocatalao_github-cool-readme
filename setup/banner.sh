# shellcheck shell=bash
# The title, and the star.

# ------------------------------------------------------------------ banner

# A star sits beside the title. If you haven't starred the repo, it's lit and space turns it off and on;
# setup goes on by itself after a few seconds, or on Enter, and stars the repo if the star is still
# lit. The star needs a terminal wide enough for the whole title (44 columns), as it's put in place
# with the cursor.
TITLE_ART=( # COOL, 26 wide and 6 rows, the star to its right; under it README, 42 wide and 5 rows: 42 wide in all
  $'\033[0;37m▄\033[0;90;47m▒▒▒▒▒\033[0;37m \033[0;90m▄\033[0;90;47m▒▒▒▒\033[0;90m▄\033[0;37m \033[0;90m▄\033[0;90;47m▒▒▒▒\033[0;90m▄\033[0;37m \033[0;90;47m▒▒\033[0;37m   \033[0m'
  $'\033[0;90;47m▓▓\033[0;37m  \033[0;90;47m▓▓\033[0;37m \033[0;90;47m▓▓\033[0;37m  \033[0;90;47m▓▓\033[0;37m \033[0;90;47m▓▓\033[0;37m  \033[0;90;47m▓▓\033[0;37m \033[0;90;47m▓▓\033[0;37m   \033[0m'
  $'\033[0;90m▀▀\033[0;37m     \033[0;90m▀▀\033[0;37m \033[0;30m┘\033[0;90m▀▀\033[0;37m \033[0;90m▀▀\033[0;37m \033[0;30m┘\033[0;90m▀▀\033[0;37m \033[0;90m▀▀\033[0;30m┘┘┘\033[0m'
  $'\033[0;97;47m▓▓\033[0;37m     \033[0;97;47m▓▓\033[0;37m  \033[0;97;47m▓▓\033[0;37m \033[0;97;47m▓▓\033[0;37m  \033[0;97;47m▓▓\033[0;37m \033[0;97;47m▓▓\033[0;37m   \033[0m'
  $'\033[0;97;47m▒▒\033[0;37m  \033[0;97;47m▒▒\033[0;37m \033[0;97;47m▒▒\033[0;37m  \033[0;97;47m▒▒\033[0;37m \033[0;97;47m▒▒\033[0;37m  \033[0;97;47m▒▒\033[0;37m \033[0;97;47m▒▒\033[0;37m   \033[0m'
  $'\033[0;97m▀\033[0;97;47m░░░░░\033[0;37m \033[0;97m▀\033[0;97;47m░░░░\033[0;97m▀\033[0;37m \033[0;97m▀\033[0;97;47m░░░░\033[0;97m▀\033[0;37m \033[0;97;47m░░░░░\033[0m'
  $'\033[0;97m▄▄▄▄▄▄\033[0;37m \033[0;97m▄▄▄▄▄▄\033[0;37m \033[0;97m▄▄▄▄▄▄\033[0;37m \033[0;97m▄▄▄▄▄\033[0;37m  \033[0;97m▄▄▄▄\033[0;37m \033[0;97m▄▄\033[0;37m \033[0;97m▄▄▄▄▄▄\033[0m'
  $'\033[0;37m▄▄▄  \033[0;97m█\033[0;37m ▄▄▄  \033[0;97m▀\033[0;37m ▄▄▄  \033[0;97m█\033[0;37m ▄▄▄  \033[0;97m█\033[0;37m ▄▄▄ \033[0;97m█\033[0;37m \033[0;97m█\033[0;37m ▄▄▄  \033[0;97m▀\033[0m'
  $'\033[0;97;47m░░▒\033[0;97m▄▄▀\033[0;37m \033[0;97;47m░░▒\033[0;97m▄\033[0;37m   \033[0;97;47m░░▒\033[0;97m▄▄█\033[0;37m \033[0;97;47m░░▒\033[0;37m  \033[0;97m█\033[0;37m \033[0;97;47m░░▒\033[0;37m \033[0;97m█\033[0;37m \033[0;97m█\033[0;37m \033[0;97;47m░░▒\033[0;97m▄\033[0;37m  \033[0m'
  $'\033[0;97;47m▒▒▓\033[0;37m  \033[0;97m█\033[0;37m \033[0;97;47m▒▒▓\033[0;37m    \033[0;97;47m▒▒▓\033[0;37m  \033[0;97m█\033[0;37m \033[0;97;47m▒▒▓\033[0;37m  \033[0;97m█\033[0;37m \033[0;97;47m▒▒▓\033[0;37m \033[0;97m█\033[0;37m \033[0;97m█\033[0;37m \033[0;97;47m▒▒▓\033[0;37m   \033[0m'
  $'\033[0;97;47m▓▓\033[0;97m█\033[0;37m  \033[0;97m█\033[0;37m \033[0;97;47m▓▓█\033[0;97m▄▄█\033[0;37m \033[0;97;47m▓▓\033[0;97m█\033[0;37m  \033[0;97m█\033[0;37m \033[0;97;47m▓▓\033[0;97m█▄▄▀\033[0;37m \033[0;97;47m▓▓\033[0;97m█\033[0;37m   \033[0;97m█\033[0;37m \033[0;97;47m▓▓█\033[0;97m▄▄█\033[0m'
)
STAR_ART=( # 7 wide, 3 rows
  '  ▗█▖  '
  '▀█████▀'
  ' ▟▀ ▀▙ '
)
TAGLINE="animated cards for your GitHub profile README"
cols=0
$HAVE_TTY && cols="$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')"

# The star shows with the full screen, wide enough for the big title it sits beside; it asks when
# GitHub says you haven't starred the repo. That's asked in the background: the title shows, its star
# lit, without waiting for the answer.
SHOW_STAR=false; ASK_STAR=false; STAR_PID=""; STAR_ANSWER=""
$FANCY && [ "${cols:-0}" -ge 44 ] && SHOW_STAR=true
if $SHOW_STAR && command -v gh >/dev/null; then
  STAR_ANSWER="$(mktemp)"
  ( star_err="$(gh api "user/starred/$TOOL_REPO" --silent 2>&1 >/dev/null)" \
    || case "$star_err" in *"HTTP 404"*) echo ask > "$STAR_ANSWER" ;; esac ) &
  STAR_PID=$!
fi

TITLE=()
for line in "${TITLE_ART[@]}"; do
  $COLOUR || line="$(printf '%s' "$line" | sed "s/$ESC\[[0-9;]*m//g")"
  TITLE+=("$line")
done
STAR_TOP=1  # centred in the space right of COOL, up to README's right edge
STAR_COL=34

STAR=on
draw_banner() { # draw_banner ask|done: the title with the star beside it; with ask, what the star does
  local i s tone=2
  [ "$STAR" = on ] && tone='1;33'
  for i in "${!TITLE[@]}"; do
    s=$((i - STAR_TOP))
    if [ "$s" -ge 0 ] && [ "$s" -lt "${#STAR_ART[@]}" ]; then printf '  %s\033[%dG%s\033[K\n' "${TITLE[$i]}" "$STAR_COL" "$(paint "$tone" "${STAR_ART[$s]}")"
    else printf '  %s\033[K\n' "${TITLE[$i]}"; fi
  done
  printf '  %s\033[K\n' "$(paint 2 "$TAGLINE")"
  if [ "$1" = ask ]; then
    if [ "$STAR" = on ]; then printf '  %s' "$(paint 33 "star the repo to support the author")"
    else printf '  %s' "$(paint 2 "star the repo to support the author")"; fi
    printf '%s\033[K\n' "$(paint 2 ", space to change")"
  fi
}

echo
if $SHOW_STAR; then
  frame="$(draw_banner "done")"
  printf '%s\n' "$frame"
  if [ -n "$STAR_PID" ]; then
    wait "$STAR_PID" 2>/dev/null || true
    if [ -s "$STAR_ANSWER" ]; then ASK_STAR=true; fi
    rm -f "$STAR_ANSWER"
  fi
  # Not starred: the title again, over itself, now with the question.
  if $ASK_STAR; then printf '\033[%dA' "$(frame_height "$frame")"; fi
fi
if $ASK_STAR; then
  enter_hint="$(paint 2 'Enter to continue')"
  frame="$(draw_banner ask)"
  printf '%s\n' "$frame"
  UP="$(frame_height "$frame")" # the banner's rows above the countdown line, wrapped ones too
  doing="setting up github-cool-readme..."
  [ "$(stty size < /dev/tty 2>/dev/null | awk '{ print $2 }')" -ge 60 ] 2>/dev/null || doing="setting up..." # one line
  quiet_keys on
  stty -icanon min 0 time 1 < /dev/tty # a key, or nothing after a tenth of a second
  ticks=40 i=0                         # 4 seconds
  while [ "$ticks" -gt 0 ]; do
    printf '\r  %s %s %d   %s\033[K' \
      "$(spinner_frame "$i")" "$doing" $(((ticks + 9) / 10)) "$enter_hint"
    i=$((i + 1))
    k="$(dd bs=16 count=1 2>/dev/null < /dev/tty; echo .)"
    k="${k%.}"
    case "$k" in
      '') ticks=$((ticks - 1)) ;;
      "$ESC") quit ;;
      ' '*)
        if [ "$STAR" = on ]; then STAR=off; else STAR=on; fi
        frame="$(draw_banner ask)" # its lines clear to their end; the countdown line below stays
        printf '\r\033[%dA%s\n' "$UP" "$frame" ;;
    esac
    case "$k" in *$'\n'* | *$'\r'*) break ;; esac
  done
  quiet_keys off
  printf '\r\033[%dA' "$UP" # the title and the star as you left it, without the key and the countdown
  draw_banner "done"
  printf '\033[J'
  if [ "$STAR" = on ]; then
    if $DRY_RUN; then report "dry run" "would star $TOOL_REPO"
    elif gh api -X PUT "user/starred/$TOOL_REPO" --silent >/dev/null 2>&1; then report starred "$TOOL_REPO, thank you"
    else report failed "starring $TOOL_REPO; you can star it at https://github.com/$TOOL_REPO"
    fi
  fi
elif $SHOW_STAR; then
  : # starred already: the title is up, its star lit, and there's nothing to ask
else
  for line in "${TITLE[@]}"; do printf '  %s\n' "$line"; done
  printf '  %s\n' "$(paint 2 "$TAGLINE")"
fi
echo
