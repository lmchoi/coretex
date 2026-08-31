---
name: commit
description: Create a single atomic commit with green tests and a conventional-commit message. Use instead of raw git commit.
model: sonnet
---

# /sp:commit

Creates a single atomic commit with verified checks. Use instead of running git commit directly.

## Usage

`/sp:commit`

## Steps

### Step 1: Show the staged diff

Run `git diff --cached --stat` and then `git diff --cached`. Review what is staged.

If nothing is staged, run `git status` and `git diff`, stage only the files belonging to the current task with explicit paths (never a blanket `git add -A`), then re-check the staged diff.

### Step 2: Check for unrelated changes

If the diff contains changes unrelated to the current task, flag them:

> The following staged changes appear unrelated to this commit: [list]
> Unstage them or explain why they belong here before proceeding.

Do not proceed until resolved.

### Step 3: Verify checks pass

Run the project's `test` command — the plugin's `scripts/sp-preflight`, run by absolute path, from the host repo, prints it as a `test=` line. If it fails, fix the failure before committing — do not commit on a red test suite.

### Step 4: Write the commit message

Use conventional commit format:
- `feat:` new feature
- `fix:` bug fix
- `test:` tests only
- `refactor:` behaviour-preserving restructure
- `chore:` tooling, config, deps
- `docs:` documentation only

Keep the subject line under 72 characters. Add a body only if the why is non-obvious.

### Step 5: Commit

```bash
git commit -m "$(cat <<'EOF'
<message>

Co-Authored-By: <name of the model actually running> <noreply@anthropic.com>
EOF
)"
```

Confirm the commit was created and show the hash.
