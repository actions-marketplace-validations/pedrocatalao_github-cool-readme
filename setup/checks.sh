# shellcheck shell=bash
# gh logged in, git able to push a workflow.

# ------------------------------------------------------------------ prerequisites

$DRY_RUN && note "$(paint 33 'dry run: nothing will be changed')"
$NO_COMMIT && note "$(paint 33 'no commit: nothing will be committed, pushed or run')"
$HAVE_TTY && note "$(paint 2 'Esc quits at any question')"

# A setup.sh from before it said where its steps came from has no SETUP_FROM.
# Where the steps came from: setup.sh says, or, from a setup.sh before setup_from, SETUP_FROM.
if declare -F setup_from >/dev/null; then report ok "$(setup_from)"; elif [ -n "${SETUP_FROM:-}" ]; then report ok "$SETUP_FROM"; fi

command -v gh >/dev/null || die "the GitHub CLI (gh) is not installed" "install it from https://cli.github.com"
command -v git >/dev/null || die "git is not installed"
gh auth status >/dev/null 2>&1 || die "gh is not logged in" "run: gh auth login"
LOGIN="$(gh api user --jq .login)"
PROFILE="$LOGIN/$LOGIN"
report ok "gh, logged in as $LOGIN"

# Pushing a workflow file over HTTPS needs the "workflow" scope; over SSH it doesn't.
PROTOCOL="$(gh config get git_protocol -h github.com 2>/dev/null || echo https)"
if [ "$PROTOCOL" = ssh ]; then
  report ok "git, over SSH"
else
  SCOPES="$(gh api -i user 2>/dev/null | tr -d '\r' | awk -F': ' 'tolower($1)=="x-oauth-scopes"{print $2}')"
  case ", $SCOPES," in
    *", workflow,"*) report ok "git, over HTTPS with the workflow scope" ;;
    *)
      if [ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]; then
        die "gh uses GH_TOKEN/GITHUB_TOKEN, which lacks the \"workflow\" scope needed to add a workflow" \
          "unset it to use your gh login, or use a token with that scope"
      fi
      report missing "the \"workflow\" scope on your gh login, needed to add a workflow over HTTPS"
      yesno "Grant it now? (opens the browser)" y || die "cannot add the workflow without it"
      cursor on; gh auth refresh -h github.com -s workflow; cursor off
      report added "the workflow scope"
      ;;
  esac
fi
