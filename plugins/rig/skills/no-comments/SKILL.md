---
name: no-comments
description: "Load on /no-comments, or before merging a diff whose comments narrate history or restate the code."
metadata:
  version: "1.0.0"
  upstream: "cursor/plugins pstack/skills/no-comments"
---

# No comments

Spawn the comment sicko. Act on accepted findings.

The standard it enforces is the comment budget in `AGENTS.md`: a comment states the one
non-obvious constraint in three lines or fewer, plus a pointer (issue number, doc path) for the
story. Everything else belongs in the issue, PR, or living doc that pointer names.

## Scope

Use the caller's files or diff. Otherwise use the current diff against the base branch, default `main`, including the working tree.

A repo whose existing comments are essays does not get swept by this skill. New code in the diff
gets the budget; slimming the legacy essays is a separate, deliberate task.

## Steps

1. Spawn the `Agent` tool with `subagent_type: "comment-sicko"`. Pass the scope, including the
   worktree path, anchored so every command it runs lands there. Do not restate its rules.
2. Inspect its report and diff. Reject application-code edits, scope escapes, exception-protected deletions, misstated `MUST KILL` reasons, and flags that treat kept intentional code as guilty. Reshape flags on our-code surprises stay actionable. Do not restore those comments. A keep survives only with proof it is about something we cannot change. Before accepting a thin `IMPORTANT` or `do not remove` kill or keep, check its history: `git log -S<symbol>`, the introducing commit, the PR and issue it links. Revert and rerun one rejected report with the failure named; reject a second and report it open.
3. Fix trivial accepted flags directly by deleting a dead path, dropping a parameter, or using the real API. If any fix needs a shape, ask the planner seat (the `planner` agent) once for the accepted set and surrounding code. Stop at the sketch. The planner shapes. Step 4 implements.
4. Implement the smallest root-cause fix in scope. Remove every named workaround. If the root cause is out of scope, land the smallest in-scope fix and report the rest open. Intent, not licence: fix real causes, redesign as if the requirement had always existed, never bolt a symptom guard onto a bug. Neither widens the fence nor authorizes fixing instances outside it.
5. Constraint comments say `do not remove`, `do not change wording`, or `talk to X before changing`. Leave keeps about things we cannot change. Offer the cheapest in-scope type, runtime, test, or CI lint that makes the comment unnecessary. If approved, encode then delete. Otherwise keep the comment and report the constraint open.
6. Report the deletion count, restored comments, reruns, planner sketch, fixes, encoding offers, encodings, unenforced constraints, and other open work.
