#!/usr/bin/env python3
"""The routine's one write: act.py <owner/repo> <number> '<comment body>'. It refuses without a fresh digest,
while the digest's slot is still closed, when the PR's head moved since the digest, or when the PR carries
coderabbit_skip, and adds the summoned-by marker stamped with the earliest time the next slot can open."""
import json
import sys
from datetime import datetime, timedelta, timezone

from digest import DIGEST_PATH, SKIP_LABEL, STAMP_S, gh, marker, request, skip_labelled, ts

# The cloud routine and a session's watcher both summon; a stale digest is how two of them spend one slot.
FRESH_MIN = 15


def main():
    repo, number, body = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    try:
        with open(DIGEST_PATH) as f:
            digest = json.load(f)
    except (OSError, ValueError) as e:
        sys.exit(f"no readable digest at {DIGEST_PATH} ({e}); run digest.py first")
    now = datetime.now(timezone.utc)
    if not digest.get("now") or now - ts(digest["now"]) > timedelta(minutes=FRESH_MIN):
        sys.exit(f"digest is older than {FRESH_MIN} min; run digest.py again")
    opens = digest.get("slot_opens_at")
    if opens and ts(opens) > now:
        sys.exit(f"slot opens at {opens}; not summoning")
    pr = next((p for p in digest.get("repos", {}).get(repo, {}).get("pull_requests", []) if p.get("number") == number), None)
    if not pr or not pr.get("head"):
        sys.exit(f"{repo}#{number} is not a candidate in the digest; not summoning")
    live = gh(f"repos/{repo}/pulls/{number}")
    if live["head"]["sha"] != pr["head"]:
        sys.exit(f"{repo}#{number} head moved since the digest; run digest.py again")
    # Labels are read again here: one added after the digest ran still stops the summon (#189).
    if skip_labelled(live.get("labels")):
        sys.exit(f"{repo}#{number} carries {SKIP_LABEL}; not summoning")
    nxt = (now + timedelta(seconds=STAMP_S)).strftime("%Y-%m-%dT%H:%M:%SZ")
    res, _ = request(f"https://api.github.com/repos/{repo}/issues/{number}/comments", {"body": f"{body}\n\n{marker(slot_opens_at=nxt)}"})
    print(res["html_url"])


if __name__ == "__main__":
    main()
