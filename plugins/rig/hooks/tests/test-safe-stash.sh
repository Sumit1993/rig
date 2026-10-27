#!/bin/bash
# Regression suite for safe-stash.sh (PreToolUse Bash).
# Blocks bare git stash, unnamed git stash push, and git stash pop.
# Allows named git stash push (-m/--message), git stash apply, and other safe subcommands.
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/safe-stash.sh"
fails=0
test_home=$(mktemp -d); test_bin=$(mktemp -d); noperl_bin=$(mktemp -d)
trap 'rm -rf "$test_home" "$test_bin" "$noperl_bin"' EXIT
# Private PATH of every system binary but mage (jq lives outside /usr/bin on Windows); noperl_bin also drops perl.
for d in /usr/local/bin /usr/bin /bin; do
  for f in "$d"/*; do
    n=${f##*/}
    case $n in mage|mage.*|jq|jq.*) continue ;; esac
    [ -e "$test_bin/$n" ] || ln -s "$f" "$test_bin/$n" 2>/dev/null
    case $n in perl|perl.*|perl5*) continue ;; esac
    [ -e "$noperl_bin/$n" ] || ln -s "$f" "$noperl_bin/$n" 2>/dev/null
  done
done
ln -s "$(command -v jq)" "$test_bin/jq"; ln -s "$(command -v jq)" "$noperl_bin/jq"
run_hook() { HOME="$test_home" PATH="${HOOK_PATH:-$test_bin}" bash "$HOOK"; }

check() { # name expected_rc json [expected_stderr_lines]
  local name=$1 want=$2 json=$3 got err lines
  err=$(printf '%s' "$json" | run_hook 2>&1 >/dev/null)
  got=$?
  if [ "$got" != "$want" ]; then
    echo "FAIL: $name (want rc=$want, got rc=$got)"; fails=$((fails + 1))
    return
  fi
  if [ $# -ge 4 ]; then
    lines=$(grep -c . <<<"$err" || true)
    if [ "$lines" -ne "$4" ]; then
      echo "FAIL: $name (want $4 stderr line(s), got $lines)"; fails=$((fails + 1))
      return
    fi
  fi
  echo "PASS: $name"
}

check_cmd() { # name expected_rc command
  local name=$1 want=$2 cmd=$3 json
  json=$(jq -n --arg c "$cmd" '{"tool_name":"Bash","tool_input":{"command":$c}}')
  check "$name" "$want" "$json"
}

echo "-- blocked: bare git stash and unnamed git stash push"
check_cmd "bare git stash blocks" 2 "git stash"
check_cmd "git stash -u blocks" 2 "git stash -u"
check_cmd "git stash --include-untracked blocks" 2 "git stash --include-untracked"
check_cmd "unnamed git stash push blocks" 2 "git stash push"
check_cmd "git -C path stash blocks" 2 "git -C /tmp/repo stash"
check_cmd "git -c k=v stash pop blocks" 2 "git -c color.ui=never stash pop"
check_cmd "git -C path stash push -m passes" 0 "git -C /tmp/repo stash push -m tag"
check_cmd "git stash save blocks" 2 "git stash save"
check_cmd "git --no-pager stash pop blocks" 2 "git --no-pager stash pop"
check_cmd "git -P stash blocks" 2 "git -P stash"
check_cmd "git --git-dir=.git stash blocks" 2 "git --git-dir=.git stash"
check_cmd "git --work-tree /x stash pop blocks" 2 "git --work-tree /x stash pop"
check_cmd "git --no-pager stash list passes" 0 "git --no-pager stash list"
check_cmd "unnamed git stash push -u blocks" 2 "git stash push -u"
check_cmd "unnamed git stash push path blocks" 2 "git stash push file.txt"
check_cmd "git stash push -m empty string blocks" 2 "git stash push -m ''"
check_cmd "git stash push --message= empty blocks" 2 "git stash push --message="

echo "-- blocked: git stash pop"
check_cmd "git stash pop blocks" 2 "git stash pop"
check_cmd "git stash pop with index blocks" 2 "git stash pop stash@{0}"
check_cmd "git stash pop --index blocks" 2 "git stash pop --index"

echo "-- allowed: named git stash push"
check_cmd "git stash push -u -m tag passes" 0 'git stash push -u -m "tag"'
check_cmd "git stash push -m tag passes" 0 'git stash push -m "tag"'
check_cmd "git stash push --message passes" 0 'git stash push --message "tag"'
check_cmd "git stash push --message=tag passes" 0 'git stash push --message=tag'
check_cmd "git stash push -m tag -u passes" 0 'git stash push -m tag -u'

echo "-- allowed: safe git stash subcommands"
check_cmd "git stash apply passes" 0 "git stash apply"
check_cmd "git stash apply stash@{0} passes" 0 "git stash apply stash@{0}"
check_cmd "git stash list passes" 0 "git stash list"
check_cmd "git stash show passes" 0 "git stash show"
check_cmd "git stash drop passes" 0 "git stash drop stash@{0}"
check_cmd "git stash clear passes" 0 "git stash clear"

echo "-- allowed: near misses and non-stash commands"
check_cmd "git status passes" 0 "git status"
check_cmd "echo git stash pop inside double quotes passes" 0 'echo "git stash pop"'
check_cmd "echo git stash inside single quotes passes" 0 "echo 'git stash'"
check_cmd "git commit -m message mentioning git stash pop passes" 0 'git commit -m "do not git stash pop"'

echo "-- compound commands"
check_cmd "compound command with git stash pop blocks" 2 "git status && git stash pop"
check_cmd "compound command with safe stash passes" 0 'git status && git stash push -u -m "tag"'

echo "-- allowed: malformed and empty stdin"
check "junk stdin does not block" 0 'junk'
check "empty payload does not block" 0 '{}'

echo "-- guard reporting: exits 2 with guard id when mage absent"
err=$(printf '{"tool_name":"Bash","tool_input":{"command":"git stash"}}' | run_hook 2>&1 >/dev/null)
rc=$?
if [ "$rc" -eq 2 ] && grep -q '^mage:rig/guard/safe-stash$' <<<"$err"; then
  echo "PASS: blocks with exit 2 and guard id on stderr when mage absent"
else
  echo "FAIL: guard report check failed (rc=$rc, err=$err)"; fails=$((fails + 1))
fi

echo "-- perl absent: a blocked command still exits 2"
HOOK_PATH=$noperl_bin check_cmd "git stash pop blocks without perl" 2 "git stash pop"
HOOK_PATH=$noperl_bin check_cmd "non-stash command passes without perl" 0 "git status"
echo "-- codex payload shape"
codex_json=$(jq -n '{session_id:"s",transcript_path:null,cwd:"/tmp",hook_event_name:"PreToolUse",model:"gpt-5-codex",permission_mode:"default",turn_id:"t",tool_name:"Bash",tool_use_id:"c",tool_input:{command:"git stash pop"}}')
check "codex payload for git stash pop blocks" 2 "$codex_json"
codex_pass=$(jq -n '{session_id:"s",transcript_path:null,cwd:"/tmp",hook_event_name:"PreToolUse",model:"gpt-5-codex",permission_mode:"default",turn_id:"t",tool_name:"Bash",tool_use_id:"c",tool_input:{command:"git stash apply"}}')
check "codex payload for git stash apply passes" 0 "$codex_pass"

[ "$fails" -eq 0 ] && echo && echo "all safe-stash hook tests passed"
exit "$fails"
