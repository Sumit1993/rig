#!/bin/bash
# mage:rig/guard/safe-stash
# PreToolUse(Bash) hook: block bare `git stash`, unnamed `git stash push`, and `git stash pop`.
# The stash stack is shared by every worktree; safe forms are `git stash push -u -m <tag>` and `git stash apply <sha>`.
# Rung: hook. Skipped: setting (no deny rule inspects command arguments or options), check (interactive stash operations do not reach repo CI).
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

cmd=$(json_get "$in" "" .tool_input.command) || exit 0
[ -n "$cmd" ] || exit 0

_ghlib="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/hooks/lib/gh-command.sh"
[ -f "$_ghlib" ] || _ghlib="$(cd "$(dirname "$0")" && pwd)/lib/gh-command.sh"
[ -f "$_ghlib" ] && . "$_ghlib"
type gh_scan >/dev/null 2>&1 || exit 0

# Fast-path check: must contain git and stash
grep -qE '\bgit\b' <<<"$cmd" || exit 0
grep -qE '\bstash\b' <<<"$cmd" || exit 0

cur="$cmd"
while printf '%s' "$cur" | gh_scan words 'git\s+stash\b' >/dev/null 2>&1; do
  words=()
  while IFS= read -r -d '' w; do words+=("$w"); done < <(printf '%s' "$cur" | gh_scan words 'git\s+stash\b')
  
  has_msg=0
  subcmd=""
  for ((i = 2; i < ${#words[@]}; i++)); do
    w="${words[i]}"
    case "$w" in
      -m|--message)
        if [ $((i + 1)) -lt ${#words[@]} ] && [ -n "${words[i+1]}" ]; then
          has_msg=1
        fi
        i=$((i + 1))
        ;;
      --message=*)
        val="${w#--message=}"
        [ -n "$val" ] && has_msg=1
        ;;
      -m?*)
        has_msg=1
        ;;
      -*)
        ;;
      *)
        if [ -z "$subcmd" ]; then
          subcmd="$w"
        fi
        ;;
    esac
  done

  block=0
  case "$subcmd" in
    pop)
      block=1 ;;
    push|"")
      [ "$has_msg" -eq 0 ] && block=1 ;;
    apply|list|show|drop|clear|branch|create|store)
      block=0 ;;
    *)
      [ "$has_msg" -eq 0 ] && block=1 ;;
  esac

  if [ "$block" -eq 1 ]; then
    cat >&2 <<MSG
Blocked by rig/guard/safe-stash: The stash stack is shared by every worktree. Use git stash push -u -m <tag> and git stash apply <sha> instead.
mage:rig/guard/safe-stash
MSG
    tool=$(json_get "$in" "Bash" .tool_name)
    report_guard "rig/guard/safe-stash" "$tool" "${subcmd:-bare}"
    exit 2
  fi

  tail=$(printf '%s' "$cur" | gh_scan tail 'git\s+stash\b') || break
  cur=${tail#*stash}
done

exit 0
