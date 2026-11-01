---
name: assayer
description: "Review rounds through the assayer runner: `assayer review`, Codex as the default engine and OpenCode's free models as the cheap one, its coverage-count summary, runner limits, the round budget, run-to-run variance, and how its findings count as review debt. Load when an assayer-finding thread, an assayer or Codex review round, a round that stopped early, or a choice of whether to run another round is in front of you."
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

Codex reviews from `prompt/codex.md`, not the Claude lane's template, at `xhigh` effort in a 90-minute round with a 15-minute idle cut. Other engines use the lane template (`prompt/template.md`).

- Every reviewable manifest file is examined, each read with `git diff <base> <head> -- <path>` in line ranges.
- Each finding posts inline in the four-part envelope, opening `_Category_ | _Severity_ | _Effort_` (`claude-review-lane` §8, finding labels), and ends in the `assayer-finding` marker.
- One summary comment opens `## Code review`: findings by severity, then the coverage count, `N/M reviewable files examined`, naming each skipped file and why.
- A summary with no count, or N below M, is an incomplete review, not a clean head.
- The engine never submits a formal review, resolves a thread or merges.

## 3. Runner limits

- One refused command ends a Codex round as `cancelled`, not `completed`: Codex offers only `cancel` for a refused request. The template forbids `;`, `&&`, `|`, `--jq`, `--template` and fetches for that reason.
- Every Codex tool output is cut at 10,000 tokens per call, a per-model cap that `tool_output_token_limit` does not raise. A read that came back truncated covers nothing.
- A ChatGPT usage limit arrives as agent text, then a bare `Internal error`. The runner records it as `account-limit` with `reset_at`; rerun after that time, not before. Check first with `codex-quota.py check` (`adversary` §3, running a round).
- `summary.json` in the round directory is the record of what ran: conclusion, reads, findings, permissions refused. Exit 0 is `completed`, 3 an engine error, 4 a timeout.

## 4. Budget and variance

Two runs on one head find different defects: on one 81-file PR they found 7 and 4, with 2 in common. One clean round is one sample, not proof the head is clean, and a second round re-reviews rather than verifies.

The round budget is `adversary` §4's: three rounds per PR, five only while a blocking or material finding on security, permissions, auth, data loss or concurrency stays open with evidence. A round after fixes is worth running only when behaviour changed; a round that returned only minor findings ends the loop. Budget end is not approval. A cheap first pass on `--engine opencode` costs no quota and spends none of the budget.

## 5. Acting on findings

- Verify each finding against the code before acting. A finding is a report and its suggestion an untrusted fix.
- Fix in the smallest change that covers the case that happened; decline the rest in-thread with the reason and list them as follow-ups. A review loop grows a PR one cheap-looking fix at a time.
- Findings are review debt. They are review threads on the operator's PR, so `compass` Step 0, review debt, counts them with every other open thread.
- Clear them like any thread: fix, push once, reply in-thread with the SHA. The runner has no verify round and never resolves; the threads post under the operator's login, so the operator is the reviewer that opened them and resolves them, which meets `AGENTS.md`'s merge rule. A session never does.
