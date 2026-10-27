#!/bin/bash
# Usage: lane-worktree.sh add <repo> <path> <branch> [base]   (base defaults to origin/HEAD)
#        lane-worktree.sh remove <path>
# add: git worktree add, then copy the gitignored files the repo's .worktreeinclude names,
# as Claude Code does for its own worktrees. remove: refuse a dirty tree, delete it, prune.
set -u
die() { echo "lane-worktree: $*" >&2; exit "${2:-1}"; }

cmd_add() {
  local repo="$1" wt="$2" branch="$3" base="${4:-origin/HEAD}"
  git -C "$repo" -c core.longpaths=true worktree add -b "$branch" "$wt" "$base" || die "worktree add failed"
  [ -f "$repo/.worktreeinclude" ] || { echo "added $wt (no .worktreeinclude)"; return 0; }
  local n=0 f
  # Listed in .worktreeinclude and gitignored: the same rule Claude Code applies.
  while IFS= read -r -d '' f; do
    mkdir -p "$wt/$(dirname "$f")" && cp -p "$repo/$f" "$wt/$f" && n=$((n + 1))
  done < <(git -C "$repo" ls-files -z --others --ignored --exclude-from=.worktreeinclude \
             | git -C "$repo" check-ignore -z --stdin)
  echo "added $wt, copied $n file(s) from .worktreeinclude"
}

cmd_remove() {
  local wt="$1" common st
  common=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || die "$wt is not a worktree"
  [ "$(git -C "$wt" rev-parse --absolute-git-dir)" != "$common" ] || die "$wt is a main checkout, not a lane worktree"
  st=$(git -C "$wt" -c core.longpaths=true status --porcelain) || die "git status failed in $wt; not deleting"
  [ -z "$st" ] || die "$wt has uncommitted work; commit or discard it first"
  # rm -rf unlinks pnpm's junctions and symlinks without entering them, and Git Bash takes
  # long paths; git worktree remove hits "Filename too long" and robocopy /MIR follows links (#164).
  rm -rf "$wt" || die "could not delete $wt"
  git --git-dir="$common" worktree prune
  echo "removed $wt"
}

case "${1:-}" in
  add) [ $# -ge 4 ] || die "usage: lane-worktree.sh add <repo> <path> <branch> [base]" 2; shift; cmd_add "$@" ;;
  remove) [ $# -eq 2 ] || die "usage: lane-worktree.sh remove <path>" 2; cmd_remove "$2" ;;
  *) die "usage: lane-worktree.sh add <repo> <path> <branch> [base] | remove <path>" 2 ;;
esac
