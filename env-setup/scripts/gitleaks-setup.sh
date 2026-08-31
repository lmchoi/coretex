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

# Prints the path to a gitleaks binary, or nothing. PATH first, then the install
# directory: a full install can land somewhere the caller's PATH does not cover,
# and the session check must not then report it missing and tell the user to
# install what they already have.
resolve_gitleaks() {
  local p
  if p="$(command -v gitleaks 2>/dev/null)"; then
    printf '%s' "$p"
    return 0
  fi
  if [ -x "$INSTALL_DIR/gitleaks" ]; then
    printf '%s' "$INSTALL_DIR/gitleaks"
    return 0
  fi
  return 1
}

# Prints the bare version ("8.30.1") a gitleaks binary reports, or nothing.
version_of() {
  "$1" version 2>/dev/null | head -1 | tr -d '[:space:]' | sed 's/^v//'
}

on_path() { # on_path <dir>
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}

if [ "$MODE" = "session" ]; then
  if gl="$(resolve_gitleaks)"; then
    v="$(version_of "$gl")"
    log "gitleaks available at $gl (${v:-version unknown})."
    if ! on_path "$(dirname "$gl")"; then
      warn "$gl is not on PATH — a pre-commit hook shelling out to 'gitleaks' will not find it."
      warn "  Add this to your shell profile: export PATH=\"$(dirname "$gl"):\$PATH\""
    fi
    exit 0
  fi
  warn_install_instructions
  exit 0
fi

# --- Full install path ---

# Idempotent on the pinned version, not merely on the name: a machine with some
# other gitleaks already on PATH must still get the version this script pins,
# or GITLEAKS_VERSION would be unenforceable wherever it matters most.
if gl="$(resolve_gitleaks)"; then
  v="$(version_of "$gl")"
  if [ "$v" = "$GITLEAKS_VERSION" ]; then
    log "gitleaks v$v already installed at $gl."
    exit 0
  fi
  log "Found gitleaks ${v:-of unknown version} at $gl; installing pinned v${GITLEAKS_VERSION}."
fi

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
