#!/bin/bash
# Regression suite: the Bash PreToolUse gate hook under Codex's own PreToolUse payload
# shape (session_id, transcript_path: null, cwd, hook_event_name, model, permission_mode,
# turn_id, tool_name: "Bash", tool_use_id, tool_input.command) rather than Claude's, asserting
# the same exit codes the Claude-shaped suites expect. Refs #141.
set -u
HOOKS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fails=0
CWD=$(mktemp -d)
cleanup() { rm -rf "$CWD"; }
trap cleanup EXIT

payload() { # <cwd> <cmd>
  jq -n --arg cwd "$1" --arg cmd "$2" '{
    session_id: "codex-sess-1",
    transcript_path: null,
    cwd: $cwd,
    hook_event_name: "PreToolUse",
    model: "gpt-5-codex",
    permission_mode: "default",
    turn_id: "turn-1",
    tool_name: "Bash",
    tool_use_id: "call-1",
    tool_input: {command: $cmd}
  }'
}

check() { # name hook want_rc cmd
  local name=$1 hook=$2 want=$3 cmd=$4 got
  payload "$CWD" "$cmd" | "$HOOKS_DIR/$hook" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (want rc=$want, got rc=$got)"; fails=$((fails + 1))
  fi
}

# Every hook must accept the Codex field set and stay a no-op on an unrelated command.
for h in no-broad-agy-kill.sh; do
  check "$h passes a plain ls under the Codex payload shape" "$h" 0 'ls -la'
done

check "no-broad-agy-kill.sh blocks a name-wide agy kill" no-broad-agy-kill.sh 2 'pkill -f agy'


[ "$fails" -eq 0 ] && echo && echo "all codex-payload hook tests passed"
exit "$fails"
