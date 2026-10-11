# Harness: Codex desktop app (Windows)
A thread here is mostly a delegate started from WSL by `codex-desktop`, for any scoped task that needs Windows; Computer Use and the in-app browser are examples, not the limit.

- Scope: work only inside the task folder (`codex-lane/tasks/<slug>/`) and the paths the packet names. Change a file outside the task folder only when the packet authorizes it and names the path. Allowed actions are the packet's; never infer permission to submit, delete, purchase or change access.
- Report: to the report file the handoff prompt names, with the evidence the packet asks for. No report file means no result.
- Ask the operator or the dispatcher: through the question mechanism the handoff prompt names, and only that. When the prompt names none, write the question into the report and stop.
- Seats: a thread never reaches the planner, adversary or reader seats itself; there is no Windows-side `claude` or `agy` to assume. It asks the dispatcher, which routes the request in WSL.
- Spawn a subagent: Codex subagents inside the thread, scoped to the same packet.
- Wait: bounded waits only; an unanswered permission prompt ends the turn.
- Worktrees: none. The task folder is the workspace.
- Gates: none from rig. Every rule in `AGENTS.md` is self-enforced here.
- Quota: the dispatcher checks Codex limits in WSL before sending.
