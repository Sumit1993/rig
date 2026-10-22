#!/bin/bash
# Windows side of the machine, run by install.sh: the codex-desktop and claude-windows targets of
# harnesses.json, plus the Windows Codex global AGENTS.md. Idempotent. RIG_WIN_HOME overrides the profile (tests).
# From Git Bash on native Windows the profile is $HOME, already holding the claude and codex targets (#199).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/build-lib.sh"
common="$(cd "$HERE" && git rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "${RIG_SRC_ROOT:-}" ]; then DOT="$RIG_SRC_ROOT/dotfiles"
elif [ -n "$common" ]; then DOT="$(dirname "$(cd "$HERE" && cd "$common" && pwd)")/dotfiles"
else DOT="$HERE"; fi

NATIVE=
if [ -n "${RIG_WIN_HOME:-}" ]; then
  WIN_HOME="$RIG_WIN_HOME"
else
  case "$(uname -s)" in
    MINGW*|MSYS*) NATIVE=1; WIN_HOME="$HOME" ;;
    *) win_profile=$(grep -qi microsoft /proc/version 2>/dev/null && cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' || true)
       [ -n "$win_profile" ] || exit 0
       WIN_HOME=$(wslpath "$win_profile") ;;
  esac
fi
winpath() {
  if [ -n "$NATIVE" ]; then cygpath -w "$1"
  elif command -v wslpath >/dev/null 2>&1 && [ -z "${RIG_WIN_HOME:-}" ]; then wslpath -w "$1"
  else echo "$1"; fi
}

codex_win=$(ls -t "$WIN_HOME"/AppData/Local/OpenAI/Codex/bin/*/codex.exe 2>/dev/null | head -1 || true)
if [ -n "$NATIVE" ] && command -v codex >/dev/null 2>&1 && [ "${CODEX_HOME:-$HOME/.codex}" = "$WIN_HOME/.codex" ]; then
  # The app and the codex CLI share one ~/.codex here; installing codex-desktop would replace the codex target.
  echo "→ Windows codex plugin: skipped, the codex target already holds the ~/.codex the app reads"
elif [ -n "$codex_win" ] || [ -d "$WIN_HOME/.codex" ]; then
  echo "→ Windows codex plugin (harnesses.json target codex-desktop)"
  wb="$WIN_HOME/.rig/codex-plugin"
  bash "$HERE/build-codex-plugin.sh" "$wb" codex-desktop >/dev/null
  if [ -n "$codex_win" ]; then
    "$codex_win" plugin marketplace add "$(winpath "$wb")" >/dev/null 2>&1 || echo "  WARN: Windows codex marketplace add failed" >&2
    "$codex_win" plugin add rig@rig-local >/dev/null 2>&1 || echo "  WARN: Windows codex plugin add failed" >&2
  fi
  echo "→ Windows codex AGENTS.md (AGENTS.md + $(rig_field codex-desktop doctrine.overlay))"
  rig_write_doctrine "$WIN_HOME/.codex/AGENTS.md" codex-desktop "$DOT"
fi

if [ -z "$NATIVE" ] && [ -d "$WIN_HOME/.claude" ]; then
  echo "→ Windows Claude Code plugin (harnesses.json target claude-windows, no hooks)"
  cb="$WIN_HOME/.rig/claude-plugin"
  bash "$HERE/build-claude-plugin.sh" "$cb" claude-windows >/dev/null
  ws="$WIN_HOME/.claude/settings.json"; [ -f "$ws" ] || echo '{}' > "$ws"
  cp "$ws" "$ws.bak-$(date +%s)"
  jq --arg p "$(winpath "$cb")" --slurpfile f "$HERE/settings.fragment.json" '
    .extraKnownMarketplaces = ((.extraKnownMarketplaces // {} | del(.rig)) + ($f[0].extraKnownMarketplaces | del(.rig))
                               + {"rig-local": {source: {source: "directory", path: $p}}})
    | .enabledPlugins = ((.enabledPlugins // {} | del(."rig@rig")) + ($f[0].enabledPlugins | del(."rig@rig")) + {"rig@rig-local": true})' \
    "$ws" > "$ws.tmp" && jq -e . "$ws.tmp" >/dev/null && mv "$ws.tmp" "$ws"
fi
