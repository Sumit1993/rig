#!/bin/bash
# Regression suite for kill-agy.sh and the watchdog fields it reads: agy_pid in the sidecar,
# the E1009 filter, and a spec inside the worktree not counting as dirty. Refs #177, #205.
set -u
SRC="$(cd "$(dirname "$0")/../../skills/farm-out" && pwd)"
KILL="$SRC/kill-agy.sh"; WATCHDOG="$SRC/run-agy-watchdog.sh"
fails=0; T=$(mktemp -d)
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fails=$((fails + 1)); fi; }

mkdir -p "$T/bin" "$T/logs" "$T/wt"
cat > "$T/bin/agy" <<'STUB'
#!/bin/sh
[ "$1" = "--version" ] && { echo "1.4.7"; exit 0; }
log=""; prev=""
for a in "$@"; do [ "$prev" = "--log-file" ] && log="$a"; prev="$a"; done
if [ "${STUB_AGY_MODE:-}" = "hang" ]; then
  i=0; while [ "$i" -lt 150 ]; do /bin/sleep 0.2; i=$((i + 1)); done; exit 0
fi
echo "E1009 12:00:00.000001 4242 file_watcher.go:194] skipping empty or temp file /x/.tmp123" >> "$log"
echo "I1009 12:00:01.000000 4242 agent.go:10] real step" >> "$log"
echo '{"status":"SUCCESS","conversation_id":"c1","num_turns":1,"response":"done"}'
STUB
printf '#!/bin/sh\n/bin/sleep 0.2\n' > "$T/bin/sleep"
chmod +x "$T/bin/agy" "$T/bin/sleep"
export PATH="$T/bin:$PATH" AGY_LOG_DIR="$T/logs" XDG_STATE_HOME="$T/state"
cleanup() { cd /; rm -rf "$T" 2>/dev/null; }
trap cleanup EXIT

git -C "$T/wt" init -q -b main
git -C "$T/wt" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
printf 'Evidence only.\nVerify: `true`\n' > "$T/wt/spec.md"

echo "-- 1. A clean evidence-only run"
bash "$WATCHDOG" "$T/wt" "$T/wt/spec.md" "$T/logs/agy-ev-1.json" 0 1m >/dev/null 2>&1
act="$T/logs/agy-ev-1.activity.log"
check "the E1009 temp-file noise is filtered" '! grep -q "skipping empty or temp file" "$act"'
check "the other log lines stay" 'grep -q "real step" "$act"'
check "an untracked spec in the worktree is not dirty" 'grep -q "AGY_EXITED .*commits=0 dirty=0 verify_rc=0" "$act"'
check "the sidecar records agy_pid" '[ -n "$(jq -r ".agy_pid // empty | numbers" "$T/logs/agy-ev-1.json.meta.json")" ]'
out=$(bash "$KILL" agy-ev-1 2>&1); rc=$?
check "a finished run is never killed (its pid may be reused)" '[ "$rc" -eq 0 ] && [[ "$out" == already\ exited* ]]'

echo "-- 2. A live run is killed by its own pid"
STUB_AGY_MODE=hang bash "$WATCHDOG" "$T/wt" "$T/wt/spec.md" "$T/logs/agy-live-1.json" 0 1m >/dev/null 2>"$T/wd.err" &
WD=$!
for _ in $(seq 1 50); do
  [ -n "$(jq -r '.agy_pid // empty' "$T/logs/agy-live-1.json.meta.json" 2>/dev/null)" ] && break
  /bin/sleep 0.2
done
pid=$(jq -r '.agy_pid // empty' "$T/logs/agy-live-1.json.meta.json" 2>/dev/null)
check "the stderr line carries the same pid" 'grep -q "^WATCHDOG: agy pid $pid slug " "$T/wd.err"'
out=$(bash "$KILL" agy-live-1 2>&1); rc=$?
check "kill-agy.sh <slug> kills that run" '[ "$rc" -eq 0 ] && [[ "$out" == killed:* ]]'
wait "$WD"
check "the watchdog still writes its sentinel" 'grep -q "^AGY_EXITED rc=137" "$T/logs/agy-live-1.activity.log"'

echo "-- 3. The stderr line is enough without a sidecar"
STUB_AGY_MODE=hang "$T/bin/agy" --log-file "$T/logs/agy-err-1.activity.log" -p x >/dev/null 2>&1 &
P=$!
echo "WATCHDOG: agy pid $P slug agy-spec-77-1700000000 activity $T/logs/agy-err-1.activity.log" > "$T/err.txt"
out=$(bash "$KILL" agy-spec-77-1700000000 "$T/err.txt" 2>&1); rc=$?
check "the pid is read from the WATCHDOG stderr line" '[ "$rc" -eq 0 ] && [[ "$out" == killed:\ agy\ pid\ $P* ]]'
wait "$P" 2>/dev/null

echo "-- 4. A pid that is not this run is refused"
/bin/sleep 20 &
S=$!
printf '{"slug":"agy-other-1","agy_pid":%s,"activity_log":"%s"}\n' "$S" "$T/logs/agy-other-1.activity.log" > "$T/logs/agy-other-1.json.meta.json"
out=$(bash "$KILL" agy-other-1 2>&1); rc=$?
check "a reused pid is refused and left alive" '[ "$rc" -eq 1 ] && kill -0 "$S" 2>/dev/null'
kill "$S" 2>/dev/null; wait "$S" 2>/dev/null
out=$(bash "$KILL" agy-nothing-1 2>&1); rc=$?
check "an unknown slug kills nothing" '[ "$rc" -eq 1 ] && [[ "$out" == refused:* ]]'
bash "$KILL" >/dev/null 2>&1; rc=$?
check "no argument is a usage error" '[ "$rc" -eq 2 ]'

[ "$fails" -eq 0 ] && echo "all kill-agy tests passed"; exit "$fails"
