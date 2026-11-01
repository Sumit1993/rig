---
name: codex-desktop
description: "Load when a task needs Windows from WSL (app reviews, QA, Computer Use, the in-app browser, desktop work), or when working inside a delegated Windows Codex thread."
metadata:
  version: "2.1.0"
---

# Codex desktop tasks

## 1. Boundary and setup

The WSL adversary seat and the Windows desktop lane are separate. The desktop lane performs a scoped task and records observations; the adversary seat challenges conclusions. A CLI installation does not supply the desktop app's Computer Use runtime.

On a WSL machine, keep CC, AGY, Rig and development repos in WSL; on native Windows they already sit beside the app (§3). Install/sign into the Windows Codex desktop app with the existing account, enable its Computer Use plugin/skill, and use a native Windows workspace for the handoff. No Windows Rig clone, Windows CC/AGY setup, new subscription, secret copying or shared Codex home is required: a thread that needs a planner, adversary or other seat asks its dispatcher, which reaches the seat from WSL. Windows and WSL Codex configurations/authentication are independent. Verify availability in the app; a trial or CLI entitlement alone does not establish Computer Use availability.

The Windows desktop must be unlocked and available to the test; Computer Use takes foreground control. The user handles authentication and permission dialogs. Follow the installed Computer Use skill and confirmation policy; never bypass its rules or automate the Codex app to press Send. The judge's read-only MCP restrictions remain intact.

## 2. Task packet

Write a self-contained Markdown packet under `~/ai-context/<repo>/<issue>-<slug>/`, its first line a `# ` title. Name:
- Objective, exact app/URL and requested output file. For app reviews, add the expected build/commit and how the UI exposes it.
- Preconditions, existing authenticated session, synthetic data and reset method.
- Steps, expected results and a concrete failure condition for each. One packet is one large autonomous step with a checklist plus "flag anything odd"; micro-steps waste round trips.
- Allowed actions and mutations, and the destination of any data sent. `handoff.py` sends the packet inline because "Approve for me" weighs only user messages; a permission that exists only in a file is not one. Default is navigation and observation; never infer permission to submit, delete, purchase or change access.
- Stop conditions: security, sign-in and permission prompts, and downloads. Name the incidental UI to ignore (banners, promos, notices), or Codex halts on it.
- Evidence: steps/outcomes, blocked/untried steps and residual uncertainty; app reviews add observed build identity. Screenshots are of named app windows, saved by Codex as files, with an MD5 of each listed in the report; the orchestrator rejects duplicate hashes.
- For Computer Use, every app the thread will drive, by name. The operator grants each one in the app before the run; an ungranted app's prompt times out and ends an unattended turn (§4).
- Cleanup limited to what the task opened, never the operator's own windows or documents. Record the PID of each process the task starts and kill only those PIDs, never by image name: an image-name kill once took down the operator's unrelated shells (#199).

Pick the surface by need:
- **Task** (`handoff.py --surface task`) for Windows work with no UI to drive: a Windows build or test run, a file or registry inspection, a Windows-only tool. The thread changes files only inside its task folder and the paths the packet's allowed actions name, so name every path it may write.
- **In-app browser** (`handoff.py --surface browser`, which mentions `@Browser`) for browser work that needs no real login. The bundled Browser plugin drives its `iab` browser through `agent.browsers`, off the operator's browser profile (`docs/tab-mentions-iab.md` in `.codex/plugins/cache/openai-bundled/browser/26.1002.52244/`). Ask for settled reads after a write or navigation.
- **Computer Use** when the work needs a real browser session, or anything outside a browser: native apps, OS dialogs, cross-app tasks. It drives the operator's live desktop, so every app it may touch is a deliberate grant (§4).
- **A human or Playwright** for any interaction the packet cannot verify through either surface; say so in the report rather than guess.

A localhost URL is a hypothesis until Windows reaches the WSL dev server; report connectivity failures instead of changing firewall settings or the stack, and record the build actually served.

## 3. Dispatch

One trusted lane folder holds every task, so the app asks for trust once: `$WIN_HOME/Documents/rig-live-tests/codex-lane`, each task in `tasks/<slug>/`. Every thread's workspace is the lane folder; a new folder per thread would register as a new project and ask again.

```bash
export WIN_HOME=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
LANE="$WIN_HOME/Documents/rig-live-tests/codex-lane"; TASK="$LANE/tasks/<slug>"
python3 "$SKILL_DIR/handoff.py" --packet "$PACKET" --windows-dir "$TASK"
TID=$(python3 "$SKILL_DIR/codex_thread.py" new --name "<packet title>" --workspace "$(wslpath -w "$LANE")")
python3 "$SKILL_DIR/codex_thread.py" send --thread "$TID" --message-file "$TASK/prompt.txt"
```

From native Windows (Git Bash) the dispatcher sits beside the app: `WIN_HOME=$HOME`, and `cygpath -w` replaces `wslpath -w`.

`handoff.py` copies and hashes the packet into a new task folder and writes a prompt naming that folder, the title and the report file. Add `--report reply-1.md` for a later step's report, `--surface browser` for the in-app browser, `--surface task` for non-UI work, and `--dispatcher codex|other` when the dispatching session is not Claude Code. `codex_thread.py new` starts a thread through the bundled app-server, persists it and mounts it in the app; `send` queues a message. Later steps go to the same `$TID` with `send`. Each task gets its own thread, so tasks run side by side. Then wait for the report file with a bounded background wait; no file means no result. A zero exit means dispatched, never passed.

```text
organizer → packet → handoff.py → tasks/<slug>/ → codex_thread new → send → thread works → report + evidence/
organizer → verify hashes, provenance, build → adversary seat → objections
```

Both directions work mid-task. The organizer reaches a thread with `codex_thread.py send`. How a thread asks back depends on `--dispatcher`:
- `claude` (the default) from inside a Claude Code session: the prompt names `claude -p --resume <session> --fork-session --tools "" --strict-mcp-config`, run through `wsl.exe` (directly in PowerShell from native Windows) with the question in `question.md`. It answers from that session's context and returns the answer as output. It runs with no tools and no MCP servers ([CLI reference](https://code.claude.com/docs/en/cli-reference): `--tools`, `--strict-mcp-config`), because a thread that reads untrusted pages may ask but never make Claude act; work that needs action comes back in the report.
- `codex`, `other`, or `claude` outside a session: the thread writes `question-N.md` in its task folder and stops the turn. Check the task folder for a new question file whenever you check for the report, answer it in a file, and send that file with `codex_thread.py send --thread "$TID" --message-file <answer>`; the thread resumes on it. A seat request (planner, adversary) is a question like any other: hold the seat from WSL and send its result back.

`handoff.py --open` still opens the documented `codex://new` composer for a human Send, the fallback when the transport below breaks. Bring deciding evidence into the engineering issue; keep private proposals out of public issues.

## 4. Transport: verified, undocumented, version-pinned

Read `references/transport.md` before changing how a thread is started or when a dispatch fails.

## 5. What to hand over

Hand over any scoped task that needs Windows: app reviews and QA, reproductions, comparisons, data inspection, cross-app tasks, Windows builds and tools. Codex's Computer Use and in-app browser are the common reasons, not the limit. Name the question the work answers and observable completion criteria. A browser-only result is not evidence about native window behavior.

## 6. CLI notes

Read `references/transport.md` before changing how a thread is started or when a dispatch fails.

## 7. Inside a delegated thread

A Windows thread works one packet. Stay inside the task folder and the paths the packet names; write the report file the prompt names, with evidence, even when blocked. Ask the dispatcher the way the prompt says, never by guessing; a decision outside the packet is a question, not a judgement call. Post, push or merge only what the packet's allowed actions name.
