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

# gh_scan needs perl; without it no call is found, so fail closed on the merge text the prefilter saw.
if ! command -v perl >/dev/null 2>&1; then
  echo "Blocked by rig/guard/merge-gate: perl is missing, so this merge's MERGE_OK token cannot be checked. Install perl." >&2
  report_guard "rig/guard/merge-gate" "Bash" "no perl"
  exit 2
fi

# Every merge's token is an assignment on that same call (`MERGE_OK=<n> gh pr merge <n>`): a token
# anywhere else in a compound command can belong to another merge or never be set when the merge runs (#196).
merges=() asgs=()
while IFS= read -r -d $'\x1e' rec; do
  asg=${rec%%$'\x1f'*}; rest=${rec#*$'\x1f'}
  IFS=$'\x1d' read -r -d '' -a words < <(printf '%s' "${rest%$'\x1d'}") || true
  pr=""
  for ((i = 3; i < ${#words[@]}; i++)); do
    case "${words[i]}" in
      [0-9]*) [[ "${words[i]}" =~ ^[0-9]+$ ]] && pr=${words[i]} ;;
      https://github.com/*/pull/*) pr=${words[i]##*/pull/}; pr=${pr%%[!0-9]*} ;;
    esac
  done
  merges+=("pr:$pr"); asgs+=("$asg")
done < <(printf '%s' "$cmd" | gh_scan calls 'gh\s+pr\s+merge\b')
if grep -qE 'pulls/[0-9]+/merge' <<<"$cmd"; then
  while IFS= read -r -d $'\x1e' rec; do
    asg=${rec%%$'\x1f'*}; rest=${rec#*$'\x1f'}
    [[ "$rest" =~ pulls/([0-9]+)/merge ]] || continue
    merges+=("api:${BASH_REMATCH[1]}"); asgs+=("$asg")
  done < <(printf '%s' "$cmd" | gh_scan calls 'gh\s+api\b')
fi
[ "${#merges[@]}" -eq 0 ] && exit 0

why=""
for k in "${!merges[@]}"; do
  kind=${merges[k]%%:*} pr=${merges[k]#*:}
  token=$(grep -oE '(^|[[:space:]])MERGE_OK=[^[:space:]]+' <<<"${asgs[k]}" | tail -1 | sed -E 's/.*MERGE_OK=//; s/^["'"'"']//; s/["'"'"']$//')
  # A merge that names no PR is blocked even with a token: the token must name the PR it merges.
  [ -n "$token" ] && [ -n "$pr" ] && [ "$token" = "$pr" ] && continue
  which="PR ${pr:-<current branch>}"; [ "$kind" = "api" ] && which="pulls/${pr:-?}/merge via gh api"
  why="merging $which needs the operator's word for this PR"
  break
done
[ -z "${why:-}" ] && exit 0
cat >&2 <<MSG
Blocked by rig/guard/merge-gate: $why (AGENTS.md §Reporting and merging: merge is a per-merge permission,
never carried forward). Ask, then record it on the merge itself: MERGE_OK=${pr:-<pr>} gh pr merge ${pr:-<pr>} ...
The token must name this PR${token:+; it names $token}.
MSG
report_guard "rig/guard/merge-gate" "Bash" "pr ${pr:-current}"
exit 2
