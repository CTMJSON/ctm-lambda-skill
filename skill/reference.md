# CTM Lambda Functions — Developer Reference

> Scope: this is the **internal** reference used to keep our Lambda helper answers accurate.
> Every claim below is marked **[DOC]** (verified against CTM support docs on 2026-11-16),
> **[PARTIAL]** (documented but with gaps/sources that disagree), or **[UNVERIFIED]**
> (observed convention, not confirmed in CTM docs — do not state these as fact to a customer).
>
> Primary source: <https://calltrackingmetrics.zendesk.com/hc/en-us/articles/6603700875661-CTM-Lambda-Functions>

---

## 1. What a Lambda is

Custom Node.js code that runs inside CTM when something happens on an activity, or when a call is being routed.

Three ways to use one, set by the Lambda's **Type** field: **[PARTIAL]**

| Type | Purpose | How it is invoked |
|---|---|---|
| `Trigger` | Run side-effect logic when an activity changes | A trigger's **Run Lambda Function** action |
| `Route` | Decide where a call goes | Tracking number **Dial Route → Lambda Action**, Voice Menu, or Smart Router |
| `Panel` | Collect/return data for people (custom UI) | Operator action in the UI |

**[PARTIAL]** The Type field and its three values are documented on the *Global Automation* article, not on the main Lambda article. Treat the exact labels as writer's guidance and confirm in-app before quoting.

### Runtime limits

- **Node.js 18.x** **[PARTIAL]** — the main product KB article (last reviewed by CTM 2022-06-01) says 18.x. The older *Global Automation* article still says **Node.js v8.10**, which is stale. Use 18.x; note that library availability differs between the two.
- **256 MB** memory **[DOC]**
- **15 seconds** execution **[DOC]** — this is the hard ceiling for *everything*, including external HTTP calls.
- Plan gating: Sales Engage, Enterprise, and Connect. **[DOC]** (Global Automation lambdas additionally require Sales Engage or Connect.)

---

## 2. Handler signature

```js
exports.handler = async (event, context, callback) => {
  // ...
};
```

**[PARTIAL]** The KB shows two forms: `(event, context)` in the simple example and
`(event, context, callback)` in the integration examples. The `callback` argument is legacy
Node-style plumbing. **Use `async` and return / `await` — do not use `callback` in new code.**
It is not documented that returning a value does anything for trigger lambdas, so for routing
the only supported way to hand back a decision is `context.done()`.

### `event`

| Property | Meaning | Status |
|---|---|---|
| `event.activity` | The call, text, chat, form, or fax that triggered the function | [DOC] |
| `event.id` | A reference to this lambda function | [DOC] |
| `event.options` | Extra inputs collected by the caller (e.g. custom action options) | [DOC] (shape not documented) |
| `event.salesforce.token`, `.instanceUrl` | OAuth token + org URL | [DOC] |
| `event.zoho.token`, `.api_domain` | OAuth token + API domain | [DOC] (`api_domain` used in the KB Zoho sample) |
| `event.hubspot.token` | OAuth token | [DOC] |
| `event.dynamics.token`, `.api_domain` | OAuth token + server URL | [DOC] |
| `event.googleads` | `{apiVersion, developerToken, accounts:[{token, customerId, loginCustomerId}]}` | [DOC] — only present when **Google Ads** is added under the Lambda's **Credentials** |
| `event.cap_token` | Internal — do not use | [UNVERIFIED] |

Integration tokens only appear once the matching integration is added under the Lambda's
**Credentials** section. **[DOC]** for Google Ads explicitly; the same "add credentials" step is
documented for Salesforce, Zendesk, Zoho and HubSpot on the Global Automation article. **[PARTIAL]**

---

## 3. `event.activity` fields

The activity is the raw CTM activity record. Authoritative field list: **CTM Data Dictionary**
(<https://calltrackingmetrics.zendesk.com/hc/en-us/articles/41854590297357-CTM-Data-Dictionary>).

Commonly needed fields **[DOC]**:

`id`, `name`, `email`, `street`, `city`, `state`, `country`, `postal_code`,
`caller_number`, `caller_number_complete`, `caller_number_format`, `caller_number_bare`,
`contact_number`, `tracking_number`, `tracking_number_bare`, `direction`, `duration`,
`ring_time`, `talk_time`, `hold_time`, `left_talk_time`, `right_talk_time`,
`called_at`, `unix_time`, `source`, `source_id`, `campaign`, `search`, `referrer`,
`tag_list`, `notes`, `audio`, `transcription`, `transcription_text`,
`excluded`, `redacted`, `is_new_caller`, `agent`, `agent_id`, `legs`, `call_path`, `transfers`,
`ga` (utmz/utma/utmb/utmc/medium/campaign/cid/gclid), `webvisit`, `visitor`.

Field notes that trip people up:

- **Time units are seconds.** `duration`, `ring_time`, `talk_time`, `hold_time` are integers in seconds. **[PARTIAL]** — the Data Dictionary says "integer" and the activity list reports ring/talk/total time in seconds, but the article never states the unit explicitly.
- **`direction`** is the string `inbound` or `outbound`. **[DOC]**
- **Caller number formats differ by field.** Use `caller_number_complete` for E.164 with `+`, `caller_number_bare` for digits only, `caller_number` for display formatting. **[DOC]** — do not assume `caller_number` has a leading `+`; normalise before sending to an API.
- **`tag_list` is an array on the activity but a comma-separated string when you write it back.** **[DOC]** It **overwrites** all existing tags, so read-modify-write. Tags are always lowercase.
- **IVR input lives at `activity.inputs.menu_inputs`** (and `inputs.geo_inputs` for Geo Router keypresses). **[DOC]** — the lambda routing example reads `call.digits` on the *second* invocation of a gather; both exist, for different contexts (see §6).
- **Custom fields are split by type**, not flat: `custom_fields.strings`, `.numbers`, `.floats`, `.dates`, `.pickers`, `.bools`. **[DOC]**

### `activity.custom_fields` vs `activity.form.custom`  **← biggest source of confusion**

- `activity.custom_fields.<field>` — custom fields on the **activity/contact record** (the CRM-ish fields on the call).
- `activity.form.custom.<field>` — the answers captured by a **FormReactor form** fill-out.
- `activity.form.email` — an email submitted on a form, distinct from `activity.email`.

**[PARTIAL]** The typed sub-objects (`custom_fields.strings`, etc.) and the flat
`custom_fields.<name>` shorthand both appear across CTM material, and the instruction set we were
given uses the flat form (`event.activity.custom_fields.intro_pause`). **Guidance: read the typed
sub-object and fall back to the flat property**, or log `Object.keys(activity.custom_fields)` once
to see what that account actually receives. Never assert one shape to a customer without checking.

Do not assume a field is custom just because it is not in the list above — check the Data Dictionary first.

---

## 4. `context`

### 4.1 CTM API helpers

`context.ctm.api_get(path)`, `api_post(path, data)`, `api_patch(path, data)`,
`api_put(path, data)`, `api_delete(path, data)`. **[DOC]**

The `https://api.calltrackingmetrics.com/api/v1/accounts/{{account_id}}/` prefix is
**added automatically** — pass only the remainder, e.g. `await context.ctm.api_get('calls.json')`. **[DOC]**

This means a lambda can only ever touch its own account. **[PARTIAL]** — the prefix behaviour is
documented; cross-account scoping follows from it but is not stated as a security guarantee.

### 4.2 Scoring and updating

```js
await context.ctm.score('reportTag', 5, 400, true, new Date());
await context.ctm.update({name: 'First Last', email: 'x@example.com', custom_fields: {user_field1: 'xyz'}});
```

**[PARTIAL]** `score()` arguments: arg1 `reportTag` (the reporting tag / conversion name),
arg2 `5` (score), arg3 `400` (the KB's third example value is interpreted in context as the
reported value/dollar amount), arg4 `true` (converted flag), arg5 `Date` (conversion date).
Arg3's exact semantic is **not documented** — the KB only ever shows `score("Hot", 5, 80, ...)`
"if the weather is above 80". **Do not explain arg3 to a customer without confirming it in-app.**

**[DOC]** `ctm.update()` writes activity/contact fields. **The `id` is never updated.** Passing an
unknown key silently does nothing rather than erroring, so changes can fail quietly — read the
record back (`api_get`) to confirm a write landed.

### 4.3 `context.ctm.ask()`

```js
const email = await context.ctm.ask('What was the email address the caller provided?');
if (email) await context.ctm.update({email});
```

**[DOC]** exists and answers questions about the activity record using AI. The KB's own framing:
"generate code that calls an AI function to answer questions about the activity record".

**Open questions — do not assert:** whether it needs transcription enabled, whether the call must
have ended first, model used, cost, and length limits. In practice, ask-about-transcript style
lambdas are attached to triggers such as *When transcription is ready* or *At the end of a
call/form/chat, once all data has been captured* — those triggers are the safe place to call it.
**[UNVERIFIED]**

### 4.4 HTTP helpers

```js
const {request, response, data} = await context.http_get(url);                      // headers as 2nd arg
const {request, response, data} = await context.http_post(url, body, headers);       // headers as 3rd arg
```

Also `http_patch`, `http_put`, `http_delete` with the same `(url, body, headers)` shape. **[DOC]**

Traps:

- **`data` is a string, not an object.** The KB's own Google Ads example does
  `JSON.parse(response.data || response.responseBody)`. So: always `JSON.parse(...)` when you expect JSON,
  and it may come back on `response.data` *or* `response.responseBody` depending on path. **[DOC]**
- **Check the status yourself.** The documented return includes a `response` object, so treat
  non-2xx as something you must inspect (`response.status`) rather than assuming a throw. Wrap in
  `try/catch` anyway. **[PARTIAL]** — the KB never explicitly documents whether non-2xx throws.
- `body` must already be a string — `JSON.stringify(payload)` before calling, and send
  `{'Content-Type': 'application/json'}`.
- **No per-request timeout is documented.** The 15 s lambda ceiling is your budget; a slow vendor
  API can burn the whole invocation and the call may fall through routing with no result.

### 4.5 `context.done()`

**[DOC]** Signal completion explicitly when you are not using `async`/`await`, and the only way to
return a **routing decision**:

```js
context.done(null, {route: 'USRxyz'});
```

If you use promises, call `context.done()` from the promise completion, otherwise the function can
be terminated before the async work returns.

---

## 5. Voice routing return shape

**[DOC]** The second argument to `context.done()` accepts:

| Key | Effect |
|---|---|
| `route` | Where to send the caller — a destination ID or a phone number |
| `say` | Text to speak to the caller before/while routing |
| `whisper` | Text whispered to the receiving destination when it answers |
| `gather` | Collect keypresses: `{finishOnKey, numDigits, timeout, state}` |

Destination IDs are CTM object IDs with a type prefix — the KB names
**`VMI…` (voice menu), `QUE…` (call queue), `USR…` (agent)**. **[DOC]**
Receiving numbers are passed as the dialable number (`dial_number` in the KB sample). **[DOC]**

Other routable objects exist as tracking-number dial routes — Geo Router, Smart Router, Routing
Table, Dial Directory, Voicemail, VoiceAI, Dialogflow — but **the KB does not publish their ID
prefixes**, so do not invent them. Look the ID up via `api_get` on the relevant endpoint, or use
the receiving number. **[PARTIAL]**

### Two-pass gather

First pass returns a gather; CTM calls the lambda **again** with the caller's response:

```js
// first invocation
const context_state = 'ask_product';
context.done(null, {say: 'Press 1 if interested, 2 if not.', gather: {finishOnKey: '#', numDigits: 1, timeout: 15, state: context_state}});

// second invocation — same lambda, now has the answer
if (event.activity.context_state === 'ask_product') {
  const digits = event.activity.digits;
}
```

**[PARTIAL]** The KB text says the function is called again "with both `call.context_state` …
and the `call.digits`". Whether those hang off `event.activity` or a differently-named object is
**not shown in a code sample**. Use `event.activity.context_state` / `event.activity.digits` as
the working assumption and verify by logging the whole `event` on a test call.

**Routing lambdas must always call `context.done()` on every code path**, including inside
`catch`. A lambda that throws or never completes leaves the caller in silence.

---

## 6. Where a Lambda can be triggered

**[DOC]** unless marked.

- **Triggers** — `Flows → Triggers → Add Action → Run Lambda Function`. Trigger types include: call/text received or sent, agent answers, agent transfers, website session associated, caller hangs up early, contact panel updated, call ends immediately, end of call/form/chat once data captured, 1 hour after data captured (GA), sale data updated, FormReactor created, PPC/cost data retrieved, Geo Router keypress, keyword spotted, audio accessed, new agent assigned, **transcription ready**.
- **Custom Actions** — `Settings → Custom Actions → Add Action → Actions → Run Lambda function`. Buttons on the softphone / call log; tick **Live Calls** to expose mid-call. This is where `event.options` comes from.
- **Routing** — tracking number **Dial Route → Lambda Action**; Voice Menu; Smart Router.
- **Global Automation** — `Flows → Global Automation → Lambdas`, fires from Global triggers, applies to **every sub-account in the agency** and **cannot** be scoped to individual sub-accounts. Also supports Ruby.

---

## 7. Packages, environment variables, credentials

**Environment variables** — `+Add Variable`, name + value; referenced as `process.env.NAME`. **[PARTIAL]** (UI documented, `process.env` access not shown in a sample).

**Credentials** — `+Add Credentials` and pick an integration; this is what populates the matching
`event.<integration>` object. Documented options: **Salesforce, Zendesk, Zoho, HubSpot**, plus **Google Ads**. **[PARTIAL]** — the Global Automation list predates the Google Ads section, so treat the list as open-ended and check the dropdown in-app.

**Packages** — `+Add Packages` selects from a curated dropdown; **Request Package** opens a
search-and-add dialog for anything else. **[DOC]** Confirmed-loadable from CTM's own samples:
`jsforce`, `@hubspot/api-client`, `dynamics-web-api`. **[DOC]**
Others (`axios`, `node-fetch`, `lodash`) are **not confirmed** — Node 18 has global `fetch` and
`JSON`, which covers most needs, and `context.http_*` already exists. **[UNVERIFIED]**

**Debugging** — the editor has a **test harness: pick a specific call and run**. Set the mode to
**Debug** to capture runtime log data for easier debugging. **[DOC]**
Log with `console.log(...)`. Retention period is not documented.

---

## 8. Security & networking

- The `api_*` helpers are account-scoped by the implicit `accounts/{{account_id}}/` prefix. **[DOC]**
- **Egress is not restricted to an allow-list** — the KB's own examples call
  `googleads.googleapis.com` and arbitrary `api.your-service.com` endpoints. **[PARTIAL]**
- **Customers that whitelist inbound traffic need our Lambda IPs** **[DOC]**:
  - US: `54.156.32.215`, `52.22.47.232`
  - EU: `35.157.125.228`, `3.76.18.20`
  (Webhooks use a different, larger set — don't mix them up.)
- **Never log tokens.** CTM explicitly warns for Google Ads to not log or expose `token` /
  `developerToken`. Apply the same rule to every integration token.
- Env vars are the right home for API keys; do not hard-code secrets in the code box.

---

## 9. Integration snippets

### Salesforce
```js
const jsforce = require('jsforce');

exports.handler = async (event, context) => {
  const conn = new jsforce.Connection({
    instanceUrl: event.salesforce.instanceUrl,
    accessToken: event.salesforce.token
  });
  const result = await conn.sobject('Lead').create({
    LastName: event.activity.name || 'Unknown',
    Phone: event.activity.caller_number_complete,
    Email: event.activity.email
  });
  console.log('Salesforce lead:', result.id);
  await context.ctm.update({custom_fields: {strings: {salesforce_id: result.id}}});
};
```

### HubSpot
```js
const hubspot = require('@hubspot/api-client');

exports.handler = async (event, context) => {
  const client = new hubspot.Client({accessToken: event.hubspot.token});
  const res = await client.crm.contacts.searchApi.doSearch({
    filterGroups: [{filters: [{propertyName: 'phone', operator: 'EQ', value: event.activity.caller_number_bare}]}],
    properties: ['email', 'phone', 'firstname', 'lastname'],
    limit: 10
  });
  console.log('HubSpot hits:', res.results ? res.results.length : 0);
};
```

### Zoho
```js
class Zoho {
  constructor(event, context) { this.context = context; this.event = event; }
  get(path) {
    return this.context.http_get(`${this.event.zoho.api_domain}${path}`, this.headers());
  }
  headers() {
    return {Authorization: `Zoho-oauthtoken ${this.event.zoho.token}`, 'Content-Type': 'application/json'};
  }
}

exports.handler = async (event, context) => {
  const client = new Zoho(event, context);
  const modules = await client.get('/crm/v2/settings/modules');
  console.log(JSON.stringify(modules.data).slice(0, 500));
};
```

### Dynamics
```js
const DynamicsWebApi = require('dynamics-web-api');

exports.handler = async (event, context) => {
  const api = new DynamicsWebApi({
    serverUrl: event.dynamics.api_domain,
    headers: {Authorization: `Bearer ${event.dynamics.token}`}
  });
  const contacts = await api.retrieveMultipleRecords('contact', '?$select=fullname,emailaddress1&$top=1');
  console.log(contacts.value);
};
```

### Generic: post the activity to your own endpoint
```js
exports.handler = async (event, context) => {
  const activity = event.activity || {};
  const payload = {
    id: activity.id,
    direction: activity.direction,
    caller: activity.caller_number_complete || activity.caller_number,
    tracking_number: activity.tracking_number,
    source: activity.source,
    ring_time: activity.ring_time,
    talk_time: activity.talk_time,
    tags: activity.tag_list,
    note: `Lambda ${event.id}`
  };

  try {
    const res = await context.http_post(
      'https://api.your-service.com/hooks/ctm',
      JSON.stringify(payload),
      {'Content-Type': 'application/json', Authorization: 'Bearer ' + process.env.MY_API_KEY}
    );
    if (!res || !res.response || res.response.status >= 300) {
      console.error('Upstream rejected:', res && res.response && res.response.status, res && res.data);
    }
  } catch (err) {
    console.error('Upstream failed:', err && err.message);
  }
};
```

### Routing: conditional destination with a catch-all
```js
exports.handler = async (event, context) => {
  const a = event.activity || {};
  const DEFAULT_ROUTE = 'QUE_REPLACE_ME';
  const VIP_ROUTE = 'USR_REPLACE_ME';

  try {
    const hours = Number(a.custom_fields && a.custom_fields.hours || 0);
    const vip = String((a.tag_list || []).join(',')).includes('vip');
    const route = vip ? VIP_ROUTE : DEFAULT_ROUTE;
    console.log('routing', a.id, '->', route, 'hours', hours);
    return context.done(null, {route});
  } catch (err) {
    console.error('routing failed, using default:', err && err.message);
    return context.done(null, {route: DEFAULT_ROUTE});
  }
};
```

---

## 10. Gotchas checklist

1. **15 s is the whole budget.** No documented per-HTTP-call timeout. Keep external calls to one or two.
2. **`data` is a JSON string.** `JSON.parse` it.
3. **Always `context.done()` on every path** in routing lambdas, including `catch`.
4. **`tag_list` overwrites.** Read-modify-write, comma-separated string, lowercased.
5. **Never write `id`.**
6. **`ctm.update()` fails quietly** on unknown keys — verify by reading the record back.
7. **`caller_number` may not be E.164.** Use `caller_number_complete`.
8. **Don't guess custom field shape** — typed sub-objects (`custom_fields.strings`) vs flat (`custom_fields.foo`) both circulate.
9. **Credentials must be granted** (`+Add Credentials`) or `event.<integration>` is undefined.
10. **Agency-wide lambdas hit every sub-account** and can't be scoped down.
11. **`callback` is legacy** — write `async` handlers.
12. **Confirm the runtime** — docs disagree (18.x vs 8.10); library availability follows the runtime.

---

## 11. Open items to confirm with the team

- `context.ctm.score()` argument 3 semantic.
- `ctm.ask()` preconditions (transcription on? call ended? cost?).
- Whether `context.http_*` throws on 4xx/5xx or returns a status to check.
- Whether `event.activity.digits` / `event.activity.context_state` is the real post-gather path.
- Full `+Add Packages` dropdown contents; process/SLA for `Request Package`.
- ID prefixes for the non-VMI/QUE/USR routable objects.
- Log retention in the UI.
- `event.options` shape for a custom action.
