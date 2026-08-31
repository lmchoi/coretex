---
name: fix
description: Bug-fix workflow — root-cause hypothesis, regression test first, minimal fix, own worktree. Ends at commit, not push.
model: sonnet
---

# /sp:fix

Fixes a bug TDD-style: regression test first, then fix. Creates its own worktree.

## Usage

`/sp:fix <description>`

## Steps

### Step 1: State the root cause hypothesis

Before touching any file, state:
- What is the observable symptom?
- What is the hypothesised root cause, with evidence from the code?
- What test would fail before the fix and pass after?

Do not proceed until the root cause is confirmed, not just the symptom.

### Step 2: Create a worktree

Run the plugin's `sp-worktree` by absolute path, from the host repo:

```bash
<plugin>/scripts/sp-worktree create <slug> fix
```

It creates `.claude/worktrees/<slug>` on branch `fix/<slug>`, runs the configured `sync` command inside it, symlinks `.env` if the main checkout has one, and creates the slice's `.claude/sp/` scratch directory.

### Step 3: Write the regression test

Write a test that fails because of the bug. Run it and confirm it is red. If the test passes before the fix, the hypothesis is wrong — re-diagnose.

### Step 4: Fix

Implement the minimal fix that makes the test pass without breaking existing tests.

Run the project's `test` command — must be fully green before committing.

### Step 5: Commit

Run `/sp:commit`. Do not push automatically — tell the user the fix is committed and suggest `/sp:push` when they are ready.
