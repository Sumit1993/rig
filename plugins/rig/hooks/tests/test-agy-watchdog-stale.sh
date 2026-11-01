#!/bin/bash
# Regression suite for run-agy-watchdog.sh's fmt_stale(), extracted the same way
# test-retry-seconds.sh drives watch-coderabbit.sh's retry_seconds(): sourced without
# running the rest of the script (which launches agy and needs a real worktree). Refs #82.
set -u
SRC="$(cd "$(dirname "$0")/../../skills/farm-out" && pwd)/run-agy-watchdog.sh"
fails=0
bash -n "$SRC" || { echo "FAIL: run-agy-watchdog.sh has a syntax error"; exit 1; }
echo "PASS: run-agy-watchdog.sh syntax ok"

fn=$(mktemp); sed -n '/^fmt_stale()/,/^}$/p' "$SRC" > "$fn"
trap 'rm -f "$fn"' EXIT
[ -s "$fn" ] || { echo "FAIL: fmt_stale() not found in $SRC"; exit 1; }

check() { # name seconds want
  local name=$1 secs=$2 want=$3 out
  out=$(bash -c 'set -u; source "$1"; fmt_stale "$2"' _ "$fn" "$secs")
  if [ "$out" = "$want" ]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (want $want, got $out)"; fails=$((fails + 1))
  fi
}

check "3 minutes 12 seconds" 192 "3m12s"
check "exactly one minute" 60 "1m0s"
check "under a minute" 45 "0m45s"
check "zero" 0 "0m0s"
check "over an hour still m/s (watchdog kills well under an hour)" 3661 "61m1s"

# Live runs against a fake agy: a run hung after its work is reaped before its timeout, and one
# with a live child is left alone. Uses pgrep, or the Windows PID on Git Bash (#208).
L=$(mktemp -d); trap 'rm -f "$fn"; rm -rf "$L"' EXIT
mkdir -p "$L/bin" "$L/wt"
cat > "$L/bin/agy" <<'FAKE'
#!/bin/bash
[ "${1:-}" = --version ] && { echo "agy fake"; exit 0; }
while [ $# -gt 0 ]; do [ "$1" = --log-file ] && log=$2; shift; done
echo started >> "$log"
if [ "$FAKE_MODE" = child ]; then sleep 12 & wait; else exec sleep 60; fi
FAKE
chmod +x "$L/bin/agy"
git -C "$L/wt" init -q && git -C "$L/wt" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
echo "work order" > "$L/spec.md"
live() { # mode
  local start; start=$(date +%s)
  FAKE_MODE=$1 PATH="$L/bin:$PATH" RIG_WATCHDOG_POLL=1 RIG_WATCHDOG_STALE=2 bash "$SRC" "$L/wt" "$L/spec.md" "$L/$1.json" 0 600 2>/dev/null
  echo $(( $(date +%s) - start ))
}
secs=$(live quiet)
if grep -q "killed hung agy" "$L/quiet.activity.log" && [ "$secs" -lt 30 ]; then echo "PASS: a hung run with no child is reaped before its timeout (${secs}s)"
else echo "FAIL: hung run not reaped (${secs}s): $(tail -2 "$L/quiet.activity.log")"; fails=$((fails + 1)); fi
live child >/dev/null
if ! grep -q "killed hung agy" "$L/child.activity.log" && grep -q "AGY_EXITED rc=0" "$L/child.activity.log"; then echo "PASS: a run with a live child is not reaped"
else echo "FAIL: a run with a live child was reaped: $(tail -2 "$L/child.activity.log")"; fails=$((fails + 1)); fi

[ "$fails" -eq 0 ] && { echo; echo "all agy-watchdog staleness tests passed"; exit 0; }
echo "$fails failure(s)"; exit 1
