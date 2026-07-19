---
name: doc-interview
description: One interview session toward a living document (PRD, risk register, strategy doc) — picks the next Open section, interrogates old-doc claims against evidence, writes only agreed text.
model: sonnet
---

# /pm:doc-interview

Runs one interview session toward a living document. Interview mode: Claude asks, the
user answers, agreed text lands in the document. Never merges old-doc text into the
document unreviewed — old docs are reaction material only.

## Usage

`/pm:doc-interview <doc-path> [section]` — with no section argument, picks the next
section whose status is Open.

## The document

If the document at `<doc-path>` doesn't exist, create it with a skeleton — every
section starts `Status: Open`. For a PRD, the default skeleton is:

```markdown
# <document title>

**Status:** In progress — built section by section via /pm:doc-interview
**Last updated:** <date>

| Section | Status |
|---|---|
| Problem | Open |
| Users & buyers | Open |
| Product shape & delivery | Open |
| Scope | Open |
| Non-goals | Open |
| Success metrics | Open |
| Open questions | — |
```

For any other document type, propose a section list to the user first and use their
adjusted version. Section statuses: `Open` → `Drafted` (text written, user hasn't
confirmed) → `Agreed`. Update the table and `Last updated:` every session.

## Steps

### Phase 1: Gather reaction material

For the chosen section, read only what's relevant:

- any older document or section this one replaces
- draft material that overlaps
- evidence artifacts: experiment results, eval runs, user research, logs — whatever the
  project holds that could back or break a claim

Sort what you find into three buckets: **validated** (evidence backs it), **asserted**
(stated in a doc, never tested), **contradicted** (docs disagree with each other or
with the evidence).

### Phase 2: Establish shared understanding (before any question)

Decision-forcing questions without shared context get bounced. Before asking anything:

1. **State your understanding of the product/project** in a short paragraph and let the
   user correct it. If you can't articulate it, you're not ready to interview.
2. **Give the decision criteria before the decision**: what the choice has to be good
   *for* (who reads it, what breaks if it's wrong), then a tie-breaker rule (e.g. "if
   still unsure, pick the cheapest to reverse"). The user decides with criteria, not on
   gut feel.
3. **Make options concrete.** For anything about framing or wording, show actual
   example text side by side — never bare labels like "option A framing".

### Phase 3: Interview

Ask the user pointed questions — one round at a time, wait for answers. Questions must
be grounded in Phase 1: quote the old claim, say which bucket it's in, ask whether it
survives. Prefer AskUserQuestion with the evidence and criteria summarized in the
option descriptions; the user can always answer freeform.

Rules:
- Never ask the user to "confirm the section" wholesale — interrogate claim by claim.
- If the user is unsure, that's an answer: record it under Open questions with what
  evidence would settle it. Don't push for a guess.
- "Explain more first" / "how do I decide this?" are valid answers — respond with
  criteria and concrete examples, not a rephrased version of the same forced choice.
- 3–6 questions per session. If a section needs more, stop, write what's agreed, and
  leave the rest Open — short sessions beat exhaustive ones.

### Phase 4: Write

Write the agreed text into the section. Mark it `Drafted`, show the user the exact
text, and only mark `Agreed` after they confirm. Move anything unresolved to Open
questions with a one-line note on what would resolve it.

### Phase 5: Close the session

- Update the status table and `Last updated:`.
- Tell the user which section is next and stop. One section (or less) per session.
- When every section is `Agreed`: mark any superseded document as superseded at its
  top, update any doc index the project keeps, and flag what downstream work the
  finished document unblocks.
