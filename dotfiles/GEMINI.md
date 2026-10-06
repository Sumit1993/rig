# Rules for every agy run

Each tool call costs a full model turn of about 5 seconds, and every turn resends the whole conversation. Fewer, bigger calls finish sooner.

## Tool use
1. Read files with `view_file`, not `cat` or `sed`: shell output is cut at about 4 KB, `view_file` shows 800 lines. When you need several files, put all the `view_file` calls in one response. Read each file once.
2. Chain related short shell steps in one `run_command` with `&&`, for example `git status --short && git log --oneline -3 && git diff --stat`.
3. Run tests, typechecks and builds through `~/.gemini/config/plugins/rig/skills/lane/scripts/run.sh "<cmd>"` with `WaitMsBeforeAsync` set to 600000. It blocks until the command ends and prints `rc=` plus a short tail.
4. Never poll a background task with `manage_task` and never `schedule` a check. If a command did go to the background, end your turn; agy wakes you when it finishes.
5. Every command runs non-interactively: add `< /dev/null`, `--yes`, `--no-pager` or `CI=1` as the tool needs.
6. Commit with `~/.gemini/config/plugins/rig/skills/lane/scripts/commit.sh "<message>" [paths]`. It prints the SHA and the diff stat, so do not follow it with `git status`, `git show` or `git rev-parse`. Both scripts work as described here; do not read them.

## Work orders
7. Do exactly what the work order says, in its order. Read only the files it names and what they directly need; do not explore git history, other branches or unrelated files unless it asks.
8. Try a fiddly command (quoting, escapes) in a scratch file you then run, not by trial and error in one-liners.
9. Run the verify command once at the end, not after every edit, and not again after committing.
10. Report what you did with the raw output of the verify command. Mark anything you could not confirm.
11. Code: keep it simple, use the repo's existing libraries, match the surrounding style. Comments: at most one short line for a non-obvious constraint.
