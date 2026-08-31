#!/usr/bin/env bash
# Structural validation for the coretex plugin marketplace.
# Exits non-zero on the first class of failure found, listing every instance.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
err() { printf '  ✗ %s\n' "$1"; fail=1; }

command -v jq >/dev/null || { echo "jq is required"; exit 2; }

echo "marketplace manifest"
manifest=.claude-plugin/marketplace.json
jq empty "$manifest" 2>/dev/null || err "$manifest does not parse"
while read -r name source; do
  [ -d "$source" ] || { err "$name: source '$source' does not exist"; continue; }
  [ -f "$source/.claude-plugin/plugin.json" ] || err "$name: no .claude-plugin/plugin.json"
done < <(jq -r '.plugins[] | "\(.name) \(.source)"' "$manifest")

echo "plugin manifests"
for f in */.claude-plugin/plugin.json; do
  jq empty "$f" 2>/dev/null || { err "$f does not parse"; continue; }
  for key in name description version; do
    [ "$(jq -r --arg k "$key" '.[$k] // empty' "$f")" ] || err "$f: missing '$key'"
  done
done

echo "skill frontmatter"
for f in */skills/*/SKILL.md; do
  [ "$(head -1 "$f")" = "---" ] || { err "$f: no frontmatter"; continue; }
  fm=$(sed -n '2,/^---$/p' "$f")
  for key in name description; do
    grep -q "^$key:" <<<"$fm" || err "$f: frontmatter missing '$key'"
  done
  declared=$(grep -m1 '^name:' <<<"$fm" | sed 's/^name:[[:space:]]*//')
  dir=$(basename "$(dirname "$f")")
  [ "$declared" = "$dir" ] || err "$f: name '$declared' does not match directory '$dir'"
done

echo "agent frontmatter"
for f in */agents/*.md; do
  [ -e "$f" ] || continue
  [ "$(head -1 "$f")" = "---" ] || { err "$f: no frontmatter"; continue; }
  fm=$(sed -n '2,/^---$/p' "$f")
  for key in name description tools; do
    grep -q "^$key:" <<<"$fm" || err "$f: frontmatter missing '$key'"
  done
done

echo "hook manifests"
for f in */hooks/hooks.json; do
  [ -e "$f" ] || continue
  jq empty "$f" 2>/dev/null || err "$f does not parse"
done

echo "script behaviour tests"
tests/run.sh || fail=1

[ "$fail" -eq 0 ] && echo "all checks passed"
exit "$fail"
