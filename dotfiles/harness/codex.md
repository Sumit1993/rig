# Harness: Codex CLI (WSL)
How Codex does what `AGENTS.md` names.

- Spawn a subagent: ask for one in plain words ("spawn an agent to…"), or define one in `~/.codex/agents/<name>.toml` with `model` and `model_reasoning_effort`.
- Ask the operator: end the turn with the question. In `codex exec` nobody answers; write the question into the report and stop.
- Wait in the background: start the job detached with its output to a file and a sentinel on exit, then check the sentinel (`no-doze`). `codex queue --thread <id> --message …` hands a running session a follow-up.
- Worktrees: `git worktree add .claude/worktrees/<task> -b <branch> origin/<default>`, where Claude Code keeps them too. Work in them by absolute path.
- Planner seat: `claude -p --agent rig:planner --output-format json "<decision, constraints, options>"`. `rig:fable-planner` only when the operator allows Fable.
- Adversary seat: the launcher in the `adversary` skill, run with the shell. A Codex organizer that authored the work still sends it to a fresh run through the launcher, never its own context.
- Reader seat: `claude -p --model haiku --output-format json`.
- Side lane: `agy -p`, per `farm-out`.
- Gates: the rig hooks the Codex build ships (`dotfiles/harnesses.json`), and only once trusted in `/hooks`; every rebuild needs the trust again. A rule whose hook is not shipped here is self-enforced.
- Quota: `codex-quota.py check` in the `adversary` skill (app-server `account/rateLimits/read`), or `/status` in the TUI. Claude's limits: the last row of `~/.claude/metrics/usage.jsonl`. agy's: `agy-quota.sh check <model>`.
