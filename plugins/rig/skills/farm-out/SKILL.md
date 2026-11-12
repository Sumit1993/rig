---
name: farm-out
description: "Load before any Agent tool call, whenever work could go to agy, Antigravity, Gemini or a side lane, and when an agy run needs launching, killing, resuming or salvaging."
metadata:
  version: "5.0.0"
---

# Delegating to Antigravity CLI (agy)

Which model gets which task is `AGENTS.md`. Model choice inside an agy run is this skill's. How to wait on a run is `no-doze`. What the runner does once a run is live (failure table, resume, kill, the babysit loop, terminal reports) is `references/handler.md`.

Verified against agy 1.4.7. Check a flag in `agy --help`.

## Gotchas

- An agy run takes a median 8 minutes, p90 28, and nearly a quarter end in ERROR. Dispatch only what the session will not wait on.
- agy meters two quota groups, not one lane per model: Gemini Flash and Pro share one, Claude Opus, Claude Sonnet and GPT-OSS share the other. `agy` with no arguments prints both. Probe with `agy-quota.sh check <model>` before fanning out.
- Gemini dry moves the lane to agy's other group: relaunch the same spec on `claude-sonnet-4-6` if `agy-quota.sh check claude-sonnet-4-6` reads usable. Both groups dry ends the dispatch; the work goes to a Claude subagent on `model: sonnet` holding the same prompt file, and a run you launched yourself with no wrapper goes the same way.
- Reference content from another repo is fetched from live refs (`gh api repos/<r>/contents/<path>`, or `git show origin/main:<path>`), never a working tree. Under Git Bash a `<rev>:<path>` argument needs `MSYS_NO_PATHCONV=1`, or it arrives as `origin\main;...`.
- `~/.gemini/GEMINI.md` (a copy of `dotfiles/GEMINI.md`; re-run `install.sh` after editing it) carries how agy works a lane: `view_file` for reads, `lane/scripts/run.sh` for suites, no polling, no wandering. agy loads it in `-p` runs (canary test, #167). Work orders stay lean on those; you still verify agy's claims.

## Launch and models

Read `references/launch.md` before launching an agy run: the watchdog command, its sidecar, model slugs and quota.

## Dispatch

A lane takes side work while the session keeps coding (`AGENTS.md` §Delegation). The session writes the work order itself: the files, the command that must pass, what to return. A work order that hinges on a ruling (security, design surface, product semantics) comes from the planner seat (the `planner` agent, Opus 5.5 at effort high; `fable-planner` only when the operator allows Fable): hand it the issue, the constraints and the worktree path, and it returns the prompt file's content. 

Bulk reading the organizer would otherwise wait on (logs, test output, a dozen files to summarize, a classification pass) goes to a Haiku subagent (`model: haiku`, Haiku 5.5) rather than into the organizer's context. Its prompt names what to read and what to return.

Write the spec to `~/ai-context/<repo>/<issue>-<slug>/spec-<lane>.md` or into the repo, never `/tmp`. Its last lines are one `` Verify: `<command>` `` line and what to return. agy runs only the suites that line names, so for an end-to-end change it names every suite the change touches, Playwright specs and BDD `.feature` files alike. A TypeScript lane's line runs the tests and `tsc --noEmit` both.

Every work order and every subagent prompt also says: every git write is `git -C <absolute worktree path>` (the Bash cwd carries over between calls, so a bare `git rebase` lands in whichever worktree the last `cd` left). A Claude subagent's prompt also says: stop any monitor or watch you armed before you report, and return a document as text for the organizer to save (the harness refuses a subagent's report file). An agy lane arms no monitor and may save evidence files.

The organizer sets the lane's worktree up before launch. `lane-worktree.sh add <repo> <path> <branch> origin/<default>` in this directory adds it and copies the gitignored files the repo's `.worktreeinclude` names (`.env` and the like). Then run the install and build the `Verify:` line needs in it: `pnpm install --frozen-lockfile`, and in a monorepo the workspace packages the lane imports (`turbo build --filter=<pkg>...`), or vitest and `tsc` cannot resolve them. Once the work lands, `lane-worktree.sh remove <path>`, never `git worktree remove` (fails on long `node_modules` paths on Windows) or `robocopy /MIR` (follows pnpm links into other trees).

Launch it yourself, one background job per lane (Claude Code: Bash `run_in_background: true`; Codex: a detached job, `dotfiles/harness/codex.md`): `run-agy-watchdog.sh <worktree> <spec> ~/ai-context/agy-logs/<slug>.json <expected_commits> <timeout> <model>`, the model per `references/launch.md`. A `nohup … &` loop sends no completion notices. The watchdog runs the spec's `Verify:` command itself and appends one line to `<slug>.activity.log`: `AGY_EXITED rc= status= commits= dirty= verify_rc=`.
- `status=SUCCESS`, `commits` at least the expected count, `dirty=0` and `verify_rc=0`: read the diff against the spec and the tail of `<slug>.json.verify.log`. That is the whole review. An evidence-only lane passes `expected_commits` 0 and is clean at `commits=0`; its spec saved inside the worktree is not counted in `dirty`.
- Anything else: spawn `subagent_type: "agy-runner"` with the spec path and the envelope path to salvage, resume or finish it (`references/handler.md`).

- One lane per item, run in parallel, each with its own branch and its own narrow test command. A run costs about 5 s per step, one step at a time, and every step resends the whole context. A ten-item lane took 400 steps and 40 minutes; ten one-item lanes each take a few minutes. Verification still runs once at the umbrella, after the item branches are merged into it.
- Reuse one planner inside the prompt-cache hour with SendMessage.
- A running agy process takes no message: a print run is one turn, and even `--input-format stream-json` holds a message until the turn ends (agy 1.1.15 changelog). Send its follow-up as the resume prompt. A running Claude subagent takes `SendMessage` at its next tool round; name the source (the operator's words, an issue, a log path) or a well-briefed lane refuses it as unsourced.
- A spec pointing outside the lane's project root says to read it with Bash or Read; context-mode refuses those paths.
- The prompt goes in the file, not the subagent's prompt. Do not brief the runner on how to run agy: path in, verified report out.
- In Workflows, where `subagent_type` is unavailable: `agent(pathOnlyPrompt, {model: 'sonnet', effort: 'medium', label: 'antigravity-gemini-3.8:<task>'})`, and the prompt says to load `farm-out` and `no-doze` first.
