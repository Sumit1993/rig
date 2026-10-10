---
name: autopilot
description: "Load before any run that outlasts the operator's attention: unattended, overnight, autonomous, \"keep going while I'm away\", a cron-driven loop, or several lanes at once. Arm the wake-up first, keep lanes in worktrees, catch stalls, verify every delegate claim, park what needs a human."
metadata:
  version: "5.0.0"
---

# Unattended run: holding a long autonomous session

One seat holds the goal across every wake-up. Every other seat is disposable. Each rule here came from a failure in a real unattended window; git history holds the stories. Assumed and not repeated: `no-doze` for how a wait is built, `farm-out` for the cheap executor, `pr-babysit` for one PR's lifecycle.

## 0. The first tick: arm the wake-up, then write the plan file

### Arm the wake-up

Nothing is dispatched until both exist. With no scheduled wake-up the run is one turn long.

1. `CronCreate` is a deferred tool. Fetch it first: `ToolSearch("select:CronCreate,CronList,CronDelete")`. Nothing prompts you to, which is why this gets skipped.
2. 30 minutes, off the :00 and :30 marks: `7,37 * * * *`. Never past the one-hour prompt cache (five minutes in usage overage); a tick past it rereads the whole context uncached, so a quiet tick is what keeps the cache warm (`#79 - autopilot §0: name the prompt-cache TTL as a ceiling on the cron interval`). A warm tick still rereads the whole context at a tenth of input price, so a large session ticks expensively: compact past ~300K before arming, and delete the job once nothing is pending rather than ticking idle (`#186 - autopilot: a warm cron tick still costs a tenth of its context`).
3. The prompt fires into this session, so ask for current state: "tick: read the plan file, check lane and PR state, then dispatch or report."
4. `CronList` after, to confirm. A cron that failed to arm looks like a quiet run.
5. Record the job ID in the plan file beside the condition that ends it (§3, the stall rule).

Jobs live in this session's memory only, fire only while the REPL is idle (so a foreground wait stays shorter than one interval), and expire after 7 days. `ScheduleWakeup` paces `/loop` and is not this.

### Write the plan file

`~/ai-context/<repo>/<issue>-<slug>/plan.md` is the source of truth: standing rules, the lane table, decisions owed, verified environment facts, a running log. If it does not exist, building it is the rest of the first tick: read the queue without touching anything, group into waves by blockers, record frozen paths.

Respect the window. Never start a lane that cannot finish and be verified in the time left. Near the end, take work only to a state that is safe to leave: pushed, commented or parked. Never mid-merge or mid-rebase.

## 1. The session and its lanes keep to their own worktrees

`AGENTS.md` §Worktrees is the rule. The main checkout and its stack belong to the session; a lane that "restores" its branch takes the run down. A lane gets an absolute worktree path and stops and reports if it is missing. The stash stack is shared by every worktree, so never a bare `git stash`: set work aside with a WIP commit.

Every dispatch prompt names the absolute worktree path, the exact verify commands the lane runs itself, the report format (findings, evidence, SHAs, blockers, no prose), the stop conditions ("abort and report rather than improvise" on any conflict, frozen path, or gate still red after N minutes), what the lane may not do (merge, close, bypass, edit a frozen path), the stall rule (§3), and the early-stop rule: status notes go in the same message as the next tool call, and it stops only when nothing can move without the operator.

Never override a lane's brief with reasoning invented on the spot; cite what supersedes it. With no source the brief wins, and a lane that refuses an unsourced order is correct.

## 2. Delegate, then verify

Verification runs once per umbrella against the build, not once per unit (§5, check every claim).

## 3. The stall rule: a wait has to hold the turn

A lane that returns saying "standing by", "waiting for" or "will be notified" has stalled. It is not waiting.

A completion notification fires only when an agent has no live background children, so a background launch followed by handing control back can never be woken. A wait is real only inside the agent's own turn: a foreground `until` loop keyed on durable evidence, loop length as the deadline (`no-doze` §2, wait on evidence).

Fix it at once and skip the acknowledgement. `SendMessage` the lane: "go read <the concrete artifact: log path, PR check, SHA> now. Then wait in the foreground with a deadline. Do not return until the evidence resolves or the deadline expires." Never accept two "waiting" reports in a row; read the artifact yourself. Put this rule in every dispatch prompt.

Evidence readable only through an MCP call is watched by the cron tick, never a monitor (`no-doze` §2, wait on evidence).

The reverse failure is a watch that outlives its job. Anything armed to watch one piece of work is torn down when that work ends; record it in the plan file's lane table beside what it watches.

## 4. A green job proves nothing. Only a posted artifact does

A workflow can report `success` having posted nothing, and does.

- Read the job that produces the artifact, not the wrapper check. A green review step means the lane ran; only the thing it was supposed to post counts.
- A green gate whose description names a retired producer is a leftover, not a pass. It flips red the moment anything re-evaluates it, and a status-only read cannot see that coming.

## 5. Check every delegate claim against live state

Check reports once per umbrella: provenance (worktree, SHA, raw output) and the diff against the spec. Re-run a gate only on a gap. Two lanes agreeing raises no confidence; they can share one stale input.

Read the delegate's full diff; a passing verify command is not evidence of behaviour. Suspect any added `continue`, `?? default`, `|| 0` or bare try/catch. A cast is proved on both halves: the runtime shape matches, and a deliberately invalid value still fails to compile.

A checked claim has three outcomes: confirmed, refuted, could not determine. A gate that writes or merges names the confirmed state it saw; "not refuted" is never a pass, and an unreadable input to a hook verdict or agy sidecar field is its own outcome, not the permissive default (`#81 - autopilot §5: a checked claim has three outcomes, not two`).

Check a PR body's claims against its file list; a body that contradicts its diff is invisible afterwards.

## 6. Ask the planner seat when the call is a judgement

Architecture, security and crypto, product semantics, and any dilemma where two rules point opposite ways go to `fable-planner` with the decision, the constraints and the options, not the whole run.

- Frame the consult around the subsystem, not the hole in front of you (§7, flip the setting).
- Reuse the same planner inside the prompt-cache hour; past it, start a new one.
- Its ruling binds that decision, and what it explicitly deferred stays deferred.
- A ruling you disagree with is still the ruling. Record the disagreement in the plan file and park it (§10, park for sign-off).

## 7 to 10. Gates, merges, bypasses, sign-off

Read `references/gates-and-merging.md` before touching a gate or a ruleset, merging anything, or parking a PR. The short form:

- A broken gate: ask whether it should exist, prefer a setting to a workflow, never parse a vendor's text (§7, flip the setting).
- Never arm auto-merge. A session that cannot merge with the operator present takes the PR to green and leaves it (§8, merging).
- Never bypass: no skip flag, `--admin` merge, `--no-verify` push or ruleset edit. Escalate (§9, never bypass).
- Work that changes what the operator sees or owns goes to green and stops; never close a diverged PR, comment on it (§10, park for sign-off).

## 11. Near-silence once the operator is away, then the handback

While the operator is away the plan file is the record; a tick reports one line or nothing. The handback is a fixed shape: one table row per PR (number, state, head SHA), then one line per decision owed, then the delta from the PR bodies. Lead with what landed. A lane that refused an unsourced order is reported as correct.

## Wake-up checklist (each tick)

1. Read the plan file first. It holds the state, not your memory.
2. Confirm the cron is still armed (`CronList`). If the session restarted, it is gone (§0, arm the wake-up).
3. Confirm every lane is alive by listing agents; a lane saying "standing by" gets the §3 fix first.
4. Check real state, not reports: default branch SHA, each PR's head SHA, each gate's description string.
5. Dispatch only work whose prerequisites are final.
6. Append findings and decisions to the plan file. One or two lines to the terminal.

Hand back on a hard blocker or when the work is done, not on a timer. Tear down the cron and every other watch (§3, the stall rule), and leave the plan file's decision list first: each entry a question, its options, and what it blocks.
