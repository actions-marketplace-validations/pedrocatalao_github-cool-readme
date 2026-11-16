#!/usr/bin/env bash
# Wires github-cool-readme into your profile repo (<you>/<you>): token secret, workflow, settings,
# first run, README. Run it again to change settings; it asks before changing anything.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/pedrocatalao/github-cool-readme/v1/setup.sh)
#
# Options: --dry-run  show what would happen, change nothing
# Needs: gh (logged in) and git. Works with the bash that ships with macOS.
#
# This file only gets the steps, in setup/, and runs them in the order below. Run from a clone
# (bash setup.sh), they're the ones next to it. Otherwise they're downloaded from v1, the newest v1
# release (COOL_README_SETUP_REF: a branch, tag or commit instead): the first three, all the title
# needs, while a spinner shows; then the rest, while the title shows.

set -euo pipefail

DRY_RUN=false
NO_COMMIT=false # for trying setup out: everything up to the commit, then no commit, push or run
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --no-commit) NO_COMMIT=true ;;
    -h|--help) echo "Usage: setup.sh [--dry-run | --no-commit]  (sets up README cards in your profile repo)"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

# The steps, in the order they run: setup/<name>.sh. The first SETUP_FIRST are all the title needs.
SETUP_BLOCKS=(
  config    # names and defaults every step uses
  ui        # output and keys: colours, frames, yes/no questions, report and die, cleaning up
  banner    # the title, and the star
  edit      # changing your files: cool-readme.yml and README.md
  migrate   # settings from before v1.5, moved to the new layout
  about     # asking for the about card's text
  checks    # gh logged in, git able to push a workflow
  repo      # Profile repo
  token     # Token
  cards     # Cards
  settings  # Settings, and the about card's text
  workflow  # Workflow
  readme    # the cards in README.md
  commit    # commit and push, after asking
  run       # the first run, and what to do next
)

SETUP_FIRST=3

# The spinner's frames: the one below, and the steps' (the star's countdown, the first run's wait).
SPINNER=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

SETUP_REPO="pedrocatalao/github-cool-readme"
SETUP_MAJOR="v1" # the releases this setup takes its steps from: v1 is always the newest
SETUP_TMP=""     # where the steps were downloaded to, removed at the end

setup_fail() { # setup_fail what [what to do]: before the steps are loaded, so plain
  printf '  failed    %s\n' "$1" >&2
  [ -z "${2:-}" ] || printf '            %s\n' "$2" >&2
  exit 1
}

here="${BASH_SOURCE[0]:-}"
if [ -f "$here" ] && [ -f "$(dirname "$here")/setup/${SETUP_BLOCKS[0]}.sh" ]; then
  SETUP_DIR="$(cd "$(dirname "$here")" && pwd)/setup" # the steps are run from the profile repo, so a full path
else
  command -v curl >/dev/null || setup_fail "curl is not installed"
  SETUP_REF="${COOL_README_SETUP_REF:-$SETUP_MAJOR}"
  SETUP_TMP="$(mktemp -d)"
  trap 'rm -rf "$SETUP_TMP"' EXIT # until the steps' own clean-up takes over
  SETUP_DIR="$SETUP_TMP"
  setup_job() { eval "SETUP_PID_$1=$!"; } # setup_job name: the background job just started is name's
  setup_get() { # setup_get name: downloads setup/<name>.sh at SETUP_REF, in the background
    { curl -fsSL --retry 2 "https://raw.githubusercontent.com/$SETUP_REPO/$SETUP_REF/setup/$1.sh" -o "$SETUP_DIR/$1.part" \
      && mv "$SETUP_DIR/$1.part" "$SETUP_DIR/$1.sh"; } 2>/dev/null &
    setup_job "$1"
  }
  setup_busy() { # setup_busy name: its download is still going
    local pid
    eval "pid=\${SETUP_PID_$1:-}"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
  }
  setup_wait() { # setup_wait name: waits for its download, and stops setup if it failed
    while setup_busy "$1"; do sleep 0.05; done
    [ -f "$SETUP_DIR/$1.sh" ] || setup_fail "could not download setup/$1.sh of $SETUP_REPO $SETUP_REF" "check your connection and try again"
  }

  # Something to see at once: a spinner until the title's steps are in.
  for setup_block in "${SETUP_BLOCKS[@]:0:SETUP_FIRST}"; do setup_get "$setup_block"; done
  setup_i=0
  while :; do
    setup_more=false
    for setup_block in "${SETUP_BLOCKS[@]:0:SETUP_FIRST}"; do setup_busy "$setup_block" && setup_more=true; done
    $setup_more || break
    [ -t 1 ] && printf '\r  \033[36m%s\033[0m setting up github-cool-readme...' "${SPINNER[$((setup_i % ${#SPINNER[@]}))]}"
    setup_i=$((setup_i + 1))
    sleep 0.1
  done
  [ -t 1 ] && printf '\r\033[K'
  for setup_block in "${SETUP_BLOCKS[@]:0:SETUP_FIRST}"; do setup_wait "$setup_block"; done

  # The rest, while the title shows; and which release v1 is, for the checks to say.
  for setup_block in "${SETUP_BLOCKS[@]:SETUP_FIRST}"; do setup_get "$setup_block"; done
  if [ -z "${COOL_README_SETUP_REF:-}" ] && command -v gh >/dev/null; then
    { gh api "repos/$SETUP_REPO/releases" --jq "[.[] | select(.draft or .prerelease | not) \
        | select(.tag_name | startswith(\"$SETUP_MAJOR.\"))][0].tag_name // empty" > "$SETUP_DIR/release" 2>/dev/null || true; } &
    setup_job release
  fi
fi

setup_from() { # where the steps came from, for the checks to say
  local release=""
  if [ -z "$SETUP_TMP" ]; then echo "setup from this clone: $SETUP_DIR"
  elif [ -n "${COOL_README_SETUP_REF:-}" ]; then echo "setup from $SETUP_REF (COOL_README_SETUP_REF): its steps downloaded"
  else
    while setup_busy release; do sleep 0.05; done
    release="$(cat "$SETUP_DIR/release" 2>/dev/null || true)"
    echo "setup ${release:-$SETUP_MAJOR}, the latest release: its steps downloaded"
  fi
}

# Each step runs in this shell, so what one asks (the cards, the settings) the next one uses.
for setup_block in "${SETUP_BLOCKS[@]}"; do
  [ -z "$SETUP_TMP" ] || setup_wait "$setup_block"
  # shellcheck source=/dev/null
  . "$SETUP_DIR/$setup_block.sh"
done
