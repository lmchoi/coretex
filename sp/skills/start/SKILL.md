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

Run `../../scripts/sp-preflight --plan <slug>` from this skill's directory. It validates the `### sp config` section and confirms `<plans>/<slug>.md` exists. If it exits non-zero, stop and show its message.

Read the plan and confirm the commit breakdown is present. If the plan has no Commits section, stop and tell the user to complete `/sp:refine` first.

If the plan file is untracked or has uncommitted changes, commit it now (from the main checkout) with a `docs:` commit. Worktrees are created from HEAD — an uncommitted plan file will not exist inside the worktree, and `/sp:implement` and `/sp:push` read it from there.

### Step 2: Create the worktree

```bash
git worktree add .claude/worktrees/<slug> -b feat/<slug>
```

If the branch already exists, confirm it and proceed.

### Step 3: Sync dependencies

If the config has a `sync` command, run it inside the new worktree to create an isolated environment, e.g.:

```bash
cd .claude/worktrees/<slug> && <sync>
```

Also symlink untracked local config the project needs (e.g. `.env`) if it exists in the main repo. Run this from the repo root (not from inside the worktree):

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
ln -sf "$REPO_ROOT/.env" "$REPO_ROOT/.claude/worktrees/<slug>/.env" 2>/dev/null || true
```

### Step 4: Confirm

Tell the user:
- Worktree path: `.claude/worktrees/<slug>`
- Branch: `feat/<slug>`
- Run `/sp:implement` to begin the TDD loop
