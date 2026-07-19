---
name: refine
description: Structured pre-implementation refinement conversation; ends by writing a plan file to the project's plans directory. Use before any feature work.
model: sonnet
---

# /sp:refine

Structured refinement conversation before any implementation begins. Ends by writing a plan file — no code written.

## Usage

`/sp:refine <feature description>`

## Steps

Work through each phase in order. Pause and wait for user input before moving to the next.

### Phase 0: Config and context check

Read the host repo's `CLAUDE.md` and find the `### sp config` section. If it is missing, stop:

> No `### sp config` section found in CLAUDE.md. Add one (see the sp plugin README) before using the sp workflow.

Note the `plans` directory and (if set) the `docs` directory from the config.

Read the plans directory and the docs directory to surface any prior decisions or existing plans that constrain or inform this feature. If the host `CLAUDE.md` documents a trust order for its docs, respect it — don't surface superseded material as a prior decision. Flag conflicts before proceeding.

### Phase 1: Restate and confirm

Restate what you understand the feature to be in one or two sentences. Ask the user to confirm or correct before continuing.

### Phase 2: Split check

Ask: can this be broken into two or more independent pieces that could ship separately?

Signals it should be split:
- Contains "and" connecting two distinct behaviours
- Part A must exist before Part B can be built
- Part A and Part B could be tested independently

If yes: propose the split, ask the user to confirm, then refine each part separately.

### Phase 3: Testability check

Ask: how would you test this? Can you write a test that fails before the work and passes after?

If unclear, flag it — untestable scope usually signals a fuzzy design decision. Don't block, but surface it.

### Phase 4: Value and alignment check

Ask:
- What does the user actually gain from this?
- Is there a simpler version that delivers most of the value?
- Does this align with the project's stated goals? If the docs directory contains a PRD or goals document, check against it — and respect any documented statuses (e.g. only sections marked agreed/settled are binding).

Surface concerns, defer to user judgement.

### Phase 5: Design discussion

Cover:
- What files change and where new code lives
- Any hard-to-reverse decisions (data formats, file structures, module boundaries)
- Follow existing patterns — read the relevant code before proposing anything

Do not edit any files during this phase.

### Phase 6: Commit breakdown

Propose a sequence of atomic, independently-testable commits. Each commit should:
- Do one logical thing
- Leave the project runnable and the test suite green
- Have a clear test that validates it

Consider whether outside-in ordering applies: write the outermost interface first before the internals.

Present as a numbered list. Ask the user to confirm or adjust.

### Phase 7: Write the plan file

After the user confirms, write `<plans>/<slug>.md`:

```markdown
# Plan: <feature name>

## Goal
One sentence — what does done look like?

## Out of scope
Explicit deferrals.

## Design
Key decisions and tradeoffs. Files affected.

## Commits
1. <commit description> — test: <what test validates this>
2. ...
```

Confirm to the user once written. Tell them to run `/sp:start <slug>` when ready to begin.
