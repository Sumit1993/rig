#!/bin/bash
# Regression suite for farm-out's lane-worktree.sh: .worktreeinclude copies and a safe remove. Refs #177, #164.
set -u
LW="$(cd "$(dirname "$0")/../../skills/farm-out" && pwd)/lane-worktree.sh"
fails=0; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fails=$((fails + 1)); fi; }

R="$T/repo"; mkdir -p "$R"
git -C "$R" init -q -b main
git -C "$R" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
printf '.env\nsecret.local\nnode_modules/\n' > "$R/.gitignore"
printf '.env\nnotes.txt\n' > "$R/.worktreeinclude"
git -C "$R" -c core.autocrlf=false add .gitignore .worktreeinclude
git -C "$R" -c user.email=t@t -c user.name=t commit -q -m files
echo "API=1" > "$R/.env"; echo s > "$R/secret.local"; echo n > "$R/notes.txt"

out=$(bash "$LW" add "$R" "$T/wt" lane/one HEAD 2>&1); rc=$?
check "add creates the worktree on its branch" '[ "$rc" -eq 0 ] && [ "$(git -C "$T/wt" branch --show-current)" = lane/one ]'
check "a gitignored file .worktreeinclude names is copied" '[ "$(cat "$T/wt/.env" 2>/dev/null)" = "API=1" ]'
check "a gitignored file it does not name stays behind" '[ ! -e "$T/wt/secret.local" ]'
check "a named file that is not gitignored stays behind" '[ ! -e "$T/wt/notes.txt" ]'
check "the copy count is reported" '[[ "$out" == *"copied 1 file(s)"* ]]'

echo x > "$T/wt/stray.txt"
bash "$LW" remove "$T/wt" >/dev/null 2>&1; rc=$?
check "remove refuses uncommitted work and keeps the tree" '[ "$rc" -ne 0 ] && [ -f "$T/wt/stray.txt" ]'
rm -f "$T/wt/stray.txt"

# A pnpm-style link out of the worktree: the delete must unlink it, not enter it.
mkdir -p "$T/outside" "$T/wt/node_modules"; echo keep > "$T/outside/f"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) cmd //c "mklink /J $(cygpath -w "$T/wt/node_modules/pkg") $(cygpath -w "$T/outside")" >/dev/null ;;
  *) ln -s "$T/outside" "$T/wt/node_modules/pkg" ;;
esac
check "the fixture link resolves" '[ -f "$T/wt/node_modules/pkg/f" ]'
out=$(bash "$LW" remove "$T/wt" 2>&1); rc=$?
check "remove deletes a clean worktree" '[ "$rc" -eq 0 ] && [ ! -e "$T/wt" ]'
check "remove does not follow a link out of the tree" '[ "$(cat "$T/outside/f" 2>/dev/null)" = keep ]'
check "git forgets the worktree" '[ "$(git -C "$R" worktree list | wc -l)" -eq 1 ]'
check "the branch survives for its PR" 'git -C "$R" rev-parse -q --verify refs/heads/lane/one >/dev/null'

bash "$LW" remove "$R" >/dev/null 2>&1; rc=$?
check "remove refuses the main checkout" '[ "$rc" -ne 0 ] && [ -d "$R/.git" ]'
bash "$LW" bogus >/dev/null 2>&1; rc=$?
check "an unknown verb exits 2" '[ "$rc" -eq 2 ]'

[ "$fails" -eq 0 ] && echo "all lane-worktree tests passed"; exit "$fails"
