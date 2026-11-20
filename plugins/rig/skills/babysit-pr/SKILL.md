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

- **CodeRabbit** reviews a ready PR when summoned: `gh pr comment <pr> --body '@coderabbitai review'`. Summon your own PR whenever it needs a review; CodeRabbit gives one review per developer per hour across every repo, so a summon spends the slot the routine would use. Post the trigger alone; anything else in the body is read as chat. The hourly routine (`scripts/coderabbit-routine/` in Sumit1993/rig) summons one PR per hour for PRs nobody is watching, never a draft or a PR labelled `coderabbit_skip`.
- **Claude** (`claude[bot]`) runs where `<skill-dir>/../../scripts/rig-meta.sh get <repo> claude_lane` says so. `@claude review` re-checks open threads or reviews incrementally, `@claude full review` starts over. Its `claude-review-liveness` comment says what the last run did and on which `sha=`; `references/claude-verdicts.md` decodes it.
- **Codex** (`assayer`) runs only when the operator runs it.

Batch fixes into one push: every push on a ready PR can spend a review on a commit you are about to amend. On a stack, work base first: get the base reviewed and merged before pushing fixes above it.

## Waiting

In T3 Code, handle what is already there, then `watch_pull_request` and end the turn. Elsewhere, wait on CI with `gh pr checks <n> --required --watch`; a review that lands later is picked up at the next session start (`compass` Step 0). Never poll with model turns, never wait on `mergeStateStatus`, and say nothing when an event needs no action.

## Reviews

Read every comment and reply posted since your last reply (all of them on a first pass), from every review: review threads, review bodies (outside-diff, nitpick and additional comments sit there, with no thread) and PR comments. CodeRabbit splits a large review into several PR comments ("part 1/4" and so on), each up to about 57k characters, longer than one tool output. List the comments first, then read each by id; save one longer than an output to a file and read it in parts.

```bash
gh api --paginate repos/{owner}/{repo}/issues/<n>/comments --jq '.[] | "\(.id) \(.user.login) \(.created_at) \(.body|length)"'
gh api repos/{owner}/{repo}/issues/comments/<id> --jq .body > <file>
gh api graphql --paginate -F owner='{owner}' -F repo='{repo}' -F n=<n> -f query='query($owner:String!,$repo:String!,$n:Int!,$endCursor:String){repository(owner:$owner,name:$repo){pullRequest(number:$n){reviewThreads(first:100,after:$endCursor){pageInfo{hasNextPage endCursor} nodes{id isResolved path comments(first:100){nodes{databaseId author{login} body}}}}}}}' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)'
gh api --paginate repos/{owner}/{repo}/pulls/<n>/reviews --jq '.[] | "\(.user.login) \(.commit_id[0:7])\n\(.body)"'
```

CodeRabbit keeps one summary comment at the top of the PR. It edits that comment in place as each review runs, so re-read it every pass: its creation time says nothing. A thread you replied to is not done. Read every reply after yours; CodeRabbit may ask or add something instead of resolving, and that reply needs an answer too.

Verify every finding against the source before changing code. Fix real bugs in the intended case; decline the rest with a written reason (unneeded guards, speculative edge cases, scope growth) and list them as follow-ups. Prefer the fix that deletes or narrows code.

Answer every finding where its reviewer reads it, and start every reply to CodeRabbit with `@coderabbitai`. In a thread: `gh api repos/{owner}/{repo}/pulls/<n>/comments/<root-id>/replies -f body='@coderabbitai Fixed in <sha>: <what>.'` A decline names why that finding is wrong or out of scope, so CodeRabbit can accept it or push back. A finding outside any thread gets its answer in a PR comment that starts with `@coderabbitai` and quotes the finding's file and lines.

Keep PRs small enough that CodeRabbit posts its findings inline: findings in threads are gated by the repo's required thread resolution, findings in review bodies and PR comments are not.

CodeRabbit replies are chat with their own limit of about 25 an hour across every PR (observed on prismalens #1028 to #1030). Reply highest severity first; replies past the limit wait for the next hour. A reply answered with `Rate Limit Exceeded` is unanswered: reply again after the stated wait. Never write the word "resolve" in a reply; CodeRabbit reads it as a command.

## Resolving threads

The reviewer that opened a thread resolves it; the session never does (`no-thread-resolve` refuses the GraphQL mutation).

- CodeRabbit checks a reply and closes the thread, or answers in-thread and leaves it open. A thread it left open with no action after your reply gets one nudge in that thread: `@coderabbitai please look at this again: close the thread if the fix holds, or say what is still needed.` An answer that asks for more gets one, like any finding.
- Claude re-judges open threads when a non-bot replies; a `fixed` verdict resolves the thread.
- A declined or deferred finding is resolved by the operator after the reason is posted in-thread.

## Merging

When the operator asks, or under `full-send`, and only when, on the current head:

- required checks are green (`gh pr checks <n> --required`);
- each reviewer has posted on this head (Claude's liveness shows a `reviewed <sha>` verdict for the head; CodeRabbit reviewed it or answered `Review finished`, unless the PR is labelled `coderabbit_skip` or the routine skipped the head as a minor-only re-review), and every finding is fixed or declined with a reason;
- every thread is resolved by the reviewer that opened it.

Merge with a merge commit whose subject is the PR title: `gh pr merge <n> --merge --subject "<title> (#<n>)"`. Where `rig-meta.sh get <repo> merge_queue` is true, enqueue with the `enqueuePullRequest` GraphQL mutation instead, and treat the PR as merged only when `gh pr view <n> --json state` reads `MERGED`. A body closing several issues repeats the keyword: `closes #a, closes #b`. Afterwards remove the worktree and branch.
