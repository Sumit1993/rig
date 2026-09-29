# Admission, stack and credential details, run modes

The detail behind `SKILL.md` §3 and §5. Read it when a PR got no review and the short list there does not explain why, or when a run log names a mode.

## Every way the lane stays quiet

Automatic rounds fire on `pull_request` for same-repo heads. Summons and in-thread replies require repository write access, checked against the collaborators API. Admission is not `author_association`.

Eight ways a PR gets no review. Whether each leaves a liveness comment is noted with it; the comment exists only where the callee was invoked, so anything the caller stub stops is silent:

1. Skipped author. An author in `skip_authors` (default `dependabot[bot]`) gets no automatic round: no review, no verify, no liveness comment. Matching is exact-login on a delimiter-wrapped list. A summon bypasses the list.
2. Draft PR. Nothing reviews a draft, summons included: the callee's `review` gate is `admitted && same_repo && draft != 'true'` with no override. Marking the pull request ready is what collects the work, and the lane then takes the whole diff in one round. An automatic round or in-thread reply skips on the caller stub, so no run is spent and no liveness comment appears. A summon executes the callee, skips on the review gate, and posts the draft verdict so the spent summon says why.
3. Fork head. Never machine-reviewed: GitHub withholds secrets from fork code and the lane avoids `pull_request_target`. A `fork-notice` job upserts a comment marked `<!-- claude-review-fork-notice -->` pointing at `coderabbit_review`. A summon does not override this. Read-only tokens fall back to a workflow warning annotation.
4. Self-skip on the workflow itself. A PR that edits `.github/workflows/claude-code-review.yml` is never reviewed: `claude-code-action` self-skips on workflow-validation mismatch. A security control, and the one case a summon cannot fix; label the PR `coderabbit_review`. A self-skip leaves the action's conclusion empty, which shares an empty conclusion with tool denials and account limits; run duration and logs separate them.
5. Auto-paused. After `auto_pause_rounds` automatic rounds (default 5) the lane posts the auto-paused verdict instead of reviewing. A paused PR is not reviewed on push, so a wait keyed on push has no end. A summon resets the counter, but only when the round posts review output.
6. `review.admission: off` in the repo's `.github/claude-review.yml` (read at the base ref) or the org's `.github/claude-review-defaults.yml` in `prismalens/gh-workflows` (read at `main`). Nothing reviews and nothing posts, with no liveness comment. One exception: a summon on a draft PR never reaches the admission check, so it still posts the draft verdict. It records lane event `admission-off`. Every summon (`@claude review`, `@claude full review`, `@claude resume`, `@claude pause`) and every in-thread reply is refused. An unquoted `off` (YAML false) is accepted. A narrower layer can never override it.
7. The `claude_review_skip` label, under any admission value, summons included. It posts one upserted verdict (`skip-label`), unless `admission: off` applies, which takes precedence and posts nothing. Removing the label lifts only this gate: under `admission: label` the PR still needs `claude_review`.
8. `review.admission: label` with no `claude_review` label. It posts one upserted verdict (`awaiting-label`). Applying the label admits the PR with no new push, and removing it stops later rounds. Only the label admits: summons on an unlabelled PR are refused.

Precedence is `off`, then the skip label, then the opt-in label, checked first in `Detect verification mode`. A refused summon leaves an existing pause as it was. `scripts/setup-repo.sh` creates both labels. Consumer stubs list `labeled` and `unlabeled` in `pull_request.types` and keep label events out of `cancel-in-progress` (gh-workflows README, principle 7 and the admission section). Without them `auto` and `off` are unaffected, and a label takes effect only at the next push or `@claude review`.

### Credentials, stacks and context

- The callee takes `CLAUDE_CODE_OAUTH_TOKEN`. When that secret is empty it passes `ANTHROPIC_API_KEY` instead; the action gives the two inputs no precedence of its own. With neither, the verdict is `no-token`.
- A stacked PR is measured against its own base, which makes a stack the supported way to review a change over `max_reviewable_lines`. Each PR in a stack keeps its own round budget and its own `@claude pause`.
- `review.context` in a repo's own config lists up to 3 public repositories the reviewer may read as reference. Each entry needs `repository`, `ref` and 1 to 20 relative `paths`. The lane reads it from the config on the base branch, never the head, so a PR cannot add its own context. It checks `private == false` and skips anything else, clones under `.claude-context/`, and never reviews that code. An org-level `review.context` is ignored.

### Refusal versus cancellation

A run that concluded `cancelled` with zero jobs executed nothing and says nothing about admission; it was evicted from its concurrency group before any `if:` ran. A run that concluded `skipped` reached the gate and was refused. Only the second is evidence.
Zero-job cancellations on the reply path are normal. In a concurrency group, new queued jobs evict pending jobs by default. With `cancel-in-progress: false` on comment events, N replies in a burst leave one run going, one pending, and the rest cancelled with zero jobs. One verify round re-checks every unresolved thread regardless.
Never read those cancellations as a stale stub. The throwaway group diverts `comment.user.type == 'Bot'` and non-PR `issue_comment` only. A human reply enters the real group by design, and a hung comment run holds the seat while new replies evict the pending slot behind it.

## The five modes

One run resolves to one mode, named in the run log. A `pull_request` event reaches only the first three.

| Mode | Reached by | What it does |
|---|---|---|
| `skip` | any trigger | Nothing reviewed. Reason is one of `no-token`, `skipped-author`, `paused`, `paused-by-request`, `no-new-commits`. `paused-by-request` comes only from a push; summons and replies are not refused by a pause |
| `review` | any trigger | Full review from scratch. Also the fallback when an incremental range cannot be trusted: `no-baseline`, `baseline-gone`, `diverged`, `range-too-large`, `identical-summon` |
| `incremental` | push, or `@claude review` | Reviews only the `baseline..head` range off the liveness marker |
| `review-full` | `@claude full review` only | From scratch with dedup disabled |
| `verify` | non-bot in-thread reply, or `@claude review` on a PR with unresolved threads | Re-judges those threads |


## Liveness marker fields

- `patch=` fingerprints the PR's own patch at `sha=`. A rebase or restack push whose patch matches it skips as `unchanged-patch`. A summon never skips on it.
- An `api-error` round advances neither `sha=` nor `rounds=`, so the head it failed on still reads as unreviewed.
- Read pause state from `paused=1` on the marker line, never from the verdict text. Pause state and verdict text are independent: a pause or resume on a head that already has a review carries that review's text forward verbatim and changes only the marker, so `reviewed <sha> and posted ...` and `paused=1` appear together. Take the marker through `head -1`.
- The third `_Lane state:` line appears only when a pause or resume landed on a head holding a standing verdict. It is rebuilt, not appended, so pause then resume then pause leaves one such line. It carries no `paused=1` substring, so a whole-body grep for `paused=1` still does not match on it alone.

