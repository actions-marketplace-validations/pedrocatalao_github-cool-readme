# shellcheck shell=bash
# Changing your files: in cool-readme.yml one setting, the list of cards and the about card's text;
# in README.md the cards block. Only functions: the steps call them.

# ------------------------------------------------------------------ settings in cool-readme.yml

# A top-level key, or "parent.child" one level down.
yaml_get() { # yaml_get file key -> value, empty if not set; without its quotes
  awk -v key="$2" '
    BEGIN { n = split(key, k, "."); Q = sprintf("%c", 39) }
    n == 1 && $0 ~ "^" k[1] ":" { sub("^" k[1] ":[[:space:]]*", ""); print unq(uncomment($0)); exit }
    n == 2 && /^[^[:space:]#]/ { in_parent = ($0 ~ "^" k[1] ":") }
    n == 2 && in_parent && $0 ~ "^[[:space:]]+" k[2] ":" { sub("^[[:space:]]+" k[2] ":[[:space:]]*", ""); print unq(uncomment($0)); exit }
    function uncomment(s) { sub(/^#.*$/, "", s); sub(/[[:space:]]+#.*$/, "", s); return s } # a comment needs a space before it: "#030506" is a value
    function unq(s,   q) { q = substr(s, 1, 1); if (length(s) > 1 && (q == "\"" || q == Q) && substr(s, length(s)) == q) s = substr(s, 2, length(s) - 2); return s }
  ' "$1"
}

# The line it changes keeps its comment. One it adds goes at the end of its parent, above the blank
# lines and comments that come before the next key: those are about that key.
yaml_set() { # yaml_set file key value: changes only that line, adding it if missing
  local tmp
  tmp="$(mktemp)"
  awk -v key="$2" -v value="$3" '
    BEGIN { n = split(key, k, "."); done = 0; held = "" }
    function comment(s) { return match(s, /[[:space:]]+#.*$/) ? substr(s, RSTART) : "" }
    function flush() { printf "%s", held; held = "" }
    n == 2 && in_parent && !done && (/^[[:space:]]*$/ || /^#/) { held = held $0 "\n"; next }
    n == 1 && !done && $0 ~ "^" k[1] ":" { print k[1] ": " value comment($0); done = 1; next }
    n == 2 && /^[^[:space:]#]/ {
      if (in_parent && !done) { print "  " k[2] ": " value; done = 1 } # the parent block ended without it
      flush()
      in_parent = ($0 ~ "^" k[1] ":")
    }
    n == 2 && in_parent && !done && $0 ~ "^[[:space:]]+" k[2] ":" {
      flush(); match($0, /^[[:space:]]+/); print substr($0, 1, RLENGTH) k[2] ": " value comment($0); done = 1; next
    }
    { flush(); print }
    END {
      if (!done) {
        if (n == 1) print k[1] ": " value
        else if (in_parent) print "  " k[2] ": " value
        else { print k[1] ":"; print "  " k[2] ": " value }
      }
      flush()
    }' "$1" > "$tmp" && mv "$tmp" "$1"
}

cards_get() { # cards_get file: the cards it lists, as a flow list or a block list; empty if none
  [ -f "$1" ] || return 0
  awk -v key="$LIST" '
    $0 ~ "^" key ":" {
      line = $0; sub("^" key ":[[:space:]]*", "", line); sub(/[[:space:]]*#.*$/, "", line)
      if (line != "") { gsub(/[][,]/, " ", line); print line; exit }
      block = 1; next
    }
    block && /^[[:space:]]*-/ { item = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", item); sub(/[[:space:]]*#.*$/, "", item); out = out " " item; next }
    block && /^[[:space:]]*(#.*)?$/ { next } # a comment or a blank line between the cards
    block { exit }
    END { if (block) print out }' "$1" | tr -d "\"'" | tr -s ' \t' '  ' | sed 's/^ *//; s/ *$//'
}
cards_set() { # cards_set file "card card": writes "show: [card, card]" in place of what was there
  local tmp
  tmp="$(mktemp)"
  awk -v key="$LIST" -v value="[$(printf '%s' "$2" | sed 's/ /, /g')]" '
    $0 ~ "^" key ":" { print key ": " value; done = 1; skip = 1; next }
    skip && /^[[:space:]]*-/ { next }
    skip && /^[[:space:]]*(#.*)?$/ { print; next } # comments and blank lines in the list stay; the cards after them go too
    { skip = 0; print }
    END { if (!done) print key ": " value }' "$1" > "$tmp" && mv "$tmp" "$1"
}

about_empty() { # about_empty file: true when the about card has no text yet (no section, or only empty values)
  awk '
    /^[^[:space:]#]/ { in_cards = ($0 ~ /^cards:/); in_about = 0; next }
    in_cards && /^[[:space:]]+about:/ {
      match($0, /^[[:space:]]+/); ai = RLENGTH; in_about = 1
      v = $0; sub(/^[[:space:]]+about:/, "", v); sub(/[[:space:]]*#.*$/, "", v); sub(/^[[:space:]]+/, "", v)
      if (v != "" && v != "{}") content = 1
      next
    }
    in_about {
      if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) next
      match($0, /^[[:space:]]*/); if (RLENGTH <= ai) { in_about = 0; next }
      s = $0; sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+#.*$/, "", s)
      if (s ~ /^(headline:[[:space:]]*(null|~)?|lines:[[:space:]]*(\[\])?|facts:[[:space:]]*(\{\})?|title:.*)$/) next
      content = 1
    }
    END { exit content }' "$1"
}
about_set() { # about_set file block: the about section under cards: replaced by block (lines indented by 4)
  local block tmp
  block="$(mktemp)"; tmp="$(mktemp)"
  { echo "  about:"; printf '%s\n' "$2"; } > "$block"
  awk -v about="$block" '
    function insert(  l) { while ((getline l < about) > 0) print l; done = 1 }
    /^[^[:space:]#]/ { skip = 0; in_cards = ($0 ~ /^cards:/); print; if (in_cards && !done) insert(); next }
    in_cards && /^[[:space:]]+about:/ { match($0, /^[[:space:]]+/); ai = RLENGTH; skip = 1; next }
    skip { match($0, /^[[:space:]]*/); if ($0 ~ /^[[:space:]]*$/ || RLENGTH > ai) next; skip = 0 }
    { print }
    END { if (!done) { print "cards:"; insert() } }' "$1" > "$tmp" && mv "$tmp" "$1"
  rm -f "$block"
}

# ------------------------------------------------------------------ README.md

readme_put() { # readme_put block: the cards block into README.md, in place of the one between the markers or at the end; where says which
  if grep -qF "$START" README.md && grep -qF "$END" README.md; then
    # Replace only what's between the markers.
    awk -v start="$START" -v end="$END" -v block="$1" '
      $0 == start { while ((getline line < block) > 0) print line; skip = 1; next }
      $0 == end { skip = 0; next }
      !skip { print }' README.md > README.md.new
    mv README.md.new README.md
    where="between the cool-readme markers"
  else
    if [ -s README.md ]; then echo >> README.md; fi
    cat "$1" >> README.md
    where="at the end; move the marked block wherever you like"
  fi
}
