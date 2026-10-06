---
name: farm-out
description: "Load before any Agent tool call, and whenever work could go to agy, Antigravity, Gemini or a side lane: decides whether it belongs on agy (its own quota) instead of a Claude subagent, and how to dispatch one. The agy-runner loads references/handler.md for kill, resume and babysit."
metadata:
  version: "5.0.0"
---

# Delegating to Antigravity CLI (agy)

Which model gets which task is `AGENTS.md`. Model choice inside an agy run is this skill's. How to wait on a run is `no-doze`. What the runner does once a run is live (failure table, resume, kill, the babysit loop, terminal reports) is `references/handler.md`.

Verified against agy 1.1.27. Check `agy --version` before trusting a flag; `agy changelog` records what moved.

## Gotchas

- An agy run takes a median 8 minutes, p90 28, and nearly a quarter end in ERROR (#150 carries the numbers). Dispatch only what the session will not wait on.
- Permission to use subagents is not an exemption. A Claude subagent on delegable work needs a stated reason in your reply, and "simpler to set up" is not one.
- agy meters two quota groups, not one lane per model: Gemini Flash and Pro share one, Claude Opus, Claude Sonnet and GPT-OSS share the other. `agy` with no arguments prints both. Probe with `agy-quota.sh check <model>` before fanning out.
- Gemini dry ends the dispatch; the work goes to a Claude subagent on `model: sonnet` holding the same prompt file, and a run you launched yourself with no wrapper goes the same way. Never a reset timer, and never the Claude and GPT group.
- Lane count is derived from the scarce resource and its scope (a review counter, a merge invariant, a weekly pool). A limit assumed per-repo can be org-wide or per-developer.
- Reference content from another repo is fetched from live refs (`gh api repos/<r>/contents/<path>`, or `git show origin/main:<path>`), never a working tree.
- `~/.gemini/GEMINI.md` carries the global standards agy loads itself. Prompts stay lean on those; you still verify agy's claims.

## Launch

The slug is generated at launch, never hardcoded. It names the log, and through `--log-file` it is the only reliable handle on the process.

```bash
mkdir -p ~/ai-context/agy-logs
SLUG="agy-<task>-$(date +%s)"
ACTIVITY=~/ai-context/agy-logs/$SLUG.activity.log   # streams; staleness keys on this
OUT=~/ai-context/agy-logs/$SLUG.json                # the envelope, written once at the end
MODEL=gemini-3.8-flash-high
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

- `gemini-3.8-flash-high` for all delegable work with a strict template and a clear spec. Not open-ended unsupervised coding. `gemini-3.7-flash-high` if 3.8 misbehaves.
- `gemini-3.8-flash-low` for purely mechanical items (a rename, a known one-line fix, running a suite): it skips thinking and runs about 3–4 s per step against 6–8 s on high (local agy transcripts, measured 2026-10).
- `gemini-3.1-pro-high` is untested here and draws on Flash's pool: a quality choice, never a quota escape.
- `claude-opus-4-6-thinking` and `claude-sonnet-4-6` sit in the other quota group and are not the Gemini fallback.
- Avoid `gemini-3.5-flash-*` and `gpt-oss-120b-medium`.
- agy has its own skills: Matt Pocock's set is at `~/ai-context/vendor/mattpocock-skills` for agy-side planning and review.

## Dispatch

A lane takes side work while the session keeps coding (`AGENTS.md` §Delegation). The session writes the work order itself: the files, the command that must pass, what to return. A work order that hinges on a ruling (security, design surface, product semantics) comes from `fable-planner`: hand it the issue, the constraints and the worktree path, and it returns the prompt file's content. A weak spec is not recoverable downstream; the lane is entitled to follow it off a cliff.

Write the spec to `~/ai-context/<repo>/<issue>-<slug>/spec-<lane>.md` or into the repo, never `/tmp`. Spawn `subagent_type: "agy-runner"` with the path. That is the whole dispatch.

- One lane per item, run in parallel, each with its own branch and its own narrow test command. A run costs about 5 s per step, one step at a time, and every step resends the whole context. A ten-item lane took 400 steps and 40 minutes, then hit its timeout; ten one-item lanes each take a few minutes (run data in #164 - Friction from a long unattended prismalens run). Past ~140k tokens agy compacts and re-reads files (google-antigravity/antigravity-cli#878). Verification still runs once at the umbrella, after the item branches are merged into it.
- Every work order carries: "Run tests, typecheck and builds in the foreground with `WaitMsBeforeAsync` 600000. Never background a command and poll it." agy's default of 5000 sends every suite to the background, and each status poll is a full step. Across 72 runs that came to 593 polls, and 7 runs were still waiting when the timeout hit (#164).
- Batch reads: one shell command reads several files, and each file is read once, whole.
- Reuse one planner inside the prompt-cache hour; a fresh one pays for the whole context again (#79 - autopilot §0: name the prompt-cache TTL as a ceiling on the cron interval). Without SendMessage, batch the hour's specs into one planner prompt.
- A running agy process takes no message: a print run is one turn, and even `--input-format stream-json` holds a message until the turn ends (agy 1.1.15 changelog). Send its follow-up as the resume prompt. A running Claude subagent takes `SendMessage` at its next tool round; name the source (the operator's words, an issue, a log path) or a well-briefed lane refuses it as unsourced (#136 - The kit matches what gh-workflows #173 changes).
- A spec pointing outside the lane's project root says to read it with Bash or Read; context-mode refuses those paths.
- The prompt goes in the file, not the subagent's prompt. Do not brief the runner on how to run agy: path in, verified report out.
- In Workflows, where `subagent_type` is unavailable: `agent(pathOnlyPrompt, {model: 'sonnet', effort: 'medium', label: 'antigravity-gemini-3.8:<task>'})`, and the prompt says to load `farm-out` and `no-doze` first. The `antigravity-<model>` label is the only sign of who is working.
