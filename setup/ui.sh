# shellcheck shell=bash
# Output and keys: colours, frames, yes/no questions, report and die, cleaning up on exit.

# ------------------------------------------------------------------ output and keys

# Questions are read from the terminal, so this also works when the script comes from a pipe.
# Without a terminal, every question takes its default.
HAVE_TTY=false
if (: < /dev/tty) 2>/dev/null; then HAVE_TTY=true; fi
COLOUR=false
[ -t 1 ] && COLOUR=true
FANCY=false # redraws in place and live timers need both
$HAVE_TTY && $COLOUR && FANCY=true

# The cursor is hidden while the guide runs, shown where you type a line, and always given back:
# on success, on an error, and on Ctrl-C.
cursor() { if $FANCY; then if [ "$1" = on ]; then printf '\033[?25h'; else printf '\033[?25l'; fi; fi; }
WORK=""
# Background jobs (starting and watching the first run) ignore Ctrl-C, so they're stopped here,
# with what they started; the job first, so it doesn't report its child being stopped.
stop_jobs() {
  local job children
  for job in $(jobs -p); do
    children="$(pgrep -P "$job" 2>/dev/null || true)"
    # shellcheck disable=SC2086 # $children is a list of pids, split on purpose
    kill "$job" $children 2>/dev/null || true
    wait "$job" 2>/dev/null || true
  done
}
# On the screens that redraw in place, keys typed while they redraw aren't shown, so a quick Enter
# doesn't add a line and the redraw stays where it is.
TTY_SAVED=""
quiet_keys() { # quiet_keys on|off
  if [ "$1" = on ]; then TTY_SAVED="$(stty -g < /dev/tty)"; stty -echo < /dev/tty
  elif [ -n "$TTY_SAVED" ]; then stty "$TTY_SAVED" < /dev/tty; TTY_SAVED=""
  fi
}
cleanup() {
  stop_jobs; quiet_keys off 2>/dev/null || true; cursor on
  [ -z "$WORK" ] || rm -rf "$WORK"
  [ -z "$SETUP_TMP" ] || rm -rf "$SETUP_TMP" # the steps, when they were downloaded
}
trap cleanup EXIT
trap 'echo; exit 130' INT TERM
cursor off

INDENT="            " # under the status column
paint() { if $COLOUR; then printf '\033[%sm%s\033[0m' "$1" "$2"; else printf '%s' "$2"; fi; }
section() { printf '\n%s\n' "$(paint 1 "$1")"; }
# redraw rows text: draws text over the last rows lines in one write, each line cleared to its end
# and what's left below cleared after it, so the screen never shows the lines empty (no flicker).
redraw() {
  local text="$2"
  text="${text//$'\n'/$'\033[K\n'}"
  printf '\033[%sA\r%s\033[K\n\033[J' "$1" "$text"
}
# frame_height text: the lines text takes on screen, a line longer than the terminal is wide taking
# more than one. Characters are counted as UTF-8 whatever the locale: bytes, less continuation bytes.
frame_height() {
  local w
  w="$(stty size < /dev/tty 2>/dev/null | awk '{ print $2 }')"
  [ "${w:-0}" -gt 0 ] 2>/dev/null || w=80
  printf '%s\n' "$1" | sed "s/$ESC\[[0-9;?]*[A-Za-z]//g" | LC_ALL=C tr -d '\200-\277' \
    | LC_ALL=C awk -v w="$w" '{ n = length($0); h += n ? int((n + w - 1) / w) : 1 } END { print h + 0 }'
}
# paint_frame text: draws text, over the frame drawn before it (FRAME_H lines; 0 for none)
FRAME_H=0
paint_frame() {
  if [ "$FRAME_H" -gt 0 ]; then redraw "$FRAME_H" "$1"; else printf '%s\n' "$1"; fi
  FRAME_H="$(frame_height "$1")"
}
note() { printf '%s%s\n' "$INDENT" "$*"; }
# The spinner's frames are setup.sh's; a setup.sh from before them (GitHub's cache can serve one for a
# few minutes after a release) gets a plain one.
[ -n "${SPINNER[*]:-}" ] || SPINNER=('-' "\\" '|' '/')
spinner_frame() { paint 36 "${SPINNER[$(($1 % ${#SPINNER[@]}))]}"; } # spinner_frame n: frame n, wrapping
report() { # report status text: green for done, yellow for skipped, red for what needs you
  local status
  status="$(printf '%-9s' "$1")"
  case "$1" in
    ok | added | set | updated | created | stored | started | generated | pushed | removed | starred) status="$(paint 32 "$status")" ;;
    skipped | kept | "dry run") status="$(paint 33 "$status")" ;;
    missing | failed | old | differs) status="$(paint 31 "$status")" ;;
  esac
  printf '  %s %s\n' "$status" "$2"
}
framed() { # framed colour line...: the lines in a box
  local tone="$1" text width=0 line
  shift
  for text in "$@"; do [ "${#text}" -gt "$width" ] && width="${#text}"; done
  line="$(printf '%*s' $((width + 2)) '' | sed 's/ /─/g')"
  echo
  paint "$tone" "┌${line}┐"; echo
  for text in "$@"; do paint "$tone" "$(printf '│ %-*s │' "$width" "$text")"; echo; done
  paint "$tone" "└${line}┘"; echo
}
die() { # die what [what to do]: a red line, a hint, and stop
  report failed "$1"
  [ -z "${2:-}" ] || note "$2"
  framed 31 "Stopped: nothing after this step was changed."
  exit 1
}

ESC="$(printf '\033')"
quit() { # Esc: stop here
  echo
  framed 33 "Stopped: nothing after this step was changed."
  exit 1
}
read_key() { # read_key: one key into KEY, "" for Enter, " " for space, UP DOWN LEFT RIGHT for the arrows,
             # SHIFT_UP SHIFT_DOWN with Shift (or Alt). Esc quits;
             # other keys like them (F1, Home, ...) are ignored.
  local saved rest c n
  while :; do
    IFS= read -rsn1 KEY < /dev/tty || { KEY=""; return 0; }
    [ "$KEY" = "$ESC" ] || return 0
    # A key like an arrow sends Esc and more right after it; a lone Esc is the Esc key. The rest is
    # read a byte at a time up to its last one, so keys typed right after it aren't lost.
    saved="$(stty -g < /dev/tty)"
    stty -icanon -echo min 0 time 1 < /dev/tty # wait at most a tenth of a second
    rest="$(dd bs=1 count=1 2>/dev/null < /dev/tty)"
    case "$rest" in
      '[' | O)
        for n in 1 2 3 4 5 6; do # Esc [ 1 ; 5 C and the like: ends on a letter or ~
          c="$(dd bs=1 count=1 2>/dev/null < /dev/tty)"
          rest="$rest$c"
          case "$c" in '' | [A-Za-z~]) break ;; esac
        done ;;
    esac
    stty "$saved" < /dev/tty
    [ -n "$rest" ] || quit
    case "$rest" in
      '[A' | 'OA') KEY=UP; return 0 ;;
      '[B' | 'OB') KEY=DOWN; return 0 ;;
      '[D' | 'OD') KEY=LEFT; return 0 ;;
      '[C' | 'OC') KEY=RIGHT; return 0 ;;
      '[1;2A' | '[1;3A' | '[1;4A') KEY=SHIFT_UP; return 0 ;;
      '[1;2B' | '[1;3B' | '[1;4B') KEY=SHIFT_DOWN; return 0 ;;
    esac
  done
}

choice() { # choice value chosen: the value with its dot, ● in green if it's the chosen one, ○ dim if not
  if [ "$1" = "$2" ]; then paint '1;32' "● $1"; else paint 2 "○ $1"; fi
}
draw_yesno() { # draw_yesno answer hint: yes and no, the answer marked, then the hint if any
  printf '%s%s  %s\n' "$INDENT" "$(choice yes "$1")" "$(choice no "$1")"
  [ -z "$2" ] || printf '%s%s\n' "$INDENT" "$(paint 2 "$2")"
}
# yesno "Question" default(y|n) [d]: returns 0 yes, 1 no, 2 show the diff (with d). With the full
# screen it's a choice like the other screens; otherwise one key, y or n, no Enter.
yesno() {
  local question="$1" def="$2" hint answer
  if [ "$def" = y ]; then hint="Y/n"; else hint="y/N"; fi
  [ -z "${3:-}" ] || hint="$hint, d: show the changes"
  if ! $HAVE_TTY; then
    answer=no; [ "$def" = y ] && answer=yes
    printf '%s%s  [%s]  %s\n' "$INDENT" "$question" "$hint" "$(paint 2 "$answer (no terminal)")"
    [ "$def" = y ]
    return
  fi
  if $FANCY; then # like the other screens: the question, then yes and no; space switches, Enter continues
    printf '%s%s\n' "$INDENT" "$question"
    answer=no; [ "$def" = y ] && answer=yes
    hint="space to change, Enter to continue"
    [ -z "${3:-}" ] || hint="space to change, d to show the changes, Enter to continue"
    quiet_keys on
    FRAME_H=0; paint_frame "$(draw_yesno "$answer" "$hint")"
    while :; do
      read_key
      case "$KEY" in
        '') break ;;
        ' ') if [ "$answer" = yes ]; then answer=no; else answer=yes; fi ;;
        LEFT) answer=yes ;;
        RIGHT) answer=no ;;
        d | D) [ -n "${3:-}" ] && { answer="diff"; break; } ;;
      esac
      paint_frame "$(draw_yesno "$answer" "$hint")"
    done
    quiet_keys off
    if [ "$answer" = diff ]; then printf '\033[%sA\r\033[J' "$FRAME_H" # for the diff, the choice and the hint go
    else paint_frame "$(draw_yesno "$answer" "")"; fi # the choice stays, the hint goes
    case "$answer" in yes) return 0 ;; no) return 1 ;; *) return 2 ;; esac
  fi
  printf '%s%s  %s  ' "$INDENT" "$question" "$(paint 2 "[$hint]")"
  while :; do
    read_key
    case "$KEY" in
      y | Y) answer=yes; break ;;
      n | N) answer=no; break ;;
      '') answer=no; [ "$def" = y ] && answer=yes; break ;;
      d | D) [ -n "${3:-}" ] && { answer="diff"; break; } ;;
    esac
  done
  if [ "$answer" = diff ]; then echo; else paint 1 "$answer"; echo; fi
  case "$answer" in yes) return 0 ;; no) return 1 ;; *) return 2 ;; esac
}

run() { # run a command that changes something, or just say so in a dry run
  if $DRY_RUN; then report "dry run" "would run: $*"; else "$@"; fi
}
