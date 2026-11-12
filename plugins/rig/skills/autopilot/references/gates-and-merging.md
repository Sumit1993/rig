# Gates, merging, bypasses and parking

The `autopilot` sections a run needs when it touches a gate, a merge or a sign-off.

## 7. Gates and rulesets: flip the setting, do not build the machine

A broken gate blocks every PR in the repo, including the PR that fixes it.

- Ask whether the gate should exist at all before asking how to fix it. Decide per subsystem, not per hole.
- Prefer a setting to a workflow. Rulesets are editable through the API, atomically, with no PR.
- Never ship a change whose own merge depends on the thing it is changing. Flip the setting first, then land the code. Nothing joins `required_status_checks` until one live PR has passed through it, watched. Product PRs never queue behind gate PRs.

## 8. Merging: take it to green and leave it

Mechanics are `babysit-pr`, merging. Specific to unattended:

- Merge only when CI is green and every review thread resolved by the reviewer that opened it. A thread the session or a lane resolved does not count.
- Never arm auto-merge. Reviewers cannot block a merge, so it fires the moment CI goes green, before the reviewer has finished, and `required_review_thread_resolution` has nothing left to block on.
- A session that cannot merge with the operator present does not merge at all. Take the PR to green, mark it ready, leave it; the routine gets it reviewed and the operator merges it through `compass`. A PR that needs the operator's sign-off (§10, park for sign-off) gets the `needs-operator` label.
- With a standing grant on a classic repo: one at a time, checking the gate after each. Every merge puts the other open PRs behind the base, auto-merge never updates a branch in that state, and nothing tells you. Go and look. Rebase the PRs you are parking at the end of the drain, not the start.

## 9. Never bypass a ruleset or a gate

When a gate blocks the only fix available, escalate. A bypass cannot be undone.

- Never bypass a gate (`--admin`, `--no-verify`, skip flags).
- A real dilemma goes to the planner seat (§6, the planner seat).

## 10. Park anything that needs the operator to sign off

- Work that changes what the operator sees or owns goes to green and stops: interface shape, exported API, architecture naming, scope. Never merge it.
- PRs that have diverged, been superseded or gone obsolete get a comment stating the state and stay open. A PR earns the comment when its body puts it outside current scope, it carries an open question only the operator can answer, or its diff no longer applies.
- Every parked item goes in the plan file's decision list as a specific question with options, never "needs review".
