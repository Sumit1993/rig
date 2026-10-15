---
name: behavior
description: "Turn \"I want the agent to always/never do X\" into a landed behavior in rig: pick the strongest form that can carry it (setting, check, hook, rule, skill), build it for every harness target in dotfiles/harnesses.json, test it, and leave a draft PR. Load when the operator asks for a new behavior, a correction keeps repeating, or a memory or note describes something the agent should do or refuse."
metadata:
  version: "0.2.0"
---

# Behavior: from a wish to a landed, tested behavior

A behavior is something the operator wants to happen at a moment: when they prompt (a skill loads), or when they are not looking (a hook blocks, a rule steers). A memory that says "always X" is a behavior nobody built yet.

## 1. State it as trigger, action, exception

Write three lines before anything else:

- **Trigger:** the observable moment, as a tool call or event. "Before `gh pr ready <n>`", not "before a PR is ready".
- **Action:** block with a message, rewrite, or add context.
- **Exception:** what must still pass. A behavior with no exception blocks real work.

If the trigger is not a tool call, an event, or a prompt the operator types, the behavior cannot be enforced. Make it a rule line (§3, rule) and say so.

## 2. Check what already enforces it

Before building anything, search for existing coverage: `permissions.deny` and `allow` in `dotfiles/settings.fragment.json`, every hook header in `plugins/rig/hooks/*.sh` (`grep -l` the trigger's verb), and `dotfiles/AGENTS.md`. If something already enforces the behavior, stop: report what covers it and change nothing. A second guard for the same trigger is a duplicate to maintain, not extra safety.

## 3. Pick the strongest forms, layered

Start at the top of the table and take every form that covers part of the behavior. A form that covers only some paths still lands; the next form down covers the rest. Example: "never read .env" is a `Read` deny rule (setting) for the Read tool, plus a hook on `Bash` for `cat`/`source`, plus nothing more. Record one reason for each form you skipped. The reasons go in the hook header or the PR body.

| Form | Use when | Lands in |
|---|---|---|
| setting | a permission or deny rule expresses it exactly | `dotfiles/settings.fragment.json` (a plugin cannot ship permission rules) |
| check | a repo test, lint or CI job can catch it after the fact | an issue in that repo, not here |
| hook | the trigger is a tool call the harness exposes | `plugins/rig/hooks/<slug>.sh` plus a test |
| rule | the agent must judge it, or no harness exposes the trigger | one line in `dotfiles/AGENTS.md` or an overlay in `dotfiles/harness/` |
| skill | it is a procedure the operator invokes by asking | `plugins/rig/skills/<slug>/SKILL.md` |

## 4. Map it onto every target

Read `dotfiles/harnesses.json`. For each target, write one line: native form, fallback, or none, with the reason.

- Claude Code (WSL): every PreToolUse tool. Matchers must name a tool in `hooks/tests/check-wiring.sh` `KNOWN`.
- Codex (WSL): PreToolUse fires for `Bash`, `apply_patch` and `Agent`. Input cannot be rewritten. Edits arrive as `apply_patch`, so an `Edit|Write` hook does not fire there. New or changed hooks run only after the operator trusts them: Codex stores a per-hook `trusted_hash` and skips untrusted hooks in headless runs. Say in the PR that the operator must approve the hook in Codex once.
- Windows targets: no hooks, because the hooks are bash reading WSL paths. The fallback is the rule line, if the behavior matters there.
- agy: hooks only where `harnesses.json` lists them for agy.

Add the hook to `hooks/hooks.json` and to each target's `hooks` list in `harnesses.json`. Leave a target out only with a reason in its `$comment`.

## 5. Build a hook the rig way

Copy the shape of `hooks/no-haiku.sh`:

- Header: `# mage:rig/guard/<slug>`, one line on what it blocks, the issue, and `Rung: hook. Skipped: <form> (<reason>), ...`.
- Read stdin once. Source `lib/json.sh` and `lib/report-guard.sh` with the fallbacks those hooks use. For a `gh` command, use `lib/gh-command.sh` (`gh_scan`), not a hand-written regex: it handles prefixes, quoting and `env` wrappers.
- If the input is unreadable, warn on stderr and exit 0. A broken hook must never block everything.
- To block, print `Blocked by rig/guard/<slug>: <why>. <what to do instead>` on stderr, then the guard id line, call `report_guard`, and exit 2. The message is for the agent: it must say how to proceed.

## 6. Test it

Write `hooks/tests/test-<slug>.sh` in the `check()` style of `test-no-haiku.sh`, with these cases:

- every blocked form of the trigger;
- the exception, and a near miss that must pass (the same verb on a different subcommand, the word inside a quoted string);
- junk stdin: exits 0;
- blocking with mage absent (`PATH=/usr/bin:/bin`): exits 2 and prints the guard id line;
- if the hook runs on Codex: a Codex-shaped payload, as in `test-codex-payload.sh`.

Run `bash plugins/rig/hooks/tests/run-all.sh` and paste the summary into the PR.

## 7. Prove it fires live

Unit tests pass a hook that never fires (wrong matcher, wrong path, missing exec bit). From a scratch git repo with no remote, run:

```bash
claude -p "Run exactly: <trigger command>. Reply with the exact error text." \
  --setting-sources project --plugin-dir <worktree>/plugins/rig --allowedTools "Bash(<verb>:*)" \
  --output-format stream-json --verbose | grep -o "Blocked by rig/guard/<slug>"
```

`--setting-sources project` keeps the installed rig plugin out, so a block can only come from the worktree copy. Pick a trigger that is harmless if the hook fails to fire. For Codex, report the live check as pending the operator's trust step; do not bypass hook trust.

## 8. Land it

Branch from `origin/master`, commit the hook, its test, `hooks.json` and `harnesses.json`, and open a draft PR. The body holds:

- the three lines from §1;
- the chosen form, each skipped form with its reason;
- the per-target table from §4;
- the test summary and the live-check line from §7.

Never mark it ready and never install it. The operator merges, then runs `dotfiles/install.sh`.
