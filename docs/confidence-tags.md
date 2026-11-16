# Confidence tags

Every factual claim in `skill/reference.md` carries one of three tags. They exist
because a Lambda fails silently, and because CTM's public docs contain gaps and
internal contradictions.

| Tag | Meaning | How to treat it |
| --- | --- | --- |
| **[DOC]** | Verified in CTM's own documentation on the date the reference was last reviewed. | State it plainly. |
| **[PARTIAL]** | Documented, but with a gap, or two CTM sources disagree. | State it, then name the gap or the disagreement. Do not edit the tag to make it look cleaner. |
| **[UNVERIFIED]** | Working convention observed in practice, not confirmed in docs. | Frame as "in practice" / "test this", never as fact. |

## Why dates matter

CTM's docs drift faster than their version numbers suggest. The main Lambda
article says **Node.js 18.x**; the Global Automation article still says **8.10**.
Both are live pages. The reference records the 18.x figure as current and notes
the stale one rather than silently picking a winner.

When you refresh the reference, update this header line:

> Primary source reviewed: **YYYY-MM-DD**

## Rules for the skill's behaviour

The skill instructs the assistant to:

1. Answer field and helper questions **only** from the reference.
2. Treat a **[PARTIAL]** or **[UNVERIFIED]** line as a reason to say so and offer
   a verification step, rather than a reason to sound confident.
3. **Never upgrade a tag in conversation.** A doc gap does not become a fact
   because it's inconvenient to admit.

This is the single most important property of the skill. An assistant that says
"I'd confirm that with a test call" is useful. One that invents a field name
costs someone an afternoon.

## The verification habit

When a tag is below **[DOC]**, the standard advice is:

- **Test harness** — the Lambda editor runs against a real call. Use it.
- **Log the object** — `console.log(Object.keys(event.activity.custom_fields))`
  answers shape questions in one call.
- **Read back after writing** — `ctm.update()` drops unknown keys silently, so
  `api_get('calls/<id>.json')` after the write is the only proof it landed.

## Current open questions

See the "Known unknowns" section of the top-level README. Each one is a place
where the honest answer is "not documented" — which is a valid answer.
