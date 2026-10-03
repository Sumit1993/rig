#!/usr/bin/env python3
"""notify.py <digest.json> '<this run's action line>': post the run's summary to Slack (SLACK_WEBHOOK_URL).

The action line is the model's; every other section is computed here from the digest, so the
lists can't drift from the facts (Sumit1993/rig#164).
"""
import json
import os
import sys
import urllib.request


def link(p):
    return f"<https://github.com/{p['repo']}/pull/{p['number']}|{p['repo'].split('/')[1]}#{p['number']}>"


def age(m):
    return f"{m}m" if m < 60 else f"{m // 60}h"


def summary(d, action):
    prs = [p for r in d["repos"].values() for p in r.get("pull_requests", []) if not p.get("excluded")]
    errors = [f"{repo}: {r['error'][:120]}" for repo, r in d["repos"].items() if "error" in r]
    errors += [f"{link(p)}: {p['error'][:120]}" for p in prs if "error" in p]
    ok = [p for p in prs if "error" not in p]
    debt = [p for p in ok if p.get("coderabbit_threads_without_operator_reply")]
    clean = [p for p in ok if p.get("coderabbit_reviewed_head") and not p.get("coderabbit_threads_without_operator_reply")]
    waiting = [p for p in ok if not p.get("coderabbit_reviewed_head") and not p.get("docs_only")]
    last = d.get("coderabbit_last_review") or {}
    lines = [f"{'⚠️' if errors else '🐇'} *CodeRabbit routine* {d['now'][11:16]}Z: {action}"]
    if errors:
        lines.append("*Errors:* " + "; ".join(errors))
    if debt:
        lines.append("*Your reply owed:* " + ", ".join(f"{link(p)} ({p['coderabbit_threads_without_operator_reply']})" for p in debt))
    if clean:
        lines.append("*Reviewed, nothing owed (check in compass):* " + ", ".join(link(p) for p in clean))
    if waiting:
        lines.append("*Waiting for review:* " + ", ".join(f"{link(p)} ({age(p['head_age_min'])})" for p in waiting))
    if last.get("age_min") is not None:
        lines.append(f"Last CodeRabbit review {last['age_min']} min ago.")
    return "\n".join(lines)


def main():
    try:
        text = summary(json.load(open(sys.argv[1])), sys.argv[2])
    except (OSError, ValueError, KeyError):
        text = f"⚠️ *CodeRabbit routine*: no digest. {sys.argv[2]}"
    url = os.environ.get("SLACK_WEBHOOK_URL")
    if not url:
        print(text)
        sys.exit("SLACK_WEBHOOK_URL is not set; put the summary above in the report instead")
    req = urllib.request.Request(url, json.dumps({"text": text}).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        print(resp.status)


if __name__ == "__main__":
    main()
