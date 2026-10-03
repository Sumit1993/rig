#!/usr/bin/env python3
"""alert.py '<text>': post one line to the operator's Slack through the SLACK_WEBHOOK_URL incoming webhook."""
import json
import os
import sys
import urllib.request

url = os.environ.get("SLACK_WEBHOOK_URL")
if not url:
    sys.exit("SLACK_WEBHOOK_URL is not set; report the alert text instead")
req = urllib.request.Request(url, json.dumps({"text": sys.argv[1]}).encode(), {"Content-Type": "application/json"})
with urllib.request.urlopen(req, timeout=20) as resp:
    print(resp.status)
