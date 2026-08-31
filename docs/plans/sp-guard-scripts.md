# Plan: sp guard scripts and per-slice scratch

Slice 1 of 4. Siblings (each gets its own plan and PR):

2. ledger + chaining — depends on this slice
3. quality content — batched questions in `refine`, `writing-good-tests` reference, Global Constraints header
4. `/sp:design` — new skill, new `specs:` config key

## Goal

Every sp skill reads its config and creates its worktree by calling a script, not by
re-executing prose, and every slice owns a scratch directory the ledger can live in.

## Out of scope

- The ledger itself, and chaining the handoffs (slice 2 — this slice only creates the
  place the ledger will live).
- Any change to `refine`'s phase structure or question batching (slice 3).
- `/sp:design` and the `specs:` config key (slice 4).
- Making the skill instructions themselves testable. `check.sh` proves structure only;
  see the limitation below.

## Design

### Where the scripts live, and how a skill resolves them

`sp/scripts/`, inside the plugin — not in the host repo. Host repos get the scripts by
installing the plugin; nothing is copied into them.

**Resolution mechanism.** Do not use `${CLAUDE_PLUGIN_ROOT}` — it is unset in the Bash
environment (verified 2026-08-31), and `sp/hooks/hooks.json` does not use it (an
earlier draft of this plan claimed it did; that was false).

Skills invoke scripts by **relative path from the skill's own directory**, so
`sp/skills/<name>/SKILL.md` calls `../../scripts/sp-preflight`.

Evidence this works, verified 2026-08-31 against the installed superpowers plugin,
which uses the same pattern:

- scripts ship into the plugin cache with the executable bit intact (`-rwxr-xr-x`)
- they execute from the cache — running `sdd-workspace` printed its usage and exited 0
- its `SKILL.md` invokes them as a bare relative path, `scripts/sdd-workspace`, with
  the instruction "from this skill's directory"

Superpowers places scripts inside each skill's own directory. sp uses a shared
`sp/scripts/` at plugin root instead, because `sp-preflight` is called from six
skills and copying it six times would reintroduce exactly the duplication this slice
removes. The cost is one extra `../..` hop, which commit 1 confirms once.

### `sp-preflight`

Validates and reads in one call, because today every skill does both in prose:

```
sp-preflight [--plan <slug>] [--worktree] [--gh]
```

On success, prints the config as `key=value` lines on stdout:

```
test=./scripts/check.sh
plans=docs/plans/
docs=docs/
```

Exits non-zero with a message naming the problem when: no `### sp config` section
exists, a required key (`test`, `plans`) is absent, `--plan <slug>` names a plan that
does not exist, `--worktree` is passed and the current branch has no worktree under
`.claude/worktrees/`, or `--gh` is passed and `gh auth status` fails.

`--worktree` exists specifically to preserve `implement`'s Step 1 guard, which
`sp/README.md` documents as one of sp's four guards ("`/sp:implement` refuses to run
if no worktree exists"). Without it, commit 3 would silently delete that guard while
appearing to be a pure refactor.

Replaces the guard prose currently duplicated across `refine` (Phase 0), `start`
(Step 1, config half only), `implement` (Step 1 via `--worktree`, Step 2 config
read), `commit` (Step 3), `push` (Step 1) and `done` (Step 1).

**Not absorbed by either script:** `start`'s "commit the plan file if it is untracked
or modified" step (`start/SKILL.md:29`). It stays as prose in `start`. Neither script
claims it, and the plan should not imply otherwise.

### `sp-worktree`

```
sp-worktree create <slug> <feat|fix>
sp-worktree branch-for <dir>      # print the branch a worktree directory is on
```

`create` makes the worktree at `.claude/worktrees/<slug>` on branch `<prefix>/<slug>`,
runs the `sync` command from config inside it, symlinks `.env` from the main checkout
if one exists, and creates the scratch directory. Fails loudly if the worktree
directory already exists.

`branch-for` parses `git worktree list` and prints the branch for a given directory.
It is a subcommand rather than prose in `done` because it is a deterministic parse
with a right answer — exactly the shape commits 1–2's fixture tests cover — and
because the sweep below proves the branch cannot be derived from the directory name.

Replaces bash currently copy-pasted between `start/SKILL.md:31-52` and
`fix/SKILL.md:26-43`.

### Decision: scratch lives inside the worktree

`.claude/worktrees/<slug>/.claude/sp/`, git-ignored.

Reachable without `git rev-parse --git-common-dir` gymnastics from inside the
worktree, and it dies with the worktree when `/sp:done` removes it — correct, since
its only job is mid-slice recovery. Alternative rejected: a repo-root scratch
directory, which survives cleanup and accumulates one stale directory per merged
slice.

The rule, one sentence, to be stated in the README: **a slice owns its worktree and
its scratch directory; nothing outside them is yours to write.**

### Decision: unify the fix worktree path, and make `done` tolerate legacy layouts

Today `start` creates `.claude/worktrees/<slug>` on `feat/<slug>` while `fix` creates
`.claude/worktrees/fix-<slug>` on `fix/<slug>`, which forces `done/SKILL.md:27` to
guess between two patterns. After this slice, new worktrees all use
`.claude/worktrees/<slug>` with the branch prefix carrying the distinction.

**Evidence — a sweep of every nc42 host repo, 2026-08-31.** An earlier draft of this
plan claimed "no `fix-` worktrees exist in any host repo, so the migration cost is
zero." That was asserted without checking and is false. `git worktree list` across all
repos found:

- `fix-` prefixed directories in `dassie` (2), `dassie-dashboard` (1) and `meridian`
  (several, all prunable)
- directory names that match no sp convention at all: `worktree-eval-log-tree-nav`,
  `worktree-eval-header-walking-skeleton`
- branch prefixes well beyond `feat/` and `fix/`: `chore/`, `docs/`, `ci/`, `chores/`,
  `claude/`, and bare branch names with no prefix
- worktrees outside `.claude/worktrees/` entirely: `nc42-worktrees/`,
  `dassie-worktrees/`

Consequences, all of which this slice must respect:

1. `sp-worktree create` governs **new** worktrees only. It does not migrate existing
   ones, and nothing in this slice renames anything on disk.
2. `done` must keep working against every shape above, which is precisely why
   `branch-for` reads the branch from git rather than reconstructing it from the
   directory name. This is the strongest argument for the change, and the sweep is
   what supplies it.
3. `--worktree` in `sp-preflight` must match on the worktree's *branch*, not on a
   directory naming pattern.

**New collision surface.** Once `feat` and `fix` share the `.claude/worktrees/<slug>`
namespace, a feature and a fix with the same slug collide where `fix-<slug>` previously
kept them apart. `sp-worktree create` fails loudly on an existing directory, so the
failure mode is safe and visible rather than silent.

### Testing approach

The scripts get behaviour tests: build a fixture repo in a temp directory (`git init`
plus a `CLAUDE.md` with a known config), run the script against it, assert exit code
and stdout. Never assert that a script contains a given line — that proves only that
the source is the source.

A `tests/run.sh` harness discovers and runs `sp/scripts/*.test.sh` and is wired into
`scripts/check.sh` so the sp `test` command covers both structure and script
behaviour.

**Known limitation, narrowed.** Commits 3 and 4 change instruction prose, and no check
in this repo can prove an agent follows it. Their test is `check.sh` staying green plus
the behaviour tests on the scripts the prose delegates to.

This limitation covers *delegation only*. It does not cover new logic that happens to
be written in a skill file: the branch lookup in `done` is a deterministic parse with a
right answer, so it moves into `sp-worktree branch-for` and gets fixture tests like any
other script. Nor does it cover the script-resolution mechanism, which is a mechanical
fact about the harness and is smoke-tested in commit 1. The general problem of testing
instruction files by the consuming agent's behaviour is slice 3's concern.

### Files affected

- new: `sp/scripts/sp-preflight`, `sp/scripts/sp-worktree`
- new: `sp/scripts/sp-preflight.test.sh`, `sp/scripts/sp-worktree.test.sh`, `tests/run.sh`
- edit: `scripts/check.sh` (run the harness)
- edit: `sp/skills/{refine,start,implement,commit,push,done,fix}/SKILL.md`
- edit: `sp/README.md`

## Why this slice bundles two independent scripts

`sp-preflight` (commits 1+3) and `sp-worktree` (commits 2+4) are independent of each
other and could have been two slices, as the sibling split was careful to do elsewhere.
They are bundled because both are prerequisites for slice 2 and neither changes
observable behaviour on its own — shipping them as one PR costs one review of a
cohesive refactor rather than two of half of it. If commit 1's smoke test fails, the
whole slice returns to `/sp:refine` together anyway.

## Commits

1. `feat: add sp-preflight` — script, its tests, and the `tests/run.sh` harness wired
   into `check.sh` (scaffolding folded into the commit whose deliverable needs it).
   Confirm once that `../../scripts/sp-preflight` resolves when invoked from a skill
   directory before commits 3–5 depend on it.
   test: fixture with no `### sp config` → non-zero; missing `test:` key → non-zero
   naming the key; complete config → `key=value` on stdout; `--plan missing-slug` →
   non-zero; `--worktree` on a branch with no worktree → non-zero; on a branch with one
   → zero.

2. `feat: add sp-worktree` — `create` and `branch-for`.
   test: fixture → worktree at `.claude/worktrees/<slug>`, branch `feat/<slug>`,
   `.claude/sp/` present, `sync` command invoked; second `create` against the existing
   directory → non-zero; `branch-for` returns the right branch for a conventional
   directory, for a legacy `fix-<slug>` directory, and for a directory whose branch
   shares no name with it — the three shapes the sweep found in the wild.

3. `refactor: call sp-preflight from the skills` — replaces the duplicated guard prose
   in `refine`, `start`, `implement` (keeping the worktree guard via `--worktree`),
   `commit`, `push`, `done`. Leaves `start`'s plan-file-commit step as prose.
   test: `check.sh` green (structural only — see limitation above).

4. `refactor: call sp-worktree from start, fix and done` — removes the copy-pasted
   bash, unifies the fix worktree path for new worktrees, switches `done` to
   `branch-for`.
   test: `check.sh` green; behaviour covered by commit 2's tests.

5. `docs: update sp README` — scripts section, scratch directory convention, the
   slice-ownership rule, and a note that `sp-worktree` governs new worktrees only.
   test: none — docs only; `check.sh` green.

6. `chore: bump sp plugin version` — `sp/.claude-plugin/plugin.json` `0.1.0` → `0.2.0`.
   The plugin cache is keyed by version (`~/.claude/plugins/cache/coretex/sp/0.1.0/`),
   and that entry's `lastUpdated` has equalled `installedAt` since 2026-07-19 — it has
   never refreshed in place. Without a bump, host machines may keep serving the old
   build after `/plugin update`.
   test: `check.sh` green (it validates that `version` is present).
