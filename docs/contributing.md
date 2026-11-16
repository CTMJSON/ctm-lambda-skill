# Contributing

The skill is a reference document, not an application. Changes are usually a
single corrected line. Two things matter: **accuracy** and **not inflating
confidence**.

## The one rule

**Never remove a tag to make a claim sound better.**

If a line is `[PARTIAL]` because two CTM pages disagree, the fix is to resolve
the disagreement with evidence and update the tag *with a note about where the
evidence came from*. It is not to delete the tag.

## Fixing an open question

If you can close one of the known unknowns (see the README), do it like this:

1. **Get evidence**, not an opinion. Precedence, best first:
   - Behaviour observed in a test call / the Lambda editor test harness, with the
     log output pasted into the PR.
   - A CTM source file or engineer statement — name the person or file.
   - CTM documentation — link it and note the date.
2. **Edit `skill/reference.md`**, replacing the gap with the fact and the tag.
   Add the evidence inline as a short note:
   ```markdown
   **[DOC]** `score()` arg 3 is the reported value. Verified against <source>,
   <date>.
   ```
3. **If the fact contradicts existing text**, delete the old text rather than
   leaving both. Stale facts in this file are worse than missing ones.
4. **Update the README's "Known unknowns"** list — remove the closed item.
5. **Bump the review date** at the top of `reference.md`.

## Editing `SKILL.md` instead

`SKILL.md` is the decision layer: when to use the skill, the failure modes, and
the rules for answering. Almost every correction belongs in `reference.md`, not
here.

Change `SKILL.md` only when the *behaviour* should change — a new class of
question, a failure mode worth promoting, a rule to add or tighten. Keep it
short; it loads into context on every invocation.

After editing `SKILL.md`, confirm the frontmatter still validates:

```bash
bash install.sh --dry-run
```

The installer enforces: `name` present and kebab-case, `description` present,
both under 1024 characters together. A malformed skill is silently ignored by
some runtimes, so this check matters more than it looks.

## Testing before you push

There is no test suite; the test is whether the assistant behaves correctly.

```bash
bash install.sh                 # install your edit
```

Then ask your assistant three questions and check the behaviour:

| Ask | Correct response |
| --- | --- |
| "What does the third argument to `context.ctm.score()` do?" | Declines or hedges — it is still an open question |
| "Write a routing lambda that sends vip to QUE1, else QUE2." | Complete script, `context.done()` on every path including `catch` |
| "Why isn't my `ctm.update()` saving?" | Mentions that unknown keys are dropped silently, and suggests reading the record back |

If any of those regress, don't push.

## Adding a new skill file

Keep the split:

- `SKILL.md` — triggers, failure modes, decision rules. Walks the assistant to
  the right behaviour.
- `reference.md` — every field, helper, tag, snippet. Read on demand.

Put anything long in `reference.md`. A bloated `SKILL.md` is loaded on every
invocation and costs context on every unrelated question too.

## Never commit

- Credentials, bearer tokens, integration tokens, API keys.
- Customer account IDs, call records, caller numbers, transcripts, CNAM values.
- Screenshots containing real customer data.
- Internal-only endpoints or infrastructure details.

The repo is public. Treat every example as something a customer could read.

## Style

Write for someone who has read the CTM help centre and is still stuck.

- Lead with the fact, then the caveat.
- Show the complete script, not a fragment.
- Name the trap before the fix.
- Prefer a table for anything enumerable.
- No marketing language. This is a reference.
