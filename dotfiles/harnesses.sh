#!/bin/bash
# Applies and checks dotfiles/harnesses.json, the one list of what each harness has installed (#169).
# Each harness is driven through its own mechanism: Claude Code through settings.json, which it
# installs from at launch; agy and Codex through their CLIs. Usage: harnesses.sh fragment|apply|check
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
M="${HARNESSES_JSON:-$HERE/harnesses.json}"
CLAUDE_JSON="${CLAUDE_JSON:-$HOME/.claude.json}"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
AGY_MCP="${AGY_MCP:-$HOME/.gemini/config/mcp_config.json}"
AGY_PLUGINS="${AGY_PLUGINS:-$HOME/.gemini/config/plugins}"
BUILT_IN_MARKETPLACES="claude-plugins-official"

# agy spawns a child that holds stdout open, so it runs detached with a bound.
agy_() { setsid -w timeout -k 5 60 agy "$@" < /dev/null 2>&1; }

fragment() {
  jq '.claude | {
    extraKnownMarketplaces: (.marketplaces | map_values({source: {source: "github", repo: .repo}, autoUpdate: .autoUpdate})),
    enabledPlugins: (.plugins | map({key: ., value: true}) | from_entries)
  }' "$M"
}

mcp_args() { jq -r --arg h "$1" --arg n "$2" '.[$h].mcp[$n] | [.command] + (.args // []) | .[]' "$M"; }

apply() {
  local n
  for n in $(jq -r '.claude.mcp | keys[]' "$M"); do
    jq -e --arg n "$n" '.mcpServers[$n]' "$CLAUDE_JSON" >/dev/null 2>&1 && continue
    mapfile -t a < <(mcp_args claude "$n"); claude mcp add -s user "$n" -- "${a[@]}" < /dev/null
  done
  if command -v agy >/dev/null 2>&1; then
    for n in $(jq -r '.agy.mcp | keys[]' "$M"); do
      jq -e --arg n "$n" '.mcpServers[$n]' "$AGY_MCP" >/dev/null 2>&1 && continue
      mapfile -t a < <(mcp_args agy "$n"); agy_ mcp add "$n" "${a[@]}"
    done
  fi
  if command -v codex >/dev/null 2>&1; then
    for n in $(jq -r '.codex.mcp | keys[]' "$M"); do
      codex mcp list --json < /dev/null 2>/dev/null | jq -e --arg n "$n" 'map(.name) | index($n)' >/dev/null && continue
      mapfile -t a < <(mcp_args codex "$n"); codex mcp add "$n" -- "${a[@]}" < /dev/null
    done
  fi
}

drift=0
report() { echo "DRIFT $1"; drift=1; }
# Plugins from a marketplace the account syncs (claude.ai, ChatGPT) are the account's, not rig's.
drop_account() { grep -v -E "@($(jq -r --arg h "$1" '.[$h].account_marketplaces // ["-"] | join("|")' "$M"))\$" || true; }
# A config file that exists but won't parse is drift, never an empty inventory (#169).
mcp_check() { # label declared config
  local got=""
  [ ! -e "$3" ] || got=$(jq -r '.mcpServers // {} | keys[]' "$3" 2>/dev/null) || { report "$1: cannot read $3"; return; }
  compare "$1" "$2" "$got"
}
compare() { # label declared installed
  local x
  for x in $(comm -23 <(sort -u <<<"$2") <(sort -u <<<"$3")); do report "$1: $x declared, not installed"; done
  for x in $(comm -13 <(sort -u <<<"$2") <(sort -u <<<"$3")); do report "$1: $x installed, not declared"; done
}

check() {
  compare "claude plugin" "$(jq -r '.claude.plugins[]' "$M")" \
    "$(claude plugin list --json < /dev/null 2>/dev/null | jq -r '.[].id' | drop_account claude)"
  compare "claude marketplace" "$(jq -r '.claude.marketplaces | keys[]' "$M"; tr ' ' '\n' <<<"$BUILT_IN_MARKETPLACES")" \
    "$(claude plugin marketplace list --json < /dev/null 2>/dev/null | jq -r '.[].name' | grep -vxF -f <(jq -r '.claude.account_marketplaces[]' "$M"))"
  mcp_check "claude mcp" "$(jq -r '.claude.mcp | keys[]' "$M")" "$CLAUDE_JSON"
  if command -v agy >/dev/null 2>&1; then
    compare "agy plugin" "$(jq -r '.agy.plugins[]' "$M")" "$(ls "$AGY_PLUGINS" 2>/dev/null)"
    mcp_check "agy mcp" "$(jq -r '.agy.mcp | keys[]' "$M")" "$AGY_MCP"
    local built; built=$(mktemp -d); bash "$HERE/build-agy-plugin.sh" "$built/p" >/dev/null
    compare "agy rig skill" "$(ls "$built/p/skills")" "$(ls "$AGY_PLUGINS/rig/skills" 2>/dev/null)"
    rm -rf "$built"
    [ "$(readlink "$HOME/.gemini/GEMINI.md")" = "$SRC_ROOT/dotfiles/GEMINI.md" ] \
      || report "agy GEMINI.md: not a link to $SRC_ROOT/dotfiles/GEMINI.md"
  fi
  if command -v codex >/dev/null 2>&1; then
    local cj; cj=$(codex plugin list --json < /dev/null 2>/dev/null)
    compare "codex plugin" "$(jq -r '.codex.plugins[]' "$M")" "$(jq -r '.installed[] | select(.installed) | .pluginId' <<<"$cj" | drop_account codex)"
    local want got; want=$(jq -r .version "$HERE/../plugins/rig/.claude-plugin/plugin.json")
    got=$(jq -r '.installed[] | select(.pluginId == "rig@rig-local") | .version' <<<"$cj")
    [ -z "$got" ] || [ "$got" = "$want" ] || report "codex plugin: rig@rig-local is $got, the repo is $want"
    local cm; if cm=$(codex mcp list --json < /dev/null 2>/dev/null) && cm=$(jq -r '.[].name' <<<"$cm"); then
      compare "codex mcp" "$(jq -r '.codex.mcp | keys[]' "$M")" "$cm"
    else report "codex mcp: codex mcp list --json failed"; fi
  fi
  [ "$drift" -eq 0 ] && echo "no drift"
  return "$drift"
}

# The main checkout, never a linked worktree: links made from a worktree die with it (install.sh).
common="$(cd "$HERE" && git rev-parse --git-common-dir 2>/dev/null || true)"
if [ -z "${SRC_ROOT:-}" ]; then
  if [ -n "$common" ]; then SRC_ROOT="$(dirname "$(cd "$HERE" && cd "$common" && pwd)")"; else SRC_ROOT="$(cd "$HERE/.." && pwd)"; fi
fi
case "${1:-}" in
  fragment) fragment ;;
  apply) apply ;;
  check) check ;;
  *) echo "usage: harnesses.sh fragment|apply|check" >&2; exit 2 ;;
esac
