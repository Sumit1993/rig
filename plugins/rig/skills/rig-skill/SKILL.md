---
name: rig-skill
description: "Load before creating, editing or deleting a rig skill, an AGENTS.md line or a harness or host overlay, and before adding a rule, script or check to any of them."
---

# Writing for rig

A rig skill is procedure an agent loads on demand: the description says when, the body says what to do. `writing-for-agents` holds the general craft; this file holds only what rig decides.

## 1. Subtract first

Adverse behaviour usually comes from a line that already exists. Find it before writing anything: search the skills, `dotfiles/AGENTS.md` and the overlays on the default branch, never a copy under a worktree. Delete or narrow that line. Add only when nothing existing causes or covers the case.

Extend the skill that owns the surface before starting a new one. Related changes go in one PR.

## 2. Where it goes

- A rule every turn needs: one line in `dotfiles/AGENTS.md`.
- Procedure for one kind of work: a section of the skill that owns it.
- The tool a harness or host uses for an action: `dotfiles/harness/<name>.md` or `dotfiles/host/<name>.md`. Skills name the action, never the tool.
- Behaviour that must hold whatever the prose says: a hook or a test. A rule against a workaround invites the next workaround; say what good looks like and gate the harm.

## 3. Shape

- Prose over scripts. A script earns its place only when it does what prose cannot, and it ships with a test.
- Generic over specific: "read every CodeRabbit comment", not which comment, section and label.
- One point per sentence, in the present tense. Evidence goes in the PR body and the story in the issue; the lint rejects dates and history.
- No tool names the tool definitions already carry.
- tstack's skills, 2 to 5 KB each, are the size to aim for. The lint caps the description at 250 characters and the body at 1,500 words; a sub-case moves to `references/`.

## 4. Wiring

A new skill gets a row in `README.md` and an entry in each `dotfiles/harnesses.json` target that should carry it; the build fails on an unlisted skill or on a pointer to a skill a target lacks. A deleted skill leaves no pointer behind: grep its name. `bash scripts/check.sh` passes before the push.
