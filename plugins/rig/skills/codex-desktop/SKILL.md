---
name: codex-desktop
description: "Hand scoped desktop or browser work from WSL to the Windows Codex desktop app (in-app browser or Computer Use), in threads started with no click. Load for app reviews, QA or any desktop task from CC, AGY or Codex."
metadata:
  harnesses: "claude agy codex"
  version: "2.0.0"
---

# Codex desktop tasks

## 1. Boundary and setup

The WSL judge and Windows desktop tester are separate lanes. The desktop lane performs a scoped task and records observations; `codex-judge` challenges conclusions. A CLI installation does not supply the desktop app's Computer Use runtime.

Keep CC, AGY, Rig and development repos in WSL. Install/sign into the Windows Codex desktop app with the existing account, enable its Computer Use plugin/skill, and use a native Windows workspace for the handoff. No Windows Rig clone, Windows CC/AGY setup, new subscription, secret copying or shared Codex home is required. Windows and WSL Codex configurations/authentication are independent. Verify availability in the app; a trial or CLI entitlement alone does not establish Computer Use availability.

The Windows desktop must be unlocked and available to the test; Computer Use takes foreground control. The user handles authentication and permission dialogs. Follow the installed Computer Use skill and confirmation policy; never bypass its rules or automate the Codex app to press Send. The judge's read-only MCP restrictions remain intact.

## 2. Task packet

Write a self-contained Markdown packet under `~/ai-context/<repo>/<issue>-<slug>/`, its first line a `# ` title. Name:
- Objective, exact app/URL and requested output file. For app reviews, add the expected build/commit and how the UI exposes it.
- Preconditions, existing authenticated session, synthetic data and reset method.
- Steps, expected results and a concrete failure condition for each. One packet is one large autonomous step with a checklist plus "flag anything odd"; micro-steps waste round trips.
- Allowed actions and mutations, and the destination of any data sent. `handoff.py` sends the packet inline because "Approve for me" weighs only user messages; a permission that exists only in a file is not one. Default is navigation and observation; never infer permission to submit, delete, purchase or change access.
- Stop conditions: security, sign-in and permission prompts, and downloads. Name the incidental UI to ignore (banners, promos, notices), or Codex halts on it.
- Evidence: steps/outcomes, blocked/untried steps and residual uncertainty; app reviews add observed build identity. Screenshots are of named app windows, saved by Codex as files, with an MD5 of each listed in the report; the orchestrator rejects duplicate hashes.
- Cleanup limited to what the task opened, never the operator's own windows or documents.

Pick the surface by need:
- **In-app browser** (Codex Browser plugin, `iab` backend) for browser work that needs no real login. It runs in the background off the operator's browser profile, reads the page structure rather than pixels, and costs far less quota. Ask for settled reads after a write or navigation.
- **Computer Use** when the work needs a real browser session, or anything outside a browser: native apps, OS dialogs, cross-app tasks. It drives the operator's live desktop, so every app it may touch is a deliberate grant (§4).
- **A human or Playwright** for any interaction the packet cannot verify through either surface; say so in the report rather than guess.

A localhost URL is a hypothesis until Windows reaches the WSL dev server; report connectivity failures instead of changing firewall settings or the stack, and record the build actually served.

## 3. Dispatch

One trusted lane folder holds every task, so the app asks for trust once: `$WIN_HOME/Documents/rig-live-tests/codex-lane`, each task in `tasks/<slug>/`. Every thread's workspace is the lane folder; a new folder per thread would register as a new project and ask again.

```bash
WIN_HOME=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
LANE="$WIN_HOME/Documents/rig-live-tests/codex-lane"; TASK="$LANE/tasks/<slug>"
python3 "$SKILL_DIR/handoff.py" --packet "$PACKET" --windows-dir "$TASK" [--report reply-1.md]
TID=$(python3 "$SKILL_DIR/codex_thread.py" new --name "<packet title>" --workspace "$(wslpath -w "$LANE")")
python3 "$SKILL_DIR/codex_thread.py" send --thread "$TID" --message-file "$TASK/prompt.txt"
```

`handoff.py` copies and hashes the packet into a new task folder and writes a prompt naming that folder, the title and the report file. `codex_thread.py new` starts a thread through the bundled app-server, persists it and mounts it in the app; `send` queues a message. Later steps go to the same `$TID` with `send`. Each task gets its own thread, so tasks run side by side. Then wait for the report file with a bounded background wait; no file means no result. A zero exit means dispatched, never passed.

```text
CC → packet → handoff.py → tasks/<slug>/ → codex_thread new → send → Computer Use → report + evidence/
CC → verify hashes, provenance, build → fresh codex-judge packet → objections
```

`handoff.py --open` still opens the documented `codex://new` composer for a human Send, the fallback when the transport below breaks. Bring deciding evidence into the engineering issue; keep private proposals out of public issues.

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

Claude Code auto mode refuses the thread-start step and long wait loops as [Create Unsafe Agents]. Running unattended needs the operator's allow rules, exact paths with no inner `*`:

```json
"Bash(python3 <SKILL_DIR>/codex_thread.py:*)",
"Bash(/mnt/c/Users/<user>/AppData/Local/OpenAI/Codex/bin/<hash>/codex.exe:*)"
```

The `<hash>` folder changes with each app update.

Read: [Computer Use](https://learn.chatgpt.com/docs/computer-use), [desktop deep links](https://learn.chatgpt.com/docs/reference/commands), [Windows app](https://learn.chatgpt.com/docs/windows/windows-app), [WSL setup](https://learn.chatgpt.com/docs/windows/wsl).

This skill is exported to Claude, AGY and Codex. Windows receives the portable request, not Linux hooks or imported WSL policy. The app's installed Computer Use skill owns desktop execution.

## 5. What to hand over

Codex's Computer Use is stronger than CC's, and CC is stronger at code, so hand over any scoped desktop or browser work: app reviews and QA, reproductions, comparisons, data inspection, cross-app tasks. Name the question the work answers and observable completion criteria. A browser-only result is not evidence about native window behavior.

## 6. CLI notes

`codex exec` runs noninteractive prompts in its own process, without the desktop app's Computer Use; `-p` is `--profile`, not a prompt mode (`codex exec --help`). The judge's JSON events, schema output and read-only ephemeral runs do not inherit AGY's constraints. Desktop work goes through §3.
