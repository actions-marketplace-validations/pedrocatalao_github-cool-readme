# shellcheck shell=bash
# Step: the token, stored as a secret.

# ------------------------------------------------------------------ token

ask_token() { # ask_token: a new classic token, checked, then stored as the secret
  local url headers status scopes
  $HAVE_TTY || die "pasting the token needs a terminal" "run this script in one"
  url="https://github.com/settings/tokens/new?scopes=repo,read:org,read:user&description=README%20cards%20($PROFILE)"
  note "Create one here; the scopes are filled in, pick an expiry, then Generate token:"
  note "$(paint 4 "$url")"
  if command -v open >/dev/null; then open "$url"; elif command -v xdg-open >/dev/null; then xdg-open "$url" >/dev/null 2>&1 || true; fi
  while :; do
    printf '%s%s ' "$INDENT" "Paste the token (hidden), then Enter:"
    # A key at a time, so Esc quits here too; Backspace works, nothing is shown.
    TOKEN=""
    cursor on
    quiet_keys on # a paste comes in one go; without this, what lands between two reads is shown
    while read_key && [ -n "$KEY" ]; do
      case "$KEY" in $'\177' | $'\b') TOKEN="${TOKEN%?}" ;; UP | DOWN | LEFT | RIGHT | SHIFT_UP | SHIFT_DOWN) ;; *) TOKEN="$TOKEN$KEY" ;; esac
    done
    quiet_keys off
    cursor off; echo
    [ -n "$TOKEN" ] || continue
    headers="$(curl -sS -o /dev/null -D - -H "Authorization: token $TOKEN" https://api.github.com/user | tr -d '\r')"
    status="$(printf '%s\n' "$headers" | awk 'NR==1{print $2}')"
    scopes="$(printf '%s\n' "$headers" | awk -F': ' 'tolower($1)=="x-oauth-scopes"{print $2}')"
    if [ "$status" != 200 ]; then report failed "GitHub rejected that token (HTTP $status); try again"; continue; fi
    case "$TOKEN" in
      github_pat_*)
        report differs "that's a fine-grained token; only classic ones are tested, organization work may be missed"
        yesno "Use it anyway?" n || continue ;;
      *)
        case ", $scopes," in
          *", repo,"*) ;;
          *) report missing "the repo scope (the token has: ${scopes:-none}); try again"; continue ;;
        esac
        case ", $scopes," in
          *", read:user,"*|*", user,"*) ;;
          *) report missing "the read:user scope; without it GitHub hides your private work; try again"; continue ;;
        esac
        case ", $scopes," in
          *", read:org,"*|*", admin:org,"*|*", write:org,"*) ;;
          *) report missing "the read:org scope; organization work may be missed"; yesno "Use it anyway?" n || continue ;;
        esac ;;
    esac
    break
  done
  printf '%s' "$TOKEN" | gh secret set "$SECRET" -R "$PROFILE"
  unset TOKEN
  report stored "the token as $SECRET"
}
token_rejected() { # token_rejected run_id: did that run fail on the token?
  gh run view "$1" -R "$PROFILE" --log-failed 2>/dev/null \
    | grep -Eq 'the token was rejected|set GITHUB_TOKEN|not been granted the required scopes'
}

# A secret can't be read back, so a token that's set isn't asked about: the first run uses it, and
# asks for a new one if it fails on it.
section "Token"
if gh secret list -R "$PROFILE" 2>/dev/null | awk '{print $1}' | grep -qx "$SECRET"; then
  report ok "your token is set"
else
  report missing "$SECRET: a classic token with the repo, read:org and read:user scopes"
  note "it lets the cards count your private and organization work"
  if $DRY_RUN; then report "dry run" "would ask for a token and store it as $SECRET"; else ask_token; fi
fi
