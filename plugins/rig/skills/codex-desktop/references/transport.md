# Transport and CLI notes

## 4. Transport: verified, undocumented, version-pinned

Verified on app 26.1002 / codex-cli 0.162.0-alpha.2 (rig#174). None of it is in OpenAI's docs; after any app update rerun one harmless two-thread probe before relying on it.
- `codex.exe app-server --stdio` with `clientInfo.name = "codex_desktop"`: `thread/start` (workspace-write sandbox, `approvalsReviewer = "auto_review"`, the "Approve for me" reviewer), `thread/name/set`, `thread/inject_items`. A thread with no item never reaches disk; the injected message persists it without a model turn.
- The app keeps its own thread catalog and only consumes queued messages for threads it has mounted. `Start-Process 'codex://threads/<id>'` mounts it (idea from the third-party bridge Remodex).
- `codex.exe queue --thread <id> --approve-for-me --message <text>` lands in `queue_1.sqlite`. The app runs queued turns read-only whatever the thread was started with; `--approve-for-me` lets Codex escalate writes through the reviewer; a mounted thread starts a turn within seconds, idle or mid-turn. Two threads started in the same second ran together, wrote their files and listed the real desktop windows through Computer Use with no prompt.

Limits:
- Computer Use runs on the active desktop in the foreground; the desktop must be unlocked and the operator's apps are the ones it drives. "Approve for me" reviews escalations; Computer Use asks once per app, and an unanswered prompt times out in about 30 s and ends the turn. Grant only the apps the task needs, in the app, before leaving a run, and revoke broad grants afterwards; `[computer_use.windows] always_allowed_app_ids` is not a config key.
- The Codex plan's 5-hour window stops a thread dead. Computer Use is the expensive surface; prefer structure reads and one screenshot per finding.
- openai/codex#49458: Windows tasks started remotely lacked Computer Use. Threads started this way did not hit it.
- Fallback if `queue` breaks: a [Stop hook](https://developers.openai.com/codex/hooks) returning `{"decision":"block","reason":"<next instruction>"}` continues a turn. Whether desktop turns run hooks is unverified.

Claude Code only: auto mode refuses the thread-start step and long wait loops as [Create Unsafe Agents]. Running unattended needs the operator's allow rules, exact paths with no inner `*`:

```json
"Bash(python3 <SKILL_DIR>/codex_thread.py:*)",
"Bash(/mnt/c/Users/<user>/AppData/Local/OpenAI/Codex/bin/<hash>/codex.exe:*)"
```

The `<hash>` folder changes with each app update.

Read: [Computer Use](https://learn.chatgpt.com/docs/computer-use), [desktop deep links](https://learn.chatgpt.com/docs/reference/commands), [Windows app](https://learn.chatgpt.com/docs/windows/windows-app), [WSL setup](https://learn.chatgpt.com/docs/windows/wsl).

`dotfiles/harnesses.json` decides which harnesses get this skill. The Windows app receives the portable request and its own global AGENTS.md (the neutral core plus the codex-desktop overlay), never Linux hooks. The app's installed Computer Use skill owns desktop execution.


## 6. CLI notes

`codex exec` runs noninteractive prompts in its own process, without the desktop app's Computer Use; `-p` is `--profile`, not a prompt mode (`codex exec --help`). The adversary launcher's JSON events, schema output and read-only ephemeral runs do not inherit AGY's constraints. Desktop work goes through §3.
