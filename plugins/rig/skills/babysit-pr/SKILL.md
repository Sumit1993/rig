---
name: babysit-pr
description: "Load after gh pr create, when a review bot (coderabbitai, claude, assayer) has posted on a PR, or when asked to watch, babysit, clear review debt on, or merge a PR."
metadata:
  version: "1.0.0"
---

# Babysit PR

Review bots are helpful, not always right. A PR is done when its findings are answered, checks are green and the operator merges it.

## Async by default

Keep the PR a draft while commits are still coming, then mark it ready once. Reviews arrive on their own schedule:

- **CodeRabbit** is summoned by the hourly routine (`scripts/coderabbit-routine/` in Sumit1993/rig), one PR per hour across every repo, never on a draft or a PR labelled `coderabbit_skip`. A hand summon needs the operator's word for that PR: `CR_SUMMON_OK=<pr> gh pr comment <pr> --body '@coderabbitai review'`. Post the trigger alone; anything else in the body is read as chat.
- **Claude** (`claude[bot]`) runs where `<skill-dir>/../../scripts/rig-meta.sh get <repo> claude_lane` says so. `@claude review` re-checks open threads or reviews incrementally, `@claude full review` starts over. Its `claude-review-liveness` comment says what the last run did and on which `sha=`; `references/claude-verdicts.md` decodes it.
- **Codex** (`assayer`) runs only when the operator runs it.

Batch fixes into one push: every push on a ready PR can spend a review on a commit you are about to amend. On a stack, work base first: get the base reviewed and merged before pushing fixes above it.

## Waiting

In T3 Code, handle what is already there, then `watch_pull_request` and end the turn. Elsewhere, wait on CI with `gh pr checks <n> --required --watch`; a review that lands later is picked up at the next session start (`compass` Step 0). Never poll with model turns, never wait on `mergeStateStatus`, and say nothing when an event needs no action.

## Reviews

Read everything the reviewers posted that is not yet answered, from every review: review threads, review bodies (outside-diff, nitpick and additional comments sit there, with no thread) and PR comments.

```bash
gh pr view <n> --comments
gh api --paginate repos/{owner}/{repo}/pulls/<n>/comments --jq '.[] | "\(.id) \(.user.login) \(.path):\(.line // "-") \(.body[0:200])"'
gh api --paginate repos/{owner}/{repo}/pulls/<n>/reviews --jq '.[] | "\(.user.login) \(.commit_id[0:7])\n\(.body)"'
```

Verify every finding against the source before changing code. Fix real bugs in the intended case; decline the rest with a written reason (unneeded guards, speculative edge cases, scope growth) and list them as follow-ups. Prefer the fix that deletes or narrows code.

Reply in-thread so the thread gate sees it: `gh api repos/{owner}/{repo}/pulls/<n>/comments/<root-id>/replies -f body='@coderabbitai Fixed in <sha>: <what>.'` A finding outside any thread gets its answer in one PR comment.

CodeRabbit replies are chat with their own limit of about 25 an hour across every PR; reply highest severity first and keep a burst under it. A reply answered with `Rate Limit Exceeded` is unanswered: reply again after the stated wait. Never write the word "resolve" in a reply; CodeRabbit reads it as a command.

## Resolving threads

The reviewer that opened a thread resolves it; the session never does (`no-thread-resolve` refuses the GraphQL mutation).

- CodeRabbit checks a "Fixed in" reply and resolves the thread, or confirms in-thread and leaves it open. Once CodeRabbit's latest comment in every open thread confirms the fix, quote those confirmations in a PR comment, then post `@coderabbitai resolve` alone.
- Claude re-judges open threads when a non-bot replies; a `fixed` verdict resolves the thread.
- A declined or deferred finding is resolved by the operator after the reason is posted in-thread.

## Merging

Only on the operator's word for that PR (`MERGE_OK=<pr>`, enforced by `merge-gate`), and only when, on the current head:

- required checks are green (`gh pr checks <n> --required`);
- each reviewer has posted on this head (Claude's liveness shows a `reviewed <sha>` verdict for the head; CodeRabbit reviewed it, unless the PR is labelled `coderabbit_skip`), and every finding is fixed or declined with a reason;
- every thread is resolved by the reviewer that opened it.

Merge with a merge commit whose subject is the PR title: `MERGE_OK=<n> gh pr merge <n> --merge --subject "<title> (#<n>)"`. Where `rig-meta.sh get <repo> merge_queue` is true, enqueue with the `enqueuePullRequest` GraphQL mutation instead, and treat the PR as merged only when `gh pr view <n> --json state` reads `MERGED`. A body closing several issues repeats the keyword: `closes #a, closes #b`. Afterwards remove the worktree and branch.
