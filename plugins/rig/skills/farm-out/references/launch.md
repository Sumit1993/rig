# Launching an agy lane

## Launch

The slug is generated at launch, never hardcoded. It names the log, and through `--log-file` it is the only reliable handle on the process.

```bash
mkdir -p ~/ai-context/agy-logs
SLUG="agy-<task>-$(date +%s)"
ACTIVITY=~/ai-context/agy-logs/$SLUG.activity.log   # streams; staleness keys on this
OUT=~/ai-context/agy-logs/$SLUG.json                # the envelope, written once at the end
MODEL=gemini-3.8-flash-low
command -v jq >/dev/null 2>&1 && jq -n \
  --arg slug "$SLUG" \
  --arg model "$MODEL" \
  --arg prompt_file "<prompt-file>" \
  --arg worktree "$PWD" \
  --arg activity_log "$ACTIVITY" \
  --arg envelope "$OUT" \
  --arg stderr_file "$OUT.err" \
  --arg started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg agy_version "$(agy --version 2>/dev/null | head -1)" \
  --arg expected_commits 0 \
  --arg print_timeout 40m \
  '{slug: $slug, model: $model, prompt_file: $prompt_file, worktree: $worktree, activity_log: $activity_log, envelope: $envelope, stderr_file: $stderr_file, started_at: $started_at, agy_version: $agy_version, expected_commits: ($expected_commits | tonumber? // $expected_commits), print_timeout: $print_timeout}' \
  > "$OUT.meta.json"
agy --model "$MODEL" \
    --log-file "$ACTIVITY" \
    --output-format json \
    -p "$(cat <prompt-file>)" \
    --dangerously-skip-permissions --print-timeout 40m \
    > "$OUT" 2> "$OUT.err" &
AGY_PID=$!            # agy itself, no subshell in between
```

- Stderr goes to its own file; `2>&1` makes the envelope unparseable, which then reads as truncation.
- Stdout holds one object written at the end, so a healthy run looks frozen. Watch `$ACTIVITY`.
- `--model` takes a slug from `agy models`. No `--effort` with an effort-suffixed slug. `--print-timeout` is a Go duration (`40m`); bare `2400` exits 2.
- The sidecar `$OUT.meta.json` exists because agy's envelope omits the model.
- `run-agy-watchdog.sh` in the skill directory wraps the launch (positional arguments, `handler.md` step 1), reaps hangs, records quota walls through `agy-quota.sh record-from-envelope`, and keeps agy's pid in the sidecar as `agy_pid`. `agy-quota.sh check` reads only that cached record and says so; `agy-quota.sh live` probes both groups at zero tokens (#133 - Every seat sees its quotas).
- Stop a run with `kill-agy.sh <slug>`, never by name or by a pid picked from `tasklist` (`handler.md`, Kill).


## Models inside agy

agy 1.4.7 `agy models` prints six slugs: `gemini-3.8-flash-{low,medium,high}`, `claude-sonnet-4-6`, `claude-opus-4-6-thinking` and `gpt-oss-120b-medium`. Re-run it before naming any other.

- `gemini-3.8-flash-low` is the default for a work order that names its files, its change and a `Verify:` line: the same order took 7 turns in 27 s on low against 11 turns in 2.9 min on high, both correct (#167). `gemini-3.8-flash-high` when the lane must work out what to change. Neither for open-ended unsupervised coding. `gemini-3.8-flash-medium` is untested here.
- `claude-sonnet-4-6` and `claude-opus-4-6-thinking` sit in the other quota group with `gpt-oss-120b-medium`. `claude-sonnet-4-6` is the Gemini fallback. Its predecessor `claude-sonnet-5-5-low` did the #167 work order in 5 turns and 24 s; 4.6 is untested here. Opus there is untested and draws on the same pool. Avoid `gpt-oss-120b-medium`.
- agy has its own skills: Matt Pocock's set is at `~/ai-context/vendor/mattpocock-skills` for agy-side planning and review.
