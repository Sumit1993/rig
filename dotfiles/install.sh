#!/bin/bash
# rig bootstrap for a new machine. Idempotent. Requires: jq, git, gh (authed).
#   install.sh           install every harness found, as dotfiles/harnesses.json declares
#   install.sh --check   read-only: report drift per harness, exit 1 on any
# RIG_SRC_ROOT overrides the checkout the doctrine is read from (tests); RIG_WIN_HOME the Windows profile.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/build-lib.sh"
CLAUDE="$HOME/.claude"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rig"

# Doctrine comes from the MAIN checkout, never a linked worktree: a worktree is removed on merge, and
# every session afterwards would launch with its import unresolved.
common="$(cd "$HERE" && git rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "${RIG_SRC_ROOT:-}" ]; then
  src_root="$RIG_SRC_ROOT"
elif [ -n "$common" ]; then
  src_root="$(dirname "$(cd "$HERE" && cd "$common" && pwd)")"
else
  src_root="$(cd "$HERE/.." && pwd)"
fi
DOT="$src_root/dotfiles"

# CLAUDE.md is an import stub, not a copy: Claude Code reads no user-level AGENTS.md, but CLAUDE.md can
# @-import it, so the body stays under version control with no second copy to drift. Never import a
# plugin-cache path; those carry a version string that changes on update.
MARKER="Edit the imported files in the rig repo, not here. Anything below this line is machine-local."
claude_header() {
  printf '@%s\n' "$DOT/AGENTS.md"
  printf '@%s\n' "$DOT/$(rig_field claude doctrine.overlay)"
  printf '\n%s\n' "$MARKER"
}
# The operator's lines after the machine-local marker survive every rewrite.
claude_md_wanted() {
  claude_header
  [ -f "$CLAUDE/CLAUDE.md" ] && awk 'found {print} /Anything below this line is machine-local\./ {found=1}' "$CLAUDE/CLAUDE.md"
  return 0
}

win_home() {
  if [ -n "${RIG_WIN_HOME:-}" ]; then echo "$RIG_WIN_HOME"; return; fi
  local p
  p=$(grep -qi microsoft /proc/version 2>/dev/null && cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' || true)
  [ -n "$p" ] && wslpath "$p"
}
newest_dir() { ls -dt "$@" 2>/dev/null | head -1; }

# ---------------------------------------------------------------------------------------------- --check
check() {
  set +e +o pipefail  # a report: every probe runs, an empty one is not an error
  local drift=0 t dir kind declared installed rev cc_rev="" wh
  flag() { echo "  DRIFT: $*"; drift=1; }
  names() { # <dir> <kind>
    case $2 in
      skills) for d in "$1"/skills/*/SKILL.md; do [ -f "$d" ] && basename "$(dirname "$d")"; done ;;
      hooks) for f in "$1"/hooks/*.sh; do [ -f "$f" ] && basename "$f"; done ;;
      agents) for f in "$1"/agents/*.md; do [ -f "$f" ] && basename "$f" .md; done ;;
    esac | sort
  }
  compare() { # <target> <installed-dir>
    for kind in skills hooks agents; do
      declared=$(rig_list "$1" "$kind" | sort); installed=$(names "$2" "$kind")
      comm -23 <(echo "$declared") <(echo "$installed") | grep . | sed "s/^/declared, not installed: $kind\//" | while read -r l; do echo "  DRIFT: $l"; done
      comm -13 <(echo "$declared") <(echo "$installed") | grep . | sed "s/^/installed, not declared: $kind\//" | while read -r l; do echo "  DRIFT: $l"; done
      [ "$(comm -3 <(echo "$declared") <(echo "$installed") | grep -c .)" = 0 ] || drift=1
    done
  }
  revision() { # <label> <commit> <version>
    echo "  revision: ${2:0:12} ($3)"
    [ -z "$cc_rev" ] || [ "${2%+dirty}" = "$cc_rev" ] || flag "$1 is built from ${2:0:12}, the CC plugin cache from ${cc_rev:0:12}; rebuild both from one release"
  }
  stamp() { # <label> <.rig-build.json>
    if [ -f "$2" ]; then revision "$1" "$(jq -r .commit "$2")" "$(jq -r .version "$2")"
    else flag "$1 has no build stamp ($2); rebuild with install.sh"; fi
  }
  doctrine_check() { # <target> <dest>
    if [ -L "$2" ]; then flag "$2 is a symlink; install.sh generates it now"
    elif [ ! -f "$2" ]; then flag "$2 missing"
    elif ! cmp -s <(rig_doctrine "$1" "$DOT") "$2"; then flag "$2 differs from AGENTS.md + $(rig_field "$1" doctrine.overlay); re-run install.sh"
    else echo "  doctrine: $2 current"; fi
  }

  rig_check_manifest || flag "harnesses.json fails its own checks"

  echo "claude (WSL Claude Code)"
  dir=$(jq -r '.plugins["rig@rig"][0].installPath // empty' "$CLAUDE/plugins/installed_plugins.json" 2>/dev/null || true)
  if [ -n "$dir" ] && [ -d "$dir" ]; then
    cc_rev=$(jq -r '.plugins["rig@rig"][0].gitCommitSha // empty' "$CLAUDE/plugins/installed_plugins.json")
    echo "  installed: $dir"
    echo "  revision: ${cc_rev:0:12} ($(jq -r '.plugins["rig@rig"][0].version // "?"' "$CLAUDE/plugins/installed_plugins.json"))"
    compare claude "$dir"
  else
    flag "rig@rig is not in $CLAUDE/plugins/installed_plugins.json"
  fi
  if [ -f "$CLAUDE/CLAUDE.md" ] && cmp -s <(claude_md_wanted) "$CLAUDE/CLAUDE.md"; then echo "  doctrine: CLAUDE.md imports current"
  else flag "$CLAUDE/CLAUDE.md does not import AGENTS.md and $(rig_field claude doctrine.overlay) from $DOT"; fi

  if command -v codex >/dev/null 2>&1; then
    echo "codex (WSL Codex CLI)"
    dir=$(newest_dir "$CODEX_DIR"/plugins/cache/rig-local/rig/*/)
    if [ -n "$dir" ]; then
      echo "  installed: $dir"; compare codex "$dir"
      stamp codex "$DATA_DIR/codex-plugin/.rig-build.json"
      codex_trust "$dir"
    else
      flag "no rig plugin under $CODEX_DIR/plugins/cache/rig-local"
    fi
    doctrine_check codex "$CODEX_DIR/AGENTS.md"
  else
    echo "codex: not installed, skipped"
  fi

  wh=$(win_home || true)
  if [ -n "$wh" ]; then
    if ls "$wh"/AppData/Local/OpenAI/Codex/bin/*/codex.exe >/dev/null 2>&1 || [ -d "$wh/.codex" ]; then
      echo "codex-desktop (Windows Codex app)"
      dir=$(newest_dir "$wh"/.codex/plugins/cache/rig-local/rig/*/); [ -n "$dir" ] || dir="$wh/.rig/codex-plugin"
      echo "  installed: $dir"; compare codex-desktop "$dir"
      stamp codex-desktop "$wh/.rig/codex-plugin/.rig-build.json"
      doctrine_check codex-desktop "$wh/.codex/AGENTS.md"
    fi
    if [ -d "$wh/.claude" ]; then
      echo "claude-windows (Windows Claude Code)"
      dir=$(newest_dir "$wh"/.claude/plugins/cache/rig-local/rig/*/); [ -n "$dir" ] || dir="$wh/.rig/claude-plugin/plugins/rig"
      echo "  installed: $dir"; compare claude-windows "$dir"
      stamp claude-windows "$wh/.rig/claude-plugin/plugins/rig/.rig-build.json"
    fi
  fi

  if command -v agy >/dev/null 2>&1; then
    echo "agy (Antigravity CLI)"
    dir="$HOME/.gemini/config/plugins/rig"
    if [ -d "$dir" ]; then
      echo "  installed: $dir"; compare agy "$dir"
      stamp agy "$DATA_DIR/agy-plugin/.rig-build.json"
    else
      flag "no rig plugin at $dir"
    fi
    [ "$(readlink "$HOME/.gemini/GEMINI.md" 2>/dev/null)" = "$DOT/GEMINI.md" ] && echo "  doctrine: GEMINI.md linked" || flag "$HOME/.gemini/GEMINI.md does not link to $DOT/GEMINI.md"
    doctrine_check agy "$HOME/.gemini/AGENTS.md"
  else
    echo "agy: not installed, skipped"
  fi

  [ "$drift" -eq 0 ] && echo "no drift" || echo "drift found"
  return "$drift"
}

# Codex keys hook trust by position (<plugin>:hooks/hooks.json:<event>:<group>:<hook>) with a hash of the
# hook; the hash is not recomputed here, so a key present means "trusted at that position".
codex_trust() { # <installed-dir>
  local f="$1/hooks/hooks.json" cfg="$CODEX_DIR/config.toml" key line pending=0
  [ -f "$f" ] || return 0
  while IFS=$'\t' read -r key line; do
    if grep -qF "[hooks.state.\"rig@rig-local:hooks/hooks.json:$key\"]" "$cfg" 2>/dev/null; then
      echo "  hook $line: trusted"
    else
      echo "  DRIFT: hook $line: pending-trust (open /hooks in Codex)"; pending=1
    fi
  done < <(jq -r '.hooks | to_entries[] | .key as $e | .value | to_entries[] | .key as $g | .value.hooks | to_entries[]
                  | "\($e | gsub("(?<a>[a-z])(?<b>[A-Z])"; "\(.a)_\(.b)") | ascii_downcase):\($g):\(.key)\t\(.value.command | capture("hooks/(?<s>[^\"/ ]+)").s)"' "$f")
  [ "$pending" -eq 0 ] || drift=1
}

if [ "${1:-}" = "--check" ]; then
  check; exit $?
fi

# ---------------------------------------------------------------------------------------------- install
for f in AGENTS.md $(for t in $(rig_targets); do rig_field "$t" doctrine.overlay; done | sort -u); do
  if [ ! -f "$DOT/$f" ]; then
    echo "  ERROR: no $f at $DOT, the main checkout is behind this branch." >&2
    echo "  Merge first, then re-run; an import of a missing file breaks every session." >&2
    exit 1
  fi
done
mkdir -p "$CLAUDE"

echo "→ CLAUDE.md (imports AGENTS.md + $(rig_field claude doctrine.overlay))"
if [ -f "$CLAUDE/CLAUDE.md" ] && cmp -s <(claude_md_wanted) "$CLAUDE/CLAUDE.md"; then
  echo "  imports current, machine-local lines untouched"
else
  if [ -f "$CLAUDE/CLAUDE.md" ]; then
    bak="$CLAUDE/CLAUDE.md.bak-$(date +%s)"; cp "$CLAUDE/CLAUDE.md" "$bak"
    if grep -q 'Anything below this line is machine-local\.' "$CLAUDE/CLAUDE.md"; then
      echo "  imports rewritten, machine-local lines kept; backup: $bak"
    else
      # No marker: the whole body is replaced, and anything machine-local in it is not carried over.
      echo "  WARNING: existing CLAUDE.md has no machine-local marker; it is replaced." >&2
      echo "  backup:  $bak — re-add anything you still want BELOW the marker line." >&2
    fi
  fi
  wanted=$(claude_md_wanted); printf '%s\n' "$wanted" > "$CLAUDE/CLAUDE.md"
fi

echo "→ statusline"
cp "$HERE/statusline-command.sh" "$CLAUDE/statusline-command.sh"

AGY="$HOME/.gemini/antigravity-cli"
if [ -d "$AGY" ]; then
  echo "→ agy statusline"
  cp "$HERE/agy-statusline-command.sh" "$AGY/statusline.sh"; chmod +x "$AGY/statusline.sh"
  s="$AGY/settings.json"; [ -f "$s" ] || echo '{}' > "$s"
  jq --arg cmd "$AGY/statusline.sh" '.statusLine = ((.statusLine // {}) + {type: "command", command: $cmd, enabled: true})' "$s" > "$s.tmp" \
    && jq -e . "$s.tmp" >/dev/null && mv "$s.tmp" "$s"
  echo "→ agy GEMINI.md"
  ln -sfn "$DOT/$(rig_field agy doctrine.file)" "$HOME/.gemini/GEMINI.md"
  echo "→ agy AGENTS.md (AGENTS.md + $(rig_field agy doctrine.overlay))"
  rig_write_doctrine "$HOME/.gemini/AGENTS.md" agy "$DOT"
  if command -v agy >/dev/null 2>&1; then
    echo "→ agy plugin (harnesses.json target agy)"
    b="$DATA_DIR/agy-plugin"
    bash "$HERE/build-agy-plugin.sh" "$b" >/dev/null && agy plugin install "$b"
  fi
fi

if command -v codex >/dev/null 2>&1; then
  echo "→ codex plugin (harnesses.json target codex)"
  mkdir -p "$CODEX_DIR"  # marketplace add fails on a machine with no CODEX_HOME yet (#141)
  cb="$DATA_DIR/codex-plugin"
  bash "$HERE/build-codex-plugin.sh" "$cb" codex >/dev/null
  codex plugin marketplace add "$cb" >/dev/null 2>&1 || echo "  WARN: codex plugin marketplace add $cb failed" >&2
  codex plugin add rig@rig-local >/dev/null 2>&1 || echo "  WARN: codex plugin add rig@rig-local failed" >&2
  echo "  open /hooks in Codex to review and trust the rig hooks; a rebuild that changes a hook asks again."
  echo "→ codex AGENTS.md (generated: AGENTS.md has no @-import in Codex)"
  rig_write_doctrine "$CODEX_DIR/AGENTS.md" codex "$DOT"
fi

bash "$HERE/install-windows.sh"

echo "→ settings.json (deep-merge: fragment overlays existing; permissions.allow unions)"
if [ -f "$CLAUDE/settings.json" ]; then
  cp "$CLAUDE/settings.json" "$CLAUDE/settings.json.bak-$(date +%s)"
  jq -s '.[0] as $cur | .[1] as $frag | ($cur * $frag)
         | .permissions.allow = (($cur.permissions.allow // []) + ($frag.permissions.allow // []) | unique)' \
    "$CLAUDE/settings.json" "$HERE/settings.fragment.json" > "$CLAUDE/settings.json.tmp"
  jq -e . "$CLAUDE/settings.json.tmp" >/dev/null
  mv "$CLAUDE/settings.json.tmp" "$CLAUDE/settings.json"
else
  cp "$HERE/settings.fragment.json" "$CLAUDE/settings.json"
fi

echo "→ done. Restart Claude Code; the rig marketplace + rig plugin load from settings."
echo "   Skills arrive under the rig: prefix, one per directory in plugins/rig/skills/."
echo "   If migrating FROM a machine with loose copies in ~/.claude/skills/, run dedupe.sh next."
echo "   install.sh --check reports drift between harnesses.json and what each harness has."
