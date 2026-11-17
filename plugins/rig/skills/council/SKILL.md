---
name: council
description: "Load when the operator says \"council\": review or feedback from judges on different providers, looped until none holds a material objection."
metadata:
  version: "1.0.0"
---

# Council

Before calling the council, answer open PR comments, fix known issues and run the relevant checks: the council judges the current implementation, not one with fixes still owed. When the operator wants the implementation discarded for new ideas, skip fixes to code being replaced.

## Members

Unless the operator names others, the council is:

- **GPT Sol**, the adversary seat: `run-review.py` with the default holder (`adversary` §3, running a round).
- **Opus 5.5**, a fresh process: the same launcher with `--holder claude`, same packet, its own run directory.
- **Gemini through agy**, the jester: a read-only `farm-out` work order on the same packet, model chosen by `farm-out`. It is non-blocking and unscored. Its points are checked like any finding, but it never gates a round and a late answer is plain feedback.

Start all three in parallel. A member that cannot run (Codex quota exhausted, agy down) is reported as missing, never replaced: the council exists for different providers, so `adversary`'s fallback to `--holder claude` does not apply here.

## A round

One frozen packet for every member (`adversary` §2, frozen packet): a dedicated worktree at full SHAs, read-only. Do not idle while they run: check each result against the code as it lands and decide what to fix, but edit nothing in the frozen worktree; the launcher fails a run whose target moved.

Each scored member returns a validated verdict: `blocked`, `risks`, `survived` or `incomplete`. Record it per round; a run that failed is `failed`, never a guess. A fresh review after fixes starts a new round, carrying `--previous-result` so objection IDs persist.

Fix what you accept, then run the next round on the changed target. The budget is `adversary` §4's: one round plus a rebuttal; stop when no material objection is open, and take one still open after the rebuttal to the operator. Fight scope growth: an objection outside the request is declined in one line and listed as a follow-up.

## Record

When the work ends in a PR, put the results in its description, before the closing generated-with line, by editing the body, never in a comment:

```markdown
## Council review

Rounds: 2

| Member | Round 1 | Round 2 |
| --- | --- | --- |
| GPT Sol | risks | survived |
| Opus 5.5 | blocked | survived |
| Gemini (jester) | 3 points, 1 taken | none new |
```

With no PR, the same table goes in the final reply. Summarize the useful findings, the disagreements between members, and the recommended next steps.
