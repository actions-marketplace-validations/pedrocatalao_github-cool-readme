# shellcheck shell=bash
# The about card's text: asking for it, to write under cards: about:.

# ------------------------------------------------------------------ the about card's text

about_placeholder() {
  echo "    headline: null        # shown large, e.g. \"Hi, I'm *$LOGIN*\"; *words* in the accent colour"
  echo "    lines: []             # a line each, e.g. [\"I build developer tools.\"]"
  echo "    facts: {}             # label: text, e.g. { Focus: Rust, Based in: Lisbon }"
}
quoted() { local s="$1"; s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; printf '"%s"' "$s"; } # as a YAML string
trimmed() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }
ask_text() { # ask_text prompt: a line you type, into ANSWER
  cursor on
  printf '%s%s ' "$INDENT" "$1"
  IFS= read -r ANSWER < /dev/tty || ANSWER=""
  cursor off
  ANSWER="$(trimmed "$ANSWER")"
}
write_about() { # asks for the headline, lines and facts, and writes them under cards: about:
  local name hello headline block="" n label text
  name="$(gh api user --jq '.name // empty' 2>/dev/null || true)"
  name="${name%% *}"; name="${name:-$LOGIN}"
  hello="Hi, I'm *$name*"
  note "$(paint 2 "words between asterisks, like *$name*, are in the accent colour")"
  ask_text "headline, shown large $(paint 2 "[$hello; - for none]"):"
  headline="${ANSWER:-$hello}"
  [ "$headline" = "-" ] || block="    headline: $(quoted "$headline")"
  note "$(paint 2 "lines, one at a time; Enter on an empty one when done")"
  n=1
  while :; do
    ask_text "line $n:"
    [ -n "$ANSWER" ] || break
    [ "$n" = 1 ] && block="${block:+$block$'\n'}    lines:"
    block="$block"$'\n'"      - $(quoted "$ANSWER")"
    n=$((n + 1))
  done
  note "$(paint 2 "facts, as label: text (Based in: Lisbon); Enter on an empty one when done")"
  n=1
  while :; do
    ask_text "fact $n:"
    [ -n "$ANSWER" ] || break
    case "$ANSWER" in
      *:*) label="$(trimmed "${ANSWER%%:*}")"; text="$(trimmed "${ANSWER#*:}")" ;;
      *) label=""; text="" ;;
    esac
    if [ -z "$label" ] || [ -z "$text" ]; then note "$(paint 33 "write it as label: text, like Based in: Lisbon")"; continue; fi
    [ "$n" = 1 ] && block="${block:+$block$'\n'}    facts:"
    block="$block"$'\n'"      $(quoted "$label"): $(quoted "$text")"
    n=$((n + 1))
  done
  if [ -z "$block" ]; then
    about_set "$CONFIG" "$(about_placeholder)"
    report added "an empty about section under cards: in $CONFIG; write the about card's text there"
  else
    about_set "$CONFIG" "$block"
    report added "the about card's text to $CONFIG"
  fi
}
