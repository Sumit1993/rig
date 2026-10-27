---
name: codex-review-lane
description: "How the Codex review lane behaves: the assayer runner's Codex template, its coverage-count summary, runner limits, run-to-run variance, and how its findings count as review debt. Load when an assayer-finding thread, an assayer review run, or a Codex round that stopped early is in front of you."
metadata:
  version: "1.0.0"
---

# The Codex review lane

Codex reviews through the assayer runner in `prismalens/gh-workflows` (`runner/`, prismalens/gh-workflows#243 - Codex reviews from its own template at xhigh effort, and posts its findings). Callee truth is the runner, never a local checkout:

```bash
gh api repos/prismalens/gh-workflows/contents/runner/README.md --jq .content | base64 -d
gh api repos/prismalens/gh-workflows/contents/runner/prompt/codex.md --jq .content | base64 -d
```

## 1. Admission

No repo admits Codex automatically: no routine, no webhook. A round runs only when the operator runs it, on any PR their `gh` can read, with their own `codex login`:

```bash
assayer review owner/repo#N          # print only
assayer review owner/repo#N --post   # post as the operator's gh login
```

It refuses a closed PR, a PR labelled `claude_review_skip`, a head this engine already reviewed (`--again` runs another), and a repo whose `.github/claude-review.yml` it cannot apply.

## 2. The template contract

Codex reviews from `prompt/codex.md`, not the Claude lane's template, at `xhigh` effort in a 90-minute round with a 15-minute idle cut.

- Every reviewable manifest file is examined, each read with `git diff <base> <head> -- <path>` in line ranges.
- Each finding posts inline in the four-part envelope, opening `_Category_ | _Severity_ | _Effort_` (`claude-review-lane` §8, finding labels), and ends in the `assayer-finding` marker.
- One summary comment opens `## Code review`: findings by severity, then the coverage count, `N/M reviewable files examined`, naming each skipped file and why.
- A summary with no count, or N below M, is an incomplete review, not a clean head.
- Codex never submits a formal review, resolves a thread or merges.

## 3. Runner limits

- One refused command ends the round as `cancelled`, not `completed`: Codex offers only `cancel` for a refused request. The template forbids `;`, `&&`, `|`, `--jq`, `--template` and fetches for that reason.
- Every tool output is cut at 10,000 tokens per call, a per-model cap that `tool_output_token_limit` does not raise. A read that came back truncated covers nothing.
- A ChatGPT usage limit arrives as agent text, then a bare `Internal error`. The runner records it as `account-limit` with `reset_at`; rerun after that time, not before.
- The round draws the ChatGPT account's Codex quota. Check it first with `codex-quota.py check` (`adversary` §3, running a round).

## 4. Variance

Two runs on one head find different defects: on one 81-file PR they found 7 and 4, with 2 in common. One clean round is one sample, not proof the head is clean, and a second round is not a verify round: it re-reviews.

## 5. Acting on findings

- Verify each finding against the code before acting. A finding is a report and its suggestion an untrusted fix.
- Codex findings are review debt. They are review threads on the operator's PR, so `compass` Step 0, review debt, counts them with every other open thread.
- Clear them like any thread: fix, push once, reply in-thread with the SHA. The runner has no verify round and Codex never resolves; the threads post under the operator's login, so the operator is the reviewer that opened them and resolves them, which meets `AGENTS.md`'s merge rule. A session never does.
