#!/usr/bin/env bash
# playwright-chromium-setup.sh — idempotent Chromium bootstrap for Playwright.
#
# Installs Playwright's bundled Chromium, plus by default the OS-level packages
# it needs, for repos that use Playwright for browser-based visual UI
# verification. Playwright's own installer skips browsers it has already
# installed, so this is safe to run on every session start.
#
# It runs the repo's *own* Playwright (node_modules/.bin/playwright) and never
# fetches the package: a repo that does not already depend on Playwright is
# skipped with a warning, rather than having ~150MB of browser pulled into it.
#
# On Linux, --with-deps makes Playwright install system packages through sudo.
# Set ENV_SETUP_BROWSER_WITH_DEPS=0 to install the browser only and leave the
# OS packages alone.
set -euo pipefail

log() { echo "[env-setup-browser] $*"; }
warn() { echo "[env-setup-browser] $*" >&2; }

PLAYWRIGHT="node_modules/.bin/playwright"

if [ ! -x "$PLAYWRIGHT" ]; then
  warn "Playwright is not a dependency here ($PLAYWRIGHT not found); skipping Chromium install."
  warn "  This plugin only bootstraps Chromium for repos that already depend on Playwright."
  warn "  If dependencies are simply not installed yet, install them and start a new session."
  warn "  In a workspace, start the session from the package that depends on Playwright."
  exit 0
fi

args=(install chromium)
if [ "${ENV_SETUP_BROWSER_WITH_DEPS:-1}" = "0" ]; then
  log "ENV_SETUP_BROWSER_WITH_DEPS=0 — installing the browser without OS dependencies."
else
  args+=(--with-deps)
fi

log "Ensuring Playwright Chromium is installed..."
if ! "$PLAYWRIGHT" "${args[@]}"; then
  warn "playwright install chromium failed — see output above."
  exit 0
fi

log "Playwright Chromium is ready."
