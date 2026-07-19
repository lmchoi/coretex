---
name: refine-scorer
description: Structured refinement conversation for scorer/eval-check design — reader-value, deterministic-first, and testability phases. Use whenever the work is a scorer, eval check, or task wiring in an Inspect AI repo.
model: sonnet
---

# /evalcraft:refine-scorer

Structured refinement conversation for designing or wiring a scorer/eval check. Ends by
writing a plan file — no code written. If the `sp` plugin is installed, the plan goes to
its configured plans directory and hands off to `/sp:start`; otherwise write it to
`docs/plans/`.

Use this when the feature is "add/change a scorer," "wire a check onto a task," or
"design an eval." Use a general refinement flow (e.g. `/sp:refine`) for everything else.

## Steps

Work through each phase in order. Pause and wait for user input before moving to the next.

### Phase 0: Context and overlap check

Read the project's plans directory, design notes, and any eval-design docs to surface
prior decisions. Additionally: check which task(s) currently score the same samples this
scorer would target. Grep the repo's task definitions for datasets and filters — if
another task already filters to an overlapping (or identical) sample set and already
runs a scorer that does similar work, flag it before proceeding. Wiring an existing
scorer onto a new task that's a strict subset of samples already scored elsewhere
produces no new signal.

### Phase 1: Restate and confirm

Restate what you understand the scorer/check to be in one or two sentences, including
which task(s) it attaches to. Ask the user to confirm or correct before continuing.

### Phase 2: Split check

Ask: can this be broken into two or more independent pieces that could ship separately?

Signals it should be split:
- Contains "and" connecting two distinct behaviours
- Part A must exist before Part B can be built
- Part A and Part B could be tested independently
- A "family" of similar checks is being proposed at once (e.g. several topic-trigger →
  expected-keyword scorers) — usually ship the first instance, backlog the rest as
  follow-ups rather than building the whole family in one slice

If yes: propose the split, ask the user to confirm, then refine each part separately.

### Phase 3: Reader value and actionability check — work backwards from here

Before any design/implementation choice, establish what the report needs to show. This
phase drives Phase 4 and 5, not the other way round — don't pick `includes()` vs. a
judge before knowing what a reader needs to see and act on.

- Who reads this, and in what frame (compliance, quality, safety, commercial)?
- What does PASS mean to the reader? What does FAIL mean? Is either ambiguous, or does
  it overstate what was actually checked (e.g. "disclosed the caveat" is not the same
  claim as "the response is fully compliant")?
- What can the reader actually do with a FAIL? Is the finding actionable on its own, or
  does it only become actionable paired with another scorer's output?
- How does the result render in the report? Is this a new section or does it join an
  existing one? What, specifically, needs to appear in `Score.explanation` for the
  reader to trust and act on the verdict (a quoted excerpt, a matched phrase, a judge's
  reasoning)?
- Is there a simpler version that delivers most of the value?
- Does this align with the project's stated goals/requirements?

Surface concerns, defer to user judgement. The output of this phase is a concrete
answer to "what does the report cell/tooltip say, and what does the reader do next" —
carry that forward into Phase 4.

### Phase 4: Deterministic-first check

Given what Phase 3 established the report needs to show, ask whether a deterministic
check (`includes()`, `pattern()`, `match()`, `exact()`) can produce it.

- If the check is substring/keyword-shaped: default to `includes()` or similar. Ground
  the target phrase list in real sample data (an actual eval run's responses), not
  assumption — search for how the phrase actually appears across models before locking
  in a target list.
- If deterministic matching will have a known paraphrase gap (some real responses
  phrase it differently than any fixed target list can catch): don't run an LLM judge
  on every sample as a blanket alternative. Prefer **escalation**: run the
  deterministic check first, and only call the LLM judge (typically
  `model_graded_fact()`) on the subset that fails the cheap check. This keeps LLM calls
  reserved for the genuine gap rather than duplicating cost on every sample, and the
  escalation rate becomes a free measurement of the deterministic check's real-world
  false-negative rate.
- Escalation isn't expressible as two independently-wired built-in scorers — inspect_ai
  has no "run B only if A fails" combinator. It needs one custom `@scorer` function
  that runs the cheap check inline and falls back to invoking the judge scorer's logic.
- If the check is inherently a subjective/semantic judgement (e.g. "does this respond
  with an unsupported directional claim"), a judge-only scorer is fine — don't force a
  deterministic layer where none fits.

### Phase 5: Testability check

Ask: how would you test this? Can you write a test that fails before the work and
passes after?

For scorers specifically: does a fixture exist (or can one be constructed) for both a
clear PASS case and a clear FAIL case, ideally drawn from real model output rather than
invented? A scorer that only ever sees synthetic, non-adversarial fixtures risks the
"100% pass rate" trap — write at least one fixture designed to bait a failure.

### Phase 6: Design discussion

Cover:
- What files change and where new code lives — follow the repo's existing layout
  (typically one module per scorer with shared helpers, separate task wiring, separate
  report/display registration)
- Any hard-to-reverse decisions (data formats, file structures, module boundaries)
- Follow existing patterns — read the relevant code before proposing anything
- **Explanation text is never hardcoded in the report layer.** Any new scorer must
  build its own `explanation` dynamically at score-time — either from the matched
  deterministic phrase or from the judge's own reasoning — not from a template written
  into the report generator. The report layer should only own display titles and
  section grouping.
- **Name scope-specific checks explicitly.** If a check encodes a fact that's true for
  the current subject but might not generalize (e.g. "no head-to-head trial exists
  between X and Y"), name the scorer to reflect that scope
  (`no_head_to_head_disclosure_check`, not a generic `disclosure_check`) so it isn't
  misapplied to a future case where the assumption inverts.

Do not edit any files during this phase.

### Phase 7: Commit breakdown

Propose a sequence of atomic, independently-testable commits. Each commit should:
- Do one logical thing
- Leave the eval runnable
- Have a clear test that validates it

Outside-in ordering usually applies: dataset/target field changes first, then the
scorer itself, then wiring it into the task, then report registration last.

Present as a numbered list. Ask the user to confirm or adjust.

### Phase 8: Write the plan file

After the user confirms, write `<plans>/<slug>.md`:

```markdown
# Plan: <scorer/eval name>

## Goal
One sentence — what does done look like?

## Out of scope
Explicit deferrals, including any related scorer family members not built in this slice.

## Design
Key decisions and tradeoffs: deterministic vs. judge choice, escalation logic if any,
what PASS/FAIL means to the reader, report registration. Files affected.

## Commits
1. <commit description> — test: <what test validates this>
2. ...

## Follow-up / explicitly deferred
Related scorer ideas, backlog items, calibration debt.
```

Confirm to the user once written. If the `sp` plugin is installed, tell them to run
`/sp:start <slug>` when ready to begin.
