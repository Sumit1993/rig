#!/bin/bash
# Windows side of a WSL machine, run by install.sh: the same skills for Windows Codex and Claude
# Code. Hooks stay out because they are bash scripts reading WSL paths. Idempotent.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RIG="$HERE/../plugins/rig"
win_profile=$(grep -qi microsoft /proc/version 2>/dev/null && cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' || true)
if [ -n "$win_profile" ]; then
  WIN_HOME=$(wslpath "$win_profile")
  codex_win=$(ls -t "$WIN_HOME"/AppData/Local/OpenAI/Codex/bin/*/codex.exe 2>/dev/null | head -1 || true)
  if [ -n "$codex_win" ]; then
    echo "→ Windows codex plugin (same build, no hooks)"
    wb="$WIN_HOME/.rig/codex-plugin"
    bash "$HERE/build-codex-plugin.sh" "$wb" >/dev/null && rm -rf "$wb/hooks"
    "$codex_win" plugin marketplace add "$(wslpath -w "$wb")" >/dev/null 2>&1 || echo "  WARN: Windows codex marketplace add failed" >&2
    "$codex_win" plugin add rig@rig-local >/dev/null 2>&1 || echo "  WARN: Windows codex plugin add failed" >&2
  fi
  if [ -d "$WIN_HOME/.claude" ]; then
    echo "→ Windows Claude Code plugin (skills and agents, no hooks)"
    cb="$WIN_HOME/.rig/claude-plugin"
    rm -rf "$cb"; mkdir -p "$cb/plugins/rig/.claude-plugin"
    cp -r "$RIG/skills" "$RIG/agents" "$cb/plugins/rig/"
    cp "$RIG/.claude-plugin/plugin.json" "$cb/plugins/rig/.claude-plugin/"
    mkdir -p "$cb/.claude-plugin"
    jq -n '{name: "rig-local", owner: {name: "rig"}, plugins: [{name: "rig", source: "./plugins/rig"}]}' > "$cb/.claude-plugin/marketplace.json"
    ws="$WIN_HOME/.claude/settings.json"; [ -f "$ws" ] || echo '{}' > "$ws"
    cp "$ws" "$ws.bak-$(date +%s)"
    jq --arg p "$(wslpath -w "$cb")" --slurpfile f "$HERE/settings.fragment.json" '
      .extraKnownMarketplaces = ((.extraKnownMarketplaces // {} | del(.rig)) + ($f[0].extraKnownMarketplaces | del(.rig))
                                 + {"rig-local": {source: {source: "directory", path: $p}}})
      | .enabledPlugins = ((.enabledPlugins // {} | del(."rig@rig")) + ($f[0].enabledPlugins | del(."rig@rig")) + {"rig@rig-local": true})' \
      "$ws" > "$ws.tmp" && jq -e . "$ws.tmp" >/dev/null && mv "$ws.tmp" "$ws"
  fi
fi

