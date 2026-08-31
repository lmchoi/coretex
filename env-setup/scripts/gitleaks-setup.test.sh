#!/usr/bin/env bash
# Behaviour tests for gitleaks-setup.sh. Runs the real script against fixture
# environments in temp directories, with a fake `curl` serving a fixture release
# tarball, so nothing here touches the network. Never asserts on the script's
# own source text.
#
# Expected failures assert exit code 1 specifically, not merely non-zero: a
# missing or broken script exits 127, which would satisfy "non-zero" and let
# every negative case pass vacuously.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/gitleaks-setup.sh"
PINNED="8.30.1"

fails=0
ok()  { printf '    ✓ %s\n' "$1"; }
bad() { printf '    ✗ %s\n' "$1"; fails=1; }

RC=0; OUT=""; ROOT=""; BIN=""; INSTALL=""; SERVE=""

# A scratch environment: BIN is the only directory on PATH that the script can
# see besides the system ones, INSTALL is GITLEAKS_INSTALL_DIR, SERVE holds the
# files the fake curl will hand back, keyed by basename.
#
# Sets globals rather than printing a path: a command substitution would run the
# whole thing in a subshell, leaving BIN and INSTALL empty in the caller — at
# which point the script under test falls back to the real PATH, the real curl
# and the real $HOME/.local/bin, and the suite installs software on the machine
# running it. HOME is redirected into the scratch root for the same reason.
setup() {
  ROOT=$(mktemp -d)
  local root="$ROOT"
  BIN="$root/bin"; INSTALL="$root/install"; SERVE="$root/serve"
  mkdir -p "$BIN" "$SERVE" "$root/home"
  cat >"$BIN/curl" <<FAKE
#!/usr/bin/env bash
# Fake curl: serves \$SERVE/<basename of url>, records every URL requested.
url=""; out=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    -*) shift ;;
    *) url="\$1"; shift ;;
  esac
done
echo "\$url" >> "$root/urls"
src="$SERVE/\${url##*/}"
[ -f "\$src" ] || exit 22
cp "\$src" "\$out"
FAKE
  chmod +x "$BIN/curl"
}

fake_gitleaks() { # fake_gitleaks <dir> <version>
  mkdir -p "$1"
  cat >"$1/gitleaks" <<FAKE
#!/usr/bin/env bash
if [ "\${1:-}" = "version" ]; then echo "$2"; fi
FAKE
  chmod +x "$1/gitleaks"
}

sha256() { # sha256 <file> — matches the script's own fallback order
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

ASSET=""
# Builds the release tarball the fake curl will serve for the pinned version,
# and the matching checksums file. Pass "tamper" to publish a checksum that does
# not describe the tarball, or "no-entry" to publish one that omits it.
serve_release() { # serve_release <version reported by the shipped binary> [tamper|no-entry|no-sums]
  local d sum; d=$(mktemp -d)
  ASSET="gitleaks_${PINNED}_$(uname_os)_$(uname_arch).tar.gz"
  fake_gitleaks "$d" "$1"
  tar -czf "$SERVE/$ASSET" -C "$d" gitleaks
  rm -rf "$d"
  sum=$(sha256 "$SERVE/$ASSET")
  case "${2:-}" in
    no-sums) return 0 ;;
    tamper) sum="0000000000000000000000000000000000000000000000000000000000000000" ;;
    no-entry) ASSET="gitleaks_${PINNED}_some_other_platform.tar.gz" ;;
  esac
  printf '%s  %s\n' "$sum" "$ASSET" > "$SERVE/gitleaks_${PINNED}_checksums.txt"
}

expect_not_installed() { # expect_not_installed <label>
  [ -e "$INSTALL/gitleaks" ] && bad "$1 — a binary was installed" || ok "$1"
}

uname_os()   { case "$(uname -s)" in Linux) echo linux ;; Darwin) echo darwin ;; esac; }
uname_arch() { case "$(uname -m)" in x86_64|amd64) echo x64 ;; arm64|aarch64) echo arm64 ;; esac; }

run() { # run [args...]
  # Refuses to run an unsandboxed script rather than falling back to the real
  # environment, so a harness bug fails the suite instead of the machine.
  if [ -z "$ROOT" ] || [ -z "$BIN" ] || [ -z "$INSTALL" ]; then
    printf '    ✗ harness: setup() did not run; refusing to execute unsandboxed\n'
    exit 1
  fi
  OUT=$(env -i HOME="$ROOT/home" \
        PATH="$BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
        GITLEAKS_INSTALL_DIR="$INSTALL" \
        bash "$SCRIPT" "$@" 2>&1); RC=$?
}

expect_rc()  { [ "$RC" -eq "$1" ] && ok "$2" || bad "$2 — wanted exit $1, got $RC: $OUT"; }
expect_out() { grep -q -- "$1" <<<"$OUT" && ok "$2" || bad "$2 — output lacked '$1': $OUT"; }
expect_no_out() { grep -q -- "$1" <<<"$OUT" && bad "$2 — output contained '$1': $OUT" || ok "$2"; }

# --- session mode ---

setup; fake_gitleaks "$BIN" "$PINNED"
run --session
expect_rc 0 "session mode with gitleaks on PATH exits 0"
expect_out "available" "it reports the binary it found"
expect_no_out "not found" "it does not tell the user to install what is present"
rm -rf "$ROOT"

setup; fake_gitleaks "$INSTALL" "$PINNED"
run --session
expect_rc 0 "session mode finds gitleaks installed outside PATH"
expect_out "available" "an off-PATH install is reported as available"
expect_no_out "not found" "an off-PATH install is not reported missing"
expect_out "not on PATH" "it says the binary will not be found by a pre-commit hook"
rm -rf "$ROOT"

setup
run --session
expect_rc 0 "session mode with no gitleaks exits 0"
expect_out "not found" "a missing gitleaks prints install instructions"
[ -e "$ROOT/urls" ] && bad "session mode downloads nothing" || ok "session mode downloads nothing"
rm -rf "$ROOT"

# --- install mode ---

setup; fake_gitleaks "$BIN" "$PINNED"
run
expect_rc 0 "install mode with the pinned version already present exits 0"
expect_out "already installed" "it says the pinned version is already there"
[ -e "$ROOT/urls" ] && bad "an up-to-date install downloads nothing" || ok "an up-to-date install downloads nothing"
rm -rf "$ROOT"

setup; fake_gitleaks "$BIN" "8.18.0"; serve_release "$PINNED"
run
expect_rc 0 "install mode with an older version on PATH exits 0"
expect_out "8.18.0" "it names the version it found"
got=$("$INSTALL/gitleaks" version 2>/dev/null)
[ "$got" = "$PINNED" ] && ok "the pinned version is installed over an older one" \
  || bad "the pinned version is installed over an older one — got '$got'"
rm -rf "$ROOT"

# --- integrity of the download ---

setup; serve_release "$PINNED"
run
expect_rc 0 "a download matching its published checksum installs"
expect_out "Checksum verified" "the verification is reported"
rm -rf "$ROOT"

setup; serve_release "$PINNED" tamper
run
expect_rc 1 "a checksum mismatch exits 1"
expect_out "mismatch" "the mismatch is named"
expect_not_installed "a mismatched download is not installed"
rm -rf "$ROOT"

setup; serve_release "$PINNED" no-entry
run
expect_rc 1 "checksums without an entry for this asset exit 1"
expect_not_installed "an unlisted asset is not installed"
rm -rf "$ROOT"

setup; serve_release "$PINNED" no-sums
run
expect_rc 1 "an unavailable checksums file exits 1"
expect_not_installed "an unverifiable download is not installed"
rm -rf "$ROOT"

setup; serve_release "$PINNED"
printf 'not a tarball\n' > "$SERVE/gitleaks_${PINNED}_$(uname_os)_$(uname_arch).tar.gz"
sum=$(sha256 "$SERVE/gitleaks_${PINNED}_$(uname_os)_$(uname_arch).tar.gz")
printf '%s  %s\n' "$sum" "gitleaks_${PINNED}_$(uname_os)_$(uname_arch).tar.gz" \
  > "$SERVE/gitleaks_${PINNED}_checksums.txt"
run
expect_rc 1 "an archive that verifies but will not unpack exits 1"
expect_out "extract" "the extraction failure is named"
expect_not_installed "a corrupt archive installs nothing"
rm -rf "$ROOT"

# --- arguments ---

setup
run --help
expect_rc 0 "--help exits 0"
expect_out "Usage" "--help prints usage"
expect_no_out '\$0' "the usage does not print a literal \$0"
expect_out "gitleaks-setup.sh" "the usage names the script to run"
expect_not_installed "--help installs nothing"
rm -rf "$ROOT"

setup; serve_release "$PINNED"
run --sesion
expect_rc 1 "a mistyped flag exits 1 instead of installing"
expect_out "unknown option" "the unknown flag is named"
expect_not_installed "a mistyped flag installs nothing"
[ -e "$ROOT/urls" ] && bad "a mistyped flag downloads nothing" || ok "a mistyped flag downloads nothing"
rm -rf "$ROOT"

setup
run --session --extra
expect_rc 1 "an unexpected second argument exits 1"
rm -rf "$ROOT"

setup
run --session
expect_no_out '\$0' "the install instructions do not print a literal \$0"
expect_out "gitleaks-setup.sh" "the install instructions name the script to run"
rm -rf "$ROOT"

exit "$fails"
