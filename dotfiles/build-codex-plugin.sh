#!/bin/bash
# Codex plugin for one harnesses.json target (codex: WSL CLI, codex-desktop: the Windows app).
# hooks.json is filtered from the Claude file so commands never drift (#141); the manifest decides the rest.
set -euo pipefail
. "$(dirname "$0")/build-lib.sh"
OUT="${1:?usage: build-codex-plugin.sh <out-dir> [codex|codex-desktop]}"
TARGET="${2:-codex}"
[ "$(rig_field "$TARGET" install)" = codex-plugin ] || { echo "build-codex-plugin: $TARGET is not a codex-plugin target" >&2; exit 1; }
rig_check_all "$TARGET" || { echo "build-codex-plugin: $TARGET failed the manifest checks above" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT/.codex-plugin" "$OUT/.claude-plugin"
jq -n --arg v "$(jq -r .version "$RIG_SRC/.claude-plugin/plugin.json")" --arg d "$(jq -r .description "$RIG_SRC/.claude-plugin/plugin.json")" \
  '{name: "rig", version: $v, description: $d}' > "$OUT/.codex-plugin/plugin.json"
rig_copy_target "$TARGET" "$OUT"

# Entries under the target's events whose script the target ships; a matcher map renames CC-only tool names.
hooks=$(rig_list "$TARGET" hooks | jq -R . | jq -s .)
events=$(jq --arg t "$TARGET" '.targets[$t].hook_events // {}' "$RIG_MANIFEST")
if [ "$hooks" != "[]" ]; then
  jq --argjson keep "$hooks" --argjson ev "$events" '
    {hooks: (.hooks | with_entries(select($ev[.key] != null) | .key as $e
      | .value |= [.[] | select((.hooks[0].command | capture("hooks/(?<s>[^\"/ ]+\\.sh)").s) as $s | $keep | index($s))
                  | .matcher = ($ev[$e][.matcher // ""] // .matcher)])
      | with_entries(select(.value | length > 0)))}' "$RIG_SRC/hooks/hooks.json" > "$OUT/hooks/hooks.json"
fi

# codex plugin marketplace add reads .claude-plugin/marketplace.json, not a root file (CLI 0.154.0, #141).
jq -n \
  '{name: "rig-local", interface: {displayName: "rig (local)"}, plugins: [
    {name: "rig", source: {source: "local", path: "./"}, policy: {installation: "AVAILABLE", authentication: "ON_INSTALL"}, category: "Productivity"}
  ]}' > "$OUT/.claude-plugin/marketplace.json"
rig_stamp "$TARGET" "$OUT"
ls "$OUT/skills"
