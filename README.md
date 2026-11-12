# rig

Sumit's portable Claude Code working style: one plugin plus dotfiles. A fresh machine behaves identically in two minutes.

## What's inside

Plugin `rig`, path-independent via `${CLAUDE_PLUGIN_ROOT}`:

| Piece | One line |
|---|---|
| `skills/triage` | Before any issue write: search open and closed, fold or file, Goal / Done when / Pointers, link and close right |
| `skills/compass` | Where the estate stands and what is next: goals are numbered milestones, `p0` orders inside one, the pick is one command |
| `skills/no-doze` | Wait on long work without dozing: sentinel first, evidence-keyed loops, batch scripts over agent-per-step |
| `skills/autopilot` | Hold a long unattended run: OS wake-up first (`scripts/wake.sh`, any harness), session and lanes in their own worktrees, stall rule, green is not evidence, park what needs a human |
| `skills/pr-babysit` | Watch a PR this session raised: merge contract, seed and arm the reviewer/CI Monitor, route events as pointers, merge or enqueue |
| `skills/claude-review-lane` | How `claude[bot]` behaves: liveness verdicts, the ways it stays quiet, summon grammar, verify rounds, who resolves a thread |
| `skills/coderabbit-lane` | How `coderabbitai[bot]` behaves: per-developer counter, hand admission by label, bare triggers, in-thread replies |
| `skills/assayer` | Review rounds through the assayer runner (Codex by default, OpenCode free): admission, template contract, coverage count, runner limits, round budget, findings as review debt |
| `skills/farm-out` | Antigravity CLI delegation: preflight probe, launch line, model choice, failure table, kill by PID (`kill-agy.sh`), lane worktrees (`lane-worktree.sh`), the runner's babysit loop |
| `skills/adversary` | The adversary seat challenges ideas, plans, specs, approaches, implementations and decisions; Sol via Codex by default, a fresh Opus when Codex is unavailable; evidence-backed objections survive rebuttal rounds |
| `skills/codex-desktop` | WSL hands scoped desktop work to the Windows Codex app in threads it starts with no click; Computer Use evidence returns to the judge |
| `agents/codex-runner` | Optional Haiku handler that runs one adversary-seat judgment so an organizer keeps the wait off its own context |
| `skills/docs-drift` | Four-phase docs-drift playbook plus the illustration standard |
| `skills/tweet` | Draft tweet options for @Desolatte from the session, voice and dedup from n8n |
| `skills/no-comments` | Enforce the comment budget on a diff via `agents/comment-sicko`. Vendored from pstack, patched 2026-08-22 |
| `skills/autofix` | CodeRabbit's autofix skill, patched 2026-07-12 so replies go in-thread |
| `agents/comment-sicko` | The subagent `no-comments` spawns. Deletes comments, never code |
| `agents/planner` | The planner seat: specs and rulings on Opus 5.5 at effort high |
| `agents/fable-planner` | The planner seat on Fable 5.1, used only when the operator allows Fable |
The rig plugin ships only the gates that stop real harm: `merge-gate` (no merge without `MERGE_OK`), `summon-gate` (no CodeRabbit summon without `CR_SUMMON_OK`), `no-thread-resolve`, `safe-stash` and `no-broad-agy-kill`.

`dotfiles/AGENTS.md` loads on every turn in every project, so it carries routing and rules only. Procedure lives in a skill that loads on demand. It is harness-neutral: it names seats (organizer, planner, adversary, reader, side lane) and capabilities, and `dotfiles/harness/{claude,codex,codex-desktop,agy}.md` say how each harness reaches them and which gates it enforces.

Each harness's global instructions are generated from the same two pieces, the core and that harness's overlay. Claude Code reads no user-level `AGENTS.md`, so `install.sh` writes `~/.claude/CLAUDE.md` as an `@` import of `AGENTS.md` and `harness/claude.md` from this checkout; machine-local rules go below the marker line. Codex (`~/.codex/AGENTS.md`), agy (`~/.gemini/AGENTS.md`) and the Windows Codex app get a generated file of core plus overlay. agy also keeps `GEMINI.md`, its lane-worker contract. A plugin cannot carry any of this.

Dotfiles, what a plugin cannot carry: `AGENTS.md`, `harness/*.md`, `harnesses.json`, `settings.fragment.json` (registers this repo as a marketplace and enables the plugin), `GEMINI.md`, `install.sh`, `install-windows.sh`, the `build-*-plugin.sh` builders and `dedupe.sh`.

One source, several harnesses. `dotfiles/harnesses.json` declares what each target gets: `claude` (Claude Code on WSL or native Windows, the whole plugin from the marketplace), `codex` (WSL CLI), `codex-desktop` (the Windows app), `claude-windows` and `agy` (lane-first). Per target it lists skills, hooks, agents, runtime files and the doctrine overlay. The builders read it, and a build fails on an artifact no target names, on a shipped skill that points at a skill the target lacks, and on a missing runtime file. `install.sh --check` reports drift per target, including Codex hooks still waiting for trust in `/hooks`. `dotfiles/tests/test-builders.sh` covers the builders.

## Guard observation

Hooks that block or rewrite tool calls report their firing to `mage observe`. This gives `mage why <id>` a key and records guard activations for learning.

### Guard identifiers

| Hook file | Guard id |
|---|---|
| `plugins/rig/hooks/no-broad-agy-kill.sh` | `rig/guard/no-broad-agy-kill` |
| `plugins/rig/hooks/merge-gate.sh` | `rig/guard/merge-gate` |
| `plugins/rig/hooks/safe-stash.sh` | `rig/guard/safe-stash` |
| `plugins/rig/hooks/no-thread-resolve.sh` | `rig/guard/no-thread-resolve` |

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

## New machine

```bash
git clone https://github.com/Sumit1993/rig && ./rig/dotfiles/install.sh
```

### Native Windows

Run `install.sh` from Git Bash, the shell Claude Code on Windows runs hooks in. The `claude` target then installs whole, hooks included. `install-windows.sh` installs the `codex-desktop` target into `~/.codex` only when no `codex` CLI shares it, since the app and the CLI read the same home here. Two Windows binaries need a shim in a PATH directory ahead of them, such as `~/.local/bin`:

- `jq.exe` (`winget install jqlang.jq`) writes CRLF, and `$(jq -r …)` keeps the `\r`. `install.sh` refuses to run until `jq` writes LF. The shim is `~/.local/bin/jq`: `#!/bin/sh` then `exec "<path to jq.exe>" -b "$@"`.
- python.org's installer ships no `python3.exe`, and the `python3` in `WindowsApps` is a Store alias stub. The shim is `~/.local/bin/python3`, the same two lines with `python.exe`, or turn the alias off under App execution aliases.

`.gitattributes` keeps the checkout LF regardless of `core.autocrlf`; on a clone made before it existed, run `git config core.filemode false` to drop the mode-only diffs NTFS reports.

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


## The adversary seat

Any agent loads `adversary` for adversarial scrutiny of an idea, plan, spec, approach, implementation or disputed decision. The seat looks for the strongest credible counterexample, challenges whether the checks prove the outcome, researches primary sources and withdraws objections disproven by evidence. The planner seat stays the planner/adjudicator; agy stays the side lane. A verdict never grants merge permission.

The default holder is GPT-6.1 Sol through `codex exec`, at fixed effort `high`; only the operator overrides it, through `RIG_ADVERSARY_EFFORT` (`xhigh` or `max`). Codex may delegate reading to its own subagents. When Codex is unavailable (quota exhausted or unknown, or a failed run), `--holder claude` gives the seat to a fresh Opus 5.5 process under the same contract, packet, schema and validator, never to the author's own context. `metadata.json` and `status.json` record the holder.

Requires Python 3.10+ and `jsonschema` (`python3 -c 'import jsonschema'` checks availability), plus an authenticated Codex CLI (or Claude Code for the fallback holder). The launcher uses existing CLI authentication; it does not purchase access or provision API credentials. For Codex, plugins and apps are disabled; configured MCP servers are inventoried, individually disabled and checked again before execution, and inventory failure blocks launch. The Claude holder gets only read and web tools with `--strict-mcp-config`.

For standalone ideas, plans, specs and approaches, put the actual proposal, assumptions, users, alternatives, constraints and success/failure criteria into a self-contained packet. Omit worktree/base/head; the launcher hashes and copies the proposal without requiring Git. For repository evidence, include source paths and exact base/target commits; use a clean dedicated git worktree (any worktree other than the main checkout) and snapshot uncommitted work first. Run directories are new directories under `~/ai-context/`, outside that worktree. The first packet excludes the author's persuasive defense.

The agent doing the work runs its own rounds (illustrative, not a live result):

```text
agent → launcher: packet.md, frozen worktree, round-1 directory
launcher → Codex: gpt-6.1-sol, high, read-only, 2400-second deadline
Codex → result.json: blocked; OBJ-001: retry can duplicate a side effect
agent → checks the scenario; fixes it; commits a new snapshot
agent → launcher: round-2 packet with prior ledger + fix evidence
Codex → result.json: OBJ-001 fixed, or open with the remaining counterexample
agent → records the decision and evidence; unresolved material disagreement → operator
```

The launcher lives in the skill's directory and is called by its absolute path:

```bash
python3 "$SKILL_DIR/run-review.py" --packet "$PACKET" --run-dir "$RUN_DIR"
python3 "$SKILL_DIR/run-review.py" --packet "$PACKET" --run-dir "$RUN_DIR" \
  --worktree "$REVIEW_WORKTREE" --base "$BASE_SHA" --head "$HEAD_SHA"
```

`status.json` reports completed, incomplete or failed. Only schema-valid, internally consistent responses for an unchanged target become `result.json`. A run with zero tool calls, a Codex error event such as a refusal, a quota error, a timeout, malformed output, a material coverage gap or a `survived` verdict without sources never counts as clean. Every `sources` entry naming a path or URL is matched against the run's tool calls; unmatched entries are listed, and they downgrade a `survived` verdict to `incomplete`. The launcher kills only its own process group on timeout or cancellation.

Keep stable objection IDs and pass the prior result with `--previous-result "$PREVIOUS_RESULT"` on a fresh rebuttal run. Missing prior IDs fail validation; the working agent still verifies the substance of fixed/withdrawn claims. The budget is three rounds, five only while a security, auth, data-loss or concurrency objection stays open (`adversary` §4). Copy deciding evidence into the issue/PR or private planning record, never cite telemetry paths.

Verify the launcher without model usage:

```bash
python3 -m unittest discover -s plugins/rig/skills/adversary/tests -v
```

[Codex noninteractive documentation](https://learn.chatgpt.com/docs/non-interactive-mode) covers sandboxing, saved authentication, JSON event output and schema-constrained results; [Claude Code headless documentation](https://code.claude.com/docs/en/headless) covers `--json-schema` and `structured_output`.

## Windows desktop tasks from WSL

CC or Codex load `rig:codex-desktop` to hand bounded desktop work to the Windows Codex desktop app, whose Computer Use drives the real desktop. On a WSL machine, development, CC, AGY and Rig stay in WSL; either way Windows needs the signed-in app with Computer Use enabled.

```text
packet → handoff.py → codex-lane/tasks/<slug>/ → codex_thread.py new → send → Computer Use
report + window screenshots + MD5s + build identity → CC → fresh adversarial judgment
```

`codex_thread.py` starts a thread through the app's bundled app-server, mounts it with a `codex://threads/<id>` link and queues work with `codex.exe queue`: no human Send, several threads at once. This transport is undocumented and version-pinned (verified on app 26.1002); the skill's §4 lists its limits, the per-app approval prompt and the Claude Code allow rules it needs. All threads share one trusted lane folder, so the app asks for trust once. `handoff.py --open` keeps the documented composer handoff as the fallback.
