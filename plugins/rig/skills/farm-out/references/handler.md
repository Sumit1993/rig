# agy handler: failure, resume, kill, babysit

The `agy-runner`'s half of `farm-out`. The dispatcher never needs this file; the runner loads it before launching.

## Failure modes

| Symptom | Cause | Action |
|---|---|---|
| Non-zero exit, empty response | State stream dropped mid-run | Check the worktree first, work often landed. Else relaunch once on Gemini |
| Exit 0, empty `response`, `status` not `SUCCESS` | Claude quota out, or the turn failed | Same |
| `authentication failed or timed out` | Login expired | Re-login, smoke-test `-p "say ok"`, then relaunch |
| Output is not parseable JSON | `--print-timeout` hit mid-write | Truncation. Resume, below |
| Parseable JSON, work half done | Out of turns or time | Resume, never re-prompt |
| Full report printed, process never exits | Hang-after-report | Artifacts exist, log ends in a full report, log stale about 3 min: kill by PID now |
| Non-zero exit, populated worktree (e.g. `Error: timeout waiting for response`) | Died after real edits, nothing committed | `git status` and `git diff` first. Never relaunch onto uncommitted work; salvage or resume |
| Empty log, non-zero exit, dead in seconds (rc=137 or a bare death) | Killed from outside, usually another session's name-wide kill | Relaunch; it never started, so no budget spent. If it recurs, find the broad kill pattern |

Since 1.1.20 a non-zero exit is a cascade-level failure. Benign tool errors and denied permissions no longer poison it, so read it.

### Resume, never delta-prompt

```bash
CID=$(jq -r .conversation_id "$OUT")
agy --conversation "$CID" --output-format json \
    -p "You stopped after step 3. Continue from step 4." --print-timeout 20m
```

The resumed turn keeps the same `conversation_id` and the full context. A fresh run is only for an envelope that never closed, meaning no `conversation_id`.

The same holds for a Claude subagent the 5-hour limit killed, whose last message is a `<synthetic>` session-limit notice. Once the window resets, `SendMessage` that agent "continue from where you stopped"; its transcript is intact. Never respawn it on the original brief, which pays again for every request it already made (`#124 - Resume a subagent from its last output after a 5-hour limit kill`).

### Kill

- By PID. `AGY_PID=$!` from the launch is agy itself. `run-agy-watchdog.sh` prints the same PID on stderr.
- PID lost: `kill -9 $(pgrep -f "$SLUG")`. The slug is on agy's argv and nowhere else.
- Every live run: `pgrep -x agy`, then `readlink /proc/<pid>/cwd` for its worktree.
- Never derive the pattern from the prompt-file name. The launch expands `$(cat <file>)`, so agy's argv holds the prompt text. The file name matches only the wrappers, and killing on it leaves agy running.
- agy processes are machine-global. `pkill -x agy`, `pkill -f agy`, `killall agy` and `pgrep -f "agy [-]-model"` are never acceptable, not even when every live run is yours. The `pre:bash:no-broad-agy-kill` hook blocks them; if it fires, you wanted a PID.
- Prove a PID is yours or kill nothing. Yours means `readlink /proc/<pid>/cwd` matches your worktree, or a `$!` you captured. "Cannot identify my run, not killing" is a correct outcome: a hung run of yours costs a timeout, the wrong kill costs someone else's unattended work.
- A runtime slug also prevents the exit-144 self-kill: it did not exist when your ancestor shells started, so it cannot match their command lines. Bracketing helps but is not sufficient; see `no-doze`.

## Handler babysit loop

The runner's section, not the dispatcher's. A handler owns its run end to end: launch, watch, kill on hang, salvage, retry. Never return "agy didn't respond" without having run this.

1. Launch with `run-agy-watchdog.sh <worktree> <promptfile> <outfile> <expected_commits> <timeout> [model]` from this skill's directory, all positional; agy's own flags (`--model`, `--log-file`) are not its arguments. It launches, reaps hang-after-report, records quota to `agy-quota.sh`, and writes the `AGY_EXITED` sentinel. A bare background launch (`(agy … > "$OUT" 2>"$OUT.err"; echo "AGY_EXITED rc=$?" >> "$ACTIVITY")`) is the shape the watchdog runs, not a second sanctioned path: taking it yourself loses both, so it must be followed by `agy-quota.sh record-from-envelope "$MODEL" "$OUT"`.
2. Wait in the foreground with repeated bounded Bash calls and a long timeout. A handler never ends a turn while its run is alive: no Monitor, no `pgrep` liveness, no bare timer. Ending the turn destroys the context the wake would land in. The background until-loop in `no-doze` is for the main session only.
3. Kill on hang-after-report per the table, by PID.
4. Empty output: check the worktree (`git status`, expected files) before assuming failure. Landed and passing its own verification is success; note the silent death.
5. Run every verify command in the spec yourself once before reporting, whatever agy pasted. Then check provenance: the pasted output names the worktree path and the head SHA. Report your output, not agy's claims.
6. A run with no output that dies within about 30 seconds never started. Relaunch without charging the budget. Three in a row is an agy-side problem: change model.
7. A quota wall hits the whole group, not one model. Flash and Pro share a pool, so relaunching on the other Gemini slug walks into the same wall. Gemini dry means agy is finished for this run, and you are not. You are a Sonnet agent already holding the prompt file and the worktree. Do the task yourself from that prompt, and say so in the report. Handing it on costs a re-read of everything you have. A weekly bar refreshes in days, so the reset timer is not a plan.
8. Retry budget: 2 real relaunches. A resume on a surviving `conversation_id` is free, it is the same run. A quota wall costs no budget; it costs the group, and a dry Gemini group costs the agy run, not the task.
9. Name any PR the lane opened: `gh pr list --head <branch> --json number,url`, URL in the report. Do not arm a watcher; a Monitor dies with your turn. The main session arms `pr-babysit` on it.
10. Preserve work before reporting. A change that passes the prompt's own verification gets committed on the lane's branch and said so. Stop there: no push, no PR, no merge.

### The three terminal reports

1. A verified result, with the verification commands you ran and their output.
2. A salvaged partial, with evidence of what landed and what did not.
3. The relaunch budget spent on real failures, with the log tail, the worktree state, and what remains.

Gemini going dry never produces report 3. It is not a terminal condition and it does not spend the step-8 budget, which counts relaunches. You finish the task on your own Sonnet and return report 1 or 2, saying which parts Gemini did and which you did.

"Standing by", "still waiting on the agy run" and every other progress update is not a terminal report. Returning one ends the handler while the work is live.
