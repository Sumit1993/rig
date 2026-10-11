# Harness: Claude Code
How Claude Code does what `AGENTS.md` names.

- Spawn a subagent: the Agent tool with `subagent_type` and `model`; in a Workflow, `agent()` with `model` and `effort`. A subagent with no `effort:` frontmatter runs at the settings default, `high` on this machine, not the parent's level; every agent in the rig plugin names its own.
- Effort: on Opus 5.5, Sonnet 5.5 and Fable 5.1, `/effort` keeps the prompt cache. Raise it for one hard step and lower it after.
- Ask the operator: AskUserQuestion.
- Wait in the background: Bash `run_in_background`, Monitor; `no-doze` holds the rules.
- Worktrees live under `.claude/worktrees/`: `EnterWorktree` for this session, `isolation: "worktree"` for a subagent, `git worktree add .claude/worktrees/agy-<task>` for an agy lane. A repo whose lanes build needs a `.worktreeinclude`.
- Planner seat: Agent `planner` (Opus 5.5, `high`); `fable-planner` only when the operator allows Fable. Reuse it with SendMessage inside the prompt-cache hour.
- Adversary seat: the launcher in the `adversary` skill, run with Bash.
- Reader seat: Agent with `model: haiku`.
- Gates: the rig plugin's hooks. `merge-gate` refuses a merge without `MERGE_OK`, `no-haiku` refuses Haiku 4.x ids, `scoped-cap-gate` refuses a Fable spawn while Fable's weekly cap reads critical, `delegate-check` refuses a Claude subagent on work agy should take, and the gh-body gates refuse unstamped or scratch-citing posts. Other hooks nudge.
- Quota: the status line keeps `rate_limits` in `~/.claude/metrics/usage.jsonl`; `session-budget` prints the 5h and 7d percent, agy's groups and Codex's limits at session start.
