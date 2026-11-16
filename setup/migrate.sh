# shellcheck shell=bash
# Settings from before v1.5, moved to the new layout.

# Settings from before v1.5, moved to the new layout: the same values, the same look, comments
# kept. Returns 1 when the file is in the new layout already, and 2 when it has something this can't
# move (a languages section written inline with excludeRepos or repoWeights, say): then the file
# stays as it is, and the action still reads it.
migrate_config() { # migrate_config file
  local tmp status=0
  tmp="$(mktemp)"
  awk '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function value(s) { sub(/[[:space:]]+#.*$/, "", s); return trim(s) }
    function unq(s) { if (length(s) > 1 && (substr(s, 1, 1) == "\"" || substr(s, 1, 1) == Q) && substr(s, length(s)) == substr(s, 1, 1)) s = substr(s, 2, length(s) - 2); return s }
    function rest(s) { sub(/^[^:]*:/, "", s); return value(s) } # what follows "key:"
    function indent(s) { match(s, /^[[:space:]]*/); return substr(s, 1, RLENGTH) }
    function items(s, out,   n, i, parts) { # the items of a flow list or map, trimmed; how many
      s = trim(s); s = substr(s, 2, length(s) - 2)
      n = split(s, parts, ",")
      for (i = 1; i <= n; i++) out[i] = trim(parts[i])
      return n
    }
    function emit(s) { print s }
    BEGIN {
      Q = sprintf("%c", 39)
      split("style matrix color background transparent include theme summary languages contributions weekly streaks about", o, " ")
      for (i in o) OLD[o[i]] = 1
      split("show count look", nw, " ")
      for (i in nw) NEW[nw[i]] = 1
      split("summary languages contributions weekly streaks about", cc, " ")
      for (i in cc) CARD[cc[i]] = 1
    }
    { line[++L] = $0 }
    END {
      # Blocks: a top-level key, its lines, and the comments and blank lines just before it.
      b = 0; pending = 0
      for (i = 1; i <= L; i++) {
        s = line[i]
        if (s ~ /^[A-Za-z_][A-Za-z0-9_]*:/) {
          b++; k = s; sub(/:.*/, "", k); key[b] = k; head[b] = s; nbody[b] = 0
          npre[b] = 0
          for (j = 1; j <= pending; j++) pre[b, ++npre[b]] = pend[j]
          pending = 0; at[k] = b
        } else if (b == 0) header[++nheader] = s
        else if (s ~ /^[[:space:]]+[^[:space:]]/ && s !~ /^[[:space:]]+#/) {
          for (j = 1; j <= pending; j++) body[b, ++nbody[b]] = pend[j]
          pending = 0; body[b, ++nbody[b]] = s
        } else pend[++pending] = s
      }
      old = 0; new = 0
      for (i = 1; i <= b; i++) {
        if (key[i] in OLD) old = 1
        if (key[i] in NEW) new = 1
        if (key[i] == "cards") {
          v = rest(head[i])
          if (v ~ /^\[/ || (v == "" && nbody[i] && trim(body[i, 1]) ~ /^-/)) old = 1; else new = 1
        }
      }
      if (!old) exit 1
      if (new) exit 2

      # The look, from the keys it was spread over.
      style = ("style" in at) ? unq(rest(head[at["style"]])) : "classic"
      if (style != "classic" && style != "oled") exit 2
      matrix = ("matrix" in at) ? unq(rest(head[at["matrix"]])) : "true"
      color = ("color" in at) ? unq(rest(head[at["color"]])) : ""
      transparent = ("transparent" in at) ? unq(rest(head[at["transparent"]])) : "true"
      if ("theme" in at) {
        t = at["theme"]; v = rest(head[t])
        if (v ~ /^\{/) { n = items(v, it); for (j = 1; j <= n; j++) { split(it[j], kv, ":"); theme[trim(kv[1])] = unq(trim(kv[2])) } }
        for (j = 1; j <= nbody[t]; j++) {
          s = trim(body[t, j]); if (s ~ /^#/ || s == "") continue
          k = s; sub(/:.*/, "", k); theme[k] = unq(rest(s))
        }
      }
      newstyle = style == "oled" ? (matrix == "false" ? "oled" : "dotmatrix") : "classic"
      if (color == "theme") color = "github"
      if (color == "") color = style == "oled" ? "amber" : "github"
      if ("background" in at) bg = rest(head[at["background"]])
      else if (style == "oled" && transparent == "false") bg = color == "amber" ? "0d0b07" : color == "green" ? "070d09" : "none"
      else bg = "none"

      for (i = 1; i <= nheader; i++) emit(header[i])
      if ("user" in at) block(at["user"], "", "")
      if ("cards" in at) block(at["cards"], "", "show")
      if ("include" in at) block(at["include"], "", "count")
      emit("look:")
      emit("  style: " newstyle)
      emit("  color: " color)
      emit("  background: " bg)
      if ("animations" in theme) emit("  animations: " theme["animations"])
      if ("border" in theme) emit("  border: " theme["border"])
      cards = 0
      for (i = 1; i <= b; i++) if (key[i] in CARD) {
        if (!cards++) emit("cards:")
        if (key[i] == "languages") languages(i); else block(i, "  ", "")
      }
      for (i = 1; i <= b; i++) if (!(key[i] in OLD) && key[i] != "user" && key[i] != "cards") block(i, "", "")
      for (j = 1; j <= pending; j++) emit(pend[j])
    }
    function block(i, ind, rename,   j, h) { # a block as it was, indented, perhaps under another name
      for (j = 1; j <= npre[i]; j++) emit(pre[i, j] == "" ? "" : ind pre[i, j])
      h = head[i]
      if (rename != "") sub(/^[A-Za-z_][A-Za-z0-9_]*:/, rename ":", h)
      if (key[i] == "contributions") gsub(/includeOpen:/, "open:", h)
      emit(ind h)
      for (j = 1; j <= nbody[i]; j++) {
        h = body[i, j]
        if (key[i] == "contributions") gsub(/includeOpen:/, "open:", h)
        emit(h == "" ? "" : ind h)
      }
    }
    function languages(i,   j, s, ci, k, v, n, it, kv, x, done, nw, wk, wv, ne, ex, seen, nr) {
      # exclude becomes hide; excludeRepos and repoWeights become repos, left out being a weight of 0.
      v = rest(head[i])
      if (v ~ /^\{/) {
        if (v ~ /excludeRepos|repoWeights/) exit 2
        s = head[i]; gsub(/exclude:/, "hide:", s); head[i] = s
        block(i, "  ", ""); return
      }
      ci = ""
      for (j = 1; j <= nbody[i]; j++) if (trim(body[i, j]) != "" && trim(body[i, j]) !~ /^#/) { ci = indent(body[i, j]); break }
      ne = 0; nw = 0
      for (j = 1; j <= nbody[i]; j++) { # first, what the repos are
        s = body[i, j]
        if (indent(s) != ci) continue
        k = trim(s); sub(/:.*/, "", k)
        if (k != "excludeRepos" && k != "repoWeights") continue
        v = rest(s)
        if (v ~ /^[\[{]/) {
          n = items(v, it)
          for (x = 1; x <= n; x++) if (it[x] != "") {
            if (k == "excludeRepos") ex[++ne] = it[x]
            else { split(it[x], kv, ":"); wk[++nw] = trim(kv[1]); wv[nw] = trim(kv[2]) }
          }
        } else if (v == "") {
          while (j < nbody[i] && length(indent(body[i, j + 1])) > length(ci)) {
            s = trim(body[i, ++j]); if (s ~ /^#/ || s == "") continue
            if (k == "excludeRepos") { sub(/^-[[:space:]]*/, "", s); ex[++ne] = value(s) }
            else { split(s, kv, ":"); wk[++nw] = trim(kv[1]); wv[nw] = value(kv[2]) }
          }
        } else exit 2
      }
      for (x = 1; x <= ne; x++) seen[tolower(unq(ex[x]))] = 1
      for (j = 1; j <= npre[i]; j++) emit(pre[i, j] == "" ? "" : "  " pre[i, j])
      emit("  " head[i])
      done = 0
      for (j = 1; j <= nbody[i]; j++) {
        s = body[i, j]
        k = trim(s); sub(/:.*/, "", k)
        if (indent(s) == ci && (k == "excludeRepos" || k == "repoWeights")) {
          if (!done++) {
            nr = ne
            for (x = 1; x <= nw; x++) if (!(tolower(unq(wk[x])) in seen)) nr++
            # Nothing to move ("excludeRepos: []", "repoWeights: {}"): an empty mapping, not "repos:" with nothing under it.
            if (!nr) emit("  " ci "repos: {}")
            else emit("  " ci "repos:")
            for (x = 1; x <= nw; x++) if (!(tolower(unq(wk[x])) in seen)) emit("  " ci ci wk[x] ": " wv[x])
            for (x = 1; x <= ne; x++) emit("  " ci ci ex[x] ": 0")
          }
          if (rest(s) == "") while (j < nbody[i] && length(indent(body[i, j + 1])) > length(ci)) j++
          continue
        }
        if (indent(s) == ci && k == "exclude") sub(/exclude:/, "hide:", s)
        emit(s == "" ? "" : "  " s)
      }
    }' "$1" > "$tmp" || status=$?
  if [ "$status" = 0 ]; then mv "$tmp" "$1"; else rm -f "$tmp"; fi
  return "$status"
}
