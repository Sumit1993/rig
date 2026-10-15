#!/bin/bash
# mage:rig/guard/no-thread-resolve
# PreToolUse(Bash) hook: block resolving reviewer review threads (AGENTS.md §Reporting and merging).
# The session must never resolve a reviewer's review thread; only the reviewer that opened it resolves it.
# Rung: hook. Skipped: setting (permissions.deny cannot inspect GraphQL mutation bodies), check (API mutations bypass repo CI).
set -u
in=$(cat)

_jlib="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/hooks/lib/json.sh"
[ -f "$_jlib" ] || _jlib="$(cd "$(dirname "$0")" && pwd)/lib/json.sh"
[ -f "$_jlib" ] && . "$_jlib"
type json_get >/dev/null 2>&1 || json_get() { return 1; }

_lib="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/hooks/lib/report-guard.sh"
[ -f "$_lib" ] || _lib="$(cd "$(dirname "$0")" && pwd)/lib/report-guard.sh"
[ -f "$_lib" ] && . "$_lib"
type report_guard >/dev/null 2>&1 || report_guard() { :; }

if [ -z "${in//[[:space:]]/}" ] || ! cmd=$(json_get "$in" "" .tool_input.command); then
  echo "no-thread-resolve: could not read input." >&2
  exit 0
fi

[ -z "$cmd" ] && exit 0

grep -q 'resolveReviewThread' <<<"$cmd" || exit 0

_ghlib="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/hooks/lib/gh-command.sh"
[ -f "$_ghlib" ] || _ghlib="$(cd "$(dirname "$0")" && pwd)/lib/gh-command.sh"
if [ -f "$_ghlib" ]; then
  . "$_ghlib"
  # The mutation must sit in a gh api graphql call's own words, not in a commit message or a grep.
  hit=0 cur="$cmd"
  while printf '%s' "$cur" | gh_scan words 'gh\s+api\s+graphql\b' >/dev/null 2>&1; do
    if printf '%s' "$cur" | gh_scan words 'gh\s+api\s+graphql\b' | tr '\0' '\n' | grep -q 'resolveReviewThread'; then hit=1; break; fi
    tail=$(printf '%s' "$cur" | gh_scan tail 'gh\s+api\s+graphql\b') || break
    cur=${tail#*graphql}
  done
  [ "$hit" -eq 1 ] || exit 0
else
  grep -qE '(^|[;&|[:space:]])gh[[:space:]]+api\b' <<<"$cmd" || exit 0
fi

cat >&2 <<MSG
Blocked by rig/guard/no-thread-resolve: The session must never resolve a reviewer's review thread; only the reviewer that opened it resolves it (AGENTS.md §Reporting and merging).
Instead: fix findings, commit, push, and reply inside the review thread. The reviewer resolves its own thread once verified.
mage:rig/guard/no-thread-resolve
MSG
tool=$(json_get "$in" "Bash" .tool_name)
report_guard "rig/guard/no-thread-resolve" "$tool" "$cmd"
exit 2
