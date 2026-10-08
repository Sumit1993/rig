#!/bin/bash
# run.sh CMD... runs to completion with stdin closed, then prints rc and an output tail that fits
# agy's ~4 KB tool-output cap. One quoted string runs through bash -c. LANE_TIMEOUT bounds it.
log=$(mktemp "${TMPDIR:-/tmp}/lane-run.XXXXXX.log")
if [ $# -eq 1 ]; then set -- bash -c "$1"; fi
timeout -k 10 "${LANE_TIMEOUT:-900}" "$@" < /dev/null > "$log" 2>&1
rc=$?
echo "rc=$rc  lines=$(wc -l < "$log")  full log: $log"
if [ "$rc" -eq 0 ]; then tail -8 "$log"; else grep -n -i -m 20 'fail\|error' "$log"; echo "--- tail"; tail -25 "$log"; fi | cut -c1-150
exit "$rc"
