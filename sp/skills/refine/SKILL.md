---
name: refine
description: Structured pre-implementation refinement conversation; ends by writing a plan file to the project's plans directory. Use before any feature work.
model: opus
---

# /sp:refine

Structured refinement conversation before any implementation begins. Ends by writing a plan file — no code written.

## Usage

`/sp:refine <feature description>`

## Steps

Work through each phase in order. Pause and wait for user input before moving to the next.

### Phase 0: Config and context check

Run the plugin's `scripts/sp-preflight` by absolute path, from the host repo — build the path from this skill's announced base directory and do not `cd` into it. It validates the host repo's `### sp config` section and prints the configured keys as `key=value` lines. If it exits non-zero, stop and show its message — do not continue without a valid config.

Note the `plans` directory and (if set) the `docs` directory from its output.

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

**Start with the real data, not the shapes.** Before proposing anything, run a few lines against a real input — the actual corpus, directory, fixture set or production sample this feature will meet — and count what comes out. How many items, how many of them degraded or unreadable, how many indistinguishable from each other. Report the counts.

This is minutes of work and it is the step that catches the expensive mistakes. A design can be right about every type and still be wrong about what the user ends up looking at, and only real data says which.

Then cover:
- What files change and where new code lives
- Any hard-to-reverse decisions (data formats, file structures, module boundaries)
- Follow existing patterns — read the relevant code before proposing anything

**Describe types, don't define them.** Say what a type has to distinguish and why — "a label must tell a real model name apart from a filename fallback, because the row styles them differently". Do not write the definition out. A type block in a plan is code that can't compile, can't be tested, and goes stale the moment real code lands near it. The argument for a shape survives contact with the codebase; the spelling of it doesn't.

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
Key decisions and tradeoffs, and what the real data showed. Files affected.
Record the reasoning behind a shape, not the shape's definition.

## Commits
1. <commit description> — test: <what test validates this>
2. ...
```

Confirm to the user once written. Tell them to run `/sp:start <slug>` when ready to begin.
