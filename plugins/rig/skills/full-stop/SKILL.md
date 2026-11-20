---
name: full-stop
description: "Load when the operator says \"full stop\", even as a closing \"Full stop.\" that reads like emphasis: the full-send work, stopping with the PR ready to merge."
metadata:
  version: "1.0.0"
---

# Full stop

Do the `full-send` work and stop with the PR ready for the operator to merge. Read `full-send` and follow its steps, proof, challenge and babysitting. "Full stop" authorizes that work, testing permission included, without a separate "full send". Its merge grant does not apply; the rules below win.

## No merging

Commit, push, rebase, fix conflicts and `--force-with-lease` this task's branch. Never merge, arm auto-merge, enqueue, push to the default branch, bypass protection, or hand any of that to a lane.

Before work begins, and again before each push, check the PR for auto-merge or a merge-queue entry and remove it. Report what you removed. If automatic merging cannot be prevented, report the blocker before going on.

## Stop at the gate

`full-send`'s merge gate is the readiness check. Proof and review cover the final diff; recheck behaviour changes and real conflict fixes before the handoff. Then fetch the base and read the live PR: head, base, checks, reviews, mergeability. It is open, not a draft, and not set to merge without the operator. If someone else merged it, report that instead.

- **Ready to merge:** the gate passes. Leave it open and unmerged.
- **Waiting on approval:** only a human approval remains, and that is the real blocker.
- **Blocked:** what prevents readiness, what you tried, what is needed. Ask per `full-send` §Asking.

Unwatch the PR, where your overlay names a PR watch, before the handoff or a question. Report the PR link, final head SHA, verdict, proof, reviewer outcome and remaining risks, and say the PR is still open and unmerged.
