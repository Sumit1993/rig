# rig

Sumit's portable Claude Code working style: one plugin plus dotfiles. A fresh machine behaves identically in two minutes.

## What's inside

Plugin `rig`, path-independent via `${CLAUDE_PLUGIN_ROOT}`:

| Piece | One line |
|---|---|
| `skills/triage` | Before any issue write: search open and closed, fold or file, Goal / Done when / Pointers, link and close right |
| `skills/compass` | Where the estate stands and what is next: goals are numbered milestones, `p0` orders inside one, the pick is one command |
| `skills/no-doze` | Wait on long work without dozing: sentinel first, evidence-keyed loops, batch scripts over agent-per-step |
| `skills/autopilot` | Hold a long unattended run: cron wake-up first, session and lanes in their own worktrees, stall rule, green is not evidence, park what needs a human |
| `skills/pr-babysit` | Watch a PR this session raised: merge contract, seed and arm the reviewer/CI Monitor, route events as pointers, merge or enqueue |
| `skills/claude-review-lane` | How `claude[bot]` behaves: liveness verdicts, the ways it stays quiet, summon grammar, verify rounds, who resolves a thread |
| `skills/coderabbit-lane` | How `coderabbitai[bot]` behaves: per-developer counter, hand admission by label, bare triggers, in-thread replies |
| `skills/farm-out` | Antigravity CLI delegation: preflight probe, launch line, model choice, failure table, kill by PID, the runner's babysit loop |
| `skills/codex-judge` | Codex challenges ideas, plans, specs, approaches, code and decisions; evidence-backed objections survive rebuttal rounds |
| `skills/codex-desktop` | WSL hands scoped desktop work to the Windows Codex app in threads it starts with no click; Computer Use evidence returns to the judge |
| `agents/codex-runner` | Thin Claude handler for one bounded independent Codex review; no self-review fallback |
| `skills/docs-drift` | Four-phase docs-drift playbook plus the illustration standard |
| `skills/tweet` | Draft tweet options for @Desolatte from the session, voice and dedup from n8n |
| `skills/no-comments` | Enforce the comment budget on a diff via `agents/comment-sicko`. Vendored from pstack, patched 2026-08-22 |
| `skills/autofix` | CodeRabbit's autofix skill, patched 2026-07-12 so replies go in-thread |
| `agents/comment-sicko` | The subagent `no-comments` spawns. Deletes comments, never code |
| `hooks/pr-created.sh` | PostToolUse(Bash, Agent): a real PR URL injects "pick its watcher now": `/autofix-pr` by default, the pr-babysit Monitor for a held round |
| `hooks/delegate-check.sh` | PreToolUse(Agent): blocks a Claude subagent on delegable work. Escape: name agy in the prompt |
| `hooks/no-haiku.sh` | PreToolUse(Agent): blocks `model=haiku` |
| `hooks/no-broad-agy-kill.sh` | PreToolUse(Bash): blocks a kill that targets agy by name; kill by PID or slug |
| `hooks/release-docs-gate.sh` | PreToolUse(Bash): blocks merging a release PR without a docs audit in 14 days. Escape: `DOCS_GATE=skip` |
| `hooks/reap-watchers.sh` | SessionEnd kills watchers, SessionStart reaps orphans. Seen-state is durable so this is free |
| `hooks/gh-body-no-scratch.sh` | PreToolUse(Bash): blocks gh issue/pr citing ai-context or /tmp. Escape: `SCRATCH_GATE=skip` |
| `hooks/gh-body-stamp.sh` | PreToolUse(Bash): blocks gh issue/pr posts whose body carries no operator-stamp marker. Escape: `STAMP_GATE=skip` |
| `hooks/issue-create-nudge.sh` | PreToolUse(Bash): nudges on third gh issue create this session to fold into an umbrella |
| `hooks/session-budget.sh` | SessionStart: one line with the 5h and 7d percent from `~/.claude/metrics/usage.jsonl`, agy quota per group, the resume cost on `--resume`, and the cheap-mode policy |
| `hooks/review-debt.sh` | SessionStart: unresolved review threads on author's non-draft PRs; clear review debt before any new pick |
| `hooks/limit-log.sh` | StopFailure(rate_limit, overloaded) and Notification(quota_auto_resume_*): one JSON line each in `~/.claude/metrics/limits.jsonl` |
| `hooks/outside-view-nudge.sh` | PreToolUse(AskUserQuestion, EnterPlanMode, fable-planner spawn): get an outside view first. 1st time, then every 3rd per session |
| `hooks/gh-write-nudge.sh` | PreToolUse(Bash): nudges once per session on a handoff-shaped or 40-plus-line gh body, a bare `#N`, and a non-draft `gh pr create` |
| `hooks/draft-posted-nudge.sh` | PostToolUse(Bash): a body file posted from ai-context is told to delete the draft, once per file |
| `hooks/agent-prompt-nudge.sh` | PreToolUse(Agent): a Fable or Opus prompt asking it to show its reasoning, a Sonnet prompt with no verify step, a second fable-planner inside the cache hour |
| `hooks/protected-edit-gate.sh` | PreToolUse(Edit, Write): blocks edits to loose skill copies and to the import line of `~/.claude/CLAUDE.md` |
| `hooks/merge-gate.sh` | PreToolUse(Bash): blocks `gh pr merge` and `pulls/N/merge` without `MERGE_OK=<pr>` on the same command |

`dotfiles/AGENTS.md` loads on every turn in every project, so it carries routing and rules only. Procedure lives in a skill that loads on demand.

Claude Code does not read the name `AGENTS.md` on its own. `install.sh` writes `~/.claude/CLAUDE.md` as a one-line `@` import to this checkout, so there is one copy. Machine-local rules go below the import line. A plugin cannot carry this; Claude Code does not load a `CLAUDE.md` at a plugin root.

Dotfiles, what a plugin cannot carry: `AGENTS.md`, `statusline-command.sh`, `agy-statusline-command.sh`, `settings.fragment.json` (registers this repo as a marketplace and enables the plugin), `GEMINI.md` (agy's global rules, linked to `~/.gemini/GEMINI.md`), `install.sh`, `build-agy-plugin.sh`, `dedupe.sh`.

Two harnesses, one source. `plugins/rig` is the Claude Code plugin. `install.sh` builds the agy plugin from it with `build-agy-plugin.sh` and runs `agy plugin install` on the result. Only skills whose `metadata.harnesses` names `agy` cross; untagged means Claude-only. agy runs as a headless lane worker, so only `lane` carries the tag. Hooks and agents never cross: agy's hooks read `toolCall.args` and answer with a `decision` field, and its agents take different model names. `hooks/tests/test-harness-split.sh` fails if a tagged skill names a Claude-only tool.

## Guard observation

Hooks that block or rewrite tool calls report their firing to `mage observe`. This gives `mage why <id>` a key and records guard activations for learning.

### Guard identifiers

| Hook file | Guard id |
|---|---|
| `plugins/rig/hooks/delegate-check.sh` | `rig/guard/delegate-check` |
| `plugins/rig/hooks/no-haiku.sh` | `rig/guard/no-haiku` |
| `plugins/rig/hooks/no-broad-agy-kill.sh` | `rig/guard/no-broad-agy-kill` |
| `plugins/rig/hooks/release-docs-gate.sh` | `rig/guard/release-docs-gate` |
| `plugins/rig/hooks/protected-edit-gate.sh` | `rig/guard/protected-edit-gate` |
| `plugins/rig/hooks/merge-gate.sh` | `rig/guard/merge-gate` |

Hooks that neither block nor rewrite (`pr-created.sh` and `reap-watchers.sh`) have no guard identifier.

### Header convention and reporting

Each blocking hook declares its identifier directly below the shebang line:

```bash
# mage:rig/guard/<slug>
```

Before exiting on a block decision, the hook calls the shared reporter:

```bash
report_guard "rig/guard/<slug>" "$tool" "$detail"
```

The reporter library is at `plugins/rig/hooks/lib/report-guard.sh`.

### Fail-open contract

The reporter is fire-and-forget and always fails open. If `mage` or `jq` is absent from PATH, the function returns 0. Calls to `mage observe` run with a 5 second timeout. Any error, non-zero exit, or timeout is ignored so the hook still exits with its block code. The reporter writes nothing to stdout because hook stdout is a protocol channel.

### Worked example

When an agent invokes `Agent` with `claude-haiku-4-5-20251001`, `plugins/rig/hooks/no-haiku.sh` blocks. The agent receives this message on stderr:

```
Blocked by routing doctrine (dotfiles/AGENTS.md): never use Haiku. Pick sonnet or above.
mage:rig/guard/no-haiku
```

At the same time, `no-haiku.sh` pipes the following payload to `mage observe` on stdin:

```json
{
  "guard_id": "rig/guard/no-haiku",
  "tool": "Agent",
  "detail": "claude-haiku-4-5-20251001"
}
```

## New machine

```bash
git clone https://github.com/Sumit1993/rig && ./rig/dotfiles/install.sh
```

## Vendored skills and their updates

Skills sourced from someone else live here as real copies, never symlinks. A symlink puts the file under another tool's ownership, and `coderabbit skills` and `npx skills` both replace what they manage, dropping any patch.

Every vendored `SKILL.md` records `upstream` in `metadata`, and a patched one also records `upstream_version`, `upstream_latest_seen`, `patched` and `patch_note`. Checking for updates is manual:

```bash
coderabbit skills          # CodeRabbit's autofix; reports its current version
npx skills                 # the pstack-sourced skills
```

When upstream has moved, re-apply the patch onto the new copy rather than diffing two blobs.

## Editing

This repo is the source of truth. Edit here, commit, push; machines with `autoUpdate: true` pick it up. Never edit the loose `~/.claude/skills/` or `~/.agents/skills/` copies; `dedupe.sh` removes them after first plugin load.

Not vendored: `mattpocock/skills`, subscribed as `mattpocock-skills@mattpocock` through `settings.fragment.json`, because a copy installed via `npx skills add` rots silently and a plugin cannot drift. mage and context-mode own their own lifecycles. Tokens and auth never live here.

Rule of thumb: if upstream ships a plugin, subscribe to it. Vendor a skill only when you patch it, and say so in the table. pstack is the exception: subscribing pulls 44 skills, about 20 of them one-idea `principle-*` files restating `AGENTS.md`, so one skill and one agent are vendored and patched.

Run `plugins/rig/scripts/ai-context-sweep.sh` (`--delete`) to list or prune `~/ai-context` candidates whose issues have closed.


## Independent Codex challenger

Claude Code loads `rig:codex-judge` for adversarial scrutiny of an idea, plan, spec, approach, code change or disputed decision. Codex looks for the strongest credible counterexample, challenges whether the checks prove the outcome, researches primary sources and withdraws objections disproven by evidence. Fable remains the Claude-side planner/adjudicator; AGY remains the execution lane. This local review does not replace required PR reviewers or grant merge permission.

Requires an authenticated Codex CLI, Python 3.10+ and `jsonschema` (`python3 -c 'import jsonschema'` checks availability). The launcher uses existing CLI authentication; it does not purchase access or provision API credentials. Choose a model with `--model` or `RIG_CODEX_MODEL`; `gpt-6.1-sol` is the current default. Model, effort and sandbox are recorded explicitly. Plugins/apps are disabled; configured MCP servers are inventoried, individually disabled and checked again before execution. Inventory failure blocks launch. Configuration must remain unchanged during a run; this is verified local capability reduction, not a general external-service isolation guarantee. Effort is explicit: high by default, xhigh for consequential or unresolved judgments.

For standalone ideas, plans, specs and approaches, put the actual proposal, assumptions, users, alternatives, constraints and success/failure criteria into a self-contained packet. Omit worktree/base/head; the launcher hashes and copies the proposal without requiring Git. For repository evidence, include source paths and exact base/target commits; use a clean dedicated worktree under `.claude/worktrees/` and snapshot uncommitted work first. Run directories are new directories under `~/ai-context/`, outside that worktree. The first packet excludes the author's persuasive defense. Read-only execution cannot run checks that require writes; report them unverified or validate separately.

Worked review and rebuttal flow (illustrative, not a live result):

```text
CC → codex-runner: packet.md, frozen review worktree, round-1 directory
launcher → Codex: configured model, high, read-only, 1200-second deadline
Codex → result.json: blocked; OBJ-001: retry can duplicate a side effect
CC → checks the scenario; fixes it; commits a new review snapshot
CC → codex-runner: round-2 packet with prior ledger + fix evidence
Codex → result.json: OBJ-001 fixed, or open with the remaining counterexample
CC → records the decision and evidence; unresolved material disagreement → operator
```

A standalone proposal needs only:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/codex-judge/run-review.py" \
  --packet "$PACKET" --run-dir "$RUN_DIR" --effort high
```

For repository evidence, the thin runner invokes:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/codex-judge/run-review.py" \
  --packet "$PACKET" --worktree "$REVIEW_WORKTREE" --run-dir "$RUN_DIR" \
  --base "$BASE_SHA" --head "$HEAD_SHA" --effort high --timeout 1200
```

`status.json` reports completed, incomplete or failed. Only schema-valid, internally consistent responses for an unchanged target become `result.json`; a blocked verdict is a completed review, not a failed process. Quota errors, timeout, malformed output and material coverage gaps never count as a clean review. The launcher kills only its own process group on timeout or cancellation. Review prompts prohibit external writes; the filesystem sandbox alone is not an external-service permission boundary.

Keep stable objection IDs and pass the prior result with `--previous-result "$PREVIOUS_RESULT"` on a fresh rebuttal run. Missing prior IDs fail validation; the session still verifies the substance of fixed/withdrawn claims. The default budget is an initial review and one rebuttal; further review needs a new concrete question, not a demand for agreement. Copy deciding evidence into the issue/PR or private planning record, never cite telemetry paths. Do not silently fall back to Claude or another model.

Verify the launcher without model usage:

```bash
python3 -m unittest discover -s plugins/rig/skills/codex-judge/tests -v
```

[Official Codex noninteractive documentation](https://learn.chatgpt.com/docs/non-interactive-mode) covers explicit sandboxing, saved authentication, JSON event output and schema-constrained results.

## Windows desktop tasks from WSL

CC, AGY or Codex load `rig:codex-desktop` to hand bounded desktop work to the Windows Codex desktop app, whose Computer Use drives the real desktop. Development, CC, AGY and Rig stay in WSL; Windows needs the signed-in app with Computer Use enabled.

```text
packet → handoff.py → codex-lane/tasks/<slug>/ → codex_thread.py new → send → Computer Use
report + window screenshots + MD5s + build identity → CC → fresh adversarial judgment
```

`codex_thread.py` starts a thread through the app's bundled app-server, mounts it with a `codex://threads/<id>` link and queues work with `codex.exe queue`: no human Send, several threads at once. This transport is undocumented and version-pinned (verified on app 26.1002); the skill's §4 lists its limits, the per-app approval prompt and the Claude Code allow rules it needs. All threads share one trusted lane folder, so the app asks for trust once. `handoff.py --open` keeps the documented composer handoff as the fallback.
