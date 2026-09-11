#!/usr/bin/env bash
# Behaviour tests for playwright-chromium-setup.sh. Runs the real script in
# fixture repos built in temp directories, against a fake Playwright binary that
# records the arguments it was handed; never asserts on the script's own source.
#
# The fake also proves a negative the old guard got wrong: when Playwright is
# not a dependency, nothing must be executed at all. An assertion that the
# script "exits 0" would pass either way — the argv file is what distinguishes
# skipping from installing.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/playwright-chromium-setup.sh"

fails=0
ok()  { printf '    ✓ %s\n' "$1"; }
bad() { printf '    ✗ %s\n' "$1"; fails=1; }

RC=0; OUT=""; DIR=""
run() { # run <dir> [env assignments...]
  local dir="$1"; shift
  OUT=$(cd "$dir" && env "$@" bash "$SCRIPT" 2>&1); RC=$?
}

expect_rc() { # expect_rc <want> <label>
  [ "$RC" -eq "$1" ] && ok "$2" || bad "$2 — wanted exit $1, got $RC: $OUT"
}

expect_out() { # expect_out <pattern> <label>
  grep -q -- "$1" <<<"$OUT" && ok "$2" || bad "$2 — output lacked '$1': $OUT"
}

expect_argv() { # expect_argv <want> <label>
  local got
  got=$(cat "$DIR/argv" 2>/dev/null || true)
  [ "$got" = "$1" ] && ok "$2" || bad "$2 — wanted argv '$1', got '$got'"
}

expect_no_argv() { # expect_no_argv <label>
  [ -e "$DIR/argv" ] && bad "$1 — playwright was executed" || ok "$1"
}

# fixture <none|node_modules|playwright> [exit code of the fake] -> prints dir
fixture() {
  local shape="$1" rc="${2:-0}" d
  d=$(mktemp -d)
  case "$shape" in
    none) ;;
    node_modules) mkdir -p "$d/node_modules" ;;
    playwright)
      mkdir -p "$d/node_modules/.bin"
      cat >"$d/node_modules/.bin/playwright" <<FAKE
#!/usr/bin/env bash
echo "\$*" > "$d/argv"
exit $rc
FAKE
      chmod +x "$d/node_modules/.bin/playwright"
      ;;
  esac
  printf '%s' "$d"
}

DIR=$(fixture none); run "$DIR"
expect_rc 0 "a repo with no node_modules exits 0"
expect_out "not a dependency" "the skip message names the missing dependency"
expect_no_argv "nothing is executed when there is no node_modules"
rm -rf "$DIR"

DIR=$(fixture node_modules); run "$DIR"
expect_rc 0 "node_modules without Playwright exits 0"
expect_no_argv "node_modules alone does not trigger an install"
rm -rf "$DIR"

DIR=$(fixture playwright); run "$DIR"
expect_rc 0 "a repo depending on Playwright exits 0"
expect_argv "install chromium --with-deps" "Chromium is installed with OS deps by default"
rm -rf "$DIR"

DIR=$(fixture playwright); run "$DIR" ENV_SETUP_BROWSER_WITH_DEPS=0
expect_rc 0 "ENV_SETUP_BROWSER_WITH_DEPS=0 exits 0"
expect_argv "install chromium" "ENV_SETUP_BROWSER_WITH_DEPS=0 drops --with-deps"
rm -rf "$DIR"

DIR=$(fixture playwright 1); run "$DIR"
expect_rc 0 "a failing playwright install does not block the session"
expect_out "failed" "the failure is reported"
rm -rf "$DIR"

exit "$fails"
