---
name: no-doze
description: "Load before launching anything that outlives one turn, when a wait, watcher or handler has gone quiet, or when a background run must be killed."
metadata:
  version: "2.0.0"
---

# Anti-stall: waiting on long work

Key a wait on durable evidence (a sentinel line, an artifact file, a commit), never on process liveness or a timer.

## 1. Sentinel first

Every long command logs to a file and appends its own exit fact:

```bash
(<cmd> > "$LOG" 2>&1; echo "DONE rc=$?" >> "$LOG")
```

Without it the completion signal is transient and a missed wake loses it.

## 2. Wait on evidence, foreground or background by who waits

```bash
for i in $(seq 1 N); do grep -q DONE "$LOG" && exit 0; sleep 15; done; echo WATCH_TIMEOUT
```

- `N` is `expected_minutes * 4 + 40`. The loop length is the timeout. `WATCH_TIMEOUT` in the log means stop waiting and salvage.
- Organizer: background, started right after launch, where the harness wakes the session when a background command ends (Claude Code's background Bash fires one notification and the session is there to receive it). A harness with no such notice waits in the foreground, like a handler.
- Handler subagent: foreground, repeated bounded Bash calls. A handler never ends a turn while its run is alive. A backgrounded loop plus an ended turn destroys the context the wake would land in, the run goes unwatched, and the parent gets a completion notice for a handler that did nothing.

### Evidence only an MCP tool can read

When no shell can reach the evidence, poll with a scheduled tick, a turn in which the model calls the tool itself (`autopilot` §0, arm the wake-up). Record it in the plan file as "tick every N min, calls `<tool>`", and disarm it when the thing resolves.

## 3. Never wait on a condition the event prevents

Before arming a loop, check that the event you wait for cannot stop the exit condition from ever being true.

```bash
until [ "$(gh pr view 495 --json mergeStateStatus --jq .mergeStateStatus)" = "CLEAN" ]; do sleep 30; done
```

An unresolved review thread pins `mergeStateStatus` at `BLOCKED`, so the posted finding is the event that guarantees this never exits.

- A PR wait keys on `reviewThreads` and comment IDs, never on merge state. Any increase is the event.
- `BLOCKED` means "CI running" or "reviewer left findings"; query `reviewThreads` to tell which.

## 4. Check before waiting

Any wake, expected or not, including a user message: check the sentinel and expected artifacts first, then decide.

## 5. Watch evidence, not reports

A lane that says waiting with no live process or changing artifact has stalled; read it and resume.

## 6. Deadline fallback

At expected duration plus 10 minutes of silence, read the logs yourself and salvage. Check artifacts before re-running anything.

## Killing safely

Any `pgrep -f` or `pkill -f` whose pattern appears in your own shell's command line kills your own shell, exit 144.

- Kill by PID. Capture `PID=$!` at launch and keep it. The rest is for a lost PID.
- The bracket trick (`"issue39[-]rca"`) is not sufficient: the harness runs each shell call inside a wrapper shell, so any other mention of the string in the same call defeats it. Generate the marker at runtime (`SLUG="run-$(date +%s)"`) and give the kill its own call.
- `kill -9 "$PID"` preferred. `kill -9 $(pgrep -f "$SLUG")` as fallback.
- A shared binary's processes are machine-global; `pkill -x <name>` reaches every session on the host.
- Prove a PID is yours (a captured `$!`, or a `readlink /proc/<pid>/cwd` you recognise) or kill nothing and say so.
- Match a pattern that is on the target's argv. A shell expands `$(cat file)` before exec, so a prompt file's name reaches only the launching shell. `farm-out` has the worked example.
