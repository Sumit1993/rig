---
name: claude-review-lane
description: "How the claude[bot] review lane behaves on any PR. Load when a claude[bot] thread, a claude-review-liveness comment, an @claude review summon, a verify round, or a PR that got no Claude review is in front of you; also before merging a PR the lane reviewed."
metadata:
  harnesses: "claude agy codex"
  version: "4.0.0"
---

# The Claude review lane

The lane is `claude-code-review.yml` in `prismalens/gh-workflows`, called by consumer stubs. It runs on mage-memory, and on prismalens PRs labelled `claude_review`. Callee truth is the workflow file, never a local checkout:

```bash
gh api repos/prismalens/gh-workflows/contents/.github/workflows/claude-code-review.yml --jq .content | base64 -d
gh api repos/prismalens/gh-workflows/contents/README.md --jq .content | base64 -d
```

## 1. Two standing rules

- Silence is never approval. No posted findings means no machine review on record for this head. Treat it exactly as a rate-limited one.
- A green job is not evidence. The lane publishes no commit status and gates nothing. A run can finish `success` having posted zero comments; read for posted output, never a check's colour.

## 2. The liveness comment

Every run that reaches the reviewer upserts one comment by `github-actions[bot]`:

```
<!-- claude-review-liveness rounds=N sha=<40-hex> patch=<64-hex> paused=1 paused_by=<login> -->
**Claude review lane** — [run](...): <verdict>
_Lane state: paused by @<login> at `<sha>` — resume with `@claude resume`. The review verdict above stands._
```

Match prefix `<!-- claude-review-liveness`. Every field after `rounds=` is optional.
- `rounds=` counts automatic review rounds. `sha=` is the last head with posted output; compare it to the merge head (if different, newer commits were never reviewed as a diff).
- Read pause state from `paused=1` on the marker line (`head -1`), never from the verdict text; a pause carries the standing verdict forward verbatim. `patch=`, `api-error` rounds and the `_Lane state:` line: `references/admission.md`.

Only the two `reviewed <sha> ...` verdict forms mean the head was reviewed. For any of the other nineteen, read `references/verdicts.md`.

Match a verdict by its prefix, never by equality. A round that reviewed without some context (an unresolved issue reference, CI failing or pending, an unparseable lockfile, a tool that could not run) appends a sentence saying so. It still counts as a review; read the note before trusting its coverage.

No liveness comment means the PR was never admitted; a watcher waiting for one waits forever.

### When the comment itself is wrong

Open `claude[bot]` threads against a comment claiming nothing was posted means the comment is stale, not the review. Cross-check threads before believing a negative verdict:

```bash
gh api graphql -F owner='{owner}' -F repo='{repo}' -F pr=<pr> -f query='query($owner:String!,$repo:String!,$pr:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:100){nodes{isResolved comments(first:1){nodes{author{login}}}}}}}}' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved|not) | .comments.nodes[0].author.login' | sort | uniq -c
```
A positive verdict needs no cross-check; nothing fabricates posted output.

## 3. Admission, and every way the lane stays quiet

Automatic rounds fire on `pull_request` for same-repo heads. Summons and in-thread replies need repository write access. Eight ways a PR gets no review: a skipped author (`dependabot[bot]` by default), a draft, a fork head, a PR that edits the review workflow itself, an auto-pause after 5 rounds, `review.admission: off`, the `claude_review_skip` label, and `admission: label` with no `claude_review` label. Which of them leave a liveness comment, how a summon interacts with each, credentials, stacks, `review.context`, and why a zero-job `cancelled` run is not evidence: `references/admission.md`.

## 4. Summon grammar

Bare PR comments, org members only. The body is read only by workflow `contains()` expressions and never reaches a prompt, so a summon carries no instructions. Put context in the PR body.

| Comment | Effect |
|---|---|
| `@claude review` | Verify when unresolved `claude[bot]` threads exist, else incremental review. Lifts either pause |
| `@claude full review` | From scratch, dedup off for that run. The fix for a green round that posted nothing, and the only way past a verify round |
| `@claude review --model opus` | Incremental on `claude-opus-5` for that run only. `@claude review --model sonnet` picks `claude-sonnet-5` back |
| `@claude pause` | Stops automatic rounds; later heads report `paused by request at <sha>`. Any admitted summon lifts it (#189 ruling) |
| `@claude resume` | Lifts an explicit pause. Not the remedy for an auto-pause, which is `@claude review` |

Neither pause is a stop; a push or a reply carries it forward. The operator's stop is `review.admission: off` or the `claude_review_skip` label (§3, admission). `default_model` is `claude-sonnet-5`; the `--model` override is an allowlist matched whole and never combines with full review.

- One summon per round. Batch fixes, push, then summon once. Summons queue behind in-flight rounds; pushes supersede queued runs.

## 5. Verification rounds

A verify round re-judges the unresolved `claude[bot]` threads instead of re-reviewing. A push never produces one; only a non-bot reply in a thread, or a summon on a PR holding unresolved threads, does. So a pushed fix leaves its thread open until someone replies.

### The order that works

Fix, push, reply to every thread, wait for the push's automatic round to finish, then summon `@claude review` once. Any other order costs a round.

- A push after replying supersedes the queued verify (`verify-superseded`; summon after your last push). `verify-cancelled` has no recorded cause and is not a tool denial.
- N replies give one round, not N; each reply evicts the pending slot.
- A summon straight after a push lets the automatic round land first and post auto-pause over the summon's result.
- An auto-paused PR cleared entirely by verify rounds stays paused; later heads need a hand summon.

One run resolves to one mode (`skip`, `review`, `incremental`, `review-full`, `verify`), named in the run log; the table is in `references/admission.md`.

How to read a verify round:

- Each unresolved thread gets `fixed`, `still_applies`, or `cannot_verify` with sha and evidence. `fixed` resolves the thread. The other two reply with evidence and leave it open.
- A `still_applies` is a claim, not a proof, and its evidence string can answer a different question than the finding asked. Test counter-evidence by running the real command before conceding.
- Delta-only review: new findings post inline; covered findings are not re-posted. Dedup is per finding, not defect; read open threads together before fixing.
- A summary comment (`## Code review — verification round`) lists thread URLs and verdicts; its absence means the round aborted. N rounds leave N comments.
- Judge every proposed fix against the code yourself: a finding is a report, its remedy an untrusted suggestion.

## 6. Who resolves a `claude[bot]` thread

The reviewer resolves what it verifies as fixed. A human rules on anything disputed, declined or deferred.

A `fixed` verdict resolves the thread citing the commit. Anything disputed, declined or deferred is resolved by a human, via GraphQL `resolveReviewThread` or the UI, after the disposition is posted in-thread.

## 7. Before a merge

0. Is every review thread resolved by the reviewer that opened it? A thread the session resolved does not count.
1. Has posted review output landed at all? Only a `reviewed <sha> ...` verdict answers yes. Auto-paused, posted-nothing, fork notices, or no comment mean unreviewed.
2. Did it land on *this* head? Read `sha=` off the liveness marker. Resolved threads describe findings, not coverage. Summon and wait, or make a deliberate risk decision to merge without one.

## 8. Finding labels

Each finding opens with `_Category_ | _Severity_ | _Effort_`. The labels are the reviewer's own judgement and do not order the work; parse them, then rank by reading the findings.
