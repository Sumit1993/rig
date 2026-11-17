---
name: full-send
description: "Load when the operator says \"full send\": take the work to a merged PR with nobody watching."
metadata:
  version: "1.0.0"
---

# Full send

The operator said "full send" because they are not watching. Updates and the final message go unread until long after you stop. You own the work from its current state to a merged PR. Without an explicit "full send", none of this applies.

"Full send" grants, for this task only:

- merging this task's PR once the merge gate passes;
- `--force-with-lease` on this task's branch after a rebase;
- every test method Proof needs, without asking first.

## Testing permission

The request is the permission. A project rule that says to ask before a test method, or to leave testing to the operator, gives way for this task: computer use, `codex-desktop`, browsers, simulators, devices, running the app or a dev server, screenshots. Rules on how to test still apply: the right command, fixture or check. It covers the tests this task needs, nothing under "Asking", and never a harness approval prompt.

## Steps

1. **Finish the change** in its own worktree (`AGENTS.md` §Worktrees), branched from `origin/<default>`. The smallest change that works; fix the case that happened.
2. **Prove it.** See Proof.
3. **Challenge it.** One `adversary` round on the frozen diff, with its rebuttal budget (`adversary` §4, the budget). `council` instead when the operator asked for one.
4. **File the PR** ready for review, rebased on the latest default branch. One line in the body says how you proved the change.
5. **Babysit it** with `babysit-pr`. Summon CodeRabbit on it rather than waiting for the routine. Fix real findings and CI failures, each with its own proof before the push.
6. **Merge** when the gate passes.
7. **Report**: the PR link, the merge commit, the proof, and every decision you made for the operator.

Hold the turn from step 1 to step 7: a turn that ends while checks or bots are pending ends the work, because nobody prompts again. Wait per `no-doze` §2; a wait that may outlast the session arms `wake.sh` (`autopilot` §0). In T3 Code, `watch_pull_request`, and `unwatch_pull_request` before stopping short of the merge.

## Proof

Follow `prove-it`, and run what the repo's CI runs. No way to prove a change means no confidence: ask.

## Merge gate

On the latest commit: the proof covers every change in the diff, `babysit-pr` §Merging holds (required checks green, each reviewer has posted on the head, every finding fixed or declined with a reason, every thread resolved by its reviewer), no human review requests changes, and GitHub reports the branch up to date and mergeable. Merge the way `babysit-pr` says. Never `--admin`, never auto-merge (`autopilot` §8, merging).

## Asking

Ask only when you cannot go on alone:

- you cannot prove the change;
- the gate cannot pass and you cannot fix that;
- the next step is outside the grant: deleting data, touching production, changing things outside the repo, closing a PR, force-pushing another branch;
- the goal is ambiguous in a way that changes the result;
- another PR makes this one obsolete.

The operator is away, so a question in a reply goes unseen. Put it in one PR comment, or the umbrella issue's when there is no PR (`AGENTS.md` §Reporting and merging): what blocks you, the options, your recommendation first. In an interactive session also use the harness's question tool. Leave the PR open and unmerged, and start the final message with the question. Decide everything else with sensible defaults and list those decisions in the report.
