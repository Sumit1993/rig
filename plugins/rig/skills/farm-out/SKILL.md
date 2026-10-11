---
name: farm-out
description: "Load before any Agent tool call, and whenever work could go to agy, Antigravity, Gemini or a side lane: decides whether it belongs on agy (its own quota) instead of a Claude subagent, and how to dispatch one. The agy-runner loads references/handler.md for kill, resume and babysit."
metadata:
  version: "5.0.0"
---

# Delegating to Antigravity CLI (agy)

Which model gets which task is `AGENTS.md`. Model choice inside an agy run is this skill's. How to wait on a run is `no-doze`. What the runner does once a run is live (failure table, resume, kill, the babysit loop, terminal reports) is `references/handler.md`.

Verified against agy 1.2.16. Check `agy --version` before trusting a flag; `agy changelog` records what moved.

## Gotchas

- An agy run takes a median 8 minutes, p90 28, and nearly a quarter end in ERROR (#150 carries the numbers). Dispatch only what the session will not wait on.
- Permission to use subagents is not an exemption. A Claude subagent on delegable work needs a stated reason in your reply, and "simpler to set up" is not one.
- agy meters two quota groups, not one lane per model: Gemini Flash and Pro share one, Claude Opus, Claude Sonnet and GPT-OSS share the other. `agy` with no arguments prints both. Probe with `agy-quota.sh check <model>` before fanning out.
- Gemini dry moves the lane to agy's other group: relaunch the same spec on `claude-sonnet-4-6` if `agy-quota.sh check claude-sonnet-4-6` reads usable (operator ruling on #167, superseding claude-kit#118). Both groups dry ends the dispatch; the work goes to a Claude subagent on `model: sonnet` holding the same prompt file, and a run you launched yourself with no wrapper goes the same way. Never a reset timer.
- Lane count is derived from the scarce resource and its scope (a review counter, a merge invariant, a weekly pool). A limit assumed per-repo can be org-wide or per-developer.
- Reference content from another repo is fetched from live refs (`gh api repos/<r>/contents/<path>`, or `git show origin/main:<path>`), never a working tree.
- `~/.gemini/GEMINI.md` (a link to `dotfiles/GEMINI.md`) carries how agy works a lane: `view_file` for reads, `lane/scripts/run.sh` for suites, no polling, no wandering. agy loads it in `-p` runs (canary test, #167). Work orders stay lean on those; you still verify agy's claims.

## Launch

The slug is generated at launch, never hardcoded. It names the log, and through `--log-file` it is the only reliable handle on the process.

```bash
mkdir -p ~/ai-context/agy-logs
SLUG="agy-<task>-$(date +%s)"
ACTIVITY=~/ai-context/agy-logs/$SLUG.activity.log   # streams; staleness keys on this
OUT=~/ai-context/agy-logs/$SLUG.json                # the envelope, written once at the end
MODEL=gemini-3.8-flash-low
command -v jq >/dev/null 2>&1 && jq -n \
  --arg slug "$SLUG" \
  --arg model "$MODEL" \
  --arg prompt_file "<prompt-file>" \
  --arg worktree "$PWD" \
  --arg activity_log "$ACTIVITY" \
  --arg envelope "$OUT" \
  --arg stderr_file "$OUT.err" \
  --arg started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg agy_version "$(agy --version 2>/dev/null | head -1)" \
  --arg expected_commits 0 \
  --arg print_timeout 40m \
  '{slug: $slug, model: $model, prompt_file: $prompt_file, worktree: $worktree, activity_log: $activity_log, envelope: $envelope, stderr_file: $stderr_file, started_at: $started_at, agy_version: $agy_version, expected_commits: ($expected_commits | tonumber? // $expected_commits), print_timeout: $print_timeout}' \
  > "$OUT.meta.json"
agy --model "$MODEL" \
    --log-file "$ACTIVITY" \
    --output-format json \
    -p "$(cat <prompt-file>)" \
    --dangerously-skip-permissions --print-timeout 40m \
    > "$OUT" 2> "$OUT.err" &
AGY_PID=$!            # agy itself, no subshell in between
```

- Stderr goes to its own file; `2>&1` makes the envelope unparseable, which then reads as truncation.
- Stdout holds one object written at the end, so a healthy run looks frozen. Watch `$ACTIVITY`.
- `--model` takes a slug from `agy models`. No `--effort` with an effort-suffixed slug. `--print-timeout` is a Go duration (`40m`); bare `2400` exits 2.
- The sidecar `$OUT.meta.json` exists because agy's envelope omits the model.
- `run-agy-watchdog.sh` in this directory wraps the launch (positional arguments, `references/handler.md` step 1), reaps hangs and records quota walls through `agy-quota.sh record-from-envelope`. `agy-quota.sh live` reads both groups' quota at zero tokens (#133 - Every seat sees its quotas).

## Models inside agy

- `gemini-3.8-flash-low` is the default for a work order that names its files, its change and a `Verify:` line: the same order took 7 turns in 27 s on low against 11 turns in 2.9 min on high, both correct (#167). `gemini-3.8-flash-high` when the lane must work out what to change. Neither for open-ended unsupervised coding. `gemini-3.7-flash-high` if 3.8 misbehaves.
- `gemini-3.1-pro-high` is untested here and draws on Flash's pool: a quality choice, never a quota escape.
- `claude-sonnet-4-6` and `claude-opus-4-6-thinking` (agy 1.3.3 `agy models`; the 5.5 slugs of 1.2.16 are gone) sit in the other quota group with `gpt-oss-120b-medium`. `claude-sonnet-4-6` is the Gemini fallback. Its predecessor `claude-sonnet-5-5-low` did the #167 work order in 5 turns and 24 s; 4.6 is untested here. Opus there is untested and draws on the same pool.
- `gemini-3.8-flash-medium`, `gemini-3.6-flash-*` and `gemini-3.1-pro-low` are listed and untested here. Avoid `gpt-oss-120b-medium`.
- agy has its own skills: Matt Pocock's set is at `~/ai-context/vendor/mattpocock-skills` for agy-side planning and review.

## Dispatch

A lane takes side work while the session keeps coding (`AGENTS.md` §Delegation). The session writes the work order itself: the files, the command that must pass, what to return. A work order that hinges on a ruling (security, design surface, product semantics) comes from the planner seat (the `planner` agent, Opus 5.5 at effort high; `fable-planner` only when the operator allows Fable): hand it the issue, the constraints and the worktree path, and it returns the prompt file's content. A weak spec is not recoverable downstream; the lane is entitled to follow it off a cliff.

Bulk reading the organizer would otherwise wait on (logs, test output, a dozen files to summarize, a classification pass) goes to a Haiku subagent (`model: haiku`, Haiku 5.5) rather than into the organizer's context. Its prompt names what to read, what to return and how each claim is checked, as for Sonnet. Haiku never coordinates, never runs unattended and never calls a PR merge-ready.

Write the spec to `~/ai-context/<repo>/<issue>-<slug>/spec-<lane>.md` or into the repo, never `/tmp`. Its last lines are one `` Verify: `<command>` `` line and what to return. agy runs only the suites that line names, so for an end-to-end change it names every suite the change touches, Playwright specs and BDD `.feature` files alike.

Launch it yourself with Bash `run_in_background: true`: `run-agy-watchdog.sh <worktree> <spec> ~/ai-context/agy-logs/<slug>.json <expected_commits> <timeout>`. The session spends nothing while agy works; the completion notice lands when it exits. The watchdog runs the spec's `Verify:` command itself and appends one line to `<slug>.activity.log`: `AGY_EXITED rc= status= commits= dirty= verify_rc=`.
- `status=SUCCESS`, `commits` at least the expected count, `dirty=0` and `verify_rc=0`: read the diff against the spec and the tail of `<slug>.json.verify.log`. That is the whole review.
- Anything else: spawn `subagent_type: "agy-runner"` with the spec path and the envelope path to salvage, resume or finish it (`references/handler.md`). A Sonnet runner that waits on a healthy run cost a median 2.4M cache-read tokens per lane across 83 lanes (#167); spend that only on a run that needs it.

- One lane per item, run in parallel, each with its own branch and its own narrow test command. A run costs about 5 s per step, one step at a time, and every step resends the whole context. A ten-item lane took 400 steps and 40 minutes, then hit its timeout; ten one-item lanes each take a few minutes (run data in #164 - Friction from a long unattended prismalens run). Past ~140k tokens agy compacts and re-reads files (google-antigravity/antigravity-cli#878). Verification still runs once at the umbrella, after the item branches are merged into it.
- Reuse one planner inside the prompt-cache hour; a fresh one pays for the whole context again (#79 - autopilot §0: name the prompt-cache TTL as a ceiling on the cron interval). Without SendMessage, batch the hour's specs into one planner prompt.
- A running agy process takes no message: a print run is one turn, and even `--input-format stream-json` holds a message until the turn ends (agy 1.1.15 changelog). Send its follow-up as the resume prompt. A running Claude subagent takes `SendMessage` at its next tool round; name the source (the operator's words, an issue, a log path) or a well-briefed lane refuses it as unsourced (#136 - The kit matches what gh-workflows #173 changes).
- A spec pointing outside the lane's project root says to read it with Bash or Read; context-mode refuses those paths.
- The prompt goes in the file, not the subagent's prompt. Do not brief the runner on how to run agy: path in, verified report out.
- In Workflows, where `subagent_type` is unavailable: `agent(pathOnlyPrompt, {model: 'sonnet', effort: 'medium', label: 'antigravity-gemini-3.8:<task>'})`, and the prompt says to load `farm-out` and `no-doze` first. The `antigravity-<model>` label is the only sign of who is working.
