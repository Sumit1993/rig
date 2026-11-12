#!/bin/bash
# SessionStart hook: one line of budget the operator used to type by hand: agy's quota state per
# group and Codex's usage limits; Claude's own limits are in /usage. Refs #123.
# On resume or fork, the resume-cost fields Claude Code sends (v2.1.251+) become one more sentence.
# Rung: hook. Skipped: impossible (the harness banner does not show external quota), check (the session starts dynamically).
set -u
# --print: the same line as plain text, on demand rather than only at session start (#177).
print=""; [ "${1:-}" = "--print" ] && print=1
if [ -n "$print" ]; then in='{}'; else in=$(cat); fi
quota="${BUDGET_QUOTA_SH:-$(cd "$(dirname "$0")/.." && pwd)/skills/farm-out/agy-quota.sh}"
codex_quota="${BUDGET_CODEX_QUOTA:-$(cd "$(dirname "$0")/.." && pwd)/skills/adversary/codex-quota.py}"

# The hook timeout is 10s: the three probes run in parallel, each cut at 6s where timeout exists (rig#183).
t=$(mktemp -d 2>/dev/null) || t=""
probe() { # name, script, args...
  local name=$1; shift
  [ -n "$t" ] && [ -x "$1" ] || return 0
  if command -v timeout >/dev/null 2>&1; then timeout 6 "$@"; else "$@"; fi 2>/dev/null | head -1 > "$t/$name"
}
probe g "$quota" check gemini-3.8-flash-high &
probe c "$quota" check claude-sonnet-4-6 &
( export RIG_CODEX_QUOTA_TIMEOUT=4; probe x "$codex_quota" check ) &
wait
read_probe() { local v=""; [ -n "$t" ] && v=$(cat "$t/$1" 2>/dev/null); echo "${v:-unknown}"; }
g=$(read_probe g); c=$(read_probe c); x=$(read_probe x)
[ -n "$t" ] && rm -rf "$t"

resume=""
src=$(jq -r '.source // empty' <<<"$in" 2>/dev/null)
gap=$(jq -r '.seconds_since_last_response // empty' <<<"$in" 2>/dev/null)
if [ -n "$gap" ] && { [ "$src" = "resume" ] || [ "$src" = "fork" ]; }; then
  ctx_tok=$(jq -r '.context_tokens // "?"' <<<"$in" 2>/dev/null)
  cold=$(jq -r '.prompt_cache_likely_expired // false' <<<"$in" 2>/dev/null)
  [ "$cold" = "true" ] && cache="prompt cache likely expired, the first request rebuilds it" || cache="prompt cache likely warm"
  resume=" Resumed after $((gap / 60))m: ${ctx_tok} context tokens re-sent, ${cache}."
fi
msg="Budget: agy gemini: ${g}. agy claude-gpt: ${c}. codex: ${x}.${resume}"
[ -n "$print" ] && { printf '%s\n' "$msg"; exit 0; }
jq -n --arg ctx "$msg" '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$ctx}}'
exit 0
