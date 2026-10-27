#!/usr/bin/env python3
"""The routine's one write: act.py <owner/repo> <number> '<comment body>'. It refuses while the digest's slot is
still closed or the PR carries coderabbit_skip, and adds the summoned-by marker stamped with the earliest time
the next slot can open."""
import json
import sys
from datetime import datetime, timedelta, timezone

from digest import DIGEST_PATH, SKIP_LABEL, STAMP_S, gh, marker, request, skip_labelled, ts


def main():
    repo, number, body = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    try:
        with open(DIGEST_PATH) as f:
            opens = json.load(f).get("slot_opens_at")
    except (OSError, ValueError):
        opens = None
    now = datetime.now(timezone.utc)
    if opens and ts(opens) > now:
        sys.exit(f"slot opens at {opens}; not summoning")
    # Labels are read again here: one added after the digest ran still stops the summon (#189).
    if skip_labelled(gh(f"repos/{repo}/issues/{number}/labels?per_page=100")):
        sys.exit(f"{repo}#{number} carries {SKIP_LABEL}; not summoning")
    nxt = (now + timedelta(seconds=STAMP_S)).strftime("%Y-%m-%dT%H:%M:%SZ")
    res, _ = request(f"https://api.github.com/repos/{repo}/issues/{number}/comments", {"body": f"{body}\n\n{marker(slot_opens_at=nxt)}"})
    print(res["html_url"])


if __name__ == "__main__":
    main()
