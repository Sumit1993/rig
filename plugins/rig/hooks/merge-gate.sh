#!/bin/bash
# mage:rig/guard/merge-gate
# PreToolUse(Bash) hook: a merge is a per-merge permission (AGENTS.md §Reporting and merging). The session
# records the operator's word as MERGE_OK=<pr> on the same command; the token names one PR and never
# carries forward. Covers gh pr merge (incl. --auto) and gh api .../pulls/<n>/merge.
# Refs #123, #20. Rung: hook. Skipped: impossible (a ruleset needing one approval is stronger; open on #20 per repo).
set -u
in=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$in" 2>/dev/null) || exit 0
[ -n "$cmd" ] || exit 0
grep -qE 'gh[[:space:]]+pr[[:space:]]+merge\b|pulls/[0-9]+/merge' <<<"$cmd" || exit 0

_lib="$(cd "$(dirname "$0")" && pwd)/lib/gh-command.sh"
[ -f "$_lib" ] || exit 0
. "$_lib"

_report_lib="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/hooks/lib/report-guard.sh"
[ -f "$_report_lib" ] || _report_lib="$(cd "$(dirname "$0")" && pwd)/lib/report-guard.sh"
[ -f "$_report_lib" ] && . "$_report_lib"
type report_guard >/dev/null 2>&1 || report_guard() { :; }

# Every merge in the command is checked, each against its own token: `MERGE_OK=5 gh pr merge 5; gh pr merge 6`
# must not ride the first merge's word.
token_for() { # <text before this call>: the last MERGE_OK there, else anywhere in the command
  local t
  t=$(grep -oE '(^|[;&|[:space:]])MERGE_OK=[^[:space:];&|]+' <<<"$1" | tail -1 | sed -E 's/.*MERGE_OK=//; s/^["'"'"']//; s/["'"'"']$//')
  [ -n "$t" ] || t=$(grep -oE '(^|[;&|[:space:]])MERGE_OK=[^[:space:];&|]+' <<<"$cmd" | tail -1 | sed -E 's/.*MERGE_OK=//; s/^["'"'"']//; s/["'"'"']$//')
  printf '%s' "$t"
}
block() { # <pr> <api yes|no> <token>
  local pr=$1 api=$2 token=$3 which
  which="PR ${pr:-<current branch>}"
  [ "$api" = "yes" ] && which="pulls/${pr:-?}/merge via gh api"
  cat >&2 <<MSG
Blocked by rig/guard/merge-gate: merging $which needs the operator's word for this PR (AGENTS.md §Reporting and
merging: merge is a per-merge permission, never carried forward). Ask, then record it on the
same command: MERGE_OK=${pr:-<pr>} gh pr merge ${pr:-<pr>} ... The token must name this PR${token:+; it names $token}.
MSG
  report_guard "rig/guard/merge-gate" "Bash" "pr ${pr:-current}"
  exit 2
}
check() { # <text before this call> <pr> <api>
  local token
  token=$(token_for "$1")
  # A merge that names no PR is blocked even with a token: the token must name the PR it merges.
  [ -n "$token" ] && [ -n "$2" ] && [ "$token" = "$2" ] && return 0
  block "$2" "$3" "$token"
}

for gh_re in 'gh\s+pr\s+merge\b' 'gh\s+api\b'; do
  seen="" cur="$cmd"
  while printf '%s' "$cur" | gh_scan prefix "$gh_re" >/dev/null 2>&1; do
    pre=$(printf '%s' "$cur" | gh_scan prefix "$gh_re")
    words=()
    while IFS= read -r -d '' w; do words+=("$w"); done < <(printf '%s' "$cur" | gh_scan words "$gh_re")
    pr="" hit="no"
    if [ "$gh_re" = 'gh\s+api\b' ]; then
      for w in "${words[@]}"; do
        if [[ "$w" =~ pulls/([0-9]+)/merge ]]; then pr="${BASH_REMATCH[1]}"; hit="yes"; break; fi
      done
      [ "$hit" = "yes" ] && check "$seen$pre" "$pr" yes
    else
      for ((i = 3; i < ${#words[@]}; i++)); do
        w=${words[i]}
        case "$w" in
          [0-9]*) [[ "$w" =~ ^[0-9]+$ ]] && pr=$w ;;
          https://github.com/*/pull/*) pr=${w##*/pull/}; pr=${pr%%[!0-9]*} ;;
        esac
      done
      check "$seen$pre" "$pr" no
    fi
    tail=$(printf '%s' "$cur" | gh_scan tail "$gh_re") || break
    rest=${tail#gh}
    seen="$seen$pre${tail%"$rest"}"
    cur=$rest
  done
done
exit 0
