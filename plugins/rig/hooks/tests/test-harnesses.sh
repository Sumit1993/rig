#!/bin/bash
# harnesses.sh check: declared vs installed, account-synced plugins ignored, codex version drift. Refs #169.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
H="$ROOT/dotfiles/harnesses.sh"
fails=0; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; echo "${out:-}" | sed "s/^/    /"; fails=$((fails+1)); fi; }

V=$(jq -r .version "$ROOT/plugins/rig/.claude-plugin/plugin.json")
mkdir -p "$T/bin"
cat > "$T/bin/claude" <<'STUB'
#!/bin/bash
case "$*" in
  "plugin list --json") echo '[{"id":"rig@rig"},{"id":"cowork@synced"}]' ;;
  "plugin marketplace list --json") echo '[{"name":"rig"},{"name":"claude-plugins-official"},{"name":"synced"}]' ;;
esac
STUB
cat > "$T/bin/codex" <<STUB
#!/bin/bash
case "\$*" in
  "plugin list --json") printf '{"installed":[{"pluginId":"rig@rig-local","installed":true,"version":"%s"},{"pluginId":"pets@openai-curated-remote","installed":true}]}' "\${CODEX_RIG_VERSION:-$V}" ;;
  "mcp list --json") echo '[]' ;;
esac
STUB
chmod +x "$T/bin/"*
for b in jq; do ln -sf "$(command -v $b)" "$T/bin/$b"; done
echo '{}' > "$T/claude.json"
manifest() { jq -n --argjson p "$1" '{claude: {marketplaces: {rig: {repo: "Sumit1993/rig", autoUpdate: true}}, plugins: $p, mcp: {}, account_marketplaces: ["synced"]},
  agy: {plugins: ["rig"], mcp: {}}, codex: {plugins: ["rig@rig-local"], mcp: {}, account_marketplaces: ["openai-curated-remote"]}}' > "$T/m.json"; }
run() { PATH="$T/bin:/usr/bin:/bin" HARNESSES_JSON="$T/m.json" CLAUDE_JSON="$T/claude.json" bash "$H" check 2>&1; }

manifest '["rig@rig"]'
out=$(run); rc=$?
check "matching install reports no drift and exits 0" '[ $rc -eq 0 ] && grep -q "no drift" <<<"$out"'
check "account-synced plugins are not drift" '! grep -q "synced\|pets" <<<"$out"'

manifest '["rig@rig","mattpocock-skills@mattpocock"]'
out=$(run); rc=$?
check "a declared plugin that is missing is drift" '[ $rc -eq 1 ] && grep -q "mattpocock-skills@mattpocock declared, not installed" <<<"$out"'

manifest '[]'
out=$(run)
check "an installed plugin that is undeclared is drift" 'grep -q "rig@rig installed, not declared" <<<"$out"'

manifest '["rig@rig"]'
out=$(CODEX_RIG_VERSION=0.0.1 run)
check "a stale codex rig build is drift" 'grep -q "rig@rig-local is 0.0.1, the repo is $V" <<<"$out"'

frag=$(HARNESSES_JSON="$T/m.json" bash "$H" fragment)
check "fragment enables declared plugins with their marketplaces" 'jq -e ".enabledPlugins[\"rig@rig\"] and .extraKnownMarketplaces.rig.autoUpdate" <<<"$frag" >/dev/null'

[ "$fails" -eq 0 ] && echo "all harnesses tests passed"
exit "$fails"
