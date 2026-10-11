#!/usr/bin/env python3
"""The routine's one write: act.py <owner/repo> <number> '<comment body>'. It waits for the slot the digest
reported, then adds the summoned-by marker stamped with the earliest time the next slot can open."""
import json
import sys
import time
from datetime import datetime, timedelta, timezone

from digest import DIGEST_PATH, STAMP_S, WAIT_MAX_S, marker, request, ts


def slot_opens_at():
    try:
        with open(DIGEST_PATH) as f:
            return json.load(f).get("slot_opens_at")
    except (OSError, ValueError):
        return None


def main():
    repo, number, body = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    opens = slot_opens_at()
    if opens:
        wait = (ts(opens) - datetime.now(timezone.utc)).total_seconds()
        if wait > WAIT_MAX_S:
            sys.exit(f"slot opens at {opens}; not summoning")
        time.sleep(max(wait, 0))
    nxt = (datetime.now(timezone.utc) + timedelta(seconds=STAMP_S)).strftime("%Y-%m-%dT%H:%M:%SZ")
    res, _ = request(f"https://api.github.com/repos/{repo}/issues/{number}/comments", {"body": f"{body}\n\n{marker(slot_opens_at=nxt)}"})
    print(res["html_url"])


if __name__ == "__main__":
    main()
