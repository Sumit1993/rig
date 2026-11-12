---
name: autopilot
description: "Load before any run that outlasts the operator's attention: unattended, overnight, autonomous, \"keep going while I'm away\", a scheduled or cron-driven loop, or several lanes at once."
metadata:
  version: "5.0.0"
---

# Unattended run: holding a long autonomous session

One seat holds the goal across every wake-up. Every other seat is disposable. Assumed and not repeated: `no-doze` for how a wait is built, `farm-out` for the cheap executor, `babysit-pr` for one PR's lifecycle.

## 0. The first tick: arm the wake-up, then write the plan file

### Arm the wake-up

Nothing is dispatched until both exist. With no scheduled wake-up the run is one turn long. An in-session cron dies with the session and freezes in standby, so an overnight run arms the OS scheduler, which works for any harness:

```bash
wake.sh arm <name> 30 <plan-file> --harness claude|codex [--session <id>] [--cwd <repo>]
```

`wake.sh` is in this plugin's `scripts/` directory, two levels above this skill's directory. Each tick is one headless turn of that harness (resuming `--session` when given) told to read the plan file and act on everything due since the last tick; ticks never stack. Switching harness is `disarm`, then `arm`.

1. `wake.sh status <name>` after, to confirm.
2. Keep the machine awake on AC power; `arm` prints that OS's way.
3. A tick must be safe to run late or twice: it checks live state.
4. Record the name in the plan file beside the condition that ends it.

Past the one-hour prompt cache a resumed tick rereads its context uncached, so 30 minutes is the ceiling while work moves; while every lane is parked until a known time, re-arm longer. A run that ends while this session stays open may use `CronCreate` (`7,37 * * * *`) instead, never both.

### Write the plan file

`~/ai-context/<repo>/<issue>-<slug>/plan.md` is the source of truth: standing rules, the lane table, decisions owed, verified environment facts, a running log. If it does not exist, building it is the rest of the first tick: read the queue without touching anything, group into waves by blockers, record frozen paths.

Near the end of the window, take work only to a state that is safe to leave: pushed, commented or parked, never mid-merge or mid-rebase.

## 1. The session and its lanes keep to their own worktrees

`AGENTS.md` §Worktrees is the rule. The main checkout belongs to the session. A lane gets an absolute worktree path and stops and reports if it is missing. The stash stack is shared by every worktree, so set work aside with a WIP commit, not `git stash`.

Every git write names its worktree with `git -C <absolute path>`, from the session too (`farm-out` §Dispatch).

Every dispatch prompt carries the `farm-out` §Dispatch lines plus: the verify commands the lane runs itself, a report of findings, evidence, SHAs and blockers, "abort and report rather than improvise" on any conflict or gate still red, and what it may not do (merge, close, bypass, edit a frozen path). Read each lane's diff against its spec once, at the umbrella.

## 3. The stall rule: a wait has to hold the turn

A lane that returns "standing by" or "waiting for" has stalled (`no-doze` §5). A background launch followed by handing control back can never be woken; a wait is real only inside the agent's own turn, keyed on durable evidence with a deadline (`no-doze` §2). Evidence readable only through an MCP call is watched by the wake-up tick, not a monitor.

Anything armed to watch one piece of work is torn down when that work ends; record it in the plan file's lane table beside what it watches.

## 6. Ask the planner seat when the call is a judgement

Architecture, security, product semantics and any dilemma where two rules point opposite ways go to the planner seat (`AGENTS.md` §Seats) with the decision, the constraints and the options. A ruling you disagree with is still the ruling: record the disagreement in the plan file and park it (§10, park for sign-off).

## 7 to 10. Gates, merges, bypasses, sign-off

Read `references/gates-and-merging.md` before touching a gate or a ruleset, merging anything, or parking a PR. The short form:

- A broken gate: ask whether it should exist, and prefer a setting to a workflow (§7, flip the setting).
- Never arm auto-merge. A session that cannot merge with the operator present takes the PR to green and leaves it (§8, merging).
- Never bypass a gate (`--admin`, `--no-verify`, skip flags). Escalate (§9, never bypass).
- Work that changes what the operator sees or owns goes to green and stops; comment on a diverged PR instead of closing it (§10, park for sign-off).

## 11. Near-silence once the operator is away, then the handback

While the operator is away the plan file is the record; a tick reports one line or nothing, and what needs the operator goes in the umbrella issue's `PARKED:` comment. The handback is a fixed shape: one table row per PR (number, state, head SHA), then one line per decision owed, then the delta from the PR bodies. Lead with what landed. A lane that refused an unsourced order is reported as correct.

## Wake-up checklist (each tick)

1. Read the plan file first. It holds the state, not your memory.
2. Confirm the wake-up is armed (`wake.sh status`, or `CronList` for an in-session cron, which a restart loses) (§0, arm the wake-up).
3. Confirm every lane is alive by listing agents; a lane saying "standing by" gets the §3 treatment.
4. Check real state, not reports: default branch SHA, each PR's head SHA, each gate's description string.
5. Dispatch only work whose prerequisites are final.
6. Append findings and decisions to the plan file; one line to the terminal.

Hand back on a hard blocker or when the work is done, not on a timer. Disarm the wake-up and every other watch, and leave the plan file's decision list first: each entry a question, its options, and what it blocks.
