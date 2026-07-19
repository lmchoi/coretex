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
| `/sp:refine` | sonnet | Starting point for any new feature — structured conversation that ends with a plan file |
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

- `/sp:refine` and `/sp:start` refuse to run if the host `CLAUDE.md` has no `### sp config`
- `/sp:start` refuses to run if no plan file exists → run `/sp:refine` first
- `/sp:implement` refuses to run if no worktree exists → run `/sp:start` first
- `/sp:done` refuses to clean up if the PR is not merged → merge first

## Escape hatches

- `/sp:fix` does not require a pre-existing plan — it creates a minimal worktree inline.

## Agents

- `plan-reviewer` — reviews a plan file between `/sp:refine` and `/sp:start`: commit
  atomicity, testability, split honesty.
- `skill-auditor` — sweeps the host repo's skills/agents for references to paths,
  commands, or symbols that no longer exist.

## Hook

Ships a `PostToolUse` hook that runs `ruff check` on any `.py` file Claude writes or
edits (via `uv run`). It no-ops silently in repos without Python or without `uv`.
