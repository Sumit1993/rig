#!/bin/bash
# mage:rig/guard/no-thread-resolve
# PreToolUse(Bash) hook: block resolving reviewer review threads (AGENTS.md §Reporting and merging).
# The session must never resolve a reviewer's review thread; only the reviewer that opened it resolves it.
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
[ -f "$_ghlib" ] && . "$_ghlib"
if type gh_scan >/dev/null 2>&1 && command -v perl >/dev/null 2>&1; then
  # Fail closed: any gh api call in a command that names resolveReviewThread and graphql is blocked, wherever the
  # query sits (flags, heredoc, variable, GraphQL comments). A command that only mentions it splits the text out.
  printf '%s' "$cmd" | gh_scan prefix '(?:env(?:\s+[A-Za-z_]\w*=\S*)*\s+|command\s+)?gh\s+api\b' >/dev/null 2>&1 || exit 0
  grep -q 'graphql' <<<"$cmd" || exit 0
else
  grep -qE '(^|[;&|[:space:]])gh[[:space:]]+api\b' <<<"$cmd" || exit 0
fi

cat >&2 <<MSG
Blocked by rig/guard/no-thread-resolve: The session must never resolve a reviewer's review thread; only the reviewer that opened it resolves it (AGENTS.md §Reporting and merging).
Instead: fix findings, commit, push, and reply inside the review thread. The reviewer resolves its own thread once verified.
If this command only mentions the mutation (a comment or commit body), move that text to a file and pass it with -F body=@file.
mage:rig/guard/no-thread-resolve
MSG
tool=$(json_get "$in" "Bash" .tool_name)
report_guard "rig/guard/no-thread-resolve" "$tool" "$cmd"
exit 2
