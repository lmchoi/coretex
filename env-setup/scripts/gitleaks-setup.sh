#!/usr/bin/env bash
# gitleaks-setup.sh — idempotent gitleaks bootstrap.
#
# Two modes:
#   --session   Fast, check-only path for a SessionStart hook. Never downloads
#               anything; if gitleaks is missing it prints a warning and exits 0
#               so it never blocks a session from starting.
#   (default)   Fuller path for provisioning a sandbox/environment from scratch:
#               downloads the pinned release for this OS/arch and installs it.
#
# Safe to run repeatedly: if gitleaks is already on PATH, both modes no-op.
set -euo pipefail

# Pinned version. Bump deliberately — the release asset names below are
# specific to this tag.
GITLEAKS_VERSION="${GITLEAKS_VERSION:-8.30.1}"
INSTALL_DIR="${GITLEAKS_INSTALL_DIR:-$HOME/.local/bin}"

MODE="install"
if [ "${1:-}" = "--session" ]; then
  MODE="session"
fi

log() { echo "[env-setup] $*"; }
warn() { echo "[env-setup] $*" >&2; }

warn_install_instructions() {
  warn "gitleaks not found on PATH."
  warn "  A repo relying on gitleaks for a fail-closed secret-scan pre-commit hook"
  warn "  will not be able to run that scan until gitleaks is installed."
  warn "  Install it yourself, e.g.:"
  warn "    brew install gitleaks"
  warn "  or download the pinned release for your OS/arch from:"
  warn "    https://github.com/gitleaks/gitleaks/releases/tag/v${GITLEAKS_VERSION}"
  warn "  or re-run this script without --session to install it now:"
  warn "    bash \"\$0\""
}

if command -v gitleaks >/dev/null 2>&1; then
  log "gitleaks already installed ($(gitleaks version 2>/dev/null || echo 'version unknown'))."
  exit 0
fi

if [ "$MODE" = "session" ]; then
  warn_install_instructions
  exit 0
fi

# --- Full install path ---

os_raw="$(uname -s)"
arch_raw="$(uname -m)"

case "$os_raw" in
  Linux) gl_os="linux" ;;
  Darwin) gl_os="darwin" ;;
  *)
    warn "Unsupported OS '$os_raw' for automatic gitleaks install."
    warn_install_instructions
    exit 0
    ;;
esac

case "$arch_raw" in
  x86_64|amd64) gl_arch="x64" ;;
  arm64|aarch64) gl_arch="arm64" ;;
  *)
    warn "Unsupported architecture '$arch_raw' for automatic gitleaks install."
    warn_install_instructions
    exit 0
    ;;
esac

asset="gitleaks_${GITLEAKS_VERSION}_${gl_os}_${gl_arch}.tar.gz"
url="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${asset}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

log "Installing gitleaks v${GITLEAKS_VERSION} (${gl_os}/${gl_arch})..."
if ! curl -fsSL "$url" -o "$tmpdir/$asset"; then
  warn "Failed to download $url"
  warn_install_instructions
  exit 0
fi

tar -xzf "$tmpdir/$asset" -C "$tmpdir" gitleaks

mkdir -p "$INSTALL_DIR"
mv "$tmpdir/gitleaks" "$INSTALL_DIR/gitleaks"
chmod +x "$INSTALL_DIR/gitleaks"

if command -v gitleaks >/dev/null 2>&1; then
  log "gitleaks v${GITLEAKS_VERSION} installed to $INSTALL_DIR/gitleaks"
else
  log "gitleaks v${GITLEAKS_VERSION} installed to $INSTALL_DIR/gitleaks (not yet on PATH)"
  warn "Add this to your shell profile: export PATH=\"$INSTALL_DIR:\$PATH\""
fi
