#!/usr/bin/env bash
# Behaviour tests for sp-worktree. Expected failures assert exit code 1
# specifically — a missing script exits 127 and would pass a bare "non-zero".
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WT="$HERE/sp-worktree"

fails=0
ok()  { printf '    ✓ %s\n' "$1"; }
bad() { printf '    ✗ %s\n' "$1"; fails=1; }

RC=0; OUT=""
run() { local dir="$1"; shift; OUT=$(cd "$dir" && "$WT" "$@" 2>&1); RC=$?; }
expect_rc() { [ "$RC" -eq "$1" ] && ok "$2" || bad "$2 — wanted exit $1, got $RC: $OUT"; }

CONFIG='### sp config

- test: `true`
- plans: `docs/plans/`
- sync: `touch synced-marker`
'

fixture() {
  local d
  d=$(mktemp -d)
  git -C "$d" init -q -b main
  git -C "$d" config user.email test@example.com
  git -C "$d" config user.name test
  printf '%s\n' "$CONFIG" >"$d/CLAUDE.md"
  git -C "$d" add -A && git -C "$d" commit -qm seed
  printf '%s' "$d"
}

# --- create ----------------------------------------------------------------
d=$(fixture)
run "$d" create alpha feat
expect_rc 0 "create exits 0"
[ -d "$d/.claude/worktrees/alpha" ] \
  && ok "worktree created at .claude/worktrees/<slug>" \
  || bad "expected worktree directory at .claude/worktrees/alpha"
[ "$(git -C "$d/.claude/worktrees/alpha" rev-parse --abbrev-ref HEAD 2>/dev/null)" = "feat/alpha" ] \
  && ok "branch is feat/<slug>" \
  || bad "expected branch feat/alpha"
[ -d "$d/.claude/worktrees/alpha/.claude/sp" ] \
  && ok "scratch directory created inside the worktree" \
  || bad "expected .claude/sp/ inside the worktree"
[ -f "$d/.claude/worktrees/alpha/synced-marker" ] \
  && ok "sync command ran inside the worktree" \
  || bad "expected the sync command to run inside the worktree"

run "$d" create alpha feat
expect_rc 1 "create against an existing worktree directory exits 1"

run "$d" create beta fix
expect_rc 0 "create with the fix prefix exits 0"
[ "$(git -C "$d/.claude/worktrees/beta" rev-parse --abbrev-ref HEAD 2>/dev/null)" = "fix/beta" ] \
  && ok "fix slices use .claude/worktrees/<slug> with a fix/ branch" \
  || bad "expected branch fix/beta at .claude/worktrees/beta"

run "$d" create gamma nonsense
expect_rc 1 "create with an unknown prefix exits 1"
rm -rf "$d"

# --- .env symlink ----------------------------------------------------------
d=$(fixture)
printf 'SECRET=1\n' >"$d/.env"
run "$d" create withenv feat
expect_rc 0 "create exits 0 when a .env is present"
[ -L "$d/.claude/worktrees/withenv/.env" ] \
  && ok ".env is symlinked into the worktree" \
  || bad "expected .env to be symlinked into the worktree"
rm -rf "$d"

# --- branch-for: the three shapes found in real host repos ------------------
d=$(fixture)
git -C "$d" worktree add -q "$d/.claude/worktrees/slice"     -b feat/slice
git -C "$d" worktree add -q "$d/.claude/worktrees/fix-legacy" -b fix/legacy-thing
git -C "$d" worktree add -q "$d/.claude/worktrees/weird"      -b worktree-unrelated-name

run "$d" branch-for .claude/worktrees/slice
[ "$OUT" = "feat/slice" ] && ok "branch-for: conventional directory" \
  || bad "branch-for slice — wanted feat/slice, got '$OUT'"

run "$d" branch-for .claude/worktrees/fix-legacy
[ "$OUT" = "fix/legacy-thing" ] && ok "branch-for: legacy fix- directory whose branch differs" \
  || bad "branch-for fix-legacy — wanted fix/legacy-thing, got '$OUT'"

run "$d" branch-for .claude/worktrees/weird
[ "$OUT" = "worktree-unrelated-name" ] && ok "branch-for: directory sharing no name with its branch" \
  || bad "branch-for weird — wanted worktree-unrelated-name, got '$OUT'"

run "$d" branch-for .claude/worktrees/does-not-exist
expect_rc 1 "branch-for an unknown directory exits 1"
rm -rf "$d"

# --- usage -----------------------------------------------------------------
d=$(fixture)
run "$d" bogus-subcommand
expect_rc 1 "an unknown subcommand exits 1"
rm -rf "$d"

exit "$fails"
