---
name: tweet
description: "Load when the user says \"/tweet\", \"tweet this\", \"this is tweetable\", or asks to share a finding or idea from the session on X/Twitter."
metadata:
  version: "1.0.0"
---

# Tweet drafting

First fetch live context from the X Context Provider n8n workflow (voice spec, recent posts for dedup, current trending). The token file defaults to `~/.claude/secrets/x-context-token`; `X_CONTEXT_TOKEN_FILE` overrides it. The call needs network access.

```bash
curl -sf -m 30 -H "X-Context-Token: $(cat "${X_CONTEXT_TOKEN_FILE:-$HOME/.claude/secrets/x-context-token}")" "https://n8n.sfun.cloud/webhook/x-context-73826577" | jq '{voice, recentSummary, mentionsProductRecently, trendingSummary, historyFreshAt}'
```

If the fetch fails, draft without the voice and dedup checks, and tell the operator they were skipped.

## 1. Gather the material

If the user pointed at a specific thing ("tweet about X"), use that. Otherwise review, in order, and pick the most tweet-worthy item:

1. The current conversation, for what this session built or discovered.
2. `git log --oneline -10` in the current repo, for what shipped recently.

Tweet-worthy means surprising, concrete and useful to other builders; leave out routine chores, private details and secrets.

## 2. Draft

Follow the fetched `voice` spec EXACTLY. It is the single source of truth, edited only in the n8n workflow, never here. Apply the fetched dedup rules:

- Do not repeat any joke, phrasing, or theme visible in `recentSummary`.
- If `mentionsProductRecently` is true, no mage-memory mention in any option.
- `trendingSummary` is optional inspiration. One option MAY riff on a current moment if it fits the session material.

Produce 2-3 options, each ≤280 chars (count it), each a distinct angle (the gotcha, the what-I-built, the human moment). Show them as plain text blocks.

## 3. Hand off

After the user picks (or edits) a draft, open X's compose window pre-filled:

```bash
URL=$(python3 -c "import urllib.parse,sys; print('https://twitter.com/intent/tweet?text='+urllib.parse.quote(sys.argv[1]))" 'TWEET TEXT HERE')
explorer.exe "$URL"
```

Posting is the operator's step. NEVER post via the X API. The intent URL is free.
