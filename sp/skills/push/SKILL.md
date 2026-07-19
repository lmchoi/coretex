---
name: push
description: Update plan docs, run full checks, then push the branch and open a PR.
model: sonnet
---

# /sp:push

Prepares docs, runs full checks, then pushes and opens a PR.

## Usage

`/sp:push`

## Steps

### Step 1: Update docs

Read the `### sp config` section of the host `CLAUDE.md` for the `plans` directory and `test` command. Read `<plans>/<slug>.md` for the current branch.

Check:
- Are completed commits marked or noted in the plan?
- Were there any deviations from the plan that should be documented?
- Did this branch rename, move, or delete anything (files, symbols, CLI entry points)? If so, grep the host repo's `.claude/skills/` and `.claude/agents/` for the old names and update any hits in the same `docs:` commit — skill files drift silently otherwise.

If anything needs updating: write the changes, then run `/sp:commit` with a `docs:` prefix before continuing. Do not skip this step.

### Step 2: Run full checks

Run the project's `test` command.

### Step 3: Fix failures autonomously

If checks fail:
1. Diagnose the root cause (not just the symptom)
2. Fix it
3. Re-run the test command
4. Repeat up to 3 times

After 3 failed attempts, stop and report what was tried and what is still failing. Do not push broken code.

### Step 4: Push and open PR

```bash
git push -u origin <branch>
gh pr create --title "<title>" --body "$(cat <<'EOF'
## Summary
- <bullet points from plan>

## Test plan
- [ ] <project test command> passes
- [ ] <any manual verification steps>
EOF
)"
```

(If `gh` is unavailable in the environment, open the PR through whatever GitHub tooling is available instead.)

Report the PR URL. Tell the user to run `/sp:done` after the PR is merged.
