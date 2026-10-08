---
name: codex-desktop
description: "Hand a scoped prompt from WSL to the Windows Codex desktop app for Computer Use. Load for Electron UX review, live app testing or other desktop tasks from CC, AGY or Codex."
metadata:
  harnesses: "claude agy codex"
  version: "1.0.0"
---

# Codex desktop tasks

## 1. Boundary and setup

The WSL judge and Windows desktop tester are separate lanes. The desktop lane performs a scoped task and records observations; `codex-judge` challenges conclusions. A CLI installation does not supply the desktop app's Computer Use runtime.

Keep CC, AGY, Rig and development repos in WSL. Install/sign into the Windows Codex desktop app with the existing account, enable its Computer Use plugin/skill, and use a native Windows workspace for the handoff. No Windows Rig clone, Windows CC/AGY setup, new subscription, secret copying or shared Codex home is required. Windows and WSL Codex configurations/authentication are independent. Verify availability in the app; a trial or CLI entitlement alone does not establish Computer Use availability.

The Windows desktop must be unlocked and available to the test; Computer Use takes foreground control. The user handles authentication and permission dialogs. Follow the installed Computer Use skill and confirmation policy; never bypass its rules or automate the Codex app to press Send. The judge's read-only MCP restrictions remain intact.

## 2. Task packet

Write a self-contained Markdown packet under `~/ai-context/<repo>/<issue>-<slug>/`. Name:
- Objective, exact app/URL and requested output. For app reviews, add the expected build/commit and how the UI exposes it.
- Preconditions, existing authenticated test session, synthetic data and reset method.
- Steps, expected results and a concrete failure condition for each.
- Allowed actions and mutations, destination/data for any intended transmission, and stop conditions. Default is navigation and observation; do not infer permission to submit, delete, purchase or change access.
- Evidence required: actual steps/outcomes, screenshots where available, blocked/untried steps and residual uncertainty. App reviews additionally need observed build identity and reproduction details.

A localhost URL is a hypothesis until the Windows browser can reach the WSL dev server. Report a forwarding/connectivity failure; do not silently change firewall settings or restart the development stack. A dev server's checkout may differ from the judge's frozen worktree: record the actual build and do not treat the test as verification of another commit.

## 3. WSL-to-Windows handoff

Prepare a new request beneath a mounted Windows workspace owned by the operator:

```bash
WIN_HOME=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
python3 "$SKILL_DIR/handoff.py" \
  --packet "$PACKET" \
  --windows-dir "$WIN_HOME/Documents/rig-live-tests/<experiment>"
```

Resolve `SKILL_DIR` to this installed skill’s absolute directory from the skill location supplied by the calling harness. The Python helper is independent of the calling harness. The directory must be new. The command copies the packet, hashes it, writes a native Windows prompt and a `codex://new` link. Add `--open` to ask Windows to open the supported link. This opens a composer: **the user must send it** and select the intended model in the app. There is no verified unattended dispatch or completion callback. A zero exit means the handoff was prepared/opened, never that a test passed.

Worked flow:
```text
CC → packet.md → handoff.py → Windows request/ + prefilled Codex composer
user → Send / app permissions → Computer Use → report.md + evidence/
CC → inspect report and artifacts → fresh codex-judge packet → objections
```

The native workspace contains the whole request; Rig remains in WSL. The prompt requests `report.md` and evidence in that directory through normal file tools. If the app cannot write files, it returns the report in chat for explicit transfer; CC does not invent a result or poll forever. Bring the report and referenced artifacts back to ai-context, verify their provenance/build identity, and copy deciding evidence into the appropriate engineering issue or private product record. Keep private proposals out of public issues.

## 4. Supported surfaces and limits

Read: [desktop deep links](https://learn.chatgpt.com/docs/reference/commands), [Computer Use](https://learn.chatgpt.com/docs/computer-use), [Windows app](https://learn.chatgpt.com/docs/windows/windows-app), [WSL setup](https://learn.chatgpt.com/docs/windows/wsl).

Deep links prefill but do not send. None of these pages documents a desktop-capable dispatch interface, so do not reverse-engineer the app's helpers, fabricate thread IDs or expose a relay. Automated dispatch waits for a documented interface and a real end-to-end check.

This skill is exported to Claude, AGY and Codex. Windows receives the portable request, not Linux hooks or imported WSL policy. The app's installed Computer Use skill owns desktop execution.

## 5. Electron UX review example

Ask the app to review a named Electron build through actual navigation, window resizing, keyboard traversal, empty/loading/error states and a representative user journey. Name the UX question (for example, can a first-time user discover how to connect a project?) and give observable completion criteria. Require screenshots with window size, confusing interactions, reproducible failures and severity tied to user impact. Avoid destructive actions and real production data unless explicitly authorized.

Electron is one use case. Other packets can request a desktop reproduction, comparison, data inspection or a cross-app task, with their own scope and output. A browser-only test is not evidence that native window controls or Electron-specific behavior work.

## 6. CLI experiments and future transport

`codex exec` runs noninteractive prompts; `-p` is `--profile`, a configuration profile, not a print/prompt mode (`codex exec --help`, codex-cli 0.160.1; [CLI reference](https://learn.chatgpt.com/docs/non-interactive-mode)). The judge's JSON events, schema output and read-only ephemeral runs do not inherit AGY's constraints. Desktop tasks retain the app's permissions/runtime. The current transport stays the documented composer handoff until another interface passes a harmless end-to-end Computer Use check.
