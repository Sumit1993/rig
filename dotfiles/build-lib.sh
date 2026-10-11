#!/bin/bash
# Shared by the build-*-plugin.sh scripts and install.sh: read dotfiles/harnesses.json, check a target's
# closure, copy its files. Sourced, not run. Story: #169 - rig declares and installs every harness's plugins.
RIG_DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RIG_SRC="$(cd "$RIG_DOTFILES/../plugins/rig" && pwd)"
RIG_MANIFEST="${RIG_MANIFEST:-$RIG_DOTFILES/harnesses.json}"

rig_targets() { jq -r '.targets | keys[]' "$RIG_MANIFEST"; }
rig_list() { jq -r --arg t "$1" --arg k "$2" '.targets[$t][$k] // [] | .[]' "$RIG_MANIFEST"; }
rig_field() { jq -r --arg t "$1" --arg p "$2" '.targets[$t] | getpath($p | split(".")) // empty' "$RIG_MANIFEST"; }

rig_src_skills() { for d in "$RIG_SRC"/skills/*/SKILL.md; do basename "$(dirname "$d")"; done; }
rig_src_hooks() { for f in "$RIG_SRC"/hooks/*.sh; do basename "$f"; done; }
rig_src_agents() { for f in "$RIG_SRC"/agents/*.md; do basename "$f" .md; done; }
rig_src_runtime() {
  (cd "$RIG_SRC" && find scripts hooks/lib data -maxdepth 1 -type f 2>/dev/null | sort)
}

# Every artifact sits in some target or under `unshipped`; every declared name exists; the claude
# target's hooks are exactly the scripts hooks.json registers.
rig_check_manifest() {
  local errs=0 kind name t
  jq -e '.targets and .unshipped' "$RIG_MANIFEST" >/dev/null || { echo "harnesses.json: not valid or missing keys" >&2; return 1; }
  for kind in skills hooks agents; do
    while IFS= read -r name; do
      jq -e --arg k "$kind" --arg n "$name" \
        '([.targets[][$k] // [] | .[]] | index($n)) != null or (.unshipped[$k] | has($n))' "$RIG_MANIFEST" >/dev/null \
        || { echo "harnesses.json: $kind/$name is in no target and not under unshipped" >&2; errs=$((errs + 1)); }
    done < <(case $kind in skills) rig_src_skills;; hooks) rig_src_hooks;; agents) rig_src_agents;; esac)
    for t in $(rig_targets); do
      while IFS= read -r name; do
        [ -n "$name" ] || continue
        case $kind in
          skills) [ -f "$RIG_SRC/skills/$name/SKILL.md" ] ;;
          hooks) [ -f "$RIG_SRC/hooks/$name" ] ;;
          agents) [ -f "$RIG_SRC/agents/$name.md" ] ;;
        esac || { echo "harnesses.json: $t declares $kind/$name, which does not exist" >&2; errs=$((errs + 1)); }
      done < <(rig_list "$t" "$kind")
    done
  done
  for t in $(rig_targets); do
    while IFS= read -r name; do
      [ -n "$name" ] && [ ! -f "$RIG_SRC/$name" ] && { echo "harnesses.json: $t declares runtime $name, which does not exist" >&2; errs=$((errs + 1)); }
    done < <(rig_list "$t" runtime)
  done
  local registered declared
  registered=$(jq -r '[.hooks[][].hooks[].command | capture("hooks/(?<s>[^\"/ ]+\\.sh)").s] | unique | .[]' "$RIG_SRC/hooks/hooks.json")
  declared=$(rig_list claude hooks | sort -u)
  [ "$registered" = "$declared" ] || { echo "harnesses.json: claude hooks differ from hooks.json:" >&2; diff <(echo "$declared") <(echo "$registered") >&2; errs=$((errs + 1)); }
  return "$errs"
}

# Text a shipped artifact carries: a skill's docs and scripts (tests excluded), a hook or runtime file.
_rig_texts() { # <target>
  local t=$1 n
  for n in $(rig_list "$t" skills); do
    find "$RIG_SRC/skills/$n" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' \) \
      -not -path '*/tests/*' -not -path '*/__pycache__/*' | sed "s#^#skill:$n\t#"
  done
  for n in $(rig_list "$t" hooks); do printf 'hook:%s\t%s\n' "$n" "$RIG_SRC/hooks/$n"; done
  for n in $(rig_list "$t" runtime); do printf 'runtime:%s\t%s\n' "$n" "$RIG_SRC/$n"; done
}

_rig_refs() { # <file> <name|name|...>: skill names the file points at
  {
    grep -ohE "rig:($2)\b" "$1" | sed 's/^rig://'
    grep -ohE "skills/($2)/" "$1" | sed 's#^skills/##; s#/$##'
    grep -ohE "\`($2)\`" "$1" | tr -d '`'
    grep -ohE "rig ($2) skill" "$1" | sed 's/^rig //; s/ skill$//'
  } 2>/dev/null | sort -u
}

# Closure: a shipped skill, hook or runtime file that names another rig skill (`name`, rig:name,
# skills/name/, "rig name skill") or a runtime file the target does not get fails the build, unless the
# target's allow_refs names that pointer with a reason.
rig_check_target() { # <target>
  local t=$1 errs=0 owner file names shipped_skills shipped_runtime ref rt other
  names=$(rig_src_skills | paste -sd'|')
  shipped_skills=" $(rig_list "$t" skills | tr '\n' ' ') "
  shipped_runtime=" $(rig_list "$t" runtime | tr '\n' ' ') "
  while IFS=$'\t' read -r owner file; do
    for ref in $(_rig_refs "$file" "$names"); do
      [ "$owner" = "skill:$ref" ] && continue
      jq -e --arg t "$t" --arg o "${owner#*:}" --arg r "$ref" '.targets[$t].allow_refs[$o][$r] // empty' "$RIG_MANIFEST" >/dev/null && continue
      case "$shipped_skills" in *" $ref "*) ;; *)
        echo "build $t: $owner (${file#"$RIG_SRC"/}) names skill $ref, which $t does not get" >&2; errs=$((errs + 1)) ;;
      esac
    done
    while IFS= read -r rt; do
      [ "$owner" = "runtime:$rt" ] && continue
      case "$shipped_runtime" in *" $rt "*) continue ;; esac
      grep -qwF "$(basename "$rt")" "$file" 2>/dev/null || continue
      echo "build $t: $owner (${file#"$RIG_SRC"/}) uses $rt, which $t does not get" >&2; errs=$((errs + 1))
    done < <(rig_src_runtime)
  done < <(_rig_texts "$t")
  if [ "$t" != claude ] && [ "$t" != claude-windows ]; then
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      echo "build $t: ${file#"$RIG_SRC"/} uses CLAUDE_PLUGIN_ROOT or ! preprocessing, which only Claude Code expands in a skill" >&2
      errs=$((errs + 1))
    done < <(for other in $(rig_list "$t" skills); do grep -rlE --include='*.md' 'CLAUDE_PLUGIN_ROOT|(^|[[:space:]:])!`' "$RIG_SRC/skills/$other"; done)
  fi
  return "$errs"
}

# Copy a target's skills, hooks and runtime files into <out>, keeping plugin-relative paths.
rig_copy_target() { # <target> <out>
  local t=$1 out=$2 n
  mkdir -p "$out/skills"
  for n in $(rig_list "$t" skills); do
    cp -r "$RIG_SRC/skills/$n" "$out/skills/"
    rm -rf "$out/skills/$n/tests" "$out/skills/$n/__pycache__"
  done
  for n in $(rig_list "$t" hooks); do mkdir -p "$out/hooks"; cp "$RIG_SRC/hooks/$n" "$out/hooks/$n"; done
  for n in $(rig_list "$t" runtime); do mkdir -p "$out/$(dirname "$n")"; cp "$RIG_SRC/$n" "$out/$n"; done
  for n in $(rig_list "$t" agents); do mkdir -p "$out/agents"; cp "$RIG_SRC/agents/$n.md" "$out/agents/"; done
}

# Provenance for install.sh --check: which source revision a build came from.
rig_stamp() { # <target> <out>
  local commit dirty=""
  commit=$(git -C "$RIG_SRC" rev-parse HEAD 2>/dev/null || echo unknown)
  [ -n "$(git -C "$RIG_SRC" status --porcelain -- . 2>/dev/null)" ] && dirty="+dirty"
  jq -n --arg t "$1" --arg v "$(jq -r .version "$RIG_SRC/.claude-plugin/plugin.json")" --arg c "$commit$dirty" \
    '{target: $t, version: $v, commit: $c}' > "$2/.rig-build.json"
}

rig_check_all() { # <target>: manifest, then the target's closure
  rig_check_manifest && rig_check_target "$1"
}

# A generated global instructions file: the neutral core plus the target's overlay (doctrine.mode generate).
rig_doctrine() { # <target> <dotfiles-root>
  local root=$2 overlay
  overlay=$(rig_field "$1" doctrine.overlay)
  [ -n "$overlay" ] && [ -f "$root/AGENTS.md" ] && [ -f "$root/$overlay" ] || return 1
  printf '<!-- Generated by rig dotfiles/install.sh from dotfiles/AGENTS.md + dotfiles/%s. Edit those in the rig repo and re-run install.sh; edits here are overwritten. -->\n\n' "$overlay"
  cat "$root/AGENTS.md"
  printf '\n'
  cat "$root/$overlay"
}

# Write a target's generated instructions file to <dest>: replaces a symlink or an earlier generated file,
# backs up anything else first. Codex reads at most 32 KiB of it.
rig_write_doctrine() { # <dest> <target> <dotfiles-root>
  local dest=$1 tmp bak
  mkdir -p "$(dirname "$dest")"
  tmp=$(mktemp "$(dirname "$dest")/.rig-doctrine.XXXXXX")
  rig_doctrine "$2" "$3" > "$tmp" || { rm -f "$tmp"; echo "  ERROR: no AGENTS.md or overlay for $2 under $3" >&2; return 1; }
  if [ -L "$dest" ]; then
    rm "$dest"; echo "  $dest was a symlink; now generated"
  elif [ -f "$dest" ] && cmp -s "$tmp" "$dest"; then
    rm -f "$tmp"; echo "  $dest already current"; return 0
  elif [ -f "$dest" ] && ! head -1 "$dest" | grep -q '^<!-- Generated by rig'; then
    bak="$dest.bak-$(date +%s)"; cp "$dest" "$bak"
    echo "  WARNING: $dest was not generated by rig; backup at $bak, re-add anything machine-local to the overlay" >&2
  fi
  mv "$tmp" "$dest"; chmod 644 "$dest"
  [ "$(wc -c < "$dest")" -le 32768 ] || echo "  WARNING: $dest is over 32 KiB; Codex reads only the first 32 KiB" >&2
  echo "  $dest generated from AGENTS.md + $(rig_field "$2" doctrine.overlay)"
}
