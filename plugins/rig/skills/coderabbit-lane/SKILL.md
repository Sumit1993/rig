---
name: coderabbit-lane
description: "Load when a coderabbitai[bot] thread, an @coderabbitai summon, a CodeRabbit rate-limit notice, a reply to CodeRabbit, or a CodeRabbit review that never arrived is in front of you."
metadata:
  version: "4.0.0"
---

# The CodeRabbit review lane

`coderabbitai[bot]` is the independent automated reviewer. `AGENTS.md` decides reviewer routing. `pr-babysit` covers watching a PR this session raised, watcher lifecycles and merge mechanics. `claude-review-lane` covers `claude[bot]`. `autofix` applies PR-thread feedback with per-change approval. Process truth is `rig/docs/pr-review-process.html`.

## 1. Admission

The hourly CodeRabbit routine (`scripts/coderabbit-routine/` in Sumit1993/rig, `Sumit1993/rig#150`) is the admission mechanism, in every repo. `auto_review` is off everywhere, so opening a PR or marking it ready spends nothing by itself. Each hour the routine summons CodeRabbit on at most one PR: first a re-review, a PR whose head moved past its last review and whose CodeRabbit threads all carry a reply, then new PRs oldest first. A re-review is skipped when the model judges the new commits to be only fixes that CodeRabbit already confirmed in-thread, since reviewing a fix only finds a smaller nit in it. A draft is never summoned, so a PR stays a draft while commits are still coming.

A PR labelled `coderabbit_skip` is never summoned, new or re-review: the digest marks it `excluded` with the reason, and `act.py` re-reads labels before posting, so a label added mid-run still holds. The label only stops admission. It resolves no thread and lifts no merge requirement, and the PR's past review still counts against the hourly slot. The operator creates the label.

The routine never merges. Merging is a local session's job when the operator asks for it (`compass` Step 0, `pr-babysit` Phase 3). The routine is a Claude Code routine; each run's report, in its run history at claude.ai/code/routines, lists what was summoned and what waits. Its summons carry a hidden `<!-- summoned-by: coderabbit-routine -->` line, so a summon without it came from a session or by hand. Its off switch is pausing the routine.

## 2. When to summon by hand

Only when the operator says so for that PR. A hand summon takes the slot the routine schedules, and two summons within the hour collide: the second is refused as rate-limited (`prismalens/gh-workflows#213`). Where rig's hooks run (Claude Code; Codex once its hooks are trusted), `summon-gate.sh` blocks a summon unless the command carries `CR_SUMMON_OK=<pr>`, the operator's word for that PR, never carried forward. Elsewhere the rule is yours to keep. Post it bare with the marker: `CR_SUMMON_OK=<pr> gh pr comment <pr> --body $'@coderabbitai review\n\n<!-- summoned-by: session -->'`. The routine sees it as pending and does not repeat it.

`.coderabbit.yaml` path instructions still shape review quality and the Claude lane cannot see them, so they stay worth writing.

## 3. The per-developer counter

Read `references/counter.md` before a hand summon, or when a review never arrived or a rate-limit reply came back.

## 4. Triggers and polling

- One trigger, bare: `@coderabbitai review`, incremental. `full review` re-reads the whole diff at the same cost; use it only when the operator asks for it.
- Post exactly the trigger and nothing else. Extra questions or bullets are parsed as chat, return "For best results, initiate chat on the files or code changes", and run no review. Context goes in the PR description, which the review reads.
- Poll after every trigger. A trigger posting is not a review starting. Wait about 60 seconds, inspect the latest `coderabbitai[bot]` comment, then report. `rate limited`: rejected, nothing ran, wait out the window. `initiate chat on the files`: misparsed, re-trigger bare. Anything else: accepted.
- CodeRabbit is not diff-only. It runs `rg`, `fd`, `sed`, `git show` and inline Python against the checkout to reason across files. It does not run test suites.

## 5. In-thread replies

Replies go in-thread, to satisfy `required_review_thread_resolution`. `cr-reply.sh` is in this plugin's `scripts/` directory, two levels above this skill's directory:

```bash
"<skill-dir>/../../scripts/cr-reply.sh" <pr> <root_id> "@coderabbitai Fixed in <sha>: <what changed>. Please verify."
```

- Never write the word "resolve" in a reply. CodeRabbit parses it as a command and returns boilerplate ("Post `@coderabbitai resolve` as a new top-level PR comment"), resolving nothing.
- Reply-in events are CodeRabbit's verdicts on your fixes. Read them.

## 6. Thread resolution

- A fixed thread needs no re-review. CodeRabbit reads the in-thread "Fixed in <sha>" reply, checks the fix and resolves the thread itself (prismalens PR #160). So push the fixes, reply in every thread, and a few minutes later re-read `isResolved`: act on whatever is still open (CodeRabbit's follow-up in that thread says why). Never summon a review to get threads resolved.
- Verified but open: CodeRabbit sometimes confirms a fix in-thread and leaves the thread open. Before escalating, re-read every unresolved thread and its latest CodeRabbit reply on the current head. Hand the operator the threads whose latest reply confirms the fix, quoting it, apart from the ones still disputed or unanswered.
- Bare top-level `@coderabbitai resolve` blanket-resolves every thread with zero validation. The operator's call only, for rounds where every thread it would close is confirmed fixed in-thread or carries a recorded decline or deferral; one confirmed fix never justifies closing the rest. It is a command, not a review request: post it alone, `gh pr comment <pr> --body '@coderabbitai resolve'`, which `summon-gate.sh` passes without `CR_SUMMON_OK`. A review request in the same command is still gated.
- A PR merges only with every review thread resolved by the reviewer that opened it. The session never resolves a CodeRabbit thread, through GraphQL `resolveReviewThread` or otherwise.
- Declining or deferring: CodeRabbit self-resolves only when code changed, so a declined or deferred finding goes to the operator, who resolves it under three rules. State the disposition (accepted-and-deferred with landing target, or rejected with reasons; "noted" is not a disposition). Wait about 60 seconds for the counter-reply so follow-up issue offers are not dropped. Reference tracking issues by number.
- Never reply and resolve in one step.
