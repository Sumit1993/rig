---
name: lane
description: "Scripts that fold several agy tool calls into one: run a check to completion with a short result, commit with SHA and stat. Load when working a delegated work order headless (agy -p)."
metadata:
  version: "0.1.0"
---

# Lane kit

agy shows at most about 4 KB of a command's output, so these print short results and keep the full log on disk.

| Need | One call |
| --- | --- |
| Run a test, typecheck or build to the end | `~/.gemini/config/plugins/rig/skills/lane/scripts/run.sh "<cmd>"` with `WaitMsBeforeAsync` 600000 |
| Commit | `~/.gemini/config/plugins/rig/skills/lane/scripts/commit.sh "<message>" [paths...]` |

`run.sh` prints `rc=`, then 8 lines on success, or the failure lines and a 25-line tail. Read the full log with `view_file` only if that is not enough.
