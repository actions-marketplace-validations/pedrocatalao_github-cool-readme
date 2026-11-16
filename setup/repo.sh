# shellcheck shell=bash
# Step: the profile repo.

# ------------------------------------------------------------------ profile repo

section "Profile repo"
if gh repo view "$PROFILE" >/dev/null 2>&1; then
  report ok "$PROFILE"
else
  report missing "$PROFILE: its README is what GitHub shows on your profile page"
  yesno "Create it as a public repo?" y || die "nothing to set up without a profile repo"
  run gh repo create "$PROFILE" --public --add-readme --description "My GitHub profile"
  if $DRY_RUN; then framed 33 "Dry run: stopping here, the rest needs the repo to exist."; exit 0; fi
  report created "$PROFILE"
fi
