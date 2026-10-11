#!/bin/bash
# A directory-marketplace Claude Code plugin for a harnesses.json target that cannot use the GitHub
# marketplace whole (claude-windows). Layout: <out>/.claude-plugin/marketplace.json + <out>/plugins/rig.
set -euo pipefail
. "$(dirname "$0")/build-lib.sh"
OUT="${1:?usage: build-claude-plugin.sh <out-dir> [claude-windows]}"
TARGET="${2:-claude-windows}"
[ "$(rig_field "$TARGET" install)" = claude-directory-marketplace ] || { echo "build-claude-plugin: $TARGET is not a directory-marketplace target" >&2; exit 1; }
rig_check_all "$TARGET" || { echo "build-claude-plugin: $TARGET failed the manifest checks above" >&2; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT/plugins/rig/.claude-plugin" "$OUT/.claude-plugin"
cp "$RIG_SRC/.claude-plugin/plugin.json" "$OUT/plugins/rig/.claude-plugin/"
rig_copy_target "$TARGET" "$OUT/plugins/rig"
jq -n '{name: "rig-local", owner: {name: "rig"}, plugins: [{name: "rig", source: "./plugins/rig"}]}' > "$OUT/.claude-plugin/marketplace.json"
rig_stamp "$TARGET" "$OUT/plugins/rig"
ls "$OUT/plugins/rig/skills"
