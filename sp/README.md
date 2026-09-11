# sp — guarded slice workflow

The engineering slice workflow: plan → worktree → TDD → PR → cleanup.

## Workflow order

```
/sp:refine → /sp:start → /sp:implement → /sp:push → /sp:done
                                ↑
                           /sp:commit (called inside implement)
                           /sp:fix    (alternative entry for bugs)
```

## Skills

| Skill | Model | When to use |
|---|---|---|
| `/sp:refine` | opus | Starting point for any new feature — structured conversation that ends with a plan file |
| `/sp:start` | haiku | After refine — creates worktree and branch, syncs deps |
| `/sp:implement` | sonnet | Inside the worktree — TDD loop, one plan commit at a time |
| `/sp:fix` | sonnet | Bug fixes — forces root cause diagnosis, regression test first |
| `/sp:commit` | sonnet | Instead of `git commit` — verifies checks, enforces atomic commits |
| `/sp:push` | sonnet | When implementation is done — updates docs, runs full checks, opens PR |
| `/sp:done` | haiku | After PR is merged — verifies merge, removes worktree, deletes branch |

## Host repo configuration (required)

Every skill reads its project-specific commands from an `### sp config` section in the
host repo's `CLAUDE.md`. `/sp:refine` and `/sp:start` refuse to run without it — add it
once per repo:

```markdown
### sp config
- test: `uv run pytest`      # full test suite; must exit non-zero on failure
- sync: `uv sync`            # optional: dependency setup inside a fresh worktree
- plans: `docs/plans/`       # where plan files live
- docs: `docs/project/`      # optional: project context read during /sp:refine
- todo: `docs/todo.md`       # optional: checked off during /sp:done
```

## Guards between skills

Most of these are enforced by `scripts/sp-preflight` rather than by prose in each skill:

- `/sp:refine` and `/sp:start` refuse to run if the host `CLAUDE.md` has no `### sp config`
- `/sp:start` refuses to run if no plan file exists → run `/sp:refine` first (`--plan`)
- `/sp:implement` refuses to run if no worktree exists → run `/sp:start` first (`--worktree`)
- `/sp:push` refuses to start if the GitHub CLI is not authenticated (`--gh`)
- `/sp:done` refuses to clean up if the PR is not merged → merge first
  (the one guard preflight does not cover — it stays as prose plus `gh pr view` in `done`)

## Scripts

**Calling convention.** Both scripts resolve the host repo from the current working
directory. Skills therefore invoke them **by absolute path, from the host repo** —
built from the base directory the harness announces when the skill loads — and never
`cd` into the plugin.

Getting this wrong is quiet rather than loud: `cd`-ing into the plugin first makes the
scripts read whatever repo the plugin checkout happens to sit in. If that repo has its
own `### sp config` (as coretex does), they exit 0 with the wrong config.

| Script | What it does |
|---|---|
| `sp-preflight [--plan <slug>] [--worktree] [--gh]` | Validates the host repo and prints its config as `key=value` lines. Exits 1 naming the problem on any failure. |
| `sp-worktree create <slug> <feat\|fix>` | Creates `.claude/worktrees/<slug>` on `<prefix>/<slug>`, runs `sync`, symlinks `.env`, creates the scratch directory. |
| `sp-worktree branch-for <dir>` | Prints the branch a worktree is on, read from git. |

Both have behaviour tests alongside them (`*.test.sh`), run by the host repo's
`test` command via `tests/run.sh`.

## Worktrees and scratch

A slice gets a worktree at `.claude/worktrees/<slug>` on branch `feat/<slug>` or
`fix/<slug>`, and a git-ignored scratch directory inside it at `.claude/sp/`.

**A slice owns its worktree and its scratch directory; nothing outside them is yours
to write.**

The scratch directory is deliberately inside the worktree, so it is removed along with
it by `/sp:done`. It is for mid-slice state only — nothing that must outlive the merge.

`sp-worktree create` governs **new** worktrees only. It never renames or migrates
existing ones, and `branch-for` reads the branch from git precisely because host repos
already contain worktrees whose directory names do not match their branches.

## Escape hatches

- `/sp:fix` does not require a pre-existing plan — it creates a minimal worktree inline.

## Agents

- `plan-reviewer` (opus) — reviews a plan file between `/sp:refine` and `/sp:start`: commit
  atomicity, testability, split honesty.
- `skill-auditor` — sweeps the host repo's skills/agents for references to paths,
  commands, or symbols that no longer exist.

## Hook

Ships a `PostToolUse` hook that runs `ruff check` on any `.py` file Claude writes or
edits (via `uv run`). It no-ops silently in repos without Python or without `uv`.
