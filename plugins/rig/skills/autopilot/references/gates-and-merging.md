# Gates, merging, bypasses and parking

The `autopilot` sections a run needs when it touches a gate, a merge or a sign-off. Section numbers match the citations elsewhere.

## 7. Gates and rulesets: flip the setting, do not build the machine

A broken gate blocks every PR in the repo, including the PR that fixes it.

- Ask whether the gate should exist at all before asking how to fix it. Decide per subsystem, not per hole.
- Prefer a setting to a workflow. Rulesets are editable through the API, atomically, with no PR. One hand-built gate duplicated `required_review_thread_resolution`, already on in the same ruleset.
- Never write a check that parses a vendor's text: comment bodies, review states, marker strings. None is a documented contract and anyone who can comment can trigger it. If you need a control, take the tool away from the agent instead.
- Never ship a change whose own merge depends on the thing it is changing. Flip the setting first, then land the code. Nothing joins `required_status_checks` until one live PR has passed through it, watched. Product PRs never queue behind gate PRs.
- Fail-closed is for security decisions, not plumbing.

## 8. Merging: take it to green and leave it

Mechanics are `pr-babysit` Phase 3. Specific to unattended:

- Merge only when CI is green and every review thread resolved by the reviewer that opened it (`pr-babysit` Phase 0). A thread the session or a lane resolved does not count.
- Never arm auto-merge. Reviewers cannot block a merge, so it fires the moment CI goes green, before the reviewer has finished, and `required_review_thread_resolution` has nothing left to block on.
- A session that cannot merge with the operator present does not merge at all. Take the PR to green, mark it ready, leave it; the routine gets it reviewed and the operator merges it through `compass`. A PR that needs the operator's sign-off (§10, park for sign-off) gets the `needs-operator` label.
- With a standing grant on a classic repo: one at a time, checking the gate after each. Every merge puts the other open PRs behind the base, auto-merge never updates a branch in that state, and nothing tells you. Go and look. Rebase the PRs you are parking at the end of the drain, not the start.

## 9. Never bypass a ruleset or a gate

When a gate blocks the only fix available, escalate. Waiting out a cooldown inside an eight hour window is cheap. A bypass cannot be undone.

Tell a gate that is failing, where retrying is right, from one that cannot be satisfied, where retrying burns the run. The tell: the same action gives the same empty result twice with no error. On the second, stop and escalate.

The PR that repairs a gate is the worst candidate in the repo for skipping review. A gate change reviewed only by the model that wrote it is the failure independent review exists to catch (§7, flip the setting).

- A conditional pre-authorisation ("this might need a bypass") is a reserve, not an instruction. Write down the exact condition that would spend it.
- Never reach for a skip flag, an `--admin` merge, a `--no-verify` push, or a ruleset edit. If a lane already used one, record it and stop that lane. Do not keep the result.
- A real dilemma goes to the planner seat (§6, the planner seat).

## 10. Park anything that needs the operator to sign off

- Work that changes what the operator sees or owns goes to green and stops: interface shape, exported API, architecture naming, scope. Never merge it.
- PRs that have diverged, been superseded or gone obsolete get a comment stating the state and stay open. Never close one. A PR earns the comment on three grounds: its body puts it outside current scope, it carries an open question only the operator can answer, or its diff no longer applies for some reason other than a mechanical rebase. Age alone is not divergence.
- An honest gap beats an invented claim. Say where the evidence for a parked item is incomplete.
- Every parked item goes in the plan file's decision list as a specific question with options, never "needs review".

