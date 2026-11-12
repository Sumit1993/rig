---
name: assayer
description: "Load when an assayer-finding thread, an `assayer review` or Codex review round, a round that stopped early, or the choice to run another review round is in front of you."
metadata:
  version: "2.0.0"
---

# The assayer review lane

The assayer runner in `prismalens/gh-workflows` (`runner/`) runs one review round over the Agent Client Protocol with an engine of your choice and posts the findings. Callee truth is the runner, never a local checkout:

```bash
gh api repos/prismalens/gh-workflows/contents/runner/README.md -H "Accept: application/vnd.github.raw"
gh api repos/prismalens/gh-workflows/contents/runner/src/engines.js -H "Accept: application/vnd.github.raw"
```

## 1. Admission

No repo admits a round automatically: no routine, no webhook. A round runs only when the operator runs it, on any PR their `gh` can read, with their own engine sign-in:

```bash
assayer review owner/repo#N                    # Codex, print only
assayer review owner/repo#N --post             # post as the operator's gh login
assayer review owner/repo#N --engine opencode  # OpenCode's free tier: no key, no quota
assayer publish <round-dir>                    # post, or resume posting, a round that already ran
```

It refuses a closed PR, a PR labelled `claude_review_skip`, a head this engine already reviewed (`--again` runs another), and a repo whose `.github/claude-review.yml` it cannot apply (`--ignore-repo-config` uses the workflow defaults). The round lives in `~/.assayer/reviews/<repo>-<pr>-<sha>-<time>/`; the engine gets no GitHub credential and nothing reaches GitHub but reads until the post.

## 2. The template contract

Codex reviews from `prompt/codex.md`; other engines use `prompt/template.md`.

- Every reviewable manifest file is examined, each read with `git diff <base> <head> -- <path>` in line ranges.
- Each finding posts inline in the four-part envelope, opening `_Category_ | _Severity_ | _Effort_`, and ends in the `assayer-finding` marker.
- One summary comment opens `## Code review`: findings by severity, then the coverage count, `N/M reviewable files examined`, naming each skipped file and why.
- A summary with no count, or N below M, is an incomplete review, not a clean head.
- The engine never submits a formal review, resolves a thread or merges.

## 3. Runner limits

- One refused command ends a Codex round as `cancelled`, so the template forbids `;`, `&&`, `|`, `--jq`, `--template` and fetches.
- Codex tool output is cut at 10,000 tokens per call; a truncated read covers nothing.
- A ChatGPT usage limit arrives as agent text, then a bare `Internal error`. The runner records it as `account-limit` with `reset_at`; rerun after that time, not before. Check first with `codex-quota.py check` (`adversary` §3, running a round).
- `summary.json` in the round directory is the record of what ran: conclusion, reads, findings, permissions refused.

## 4. Budget

One clean round is one sample, not proof the head is clean.

The round budget is `adversary` §4's.

## 5. Acting on findings

- Verify each finding against the code before acting.
- Fix in the smallest change that covers the case; decline the rest in-thread with the reason.
- Clear them like any thread: fix, push once, reply in-thread with the SHA. The threads post under the operator's login, so the operator resolves them.
