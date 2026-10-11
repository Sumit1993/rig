#!/bin/bash
# Builds every harnesses.json target into a temp dir and checks what crossed, the manifest checks
# that fail a build, and two shipped hooks run from the built Codex plugin. Refs #169.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
D="$ROOT/dotfiles"
fails=0; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fails=$((fails+1)); fi; }
. "$D/build-lib.sh"
listed() { rig_list "$1" "$2" | sort | tr '\n' ' '; }

# --- every target builds
bash "$D/build-codex-plugin.sh" "$T/codex" codex >/dev/null 2>"$T/err"; check "codex builds $(head -c 300 "$T/err")" '[ -d "$T/codex/skills" ]'
bash "$D/build-codex-plugin.sh" "$T/desk" codex-desktop >/dev/null 2>&1; check "codex-desktop builds" '[ -d "$T/desk/skills" ]'
bash "$D/build-agy-plugin.sh" "$T/agy" >/dev/null 2>&1; check "agy builds" '[ -f "$T/agy/plugin.json" ]'
bash "$D/build-claude-plugin.sh" "$T/cw" claude-windows >/dev/null 2>&1; check "claude-windows builds" '[ -f "$T/cw/.claude-plugin/marketplace.json" ]'
check "a target of another kind is refused" '! bash "$D/build-codex-plugin.sh" "$T/x" agy >/dev/null 2>&1'

# --- what crossed equals the manifest
for pair in codex:"$T/codex" codex-desktop:"$T/desk" agy:"$T/agy" claude-windows:"$T/cw/plugins/rig"; do
  t=${pair%%:*}; dir=${pair#*:}
  check "$t skills are exactly the manifest's" '[ "$(ls "$dir/skills" | sort | tr "\n" " ")" = "$(listed "$t" skills)" ]'
  check "$t carries a build stamp" 'jq -e --arg t "$t" ".target == \$t and (.commit | length > 6)" "$dir/.rig-build.json" >/dev/null'
  check "$t ships no skill tests" '[ -z "$(find "$dir/skills" -type d \( -name tests -o -name __pycache__ \))" ]'
done
check "codex hooks are exactly the manifest's" '[ "$(ls "$T/codex/hooks"/*.sh | xargs -n1 basename | sort | tr "\n" " ")" = "$(listed codex hooks)" ]'
check "codex gets every hooks/lib file (json.sh included)" '[ -f "$T/codex/hooks/lib/json.sh" ] && [ -f "$T/codex/hooks/lib/gh-command.sh" ] && [ -f "$T/codex/hooks/lib/report-guard.sh" ]'
check "codex gets rig-meta.sh with its registry, and cr-reply.sh" '[ -x "$T/codex/scripts/rig-meta.sh" ] && [ -f "$T/codex/data/repo-meta.json" ] && [ -x "$T/codex/scripts/cr-reply.sh" ]'
check "codex hooks.json registers only PreToolUse" 'jq -e "(.hooks | keys) == [\"PreToolUse\"]" "$T/codex/hooks/hooks.json" >/dev/null'
check "codex matchers are Bash or Agent only (outside-view-nudge mapped)" \
  'jq -e "[.hooks.PreToolUse[].matcher] | all(. == \"Bash\" or . == \"Agent\")" "$T/codex/hooks/hooks.json" >/dev/null'
check "every codex hooks.json command has its script" \
  '[ -z "$(jq -r ".hooks[][].hooks[].command" "$T/codex/hooks/hooks.json" | sed -E "s#.*hooks/([^\"]+)\".*#\1#" | while read -r h; do [ -f "$T/codex/hooks/$h" ] || echo "$h"; done)" ]'
check "no agents cross to codex, codex-desktop or agy" '[ ! -e "$T/codex/agents" ] && [ ! -e "$T/desk/agents" ] && [ ! -e "$T/agy/agents" ]'
check "codex-desktop and agy get no hooks" '[ ! -e "$T/desk/hooks" ] && [ ! -e "$T/agy/hooks" ]'
check "claude-windows drops farm-out, lane and agy-runner" \
  '[ ! -e "$T/cw/plugins/rig/skills/farm-out" ] && [ ! -e "$T/cw/plugins/rig/skills/lane" ] && [ ! -e "$T/cw/plugins/rig/agents/agy-runner.md" ]'
check "no SKILL.md keeps a metadata.harnesses tag" '! grep -lE "^[[:space:]]+harnesses:" "$ROOT"/plugins/rig/skills/*/SKILL.md'

# --- the checks that fail a build (a manifest copy with one change each)
variant() { jq "$1" "$D/harnesses.json" > "$T/m.json"; }
variant '.targets |= with_entries(.value.skills -= ["tweet"])'
check "a skill in no target and not unshipped fails" '! RIG_MANIFEST="$T/m.json" bash -c ". \"$D/build-lib.sh\"; rig_check_manifest" 2>/dev/null'
variant '(.targets |= with_entries(.value.skills -= ["tweet"])) | .unshipped.skills.tweet = "test"'
check "the same skill under unshipped passes" 'RIG_MANIFEST="$T/m.json" bash -c ". \"$D/build-lib.sh\"; rig_check_manifest" 2>/dev/null'
variant '.targets.codex.skills += ["no-such-skill"]'
check "a declared skill that does not exist fails" '! RIG_MANIFEST="$T/m.json" bash -c ". \"$D/build-lib.sh\"; rig_check_manifest" 2>/dev/null'
variant '.targets.claude.hooks -= ["merge-gate.sh"] | .targets.codex.hooks -= ["merge-gate.sh"] | .unshipped.hooks["merge-gate.sh"] = "test"'
check "claude hooks must match hooks.json" '! RIG_MANIFEST="$T/m.json" bash -c ". \"$D/build-lib.sh\"; rig_check_manifest" 2>/dev/null'
variant '.targets.codex.skills -= ["coderabbit-lane"]'
out=$(RIG_MANIFEST="$T/m.json" bash "$D/build-codex-plugin.sh" "$T/y" codex 2>&1 >/dev/null)
check "codex without coderabbit-lane fails closure (compass names it)" '[ -n "$out" ] && grep -q "names skill coderabbit-lane" <<<"$out"'
variant '.targets.codex.runtime -= ["scripts/cr-reply.sh"]'
out=$(RIG_MANIFEST="$T/m.json" bash "$D/build-codex-plugin.sh" "$T/y" codex 2>&1 >/dev/null)
check "codex without cr-reply.sh fails closure" 'grep -q "uses scripts/cr-reply.sh" <<<"$out"'
variant '.targets.codex.runtime -= ["hooks/lib/json.sh"]'
out=$(RIG_MANIFEST="$T/m.json" bash "$D/build-codex-plugin.sh" "$T/y" codex 2>&1 >/dev/null)
check "codex without json.sh fails closure" 'grep -q "uses hooks/lib/json.sh" <<<"$out"'
variant '.targets.codex.allow_refs = {}'
out=$(RIG_MANIFEST="$T/m.json" bash "$D/build-codex-plugin.sh" "$T/y" codex 2>&1 >/dev/null)
check "an allow_refs entry is what lets no-doze point at autopilot" 'grep -q "no-doze.*names skill autopilot" <<<"$out"'

# --- shipped hooks run from the built Codex plugin, Codex payload shape
mkdir -p "$T/home" "$T/bin" "$T/repo"
git -C "$T/repo" init -q && git -C "$T/repo" remote add origin https://github.com/prismalens/sreforge.git
printf '#!/bin/bash\necho "chore(main): release 1.2.0"\n' > "$T/bin/gh"; chmod +x "$T/bin/gh"
payload() { jq -n --arg cwd "$T/repo" --arg cmd "$1" '{session_id: "s", transcript_path: null, cwd: $cwd,
  hook_event_name: "PreToolUse", model: "gpt-6.1-sol", turn_id: "t", tool_name: "Bash", tool_use_id: "c", tool_input: {command: $cmd}}'; }
run_built() { payload "$2" | HOME="$T/home" PATH="$T/bin:$PATH" CLAUDE_PLUGIN_ROOT="$T/codex" "$T/codex/hooks/$1" >/dev/null 2>&1; echo $?; }
err=$(payload "gh pr merge 7 --merge" | HOME="$T/home" PATH="$T/bin:$PATH" CLAUDE_PLUGIN_ROOT="$T/codex" "$T/codex/hooks/release-docs-gate.sh" 2>&1 >/dev/null)
check "built release-docs-gate blocks a stale release merge on the audit, not blind" 'grep -q "no docs audit in the last 14 days" <<<"$err"'
check "built release-docs-gate passes a non-merge" '[ "$(run_built release-docs-gate.sh "git status")" = 0 ]'
mv "$T/codex/scripts/rig-meta.sh" "$T/rig-meta.off"
check "built release-docs-gate blocks when rig-meta.sh is gone" '[ "$(run_built release-docs-gate.sh "gh pr merge 7 --merge")" = 2 ]'
mv "$T/rig-meta.off" "$T/codex/scripts/rig-meta.sh"; rm "$T/codex/hooks/lib/json.sh"
check "built release-docs-gate blocks when json.sh is gone" '[ "$(run_built release-docs-gate.sh "gh pr merge 7 --merge")" = 2 ]'
check "built merge-gate blocks a merge with no MERGE_OK" '[ "$(run_built merge-gate.sh "gh pr merge 7 --merge")" = 2 ]'
check "built merge-gate passes MERGE_OK naming the PR" '[ "$(run_built merge-gate.sh "MERGE_OK=7 gh pr merge 7 --merge")" = 0 ]'

if command -v agy >/dev/null 2>&1; then
  out=$(HOME="$T/home" timeout 30 agy plugin validate "$T/agy" 2>&1)
  check "agy plugin validate passes" 'grep -q "\[ok\]" <<<"$out" && ! grep -qi "error" <<<"$out"'
else
  echo "SKIP: agy not installed, plugin validate not run"
fi

[ "$fails" -eq 0 ] && echo "all builder tests passed"; exit "$fails"
