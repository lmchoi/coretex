#!/usr/bin/env bash
# playwright-chromium-setup.sh — idempotent Chromium bootstrap for Playwright.
#
# Installs Playwright's bundled Chromium plus OS-level deps, for repos that use
# it for browser-based visual UI verification. Playwright's own installer
# already skips browsers it has already installed, so this is safe to run on
# every session start.
set -euo pipefail

log() { echo "[env-setup-browser] $*"; }
warn() { echo "[env-setup-browser] $*" >&2; }

if ! command -v npx >/dev/null 2>&1; then
  warn "npx not found on PATH; skipping Chromium install."
  warn "  Install Node.js, then run: npx playwright install chromium --with-deps"
  exit 0
fi

if [ ! -d node_modules ]; then
  warn "node_modules not found; skipping Chromium install until dependencies are installed."
  warn "  Re-run after install: npx playwright install chromium --with-deps"
  exit 0
fi

log "Ensuring Playwright Chromium is installed..."
if ! npx --yes playwright install chromium --with-deps; then
  warn "playwright install chromium failed — see output above."
  exit 0
fi

log "Playwright Chromium is ready."
