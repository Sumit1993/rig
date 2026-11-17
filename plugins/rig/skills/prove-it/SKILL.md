---
name: prove-it
description: "Load before calling a change done, fixed or working, and before writing a PR's proof line: show observed evidence, not only green tests."
metadata:
  version: "1.0.0"
---

# Prove it

A change is done when you have watched it work, not when its tests are green. Proof is evidence you observed in this session that someone else can check without replaying your run.

1. **Reproduce first.** Before fixing, run the failure and keep the command and its output. After fixing, rerun the same reproduction and watch it pass.
2. **Prove it where the user touches it.** Run the real command or app and walk the changed flow; capture the output or a screenshot. A mocked test does not prove user-facing behaviour.
3. **Never buy green.** Do not edit, skip or weaken a test to pass it. A test you add is seen failing without the fix.
4. **Trust the observation last.** Confirm the running build contains the change (fresh build, right instance) before what you see counts. A proxy is not proof: a file's mtime, cached output, "it compiles", a delegate's say-so. When a check surprises you, suspect how you looked before the system.
5. **Check one effect past the screen** when there is one: the file, row, network call or state after a reload.
6. **Report the proof.** List each piece: the command with an output excerpt, or the artifact. Name anything unproven and what blocks it, and say "inconclusive" rather than "done". A PR body carries one proof line.

A project with its own verification skill keeps it; this is the floor beneath it.
