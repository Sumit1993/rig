#!/bin/bash
# mage:rig/guard/scoped-cap-gate
# PreToolUse(Agent) hook: refuse a spawn on a model whose own weekly cap (Fable) reads critical.
# Reads the /api/oauth/usage cache the status line keeps; no cache or a passed reset allows. Refs #133.
# Rung: hook. Skipped: impossible (the harness has no per-model spawn cap), check (usage cache varies dynamically during the session).
set -u
in=$(cat)
cache="${SCOPED_CAP_USAGE:-$HOME/.claude/metrics/usage-api.json}"

_lib="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/hooks/lib/report-guard.sh"
[ -f "$_lib" ] || _lib="$(cd "$(dirname "$0")" && pwd)/lib/report-guard.sh"
[ -f "$_lib" ] && . "$_lib"
type report_guard >/dev/null 2>&1 || report_guard() { :; }

model=$(jq -r '.tool_input.model // ""' <<<"$in" 2>/dev/null) || exit 0
agent=$(jq -r '.tool_input.subagent_type // ""' <<<"$in" 2>/dev/null) || exit 0
# The spawn's model wins; else a rig agent's frontmatter model, so the planner seat on Opus never meets Fable's cap.
if [ -z "$model" ] && [ -n "$agent" ]; then
  af="${SCOPED_CAP_AGENTS:-$(cd "$(dirname "$0")/.." && pwd)/agents}/${agent#rig:}.md"
  [ -r "$af" ] && model=$(awk 'NR>1 && /^---/{exit} /^model:/{print $2; exit}' "$af")
fi
case "${model,,}" in
  fable*|claude-fable*) want=fable ;;
  *) exit 0 ;;
esac
[ -r "$cache" ] || exit 0

row=$(jq -c --arg m "$want" --argjson now "$(date +%s)" '
  [.limits[]? | select(.kind == "weekly_scoped" and ((.scope.model.display_name // "") | ascii_downcase) == $m)
   | select(.severity == "critical")
   | select((.resets_at // "" | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | try fromdateiso8601 catch 0) > $now)] | first // empty' "$cache" 2>/dev/null)
[ -n "$row" ] || exit 0

pct=$(jq -r '.percent' <<<"$row"); reset=$(jq -r '.resets_at[0:16]' <<<"$row")
echo "Blocked by rig/guard/scoped-cap-gate: Fable's weekly cap is at ${pct}% (critical) until ${reset}Z. Spawn the planner seat on Opus (agent planner) instead, and say so in the report." >&2
echo "mage:rig/guard/scoped-cap-gate" >&2
report_guard "rig/guard/scoped-cap-gate" "Agent" "${model:-$agent}"
exit 2
