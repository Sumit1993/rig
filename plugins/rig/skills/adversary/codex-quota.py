#!/usr/bin/env python3
"""codex-quota.py check [--json] [--cached]: can Codex take a run now? Exit 0 usable, 1 exhausted, 2 unknown.

Live: the app server's account/rateLimits/read, no model turn. Fallback (or --cached): the newest
rollout's rate_limits, which is only as fresh as the last Codex turn, so the line says how old it is.
"""
import json
import os
import queue
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

CODEX = os.environ.get("RIG_CODEX_BIN", "codex")
HOME = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
TIMEOUT = float(os.environ.get("RIG_CODEX_QUOTA_TIMEOUT", "15"))
NOW = time.time()


def live():
    proc = subprocess.Popen([CODEX, "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, text=True, start_new_session=True)
    lines = queue.Queue()
    threading.Thread(target=lambda: [lines.put(line) for line in proc.stdout], daemon=True).start()
    try:
        # stdin stays open: the server exits on EOF before it answers.
        for msg in ({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"clientInfo": {"name": "rig-codex-quota", "version": "1"}}},
                    {"jsonrpc": "2.0", "method": "initialized"},
                    {"jsonrpc": "2.0", "id": 2, "method": "account/rateLimits/read"}):
            proc.stdin.write(json.dumps(msg) + "\n")
        proc.stdin.flush()
        deadline = time.monotonic() + TIMEOUT
        while time.monotonic() < deadline:
            try:
                line = lines.get(timeout=max(0.1, deadline - time.monotonic()))
            except queue.Empty:
                break
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            if not isinstance(msg, dict) or msg.get("id") != 2:
                continue
            if "error" in msg:
                error = msg["error"]
                raise RuntimeError(f"app-server: {error.get('message', error) if isinstance(error, dict) else error}")
            r = msg.get("result")
            limits = (r.get("rateLimits") or {}) if isinstance(r, dict) else None
            if not isinstance(limits, dict):
                raise RuntimeError("app-server rate-limit answer is malformed")
            return {
                "source": "live",
                "allowed": r.get("ordinaryUsageAllowed"),
                "reached": limits.get("rateLimitReachedType"),
                "plan": limits.get("planType"),
                "windows": [{"used": w.get("usedPercent"), "minutes": w.get("windowDurationMins"), "resets_at": w.get("resetsAt")}
                            for w in (limits.get("primary"), limits.get("secondary")) if w],
            }
        raise RuntimeError("app-server gave no rate-limit answer")
    finally:
        proc.kill()


def find_limits(node):
    if isinstance(node, dict):
        if isinstance(node.get("rate_limits"), dict):
            return node["rate_limits"]
        for value in node.values():
            found = find_limits(value)
            if found:
                return found
    return None


def cached():
    rollouts = sorted(HOME.glob("sessions/**/rollout-*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    for path in rollouts[:5]:
        for line in reversed(path.read_text(errors="replace").splitlines()):
            if "rate_limits" not in line:
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            limits = find_limits(event)
            if not limits:
                continue
            try:
                at = datetime.fromisoformat(event["timestamp"].replace("Z", "+00:00")).timestamp()
            except (KeyError, AttributeError, TypeError, ValueError):
                at = path.stat().st_mtime
            return {
                "source": "cached",
                "age_min": int((NOW - at) // 60),
                "allowed": None,
                "reached": None,
                "plan": limits.get("plan_type"),
                "windows": [{"used": w.get("used_percent"), "minutes": w.get("window_minutes"), "resets_at": w.get("resets_at")}
                            for w in (limits.get("primary"), limits.get("secondary")) if w],
            }
    raise RuntimeError(f"no rate_limits in {HOME}/sessions")


def when(epoch):
    return datetime.fromtimestamp(epoch, timezone.utc).strftime("%Y-%m-%dT%H:%MZ")


def verdict(q):
    for w in q["windows"]:
        if w["resets_at"] and w["resets_at"] <= NOW:
            w["used"] = 0
    full = [w for w in q["windows"] if (w["used"] or 0) >= 100]
    q["exhausted"] = q["allowed"] is False or bool(full)
    q["resets_at"] = max(w["resets_at"] for w in full) if full and all(w["resets_at"] for w in full) else None
    name = {300: "5h", 10080: "weekly"}
    parts = ", ".join(f"{name.get(w['minutes'], str(w['minutes']) + 'm')} {round(w['used'] or 0)}%" for w in q["windows"])
    if q["exhausted"]:
        head = f"exhausted until {when(q['resets_at'])}" if q["resets_at"] else f"exhausted ({q['reached'] or 'usage not allowed'}, reset unknown)"
    else:
        head = "usable"
    tail = f" [from the last session log, {q['age_min']}m old]" if q["source"] == "cached" else ""
    q["line"] = f"{head}: {parts}{tail}"
    return q


def main():
    args = sys.argv[1:]
    if not args or args[0] != "check":
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        return 2
    errors = []
    sources = [cached] if "--cached" in args else [live, cached]
    for source in sources:
        try:
            q = verdict(source())
            break
        except (OSError, RuntimeError, AttributeError, KeyError, TypeError, ValueError) as e:
            errors.append(f"{source.__name__}: {e}")
    else:
        q = {"line": "unknown: " + "; ".join(errors), "exhausted": None}
    print(json.dumps(q) if "--json" in args else q["line"])
    return 2 if q["exhausted"] is None else int(q["exhausted"])


if __name__ == "__main__":
    sys.exit(main())
