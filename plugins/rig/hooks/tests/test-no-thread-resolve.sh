#!/bin/bash
# Regression suite for no-thread-resolve.sh (PreToolUse Bash).
# Blocks gh api calls executing resolveReviewThread; allows read queries, other mutations, and near misses.
set -u
HOOK="$(cd "$(dirname "$0")/.." && pwd)/no-thread-resolve.sh"
fails=0

check() { # name expected_rc json [expected_stderr_lines]
  local name=$1 want=$2 json=$3 got err lines
  err=$(printf '%s' "$json" | "$HOOK" 2>&1 >/dev/null)
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

check_cmd() { # name expected_rc cmd
  local name=$1 want=$2 cmd=$3 json
  json=$(jq -n --arg c "$cmd" '{"tool_name":"Bash","tool_input":{"command":$c}}')
  check "$name" "$want" "$json"
}

check_codex() { # name expected_rc cmd
  local name=$1 want=$2 cmd=$3 json
  json=$(jq -n --arg c "$cmd" '{
    session_id: "codex-sess-1",
    transcript_path: null,
    cwd: "/tmp",
    hook_event_name: "PreToolUse",
    model: "gpt-5-codex",
    permission_mode: "default",
    turn_id: "turn-1",
    tool_name: "Bash",
    tool_use_id: "call-1",
    tool_input: {command: $c}
  }')
  check "$name (Codex payload)" "$want" "$json"
}

echo "-- blocked: resolveReviewThread via gh api"
check_cmd "gh api graphql with resolveReviewThread query blocks" 2 \
  'gh api graphql -f query='\''mutation { resolveReviewThread(input: {threadId: "PRRT_1"}) { thread { isResolved } } }'\'''
check_cmd "gh api graphql with variable resolveReviewThread blocks" 2 \
  'gh api graphql -f query="mutation($id: ID!) { resolveReviewThread(input: {threadId: $id}) { thread { id } } }" -f id=PRRT_1'
check_cmd "gh api graphql with here-string mutation blocks" 2 \
  'cd repo && gh api graphql -F query=@- <<< '\''mutation { resolveReviewThread(input:{threadId:"x"}) { clientMutationId } }'\'''
check_cmd "gh api graphql with env prefix blocks" 2 \
  'GH_TOKEN=x gh api graphql -f query='\''mutation{resolveReviewThread(input:{threadId:"y"}){clientMutationId}}'\'''

echo "-- allowed: query reviewThreads, thread reply mutation, and near misses"
check_cmd "read query for reviewThreads passes" 0 \
  'gh api graphql -f query='\''{ repository(owner:"o",name:"r") { pullRequest(number:1) { reviewThreads(first:50) { nodes { isResolved } } } } }'\'''
check_cmd "addPullRequestReviewThreadReply mutation passes" 0 \
  'gh api graphql -f query='\''mutation { addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:"x", body:"Fixed in abc"}) { comment { id } } }'\'''
check_cmd "echo mentioning resolveReviewThread passes" 0 \
  'echo "the session never runs resolveReviewThread"'
check_cmd "gh pr view reviewThreads passes" 0 \
  'gh pr view 1 --json reviewThreads'
check_cmd "grep resolveReviewThread passes" 0 \
  'grep -rn resolveReviewThread plugins/'
check_cmd "unrelated command passes" 0 \
  'ls -la'

echo "-- allowed with stderr warning: junk stdin"
check "junk stdin does not block and emits one stderr line" 0 'junk' 1
check "empty payload does not block" 0 '{}'

echo "-- codex payload shape"
check_codex "codex payload with resolveReviewThread blocks" 2 \
  'gh api graphql -f query='\''mutation { resolveReviewThread(input: {threadId: "PRRT_1"}) { thread { isResolved } } }'\'''
check_codex "codex payload with read query passes" 0 \
  'gh api graphql -f query='\''{ repository(owner:"o",name:"r") { pullRequest(number:1) { reviewThreads(first:50) { nodes { isResolved } } } } }'\'''

echo "-- guard reporting: exits 2 with guard id when mage absent"
payload=$(jq -nc --arg c 'gh api graphql -f query="mutation { resolveReviewThread(input:{threadId: x }) { clientMutationId } }"' '{"tool_name":"Bash","tool_input":{"command":$c}}')
err=$(printf '%s' "$payload" | PATH=/usr/bin:/bin "$HOOK" 2>&1 >/dev/null)
rc=$?
if [ "$rc" -eq 2 ] && grep -q '^mage:rig/guard/no-thread-resolve$' <<<"$err"; then
  echo "PASS: blocks with exit 2 and guard id on stderr when mage absent"
else
  echo "FAIL: guard report check failed (rc=$rc, err=$err)"; fails=$((fails + 1))
fi

# Prose that names the mutation next to an unrelated gh api call must pass.
for c in 'git commit -qam "the read before resolveReviewThread" && gh api repos/o/r/pulls/1/comments' \
  'gh api repos/o/r/issues/1/comments -f body="we never call resolveReviewThread"'; do
  rc=0; printf '%s' "$(jq -nc --arg c "$c" '{tool_name:"Bash",tool_input:{command:$c}}')" | bash "$HOOK" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then echo "PASS: prose mention passes: ${c:0:40}"; else echo "FAIL: prose mention blocked (rc=$rc): $c"; fails=$((fails + 1)); fi
done
[ "$fails" -eq 0 ] && echo && echo "all no-thread-resolve hook tests passed"
exit "$fails"
