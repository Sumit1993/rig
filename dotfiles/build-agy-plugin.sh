#!/bin/bash
# agy plugin from the agy target in harnesses.json: a root plugin.json and the target's skills. Hooks and agents
# stay out: agy's hook payload and agent frontmatter differ from Claude Code's. Story: rig#134.
set -euo pipefail
. "$(dirname "$0")/build-lib.sh"
OUT="${1:?usage: build-agy-plugin.sh <out-dir>}"
rig_check_all agy || { echo "build-agy-plugin: agy failed the manifest checks above" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT/skills"
jq -n --arg d "$(jq -r .description "$RIG_SRC/.claude-plugin/plugin.json")" \
  '{"$schema": "https://antigravity.google/schemas/v1/plugin.json", name: "rig", description: $d}' > "$OUT/plugin.json"
rig_copy_target agy "$OUT"
rig_stamp agy "$OUT"
ls "$OUT/skills"
