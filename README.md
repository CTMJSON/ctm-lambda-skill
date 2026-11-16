# ctm-lambda

An agent skill for writing, debugging and explaining **CallTrackingMetrics Lambda
functions** — the Node.js code CTM runs when an activity changes or a call is
being routed.

Clone it, run one script, and your AI assistant stops guessing about Lambda APIs.

```bash
git clone https://github.com/CTMJSON/ctm-lambda-skill.git
cd ctm-lambda-skill
bash install.sh
```

That's it. Works with Chatbox and Claude Code; safe to re-run.

---

## Why this exists

A Lambda fails **silently**. A misspelled field is `undefined`. An unknown
`ctm.update()` key is dropped with no error. A missing `context.done()` leaves a
live caller listening to silence. There is no stack trace to hand back to you,
and the editor's 15-second budget can be gone before you notice.

That means a confident-sounding wrong answer is expensive: you paste it, test it
on a real call, and discover the field never existed. This skill is built around
one rule — **prefer a verified fact over a plausible guess.**

## What it does

When your assistant is asked to write or debug a Lambda, it gets:

- **A quick reference** — runtime, limits, the correct handler shape, every
  `context.ctm` helper and the routing result object.
- **The five failure modes that actually break lambdas**, each with the fix.
- **Field guidance** — which activity fields exist, and the traps
  (`caller_number` is not E.164, `tag_list` overwrites, form answers live on the
  form, not the activity).
- **Confidence tagging** — every claim in the reference is marked **[DOC]**
  (verified in CTM's own docs), **[PARTIAL]** (documented with gaps, or sources
  disagree) or **[UNVERIFIED]** (convention, not confirmed). The skill is
  instructed never to upgrade a tag mid-conversation, so you get "I'd confirm
  that" instead of an invented method name.
- **Working integration snippets** — Salesforce, HubSpot, Zoho, Dynamics, plus a
  generic webhook poster and a conditional router.

## Example

> **You:** Use the ctm-lambda skill to write a router that sends calls tagged
> `vip` to queue `QUE123` and everything else to `QUE456`.

You get a complete, paste-ready script — not a fragment — that:

- reads `event.activity.tag_list`,
- calls `context.done(null, {route})` on **every** path including `catch`,
- falls back to a default route if anything throws,
- puts the destination IDs in named constants at the top.

## Install options

```bash
bash install.sh              # every runtime found on this machine
bash install.sh --chatbox    # Chatbox only
bash install.sh --claude     # Claude Code only
bash install.sh --check      # show what is installed, change nothing
bash install.sh --dry-run    # print what would happen
```

| Runtime | Installed to |
| --- | --- |
| Chatbox | `~/Library/Application Support/CTMChat/skills/ctm-lambda/` |
| Claude Code | `~/.claude/skills/ctm-lambda/` |

The script validates `SKILL.md` frontmatter before copying (name + description
present, under 1024 characters) so a malformed skill never lands in your runtime.
Existing installs are backed up to `<dir>.bak.<timestamp>` before being replaced.

Both apps read skills at startup — if the skill doesn't show up, restart the app
or start a new session.

## Verify it worked

Ask your assistant:

> Use the ctm-lambda skill to write a routing lambda.

It should reference the 15-second limit and `context.done()`. If it instead
invents fields or hands you a snippet, the skill didn't load.

## Repo layout

```
skill/
  SKILL.md       # the decision layer: triggers, failure modes, before-you-answer rules
  reference.md   # the full spec, with confidence tags
install.sh       # validates and installs into each runtime
docs/
  confidence-tags.md   # what [DOC] / [PARTIAL] / [UNVERIFIED] mean
  contributing.md      # how to correct the skill without breaking it
```

## Sources

Everything in `reference.md` traces to CTM's public support documentation, read
2026-11-16:

- [CTM Lambda Functions](https://calltrackingmetrics.zendesk.com/hc/en-us/articles/6603700875661-CTM-Lambda-Functions)
- [CTM Data Dictionary](https://calltrackingmetrics.zendesk.com/hc/en-us/articles/41854590297357-CTM-Data-Dictionary)
- [Global Automation](https://calltrackingmetrics.zendesk.com/hc/en-us/articles/9469269539213-Global-Automation)
- [Call Routing](https://calltrackingmetrics.zendesk.com/hc/en-us/articles/25005269018253-Call-Routing)
- [Custom Actions](https://calltrackingmetrics.zendesk.com/hc/en-us/articles/6351460453389-Custom-Actions)
- [IP Addresses Allow List](https://calltrackingmetrics.zendesk.com/hc/en-us/articles/28294806087821-IP-Addresses-Allow-List)

No CTM customer data, account IDs, credentials or internal endpoints are in this
repo. `reference.md` is public documentation plus analysis.

## Known unknowns

These are **not** answered by public docs. The skill deliberately declines to
guess at them — see `docs/contributing.md` if you can close one:

- `context.ctm.score()` — what the third argument means
- `context.ctm.ask()` — whether transcription must be enabled, whether the call
  must have ended, cost and limits
- `context.http_*` — whether non-2xx throws or returns a status to check
- The `event.activity.digits` / `context_state` path on a second gather pass
- Contents of the `+Add Packages` dropdown, and the `Request Package` process
- ID prefixes for routable objects beyond `VMI…` / `QUE…` / `USR…`
- How long the editor retains runtime logs

## License

MIT — see [LICENSE](LICENSE).
