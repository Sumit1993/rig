#!/bin/bash
# Usage: kill-agy.sh <slug|envelope.json> [watchdog-stderr-file]
# Stops one agy run by the pid run-agy-watchdog.sh recorded for it, never by name.
# The pid comes from <envelope>.meta.json (agy_pid), else from the watchdog's
# "WATCHDOG: agy pid <pid> slug <slug> activity <log>" stderr line. Exit 0 killed or
# already gone, 1 refused (pid not provably this run's), 2 usage.
set -u
ARG="${1:-}"; ERRFILE="${2:-}"
[ -n "$ARG" ] || { echo "usage: kill-agy.sh <slug|envelope.json> [watchdog-stderr-file]" >&2; exit 2; }
LOGS="${AGY_LOG_DIR:-$HOME/ai-context/agy-logs}"

META=""
case "$ARG" in
  *.json) META="$ARG.meta.json" ;;
  *) [ -f "$LOGS/$ARG.json.meta.json" ] && META="$LOGS/$ARG.json.meta.json" ;;
esac
if [ -z "$META" ] || [ ! -f "$META" ]; then
  META=$(grep -lF "\"slug\": \"$ARG\"" "$LOGS"/*.meta.json 2>/dev/null | head -1)
fi

PID=""; ACT=""
if [ -n "$META" ] && [ -f "$META" ]; then
  if [ -n "$(jq -r '.ended_at // empty' "$META" 2>/dev/null)" ]; then
    echo "already exited: $ARG ($META has ended_at); nothing to kill"; exit 0
  fi
  PID=$(jq -r '.agy_pid // empty' "$META" 2>/dev/null)
  ACT=$(jq -r '.activity_log // empty' "$META" 2>/dev/null)
fi
if [ -z "$PID" ] && [ -n "$ERRFILE" ]; then
  line=$(grep -E "^WATCHDOG: agy pid [0-9]+ slug [^ ]+ activity " "$ERRFILE" 2>/dev/null \
    | grep -F -e " slug $ARG " -e "activity $ARG" | tail -1)
  [ -n "$line" ] || line=$(grep -E "^WATCHDOG: agy pid [0-9]+ slug " "$ERRFILE" 2>/dev/null | tail -1)
  PID=$(sed -E 's/^WATCHDOG: agy pid ([0-9]+) .*/\1/' <<<"$line")
  ACT=$(sed -E 's/.* activity (.*)$/\1/' <<<"$line")
fi
case "$PID" in ''|*[!0-9]*) echo "refused: no recorded agy pid for $ARG; not killing" >&2; exit 1 ;; esac

kill -0 "$PID" 2>/dev/null || { echo "not running: agy pid $PID ($ARG); nothing to kill"; exit 0; }

# A pid can be reused; it is ours only if its argv carries this run's --log-file. Issue #205.
argv=$(tr '\0' ' ' < "/proc/$PID/cmdline" 2>/dev/null) || argv=""
[ -n "$argv" ] || argv=$(ps -p "$PID" -o args= 2>/dev/null)
mark=$(basename "${ACT:-}")
if [ -z "$mark" ] || [ -z "$argv" ] || [[ "$argv" != *"$mark"* ]]; then
  echo "refused: pid $PID does not carry ${mark:-a known activity log} on its argv; not killing" >&2
  exit 1
fi
kill -9 "$PID" 2>/dev/null || { echo "refused: kill -9 $PID failed" >&2; exit 1; }
echo "killed: agy pid $PID ($ARG)"
