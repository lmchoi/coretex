#!/usr/bin/env bash
# Behaviour tests for sp-preflight. Runs the real script against fixture repos
# built in temp directories; never asserts on the script's own source text.
#
# Expected failures assert exit code 1 specifically, not merely non-zero:
# a missing or broken script exits 127, which would satisfy "non-zero" and let
# every negative case pass vacuously.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PREFLIGHT="$HERE/sp-preflight"

fails=0
ok()  { printf '    ✓ %s\n' "$1"; }
bad() { printf '    ✗ %s\n' "$1"; fails=1; }

RC=0; OUT=""
run() { # run <dir> [args...]
  local dir="$1"; shift
  OUT=$(cd "$dir" && "$PREFLIGHT" "$@" 2>&1); RC=$?
}

expect_rc() { # expect_rc <want> <label>
  [ "$RC" -eq "$1" ] && ok "$2" || bad "$2 — wanted exit $1, got $RC: $OUT"
}

expect_out() { # expect_out <pattern> <label>
  grep -q -- "$1" <<<"$OUT" && ok "$2" || bad "$2 — output lacked '$1': $OUT"
}

fixture() { # fixture <CLAUDE.md contents> -> prints repo path
  local d
  d=$(mktemp -d)
  git -C "$d" init -q
  git -C "$d" config user.email test@example.com
  git -C "$d" config user.name test
  printf '%s\n' "$1" >"$d/CLAUDE.md"
  printf 'x\n' >"$d/seed"
  git -C "$d" add -A && git -C "$d" commit -qm seed
  printf '%s' "$d"
}

GOOD_CONFIG='# fixture

### sp config

- test: `./scripts/check.sh`   # trailing comment should be ignored
- plans: `docs/plans/`
- docs: `docs/`
'

d=$(fixture '# fixture with no config')
run "$d"
expect_rc 1 "missing '### sp config' exits 1"
expect_out "sp config" "missing config names the section"
rm -rf "$d"

d=$(fixture '### sp config

- plans: `docs/plans/`
')
run "$d"
expect_rc 1 "config missing the 'test' key exits 1"
expect_out "missing required key: test" "missing-key message names the key"
rm -rf "$d"

d=$(fixture "$GOOD_CONFIG")
run "$d"
expect_rc 0 "complete config exits 0"
grep -qx 'test=./scripts/check.sh' <<<"$OUT" \
  && ok "prints test= with the trailing comment stripped" \
  || bad "expected line 'test=./scripts/check.sh', got: $OUT"
grep -qx 'plans=docs/plans/' <<<"$OUT" \
  && ok "prints plans=" \
  || bad "expected line 'plans=docs/plans/', got: $OUT"
rm -rf "$d"

d=$(fixture "$GOOD_CONFIG")
mkdir -p "$d/docs/plans" && : >"$d/docs/plans/real-slice.md"
run "$d" --plan missing-slice
expect_rc 1 "--plan naming no such plan exits 1"
expect_out "missing-slice" "--plan failure names the slug"
run "$d" --plan real-slice
expect_rc 0 "--plan naming an existing plan exits 0"
rm -rf "$d"

d=$(fixture "$GOOD_CONFIG")
run "$d" --worktree
expect_rc 1 "--worktree with no worktree for this branch exits 1"
git -C "$d" worktree add -q "$d/.claude/worktrees/slice" -b feat/slice 2>/dev/null
run "$d/.claude/worktrees/slice" --worktree
expect_rc 0 "--worktree from inside the slice worktree exits 0"
rm -rf "$d"

d=$(fixture "$GOOD_CONFIG")
OUT=$(cd "$d" && SP_GH_CMD='false' "$PREFLIGHT" --gh 2>&1); RC=$?
expect_rc 1 "--gh exits 1 when the auth probe fails"
OUT=$(cd "$d" && SP_GH_CMD='true' "$PREFLIGHT" --gh 2>&1); RC=$?
expect_rc 0 "--gh exits 0 when the auth probe succeeds"
rm -rf "$d"

d=$(fixture "$GOOD_CONFIG")
run "$d" --nope
expect_rc 1 "an unknown flag exits 1"
rm -rf "$d"

exit "$fails"
