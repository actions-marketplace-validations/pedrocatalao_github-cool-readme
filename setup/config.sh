# shellcheck shell=bash
# Names and defaults every step uses.

TOOL_REPO="pedrocatalao/github-cool-readme"
REF="${COOL_README_REF:-v1}"   # the version of the action the workflow uses
WORKFLOW=".github/workflows/cool-readme.yml"
CONFIG="cool-readme.yml"
OUT="stats"        # where workflows from before the cards branch commit the cards
BRANCH="cards"     # where the workflow publishes them now
SECRET="CARDS_TOKEN"
START="<!-- cool-readme:start -->"
END="<!-- cool-readme:end -->"

CARD_NAMES="summary languages contributions weekly streaks about repos"
DEFAULT_CARDS="summary languages contributions weekly" # on unless cool-readme.yml says otherwise
LIST=show # the key of the list of cards: cards before v1.5, in a file setup couldn't move

# Every card is shown 400 wide, so two fit a row: every card is 450 x 219, scaled.
WIDTH=400
