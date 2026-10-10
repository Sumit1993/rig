#!/bin/bash
# Reads the statusline JSON Claude Code pipes in. rate_limits arrives on v2.1.251+ for
# Pro and Max after the first API response; each render is also appended to
# ~/.claude/metrics/usage.jsonl so a window that fills up has a local trace. Story: rig#124.
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
five_live="$five"  # only log the trace row when this render actually carried live rate_limits

# PS1-based portion: bold green user@host, reset, colon, bold blue cwd, reset
prompt=$(printf "\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m" "$(whoami)" "$(hostname -s)" "$cwd")

extra=""
# Model (+effort)
label="$model"
[ -n "$effort" ] && label="${label} (${effort})"
[ -n "$label" ] && extra=" | \033[0;36m${label}\033[00m"

color_for() {  # percent -> ansi color: green <50, yellow 50-79, red 80+
  case "$1" in ''|*[!0-9]*) printf '\033[0;32m'; return ;; esac
  if [ "$1" -ge 80 ]; then printf '\033[0;31m'; elif [ "$1" -ge 50 ]; then printf '\033[0;33m'; else printf '\033[0;32m'; fi
}

# Context progress bar (10 blocks wide)
if [ -n "$used" ]; then
  pct=$(printf '%.0f' "$used")
  filled=$(( pct * 10 / 100 )); empty=$(( 10 - filled ))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}█"; done
  for i in $(seq 1 $empty);  do bar="${bar}░"; done
  extra="${extra} | $(color_for $pct)${bar} ${pct}%\033[00m"
fi

# rate_limits is absent until the first API response of the session. Fall back to the last
# traced row so the account windows don't render blank at session start. Story: rig#<lag fix>.
stale=""
if [ -z "$five" ]; then
  last=$(tail -n 1 ~/.claude/metrics/usage.jsonl 2>/dev/null)
  if [ -n "$last" ]; then
    five=$(echo "$last" | jq -r '.five_hour.used_percentage // empty')
    week=$(echo "$last" | jq -r '.seven_day.used_percentage // empty')
    five_reset=$(echo "$last" | jq -r '.five_hour.resets_at // empty')
    [ -n "$five" ] && stale="~"
  fi
fi

# Account windows: 5h and 7d percent, plus minutes until the 5h window resets
if [ -n "$five" ]; then
  f=$(printf '%.0f' "$five"); w=$(printf '%.0f' "${week:-0}")
  left=""
  if [ -n "$five_reset" ]; then
    case "$five_reset" in *[!0-9]*) reset_epoch=$(date -d "$five_reset" +%s 2>/dev/null || echo 0) ;; *) reset_epoch=$five_reset ;; esac
    secs=$(( reset_epoch - $(date +%s) ))
    [ "$secs" -gt 0 ] && left=" ↺$(( secs / 60 ))m"
  fi
  extra="${extra} | ${stale}5h $(color_for $f)${f}%\033[00m${left} | ${stale}7d $(color_for $w)${w}%\033[00m"
fi

# Per-model weekly caps (Fable) are not in the stdin payload. /api/oauth/usage has them; refresh a
# cache in the background at most every 5 minutes and render from the cache. Undocumented, so any
# failure just leaves the field off. Story: rig#133.
# A separate lock file gates the debounce so a killed/failed fetch doesn't lock in staleness: the
# fetch runs under setsid, detached from this script's process group, because Claude Code reaps
# that group the moment this script returns and would otherwise kill a backgrounded curl before it
# finishes. Story: rig#<lag fix>.
api=~/.claude/metrics/usage-api.json
lock=~/.claude/metrics/usage-api.lock
if [ -z "$(find "$lock" -mmin -5 2>/dev/null)" ]; then
  mkdir -p ~/.claude/metrics; touch "$lock"
  setsid bash -c '
    tok=$(jq -r ".claudeAiOauth.accessToken // empty" ~/.claude/.credentials.json 2>/dev/null)
    [ -n "$tok" ] || exit 0
    curl -sf --max-time 8 https://api.anthropic.com/api/oauth/usage \
      -H "Authorization: Bearer $tok" -H "anthropic-beta: oauth-2025-04-20" -o "'"$api"'.tmp" \
      && jq -e ".limits" "'"$api"'.tmp" >/dev/null 2>&1 && mv "'"$api"'.tmp" "'"$api"'"
  ' </dev/null >/dev/null 2>&1 &
fi
scoped=$(jq -c '[.limits[]? | select(.kind == "weekly_scoped") | {model: .scope.model.display_name, percent, severity, resets_at}]' "$api" 2>/dev/null)
while IFS=$'\t' read -r name p; do
  [ -n "$name" ] && extra="${extra} | ${name} $(color_for "$p")${p}%\033[00m"
done < <(jq -r '.[] | "\(.model)\t\(.percent)"' <<<"${scoped:-[]}" 2>/dev/null)

printf '%b' "${prompt}${extra}"

# Trace: one line per change of any tracked value, only when this render carried live account fields
if [ -n "$five_live" ]; then
  log=~/.claude/metrics/usage.jsonl; mkdir -p ~/.claude/metrics
  row=$(echo "$input" | jq -c --argjson scoped "${scoped:-[]}" '{session:.session_id, model:.model.id, ctx_pct:(.context_window.used_percentage|floor),
      cost_usd:.cost.total_cost_usd, five_hour:.rate_limits.five_hour, seven_day:.rate_limits.seven_day, scoped:$scoped}')
  prev=$(tail -n 1 "$log" 2>/dev/null | jq -c 'del(.ts)' 2>/dev/null)
  [ "$row" != "$prev" ] && echo "$row" | jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{ts:$ts} + .' >> "$log"
fi

# Claude Code drops the whole render when this script exits non-zero; the trace test above is false on an unchanged row.
exit 0
