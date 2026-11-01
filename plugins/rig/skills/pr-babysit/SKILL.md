---
name: pr-babysit
description: "Load after any gh pr create, and when asked to watch, babysit, hold a review round on, or merge a PR."
metadata:
  version: "5.0.0"
---

# PR watch: the session-scoped review round

The default is async (`Sumit1993/rig#150`). Keep the PR a draft while work continues, mark it ready once at the end, and leave it. The hourly CodeRabbit routine (`scripts/coderabbit-routine/` in Sumit1993/rig) summons CodeRabbit on it, and findings come back as review debt at the next session start in that repo (`compass` Step 0). Phases 1 and 2 run only when the operator asks to hold a round in this session; Phase 3 also runs when the operator asks to merge.

A held round is one PR, whichever session raised it, watched until its round ends, so the session reacts to findings without the user relaying them. Not a lifecycle manager: the merge queue removed cascade shepherding, and a PR left over from an earlier session needs no local watcher because GitHub notifications cover verify-then-resolve and enqueue.

Reviewer behaviour lives elsewhere. `claude-review-lane` owns `claude[bot]`, `coderabbit-lane` owns `coderabbitai[bot]`, and both load on a PR of any age. Load the owning skill before acting on that reviewer. The trigger syntax and `cr-reply.sh` appear below so a router recognises them; the preconditions (cooldown arithmetic, budget, the post-trigger poll) live only there, and acting on the fragments produces confidently wrong reports.

Process truth is `rig/docs/pr-review-process.html`. Whoever changes the process updates that page in the same session.

Reviews arrive on their own schedule: the Claude lane in 2 to 5 minutes, CodeRabbit within the hour the routine summons it (median 3.5 hours after a burst of PRs), CI in 5 to 10. Never poll with model turns. Never wait for the user to relay an event. Arm a deterministic watcher and process deltas.

Scripts sit in this skill's directory; shared ones (`cr-reply.sh`, `rig-meta.sh`) in this plugin's `scripts/` directory, two levels up (`<skill-dir>/../../scripts/`). Resolve both to absolute paths before handing them to a watcher or a background process. Watch scripts read the repo off the cwd's origin remote; `--repo owner/name` overrides.

Per-repo facts come from the registry, never from memory. Run `<skill-dir>/../../scripts/rig-meta.sh current` first; it reads `data/repo-meta.json` folded with runtime observations.

## Phase 0: the merge contract

Whether anything is enforced is a per-repo fact. `rig-meta.sh get <owner/repo> enforced` answers without a network call. `false` means we checked and nothing is enforced, so holding the PR for the operator is the only gate. "No such key" means we never looked. Read enforcement off `rulesets`; a 404 from `branches/<b>/protection` proves nothing, because a repo on rulesets returns 404 there either way.

Where a repo enforces, the contract is three facts:

- Two required checks, `CI gate` and `Validate PR title (conventional commits)`. Nothing else. No review check, evidence artifact, marker job, SHA pinning, carry-forward or committed high-risk path list. `cr-preview.sh` and `cr-evidence.sh` do not exist.
- `required_review_thread_resolution: true`. One unresolved thread blocks the merge. The merge condition is stricter than the ruleset: every review thread resolved by the reviewer that opened it. GitHub cannot tell who resolved a thread, so check it: a thread this session resolved does not count. This is the only thing that enforces a finding, which is what makes Phase 2's in-thread protocol load-bearing.
- Reviewers are advisory. No check waits on them, so no check proves a review happened. What counts as evidence is in `claude-review-lane`.

Push freely; nothing runs pre-push. Escalate by risk, and never pay model tokens for review a cheaper layer already covers:

| Tier | When | What |
|---|---|---|
| Claude review (`claude[bot]`) | Where `rig-meta.sh get <repo> claude_lane` says the lane runs: every same-repo PR, automatic, but not every round and not every author | The default. Inline findings. Advisory, but every thread it opens blocks. See `claude-review-lane` |
| CodeRabbit (`coderabbitai[bot]`) | Every ready PR not labelled `coderabbit_skip`, summoned by the hourly CodeRabbit routine; `auto_review` is off everywhere | The independent lane, drawing a scarce per-developer counter. See `coderabbit-lane` |
| Codex (`assayer review`) | Only when the operator runs it, any repo | Findings post as the operator, each ending in `assayer-finding`. See `assayer` |
| One Opus 5 pass | Non-trivial PRs | Spec and ADR conformance, which the bots cannot see |
| `/code-review ultra` | Rare | Engine core, security boundary, contract or schema changes |

A PR body that closes several issues repeats the keyword per issue, `closes #a, closes #b`; GitHub links only the first number after one keyword. `pr-created.sh` reads `closingIssuesReferences` and says when the body names more than GitHub linked (gh-workflows #140 claimed seven, linked one).

Never bypass the ruleset. Batch every fix before you push: the routine can summon a ready PR on its next hourly run, so a push mid-batch spends a slot on a commit you are about to amend. Keep the PR a draft while commits are still coming.

## Phase 1: arm the watcher, only for a held round

Only when the operator asks to hold a round here, or to merge: read `references/held-round.md`.

## Phase 2: on each event

Only when the operator asks to hold a round here, or to merge: read `references/held-round.md`.

## Phase 3: merge, once the user says so or under an explicit standing grant

Only when the operator asks to hold a round here, or to merge: read `references/held-round.md`.

## Notes

- Auto-merge and the merge queue both outrun every reviewer. The thread gate only blocks once a thread exists, and auto-merge can fire between a review landing and its fix commit. Order the round as review posted, then fix, then resolve, then merge, never the reverse. On queue repos "review posted" is read off the liveness comment.
- Never wait on `mergeStateStatus`. An unresolved thread pins it at `BLOCKED`. Key on `reviewThreads` and comment IDs (`no-doze` §3, conditions the event prevents).
- Wait for CI on `gh pr checks <n> --required`, never on `statusCheckRollup[].status`. CodeRabbit's `CodeRabbit` commit status is a `StatusContext`, which carries `.state` and no `.status`, so a loop waiting for every entry to read `COMPLETED` only ends at its deadline (seen on prismalens/prismalens#727).
- Watching is cheap: a shell poll every 75 seconds, zero tokens while quiet. Prefer over-watching to relaying.
- Rate limits are invisible on both obvious channels. CodeRabbit posts the notice as an issue comment, so `/pulls/N/comments` misses it, and the `Review rate limited` check passes by design. `watch-coderabbit.sh` polls `/issues/N/comments` for the `rate limited by coderabbit.ai` marker, deduped on `updated_at` because CodeRabbit edits one summary comment in place.
- `~/ai-context/state/cr-watch/` is durable across sessions. Re-arming is always safe.
- A `git checkout` under a running watcher kills it. Bash reads a script incrementally, so switching branches rewrites `watch-coderabbit.sh` beneath the running shell, usually exit 144, with no event. Re-arm after any branch change, or run the watcher from a path that is not moving.
- A watcher dies with its task, not the session. Stop it the moment its PR is merged, closed or handed off. In Claude Code the SessionEnd hook also kills watchers and SessionStart reaps orphans; re-arming after either is free. Elsewhere kill it by its captured PID (`no-doze`, killing safely).
- In Claude Code, `hooks/pr-created.sh` injects a reminder whenever a PR URL appears in a Bash or Agent tool result, seeds the seen-state, and says when the new PR touches files an open draft already changes. It reminds the session that reviews run async; run Phase 1 only for a held round. It also runs on `Agent`, because an agy lane's PR URL arrives in the handler's report, not a Bash result.
- Phase 3's cascade is a background process with a single completion, not a persistent watcher.
