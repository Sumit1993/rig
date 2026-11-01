# The per-developer counter

## 3. The per-developer counter

The lane runs on the Free/OSS plan, seat assignment disabled:

| Plan | PR/hr | Files per review |
|---|---|---|
| Free | 1 | 150 |
| OSS (our public repos) | 1 to 10, typically 1 or 2 | 100 to 300 |
| Team | 8 | 300 |

Essentials was formerly called Pro, and Team was formerly called Pro+.

- **With `auto_review` off, nothing fires on its own.** Before #150 a repo carrying `auto_review: true` was reviewed 8 to 93 seconds after `gh pr create` whatever its star count (`prismalens/gh-workflows` `#158`, `#155`, `#142`). A repo with no `.coderabbit.yaml` gets CodeRabbit's default, which is on; every repo in the routine carries one with `enabled: false`.
- **A draft is never reviewed.** The routine skips drafts, and CodeRabbit posts `Draft PR not reviewed` on a draft summon (`prismalens/gh-workflows#161`). Open the draft first, push as often as the work wants, and mark ready once at the end.
- **Do not read the plan off the bot.** CodeRabbit's run configuration reports a feature tier, and it printed "Plan: Team" on a repo that is rate-limited as Free, because open-source projects receive Team features without a subscription. The name the bot prints is not the row of the rate-limit table that applies.
- The counter is per developer, not per repo, branch, session or subagent. Every repo in the routine draws one pool. Run at most one review at a time across every repo you touch; parallel runs serialise and delay every lane.
- Every run spends a slot: initial reviews, incremental reviews, manual `@coderabbitai review`. The CLI's `coderabbit review --agent` posts to the PR regardless of labels (marker `coderabbit-cli-agent-hint`, recorded on `#123`). Repos set `auto_pause_after_reviewed_commits: 1` in `.coderabbit.yaml`: one review per PR, then batch fixes before the routine re-requests.
- Auto-pause is recoverable. A push past the limit pauses the lane on that PR and nothing arrives on its own. A bare `@coderabbitai resume` restarts it, and what follows is a real review of the final head that posts `Review completed`, so a PR paused by its own fix commits can still meet a merge condition requiring one. Resume deliberately; it spends a slot.
- Batch fixes before requesting. Never spend a slot on a commit you are about to amend.
- Remaining capacity is not readable. `@coderabbitai rate limit` returns documentation links.
- The notice's stated wait is accurate. Obey it, because it is the same one-review-per-developer-per-hour Free limit measured directly, not a guess. It is the per-developer window anchored to the last accepted review, measured exact to within fifteen seconds. A flat 60 minutes from the refusal has the wrong anchor and lands about 21 minutes late. `watch-coderabbit.sh` arms on the parsed figure and falls back to `CR_WATCH_COOLDOWN_SECONDS` (default 3600, a coincidental match to the hourly limit since this is the unparseable-notice fallback, not the limit itself) only when nothing parses; the event line names which it used. CodeRabbit has used at least three wordings, and the pattern once matched only the first:
  - `Next review available in: **47 minutes**`
  - `**Next included review available in 30 minutes.**`
  - `Your next included review will be available in 23 minutes.`
- The documented limit is one review per developer per hour on Free, rolling. The observed interval between an accepted review and the next runs about 55 to 57 minutes.
- `review full` is not a way past the limit, and it is not a retry. Both forms draw the same budget. A success shortly after a refusal is the window rolling over. The note "CodeRabbit is an incremental review system and does not re-review already reviewed commits" is a footer on every reply to a summon, accepted ones included (`prismalens/gh-workflows#213`); it is never a refusal.
- CodeRabbit edits its reply in place, so a first read can show the opposite of the settled outcome. Read `updated_at`, wait for it to stop changing, classify on the settled body, and re-read before acting, not only before classifying.
