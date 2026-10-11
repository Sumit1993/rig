---
name: adversary
description: "Adversarial challenge, second opinion, hole-poking or a rebuttal of objections for an idea, plan, spec, approach, implementation or decision. Runs the adversary seat: GPT-6.1 Sol via Codex by default, another fresh agent when Codex is unavailable. Load before asking anyone to try to break a proposal."
metadata:
  version: "2.0.0"
---

# Adversary seat

## 1. The seat

The adversary tries to break a proposal before anyone acts on it. It is not the implementer, the planner or a merge authority. Invoke it to attack an idea's value or feasibility, a spec's assumptions, competing approaches, a substantial plan before implementation, an implementation before it is called done, or a disputed product or architecture decision. Mechanical edits do not need it.

The default holder is GPT-6.1 Sol through `codex exec`, at effort `high`. The effort is fixed: an agent does not choose it. The operator alone overrides it, through `RIG_ADVERSARY_EFFORT` (`xhigh` or `max`). Codex may use its own subagents for reading; it owns and verifies every objection they feed it.

When Codex is unavailable (its quota is exhausted or unknown, or the run failed), another agent holds the seat: `--holder claude` runs Opus 5.5 at the same effort, under the same contract, packet, result schema and validator, in a fresh process. The seat never passes to the author's own context; a self-review is not a substitute. `metadata.json` and `status.json` record the holder, so the ledger shows who judged.

The agent doing the work runs its own adversary rounds: it calls the launcher with its shell and reads the result. `codex-runner` is optional, for an organizer that wants the wait off its own context.

## 2. Frozen packet

The packet lives under `~/ai-context/<repo>/<issue>-<slug>/`. It carries:

- The mode (idea, plan, spec, approach, code or decision), the original objective and observable acceptance criteria.
- For repository evidence: absolute source paths, the base and target commits, and a clean, dedicated git worktree that is not the main checkout. Commit a snapshot first when the work is uncommitted.
- Applicable constraints, linked issues and PRs by title, and the surrounding direction. Private product questions stay in their private record.
- Verification commands and existing evidence, with commands actually run kept apart from proposed checks.
- A bounded question and the evidence that would falsify the recommendation. A first-round packet leaves out the author's defense and preferred verdict.

A proposal without a repository is self-contained: the proposal itself, its assumptions, intended users, alternatives, constraints and success and failure criteria, with source excerpts and exact URLs copied in. A linked mutable document is not frozen evidence.

The launcher prepends `review-contract.md`, requires full `--base` and `--head` SHAs with `--worktree`, rejects a mismatched HEAD or a dirty tree, copies the packet, and records hashes, arguments, holder and runtime status in a new run directory under `~/ai-context`. It needs Python 3.10+ with `jsonschema` (`python3 -m pip install -r requirements.txt` from this skill's directory), an authenticated `codex` (or `claude` for the fallback holder), and Git only for repository evidence. A missing dependency is a failed dispatch, not a reason to buy access.

## 3. Running a round

The launcher is `run-review.py` in this skill's directory; `$SKILL_DIR` below stands for that directory's absolute path. A standalone proposal:

```bash
python3 "$SKILL_DIR/run-review.py" --packet "$PACKET" --run-dir "$RUN_DIR"
```

Repository evidence adds the frozen worktree and its SHAs:

```bash
python3 "$SKILL_DIR/run-review.py" --packet "$PACKET" --run-dir "$RUN_DIR" \
  --worktree "$REVIEW_WORKTREE" --base "$BASE_SHA" --head "$HEAD_SHA"
```

When Codex is unavailable, the same command with `--holder claude` gives the seat to a fresh Opus process. Packet mode copies the proposal into a fresh evidence directory and runs there; repository mode runs in the worktree. The default deadline is 2400 s. A run takes many minutes: wait on it per `no-doze` §2, in the foreground or in the background, until `status.json` exists.

Check Codex's usage before planning around a judgment: `codex-quota.py check` prints one line (`usable: 5h 40%, weekly 67%` or `exhausted until <time>: …`) and exits 0 usable, 1 exhausted, 2 unknown. It asks the Codex app server's `account/rateLimits/read` method ([protocol](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/src/protocol/common.rs)), with no model turn, and falls back to the newest Codex rollout log, labeled with its age. The launcher runs the same check: an exhausted quota fails the run before launch, and a failed run records the quota so a usage limit is not read as a generic error. Session start prints it in the budget line. An exhausted or unknown quota passes the seat to `--holder claude`, or the judgment waits for the reset when the operator prefers Codex.

The Codex holder runs fresh, read-only, with saved CLI authentication and native web search. Plugins and apps are off; every configured MCP server is discovered and disabled, and a second inventory must show all of them disabled, or the launch is refused. The Claude holder gets only Read, Grep, Glob, WebSearch and WebFetch, with `--strict-mcp-config`. Filesystem sandboxing is not an external-service boundary: write-capable integrations stay out of this seat. Builds that need writes are separate verification work, or are reported unverified.

The launcher enforces its deadline and kills only its own process group; SIGINT or SIGTERM cleans up the group and records failure. It never retries, switches model or holder on its own, or writes a judgment itself. These outcomes are failures, never a clean verdict:

- the frozen target or packet changed during the run;
- the holder finished with zero tool calls, or Codex reported an error such as a refusal (`codex_error_info`);
- the result fails the schema, the ledger rules, or names no sources under a `survived` verdict.

## 4. Objections and rebuttals

Findings are confirmed defects, credible risks or open questions. Each objection carries a stable ID, a failure scenario, the violated constraint, evidence, impact and a falsification check. There is no finding count, no speculative certainty and no style-only objection. The seat challenges the premise, design, scope, verification and claimed benefit, and looks for simpler alternatives and attacks the author did not anticipate.

The working agent checks each claim and records it accepted, refuted with evidence, or unresolved. It fixes accepted findings and sends a new packet with the previous validated result, the revised target and its evidence-based response to each objection, through a fresh run with `--previous-result "$PREVIOUS_RESULT"`. The launcher copies the prior ledger into the prompt and rejects a result missing any prior ID. That enforces continuity, not the substance of a claimed fix. IDs are preserved, disproven objections are withdrawn, and fixed is kept apart from merely disputed. The seat tests rebuttals rather than accepting or defending its earlier answer.

Default budget: an initial round plus one rebuttal round. Another round needs a new concrete question, not a request to keep going until agreement. Unresolved material disagreements go to the operator. A `survived` verdict means no material objection remains within the stated coverage; it is not a guarantee or a permission to merge.

## 5. Evidence and record

`result.json` is the validated judgment. `status.json` is the authority on its standing: `completed`, `incomplete` or `failed`, the holder, and `unmatched_sources`, every `sources` entry naming a path or URL that no tool call in the run touched. A `survived` verdict with any unmatched source is downgraded to `incomplete` in `status.json`, with the reason. `events.jsonl`, stderr and metadata are telemetry. Check the exit status, target identity and validation before relying on a finding. Copy the decision, commands and deciding evidence into the issue, PR or private record; a log or prompt path is never cited as durable evidence.

The seat reads outside primary sources and the surrounding records before ruling, names its sources and limits, and gives the strongest objection to its own recommendation. It reports what survived as well as what failed. Unreachable sources are a stated coverage gap, never an invented citation.

## 6. Live evidence

Use `codex-desktop` to run a scoped Windows task or experiment. Its observations are separate evidence, not permission for the read-only seat to change apps. Feed the test report, screenshots, build identity and missing coverage into a new packet. A prepared or opened request is not a performed test.
