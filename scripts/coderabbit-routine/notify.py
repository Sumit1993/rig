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
    if m < 60:
        return f"{m}m"
    if m < 1440:
        return f"{m // 60}h {m % 60}m" if m % 60 else f"{m // 60}h"
    return f"{m // 1440}d {m % 1440 // 60}h"


def item(p, note=""):
    title = (p.get("title") or "")[:70]
    return f"• {link(p)}  {title}" + (f"  _({note})_" if note else "")


def section(head, rows):
    return [f"\n*{head}*", *rows] if rows else []


def summary(d, action):
    prs = [p for r in d["repos"].values() for p in r.get("pull_requests", []) if not p.get("excluded")]
    errors = [f"• {repo}: {r['error'][:120]}" for repo, r in d["repos"].items() if "error" in r]
    errors += [f"• {link(p)}: {p['error'][:120]}" for p in prs if "error" in p]
    ok = [p for p in prs if "error" not in p]
    debt = [p for p in ok if p.get("coderabbit_threads_without_operator_reply")]
    clean = [p for p in ok if p.get("coderabbit_reviewed_head") and not p.get("coderabbit_threads_without_operator_reply")]
    waiting = [p for p in ok if not p.get("coderabbit_reviewed_head")]
    last = d.get("coderabbit_last_review") or {}
    lines = [f"{'⚠️' if errors else '🐇'} *CodeRabbit routine* · {d['now'][11:16]}Z", f">{action}"]
    lines += section("Errors", errors)
    lines += section("Your reply owed", [item(p, f"{n} thread{'s' * (n > 1)}") for p in debt for n in [p["coderabbit_threads_without_operator_reply"]]])
    lines += section("Waiting for review", [item(p, f"head {age(p['head_age_min'])} old") for p in waiting])
    lines += section("Reviewed, nothing owed (check in compass)", [item(p) for p in clean])
    if last.get("age_min") is not None:
        lines.append(f"\n_Last CodeRabbit review {age(last['age_min'])} ago_")
    return "\n".join(lines)


def main():
    try:
        with open(sys.argv[1]) as f:
            text = summary(json.load(f), sys.argv[2])
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        text = f"⚠️ *CodeRabbit routine*: no digest. {sys.argv[2]}"
    url = os.environ.get("SLACK_WEBHOOK_URL")
    if not url:
        print(text)
        sys.exit("SLACK_WEBHOOK_URL is not set; put the summary above in the report instead")
    req = urllib.request.Request(url, json.dumps({"text": text}).encode(), {"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            print(resp.status)
    except OSError as e:
        print(text)
        sys.exit(f"Slack post failed: {e}")


if __name__ == "__main__":
    main()
