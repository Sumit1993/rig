# Holding a review round in this session

## Phase 1: arm the watcher, only for a held round

The trigger is the operator asking to hold this PR's round in this session. A PR merely existing is not one; the routine has it.

Seed the seen-state first, both files, so existing comments never replay as `NEW`:

```bash
mkdir -p ~/ai-context/state/cr-watch
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner); KEY=${REPO//\//-}
C=$(mktemp); trap 'rm -f "$C"' EXIT
gh api "repos/$REPO/pulls/<pr>/comments?per_page=100" > "$C"
jq -r '.[] | select(.user.login|test("coderabbit")) | .id' "$C" \
  > ~/ai-context/state/cr-watch/$KEY-pr<pr>.seen
jq -r '.[] | select(.user.login|test("claude";"i")) | .id' "$C" \
  > ~/ai-context/state/cr-watch/$KEY-pr<pr>-claude.seen
```

Then arm a persistent watcher. In Claude Code that is the Monitor tool with `persistent: true`; elsewhere run the script as a background process logging to a file and read the new lines at every turn:

```
command: <skill-dir>/watch-coderabbit.sh <pr> [<pr>...]
description: CodeRabbit comments + CI reds on PR <pr>
```

One watcher covers many PRs. If one is already running for this repo, stop it (Claude Code: TaskStop) and re-arm with the combined list; seen-state makes that free.

Event lines and what each one asks for are in `events.md` beside this file; read it when the first line arrives, not before.

The first line is the presence verdict, `CODERABBIT ACTIVE on <repo> — watching reviews, rate limits, CI and merge state` or `CODERABBIT ABSENT on <repo> — watching CI + merge state ONLY`. `rig-meta.sh get <owner/repo> coderabbit` is the source of truth; the watcher checks it, then probes for a committed `.coderabbit.yaml` or `.yml`, then for a `coderabbit*` author in recent comments, and writes a positive probe back to the registry. ABSENT skips the CodeRabbit polls and means unreviewed, exactly like a rate limit: a repo with no reviewer produces a quiet watch that is byte-identical to "reviewed, found nothing". Decide by risk: trivial or knowledge-base-only merges on CI alone, anything else wants the Opus 5 pass, and no local CLI step substitutes.

Env knobs: `CR_WATCH_AUTORETRY=0` makes rate-limit handling detect-only, posting no comment. `CR_WATCH_MAX_RETRIES=N` caps auto re-triggers per PR, default 2. `CR_WATCH_ASSUME_CODERABBIT=1|0` skips the probe.


## Phase 2: on each event

The session that owns the watcher is a thin router. Read the sentinel line, then hand the payload path to the seat that last touched the diff, usually the reviewer agent, resumed (Claude Code: SendMessage). Never fresh-spawn a fixer when a seat already holds the diff. Never paste a comment body into the routing session. Triage per finding: line-level goes to an agy delta prompt, judgement to the resumed Claude seat.

Per-event handling is in `events.md`.


## Phase 3: merge, once the user says so or under an explicit standing grant

Nothing merges on its own; every merge waits for `MERGE_OK`, and `compass` Step 0 is where the operator gives it for PRs whose review came back clean.

Check `rig-meta.sh get <owner/repo> merge_queue` first.

Every repo merges with merge commits, queues included (#164). A stacked PR keeps its history when its base lands, and release-please parses the Git history for Conventional Commit messages ([README](https://github.com/googleapis/release-please#readme)), so every commit message is conventional, the merge commit included. A repo whose `merge_commit_title` is `MERGE_MESSAGE` titles it `Merge pull request #N`, which release-please skips; pass the PR title as the subject.

- Queue repos (`merge_queue` true): enqueue with the `enqueuePullRequest` GraphQL mutation (`gh pr merge` answers `Auto merge is not allowed for this repository`, seen on prismalens/gh-workflows#217 - chore: remove the hourly review queue; the CodeRabbit summoner routine summons again), and the merge queue tests a speculative merge onto main before landing it. No BEHIND cascade, no update-branch babysitting. Enqueued is not merged: retarget, rebase or delete anything stacked on the PR only once `gh pr view <n> --json state` reads `MERGED`. Do not enqueue before the liveness comment shows posted review output (`claude-review-lane` §2, the liveness comment). The routine gates on checks and threads, not on whether a reviewer spoke, so enqueueing into silence merges an unreviewed head.
- Classic repos (`merge_queue` false): merge by hand once CI is green and every review thread resolved by the reviewer that opened it, `gh pr merge <n> --merge --subject "<PR title> (#<n>)"`; the PR title is already a Conventional Commit. BEHIND still applies, so update the branch and re-green before merging the next.

Afterward remove the lane's worktree and delete its local branch (`AGENTS.md` §Worktrees). `git worktree unlock` first if git refuses because the tree is locked.
