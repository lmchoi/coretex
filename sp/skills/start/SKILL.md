---
name: start
description: Create the worktree and branch for a refined slice. Requires a plan file in the project's plans directory.
model: haiku
---

# /sp:start

Creates a worktree and branch for a refined feature slice. Run after `/sp:refine` has written the plan.

## Usage

`/sp:start <slug>`

The slug must match a plan file in `<plans>/<slug>.md`, where `<plans>` comes from the `### sp config` section of the host `CLAUDE.md`.

## Steps

### Step 1: Guard — config and plan must exist

Run the plugin's `scripts/sp-preflight --plan <slug>` by absolute path, from the host repo — build the path from this skill's announced base directory and do not `cd` into it. It validates the `### sp config` section and confirms `<plans>/<slug>.md` exists. If it exits non-zero, stop and show its message.

Read the plan and confirm the commit breakdown is present. If the plan has no Commits section, stop and tell the user to complete `/sp:refine` first.

If the plan file is untracked or has uncommitted changes, commit it now (from the main checkout) with a `docs:` commit. Worktrees are created from HEAD — an uncommitted plan file will not exist inside the worktree, and `/sp:implement` and `/sp:push` read it from there.

### Step 2: Create the worktree

Run the plugin's `sp-worktree` by absolute path, from the host repo:

```bash
<plugin>/scripts/sp-worktree create <slug> feat
```

It creates `.claude/worktrees/<slug>` on branch `feat/<slug>`, runs the configured `sync` command inside it, symlinks `.env` if the main checkout has one, and creates the slice's `.claude/sp/` scratch directory. It fails if the worktree directory already exists — resolve that rather than reusing it.

### Step 3: Confirm and hand off

Tell the user:
- Worktree path: `.claude/worktrees/<slug>`
- Branch: `feat/<slug>`

Then run `/sp:implement` to begin the TDD loop.
