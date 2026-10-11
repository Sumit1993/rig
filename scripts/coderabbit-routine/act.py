#!/usr/bin/env python3
"""The routine's one write: act.py <owner/repo> <number> '<comment body>'. It adds the summoned-by marker,
stamped with the earliest time the next slot can open, for the next run's digest to read."""
import sys
from datetime import timedelta

from digest import NOW, SLOT_MIN, marker, request


def main():
    repo, number, body = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    opens = (NOW + timedelta(minutes=SLOT_MIN)).strftime("%Y-%m-%dT%H:%M:%SZ")
    res, _ = request(f"https://api.github.com/repos/{repo}/issues/{number}/comments", {"body": f"{body}\n\n{marker(slot_opens_at=opens)}"})
    print(res["html_url"])


if __name__ == "__main__":
    main()
