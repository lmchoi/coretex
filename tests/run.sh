#!/usr/bin/env bash
# Runs every *.test.sh shipped alongside a plugin's scripts.
# Each test file prints its own results and exits non-zero if any case failed.
set -uo pipefail
cd "$(dirname "$0")/.."

shopt -s nullglob
fail=0
tests=(*/scripts/*.test.sh)

if [ ${#tests[@]} -eq 0 ]; then
  echo "  no script tests found"
  exit 0
fi

for t in "${tests[@]}"; do
  echo "  $t"
  bash "$t" || fail=1
done

exit "$fail"
