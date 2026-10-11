# Harness: Antigravity CLI (agy)
agy is mostly a lane, not an organizer. A lane run follows `GEMINI.md`, the lane-worker contract: do exactly the work order, verify once, report raw output. What follows applies when the operator talks to agy directly.

- Spawn a subagent: `invoke_subagent`; agents take `model: inherit|flash|pro` and no effort.
- Ask the operator: end the turn with the question.
- Wait in the background: a command that went to the background wakes the session when it ends; never poll it with `manage_task` or `schedule` a check.
- Worktrees: `git worktree add .claude/worktrees/agy-<task> -b <branch> origin/<default>`, worked by absolute path.
- Planner seat: `claude -p --agent rig:planner --output-format json "<decision, constraints, options>"`; `rig:fable-planner` only when the operator allows Fable.
- Adversary seat: the launcher in the `adversary` skill, run with the shell.
- Reader seat: `claude -p --model haiku --output-format json`, or agy's own Flash.
- Gates: none. agy's hooks take a different payload and rig ships none to it, so every rule in `AGENTS.md` is self-enforced here.
- Quota: `agy -p "/usage" --output-format json` reads both groups without spending a turn; `agy-quota.sh check <model>` reads the recorded walls.
