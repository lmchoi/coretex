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

Read the `### sp config` section of the host `CLAUDE.md` for the `sync` command (if any):

```bash
git worktree add .claude/worktrees/fix-<slug> -b fix/<slug>
cd .claude/worktrees/fix-<slug> && <sync>
```

Then symlink untracked local config the project needs (e.g. `.env`) from the repo root (not from inside the worktree):

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
ln -sf "$REPO_ROOT/.env" "$REPO_ROOT/.claude/worktrees/fix-<slug>/.env" 2>/dev/null || true
```

### Step 3: Write the regression test

Write a test that fails because of the bug. Run it and confirm it is red. If the test passes before the fix, the hypothesis is wrong — re-diagnose.

### Step 4: Fix

Implement the minimal fix that makes the test pass without breaking existing tests.

Run the project's `test` command — must be fully green before committing.

### Step 5: Commit

Run `/sp:commit`. Do not push automatically — tell the user the fix is committed and suggest `/sp:push` when they are ready.
