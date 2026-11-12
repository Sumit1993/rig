---
name: compass
description: "Load when a session picks up work cold, is asked \"what's next\" or \"where are we\", must rank a queue, or merges on the operator's word; also for the label and milestone vocabulary."
metadata:
  version: "1.2.0"
---

# Direction

GitHub is the record and this skill is the reader. There is no script. Run the commands below with `gh` from inside the repo. Never run an unfiltered `gh issue list`; picking by recency is the failure this replaces. The ruling with the evidence is the last superseding comment on `Sumit1993/rig#100`.

## The vocabulary

Nine labels, the same in every repo, and nothing else:

| kind | state | priority |
| --- | --- | --- |
| `bug`, `enhancement`, `documentation`, `decision` | `blocked`, `parked`, `needs-operator` | `p0`, `p1` |

Bot labels (`dependencies`, `github_actions`, `javascript`, `autorelease:*`) and the review-lane labels `coderabbit_review`, `coderabbit_skip`, `claude_review` and `claude_review_skip` are mechanism, not vocabulary. Leave them alone and do not count them as drift.

A milestone is titled with the version it ships, `0.5.0`. A repo has at most two open: current and next. Line one of the description is the done-when sentence. There is no number prefix, no due date, and no order across repos.

Never create, rename or delete a label or a milestone. If the vocabulary lacks something, file an issue labelled `needs-operator` saying what and why. On a repo's first run the operator installs the labels and milestones, the skill never does.

## Step 0: review debt

Reviews land hours after a PR is marked ready. Before any new pick, list the operator's ready PRs in this repo and clear their findings, PR by PR, base first on a stack (`babysit-pr`):

```
gh pr list --author @me --state open --json number,title,isDraft --jq '.[] | select(.isDraft | not) | "#\(.number)\t\(.title)"'
```

Collect findings that need the operator's ruling and ask them all in one question at the end. List the PRs that pass `babysit-pr`'s merge conditions, ask once for the whole list, and merge each one granted.

## Step 1: read the repo and report drift

```
gh repo view --json nameWithOwner -q .nameWithOwner
gh label list --json name -q '.[].name'
gh api 'repos/{owner}/{repo}/milestones?state=open' --jq '.[] | "\(.title)\t\(.open_issues) open, \(.closed_issues) closed\t\(.description | split("\n")[0])"'
```

Drift is any label outside the nine and the mechanism set, more than two open milestones, or a milestone title that is not a bare version. Report drift to the operator in one line each. Do not fix it.

## Step 2: the current milestone

Current is the lowest open version. Sort the titles with `sort -V` and take the first. If the repo has no open milestone, nothing is startable; say so and stop.

## Step 3: the pick is a batch

```
gh issue list --state open --milestone '<current>' --limit 500 --json number,title,labels,createdAt --jq '
  map(select(.labels | map(.name) | index("blocked") | not))
  | sort_by([(.labels | map(.name) | index("p0") == null), .createdAt])
  | .[] | "#\(.number)\t\(.labels | map(.name) | join(","))\t\(.title)"'
```

The first line is the lead. `p0` sorts to the front of its own milestone and nowhere else. `blocked` is skipped; the comment on that issue names the blocker. An issue whose body says it is blocked but carries no label is a triage note: open it, and if the blocker is real, add the `blocked` label with a comment.

The pick is the lead plus every other startable issue in the list that touches the same files: read the bodies and the Pointers, not the titles. One branch, one draft PR, `closes #a, closes #b`, marked ready once at the end. Each PR is one review slot and hours of queue wait, so two PRs where one would do cost twice. Work found mid-session on the same files joins the open draft; it gets its own PR only when it is its own unit.

An issue with no milestone is not startable. Count them and report the number:

```
gh issue list --state open --search 'no:milestone' --json number --jq length
```

## Step 4: what is in flight

```
gh pr list --state open --json number,title,isDraft,updatedAt --jq '.[] | select(.title | startswith("chore(deps)") | not) | "#\(.number)\t\(if .isDraft then "draft" else "ready" end)\t\(.title)"'
```

A ready PR on the lead means the batch is already taken. Before moving to the next line, compare that PR's files with the rest of the batch: a same-file issue it left out waits for that PR, or joins it, unless it is its own unit. An open draft on the same files is where the batch goes.

## Handoffs

Each repo's pinned issue is the handoff log. Its last comment says where the previous session stopped. Read it after the pick, never instead of it, and never treat a list in its body as a queue.
