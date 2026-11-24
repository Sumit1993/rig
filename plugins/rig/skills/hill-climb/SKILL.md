---
name: hill-climb
description: "Use when asked to hill-climb a product or surface: agents fix it category by category until judges score every category at or above a bar."
metadata:
  version: "1.0.0"
---

# Hill climb

Lanes improve a product until judges score every category at or above a bar.

**Set the bar from a survey.** Research every surface first (`why-first`). For each category, write numbered bar items, a "beats it" line and a rubric at 5, 8.5 and 10. The target is to be as good as or better than the tool the user would otherwise open, never a copy of it.

**Keep requirements as data.** Each requirement or condition is one entry in a single climb file:
- the operator's words and the date;
- the surfaces it covers;
- how to simulate it;
- a stamp that proves it ran;
- a threshold;
- a CI case, owed later.

Generate the bar tables, judge prompts and lane briefs from that file; never retype them. A requirement the operator states mid-climb goes into the file in the same turn. A score on a condition whose stamp is missing reads "not tested".

**Use one simulated environment.** It is one command that builds the app, stages each condition and prints a sheet for judges. Judges, testers, Playwright and CI all use it. It lives in the product repo; if it is missing, build it first. Do the same for a runtime registry of the product's kinds and options: a feature is done only once it is declared there. Enforce rules in code (generated ids, lint rules, ratchets that only shrink), not in prose.

**Climb mode.** Every fix lands on one integration branch, with no PRs, no new tests and no CI until the bar is met. Each change passes typecheck, the static checks (including a conflict-marker guard) and the existing tests in the folders it touched. Re-run that gate after every merge. Lanes go through `farm-out`, one surface per lane.

**Judge at each checkpoint.** Reseed the environment, with real agent threads beside the fakes. Then run these judges in parallel:

| Judge | Who | What it does |
| --- | --- | --- |
| Strict | `adversary` seat | Scores each category. |
| Lenient | A side judge | Scores each category. Check its claims on screen, because it invents evidence. |
| Third | Another model family | Scores, so the merge rule has a median. |
| Cold-start tester | A fresh agent | Reports what was odd, misleading or confusing, and whether a new user would try the product. |
| Stranger | A fresh agent | Plays freely for 5 minutes, then answers "what is this app for?". |

The operator vetoes from a contact sheet before any score is posted.

Do not send a judge prompt unless it has all of these:
- reference shots for each category, or an explicit "none";
- calibration anchors (each judge scores the reference apps blind, and gaps over 1 point are reconciled once);
- a merge rule fixed before scoring;
- a stop rule.

Also include:
- a recall test with planted defects;
- a list of what changed since the last scoring;
- the known false alarms;
- write access to a disposable server.

Each score has a "vs reference: behind / at par / ahead" column. 8.5 needs at par, and 10 needs ahead. Credit only what was seen working, never what was read in source. Rebuild the prompt from the climb file every time, never by copying the last one.

The default merge is the median of the judges, plus a fix-list entry for each flaw below the bar that is backed by a screenshot. The default stop is every category at the bar on two checkpoints in a row.

**Distribute once the bar is met.** Cut the integration branch into PRs by surface, each within CodeRabbit's file limit (`babysit-pr`). Write the tests now, starting with the CI cases owed, then hand each PR to `babysit-pr`.

**Failures to design out:**
- Check a lane's real state before reporting it. A lane can end its turn mid-suite or die while it is still listed as running.
- Kill by PID, never by image name.
- After an outage or a rate limit, check each failed lane, then resume it from its own git state.
- Verify a measurement before acting on it. A first-page-only script once reported a false bottleneck.
- Run screenshots against a production build; the dev server crashes under them.
- Tools listen on loopback by default.

**Adapting to a product:** the bar shape, the judges, climb mode and requirements-as-data are generic. The categories, reference apps, simulators and registry kinds belong to the product.
