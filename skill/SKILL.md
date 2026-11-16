---
name: ctm-lambda
description: "Use when writing, debugging, reviewing or explaining a CTM Lambda function (Node.js code in Flows > Lambdas), or when answering customer questions about event.activity fields, context.ctm helpers, routing with context.done, http_get/http_post, npm packages or integration tokens in a lambda. Triggers: lambda returning wrong route, caller hears silence, context.done, context.ctm.score, ctm.update not saving, tag_list overwritten, custom_fields undefined, digits/context_state gather, Salesforce/HubSpot/Zoho/Dynamics lambda, Lambda Action route."
---

# CTM Lambda functions

Author and debug the Node.js code CTM runs when an activity changes or a call is
being routed. The customer pastes code into a web editor and tests it against a
real call — there is no local build step, no deploy, and no stack trace to hand
back to you.

**Core principle: a lambda fails silently.** A misspelled field is `undefined`, an
unknown `update()` key is ignored, and a missing `context.done()` leaves a live
caller in silence. Prefer a fact you verified over a plausible-looking guess.

## Quick reference

| Thing | Value |
|---|---|
| Runtime | Node.js 18.x, 256 MB, **15 seconds total** |
| Plans | Sales Engage, Enterprise, Connect |
| Editor | Flows → Lambdas (+Add Packages / +Add Variable / +Add Credentials) |
| Handler | `exports.handler = async (event, context) => {}` |
| Activity | `event.activity` |
| Route result | `context.done(null, {route, say, whisper, gather})` |
| CTM API | `context.ctm.api_get('calls.json')` — account prefix added for you |
| External | `context.http_post(url, JSON.stringify(body), headers)` |

## The 5 failure modes that actually happen

Everything else is detail. These five account for most broken lambdas.

1. **`data` is a JSON string, not an object.** Parse it.
   ```js
   const data = JSON.parse(res.data || res.responseBody || '{}');
   ```
2. **No `context.done()` on a routing lambda.** Every path must return one,
   including `catch`. A throw = silence for the caller.
3. **`ctm.update()` accepted nothing and said nothing.** Unknown keys are dropped
   without error. Read the record back with `api_get` to confirm a write landed.
   Never write `id`.
4. **`tag_list` overwrites instead of appending.** It is a comma-separated string,
   lowercased on write. Read → append → write the whole list.
5. **15 seconds is the whole budget.** No documented per-HTTP-call timeout; one
   slow vendor burns the invocation and the call falls through routing.

## Before you answer

Classify the question, because the safe answer differs:

| Question | Do this |
|---|---|
| What field/helper exists | Answer from `reference.md` only |
| What does this argument mean | If `reference.md` marks it **[PARTIAL]** or worse, say so and give the test-harness check |
| Why is it broken | Ask for the log output, or have them log `Object.keys(activity.custom_fields)` / the whole `event` on one test call |
| Will it work | Do not promise. Name the limit (15 s, credentials granted, runtime) and let the test harness decide |

`reference.md` tags every line **[DOC]** (verified in CTM docs), **[PARTIAL]**
(documented with gaps, or sources disagree), or **[UNVERIFIED]** (convention).
**Do not upgrade a tag in conversation.** "I'm not sure, here's how to check" is
a correct answer; an invented field name is not.

## Attribution

Customers fix CTM-side configuration themselves in the self-service platform.
Attribute work by where it happens — "your website code", "the destination API",
"the Lambda editor in your CTM account" — never by promising CTM will build it,
and never claiming it "requires nothing on your end."

## Writing the answer

- Give the **complete script**, ready to paste, not a fragment.
- Put every customer-specific value in a `const` at the top, named for what it is.
- Include `try/catch` and a default route in every routing example.
- State the 15-second limit whenever the code calls an external API.
- Explain in plain language what the script does and where to install it.
- Keep account data and tokens out of logs and out of the reply.

## Two-pass gather

The only non-obvious control flow. First invocation returns a gather; CTM calls
the **same lambda again** with the caller's answer:

```js
if (event.activity.context_state === 'ask_product') {
  const digits = event.activity.digits;   // [PARTIAL] path: log `event` to confirm
} else {
  context.done(null, {
    say: 'Press 1 if interested, 2 if not.',
    gather: {finishOnKey: '#', numDigits: 1, timeout: 15, state: 'ask_product'}
  });
}
```

The KB shows the values exist but never a code sample of the second pass, so log
the full `event` on the first live test rather than trusting the path.

## Common mistakes

| Mistake | Fix |
|---|---|
| Passing an object as the HTTP body | `JSON.stringify` first |
| Headers in the wrong position | 3rd arg on post/patch/put, 2nd on get |
| Assuming `caller_number` is E.164 | Use `caller_number_complete` (has `+`) or `caller_number_bare` |
| Treating `activity.custom_fields` as flat | Typed sub-objects also circulate; log the keys for that account |
| Reading form answers off the activity | `activity.form.email`, `activity.form.custom.<field>` |
| Using `callback` | Write `async`; `callback` is legacy |
| Logging an integration token | Never log tokens, even truncated |
| Guessing a destination ID prefix | Only `VMI…`/`QUE…`/`USR…` are published — look others up via `api_get` |
| Adding an agency-wide lambda to fix one account | Global lambdas hit every sub-account and cannot be scoped |

## Reference

`reference.md` in this directory is the full spec: handler signature, every
`context.ctm` helper, activity fields from the CTM Data Dictionary, routing result
shape, trigger points, packages/credentials, the Lambda IP allow-list, integration
snippets, and an open-questions list.

Read it before answering anything about a specific field, argument, or helper.
