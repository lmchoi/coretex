---
name: implement
description: TDD implementation loop for the active slice's plan, one atomic commit at a time.
model: sonnet
---

# /sp:implement

Implements a feature slice TDD-style inside its worktree. Run after `/sp:start`.

## Usage

`/sp:implement`

Detects the active worktree and plan automatically from the current branch.

## Steps

### Step 1: Guard — worktree must exist

Check that a `.claude/worktrees/` directory exists for the current branch. If not:

> No worktree found. Run `/sp:start <slug>` first.

### Step 2: Orient

Read the `### sp config` section of the host `CLAUDE.md` for the `test` command and `plans` directory. Read `<plans>/<slug>.md` to get the commit breakdown.

Read the existing code in every file you will touch before writing anything. Follow existing patterns exactly — do not invent new abstractions or deviate from the established style. If unsure where something belongs, read more code first.

### Step 3: TDD loop — one commit at a time

For each commit in the plan:

1. **Write the failing test first.** Run it and confirm it is red before writing any implementation.
2. **Implement** until the test passes.
3. **Run the project's `test` command** — full test suite must be green.
4. **Run `/sp:commit`** with the commit description from the plan.

Never batch multiple plan commits into one. Never declare a step done without a green full test run.

### Step 4: When all commits are done

Tell the user all commits are complete and tests are green. Tell them to run `/sp:push` when ready to push.
