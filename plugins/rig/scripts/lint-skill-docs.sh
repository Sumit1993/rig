#!/bin/bash
# lint-skill-docs.sh — skills and dotfiles docs carry present-tense facts and
# procedures only: no dates, no event narrative. Git history owns provenance.
# Fenced code blocks are exempt: an example log row or transcript is data, not prose.
# Exits 1 with the offending lines when a marker is found.
set -u
root=$(git rev-parse --show-toplevel 2>/dev/null) || root=$(cd "$(dirname "$0")/../../.." && pwd)
pattern='20[0-9]{2}-[0-9]{2}-[0-9]{2}|found live|last session|we learned|earlier attempt'

hits=""
for f in "$root"/plugins/*/skills/*/SKILL.md "$root"/dotfiles/AGENTS.md; do
  [ -f "$f" ] || continue
  found=$(awk '/^[[:space:]]*```/ {fence = !fence; print ""; next} {print (fence ? "" : $0)}' "$f" \
    | grep -nE "$pattern" | sed "s#^#$f:#") || true
  [ -n "$found" ] && hits="${hits}${found}"$'\n'
done

# Shape: the always-loaded description says when to load, the body stays small and detail
# nests in references/ (#157 - rig loads less and says it once). Vendored skills keep upstream's body.
for f in "$root"/plugins/*/skills/*/SKILL.md; do
  d=$(sed -n 's/^description: *"\{0,1\}//p' "$f" | head -1)
  case "$d" in Load*|Use*) ;; *) hits="${hits}$f: description must open with when to load it (Load when/before, Use when)"$'\n' ;; esac
  [ "${#d}" -le 250 ] || hits="${hits}$f: description is ${#d} chars; 250 at most"$'\n'
  if ! grep -q '^  upstream:' "$f"; then
    w=$(awk 'n>=2 {print} /^---$/ {n++}' "$f" | wc -w)
    [ "$w" -le 1500 ] || hits="${hits}$f: body is $w words; move a sub-case to references/ (1500 at most)"$'\n'
  fi
  for r in "$(dirname "$f")"/references/*.md; do
    [ -f "$r" ] || continue
    grep -rqF "$(basename "$r")" "$(dirname "$f")" --include=*.md --exclude="$(basename "$r")" \
      || hits="${hits}$r: no SKILL.md or reference points to it"$'\n'
  done
done

if [ -n "${hits// /}" ] && [ "$hits" != $'\n' ]; then
  echo "doc lint: state the constraint and leave provenance to git history; keep each skill small and its description a trigger:"
  printf '%s' "$hits"
  exit 1
fi
echo "doc lint: clean"
