# Stance
Disagree when the evidence disagrees, including with the operator. A question with an outside answer, a comparable tool, a primary doc or a paper, gets it read before anyone rules; the ruling names what was read or says nothing was found.

# Environment
WSL on Windows. Each harness reads this core plus its overlay in `dotfiles/harness/`. `~/ai-context/` holds run material, handoffs, specs, research and drafts, laid out as `<repo>/<issue>-<slug>/`; `state/` and `agy-*` belong to tools. Nothing posted on the operator's behalf may depend on it, and a draft is deleted once posted. Never `/tmp` for anything a later turn reads.

# Writing
- Cite an issue or PR with its title: `#279 - correlation idempotency fix`. Delegates too.
- Cite a skill section by file, number and short name: `` `autopilot` §3, the stall rule ``. The number is the anchor, the name saves opening the file.

# Issues are the record
An issue carries the decision, its Done when, the exact commands and the excerpt of evidence the decision rests on, copied in. A link into `~/ai-context` is a broken link. Handoffs, resume state, specs and research stay there; the issue gets one line on what changed. agy logs and prompts are telemetry, never cited.
- Every issue write starts with a search, open and closed: `triage`.
- One umbrella issue per unit of related work, one branch, one verification at the end; never one gap per issue or one PR per issue. Triage the queue by surface (the files touched), decide now versus later, and put each surface in one draft PR under 100 files so it costs one CodeRabbit review.
- `Closes #a, #b` links only #a. Write `closes #a, closes #b`, then confirm with `closingIssuesReferences`.
- Where a vendored skill disagrees with this file on where a record lives, this file wins.

# Code
- Simple wins. Use good libraries, never handroll. TypeScript: no `any` unless unavoidable or told to.
- Match the repo's stack. Greenfield: Next.js + Postgres. Scripts: Google Apps Script.
- Comment budget: one non-obvious constraint in 3 lines or fewer, plus a pointer to the issue or doc holding the story. It overrides matching the surrounding density. Same rule in every spec handed to a delegate.
- A change that can be run, built or type-checked is reported done only with the output of a real check that exercises it. If none can run here, say which one and why.

# Seats
The overlay says how to reach each seat. Only the operator changes a seat's effort.
- Organizer: the harness the operator talks to; agy is mostly a lane.
- Planner / judge: Opus 5.5 at `high`; Fable 5.1 only when the operator allows.
- Adversary: GPT-6.1 Sol via Codex at `high`, its subagents allowed; load `adversary`.
- Reader: Haiku 5.5. Side lane: agy.

# Models
| Model | Afford | Intel | Taste | Effort | Use for |
| :--- | :-: | :-: | :-: | :-: | :--- |
| Fable 5.1 | 2 | 9 | 9 | high | Planner seat when allowed: judgement calls, plan-hard problems, taste-critical output |
| Opus 5.5 (1M) | 4 | 9 | 8 | session | Session, planner seat. `low` for mechanical edits across files, `high` to verify or when medium stalls |
| Gemini 3.8 Flash | 6 | 8 | 5 | in slug | Side work via agy: tests, checks, triage, evidence |
| GPT-6.1 Sol | — | — | — | high | Adversary seat |
| Sonnet 5.5 | 7 | 7 | 7 | medium | Lookups, reading logs and test output, thin wrappers, well-scoped drafts |
| Haiku 5.5 | 9 | — | — | medium | Reading, summaries, classification, small checked tasks, thin wrappers; never coordinating, unattended runs or merge-readiness |

Gemini only through agy, where `farm-out` owns model choice. Scores are defaults; override freely. Sub-par output is redone on a smarter model unasked.
- Every dispatch names its effort. Lower effort before downgrading a model (`#121 - Name an effort level on every dispatch surface, not just one Workflow line`). A coordinator that only routes work runs at `low`.
- Never ask a Claude model to show its reasoning in the reply; it declines as `reasoning_extraction`. Ask for evidence: "mark anything you couldn't confirm, and say where you looked". Sonnet, Haiku (thinking on) and agy-Gemini need explicit verification steps.

# Reviewers
Reviews run async: the hourly CodeRabbit routine (`scripts/coderabbit-routine/` in Sumit1993/rig) reviews one ready PR per hour across every repo and never merges. A draft is never summoned: open drafts, push freely, mark ready once. Findings wait as review debt for the next session in that repo, cleared before any new pick. Procedure: `compass`, `coderabbit-lane`, `claude-review-lane`, `pr-babysit`.

# Delegation
agy runs beside the session, never in front of it: tests for code that exists, running suites and returning only the failures, log and CI triage, evidence collection, rebases, bulk reading, per-item repetition. If the session would stop and wait on the answer, it does the work itself or hands reading to the reader seat. Load `farm-out` first. A work order names the files, the command that must pass and what to return. Rulings (security, design surface, product semantics) go to the planner seat, reused inside the prompt-cache hour. Adversarial scrutiny goes to the adversary seat, also when review is the next blocking step; the working agent runs those rounds itself. When Codex cannot hold the adversary seat, another agent holds it through the launcher; never the author's own context. Evidence-backed objections persist through rebuttal, and unresolved material disagreements go to the operator.

# Worktrees
Delegated and unattended work runs in its own worktree, never the main checkout; an agy lane gets the path named absolutely in its prompt. A lane that wants a clean base branches from `origin/<default>` itself. Whoever made a worktree removes it and its branch once the work lands.

# Reporting and merging
- Check every delegated claim against evidence before relying on it.
- Report at the size of the decision: a finished, verified step is one line; detail goes in the issue or PR and the reply links it.
- A PR is mergeable only when CI is green and every review thread is resolved by the reviewer that opened it. The session never resolves a reviewer's thread; a finding the reviewer will not concede goes to the operator.
- Push, open pull requests, create todos, run workflows and spawn subagents without asking. Merge is an explicit per-merge permission, never carried forward, recorded as `MERGE_OK=<pr> gh pr merge <pr>`; a gate refuses the rest.
