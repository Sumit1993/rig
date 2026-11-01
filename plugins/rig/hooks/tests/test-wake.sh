#!/bin/bash
# wake.sh: a tick runs one harness turn under a lock and stamps it; arm renders each OS's
# scheduler config. On Windows the real Task Scheduler round trip runs too.
set -u
W="$(cd "$(dirname "$0")/../../scripts" && pwd)/wake.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export RIG_WAKE_STATE="$T/state"
fails=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fails=$((fails+1)); fi; }
bash -n "$W"; check "syntax ok" '[ $? -eq 0 ]'

printf '#!/bin/bash\necho "runner harness=$1 session=$2"; echo "$3" > "%s/prompt"\n' "$T" > "$T/runner"; chmod +x "$T/runner"
echo "# plan" > "$T/plan.md"
for os in windows macos linux; do
  out=$(bash "$W" arm t1 30 "$T/plan.md" --os "$os" --dry-run 2>&1)
  case $os in
    windows) check "windows config wakes the machine and catches up a missed run" 'grep -q "<WakeToRun>true" <<<"$out" && grep -q "<StartWhenAvailable>true" <<<"$out" && grep -q "PT30M" <<<"$out"' ;;
    macos) check "macos config runs every 1800 s" 'grep -q "<integer>1800</integer>" <<<"$out"' ;;
    linux) check "linux timer is persistent and wakes the system" 'grep -q "OnCalendar=\*:0/30" <<<"$out" && grep -q Persistent=true <<<"$out" && grep -q WakeSystem=true <<<"$out"' ;;
  esac
done
check "dry run writes no state" '[ ! -e "$T/state/t1" ]'
check "a bad name is refused" '! bash "$W" arm "a b" 30 "$T/plan.md" --dry-run 2>/dev/null'
check "under 5 minutes is refused" '! bash "$W" arm t1 2 "$T/plan.md" --dry-run 2>/dev/null'
check "an unknown harness is refused" '! bash "$W" arm t1 30 "$T/plan.md" --harness agy --dry-run 2>/dev/null'

# State as arm writes it, without touching the OS scheduler.
mkdir -p "$T/state/t2"; echo "$T/plan.md" > "$T/state/t2/plan"; echo codex > "$T/state/t2/harness"
printf 'sid-1' > "$T/state/t2/session"; echo "$T" > "$T/state/t2/cwd"
RIG_WAKE_RUNNER="$T/runner" bash "$W" tick t2
check "tick runs the harness with its session" 'grep -q "runner harness=codex session=sid-1" "$T/state/t2/log"'
check "tick prompt names the plan file and the last tick" 'grep -q "$T/plan.md" "$T/prompt" && grep -q "Last tick: never" "$T/prompt"'
check "tick stamps itself and records the exit" '[ -s "$T/state/t2/last" ] && grep -q "TICK_DONE rc=0" "$T/state/t2/log"'
RIG_WAKE_RUNNER="$T/runner" bash "$W" tick t2
check "the next tick sees the last one" '! grep -q "Last tick: never" "$T/prompt"'
mkdir "$T/state/t2/lock"
RIG_WAKE_RUNNER="$T/runner" bash "$W" tick t2
check "a tick while one runs is skipped, not stacked" 'grep -q "skipped: previous tick still running" "$T/state/t2/log" && [ -d "$T/state/t2/lock" ]'
rmdir "$T/state/t2/lock"
check "status reports the harness and plan" 'bash "$W" status t2 | grep -q "t2: codex plan="'
check "status of an unknown name fails" '! bash "$W" status nope >/dev/null'

case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)
  n="rigtest$$"
  bash "$W" arm "$n" 60 "$T/plan.md" >/dev/null 2>&1
  check "windows: arm registers a Task Scheduler task" 'MSYS_NO_PATHCONV=1 schtasks.exe /query /tn "rig-wake-$n" /xml 2>/dev/null | tr -d "\0" | grep -q "<WakeToRun>true"'
  bash "$W" disarm "$n" >/dev/null 2>&1
  check "windows: disarm removes it and the state" '! MSYS_NO_PATHCONV=1 schtasks.exe /query /tn "rig-wake-$n" >/dev/null 2>&1 && [ ! -e "$T/state/$n" ]' ;;
esac

[ "$fails" -eq 0 ] && { echo; echo "all wake tests passed"; exit 0; }
echo "$fails failure(s)"; exit 1
