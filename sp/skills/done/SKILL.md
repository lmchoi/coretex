---
name: done
description: Post-merge cleanup — remove the worktree, delete the branch, archive the plan file. Run from the main checkout.
model: haiku
---

# /sp:done

Post-merge cleanup. Verifies the PR is merged before doing anything destructive.

## Usage

`/sp:done`

Run this after the PR for the current branch has been merged.

## Steps

### Step 1: Detect the branch and worktree

Run this skill from the main checkout, not from inside the worktree — the steps below remove the worktree and check out the default branch, which fail from inside it. If currently inside the worktree, `cd` back to the main checkout first.

```bash
git worktree list
```

Pick the worktree under `.claude/worktrees/` being cleaned up (if more than one, ask the user which). Set `SLUG` to its directory name and `BRANCH` to its branch (`feat/$SLUG` or `fix/$SLUG`).

Run `../../scripts/sp-preflight` from this skill's directory for the `plans` directory and the optional `todo` file.

### Step 2: Verify the PR is merged

```bash
gh pr view "$BRANCH" --json state,number
```

If `state` is not `MERGED`, stop:

> PR is not merged yet (state: <state>). Merge it first, then re-run /sp:done.

Do not proceed until confirmed merged.

### Step 3: Remove the worktree

```bash
git worktree remove .claude/worktrees/"$SLUG" --force
```

### Step 4: Delete the local branch

```bash
git checkout <default-branch>
git pull --ff-only
git branch -d "$BRANCH"
```

`--ff-only` matters: if the default branch has diverged from its remote (e.g. a prior session left unpushed local commits), a plain `git pull` silently rebases or merges and rewrites local history. `--ff-only` fails loudly instead so a real divergence gets surfaced to the user rather than resolved automatically mid-cleanup.

### Step 5: Archive the plan

Check whether a plan file exists for this slice:

```bash
ls <plans>/"$SLUG".md 2>/dev/null
```

If the file exists, move it to the archive:

```bash
mv <plans>/"$SLUG".md <plans>/archive/"$SLUG".md
```

If the config names a `todo` file and the slug has a matching `- [ ]` line anywhere in it, check it off or remove it.

If no matching plan file is found, list the plans directory and ask the user which one (if any) corresponds to this slice.

### Step 6: Confirm

Tell the user the branch and worktree have been cleaned up, they are back on the default branch, and which plan file (if any) was archived.
