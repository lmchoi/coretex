# env-setup — gitleaks bootstrap

Idempotent `SessionStart` hook that makes sure [gitleaks](https://github.com/gitleaks/gitleaks)
is available, so a repo's fail-closed secret-scan pre-commit hook (e.g. a `.husky/pre-commit`
that shells out to `gitleaks protect --staged`) actually has the binary it needs.

Generic on purpose: this plugin only deals with gitleaks. It does not install project
dependencies (`npm install`, `pnpm install`, etc.) — that stays project-local because
different repos use different package managers and lockfiles.

## What the hook does

On every `SessionStart` (`startup` or `resume`) it runs `scripts/gitleaks-setup.sh --session`:

- If `gitleaks` is on `PATH`, it no-ops.
- If it is not on `PATH` but has been installed into the install directory, it says so
  and points out that a pre-commit hook shelling out to `gitleaks` still will not find
  it — the install is not the problem, the profile is.
- Otherwise it prints a warning with install instructions and exits `0` — a missing
  gitleaks binary never blocks a session from starting; it's the consuming repo's own
  pre-commit hook that should fail closed if the scan can't run.

The same script also has a fuller, non-`--session` path meant for provisioning a
sandbox/environment from scratch (e.g. a Dockerfile build step, or a one-off setup
script you run yourself): it downloads the pinned gitleaks release tarball that matches
the current OS/arch from GitHub releases, **verifies it against the checksums published
with that release**, and installs it to `~/.local/bin` (override with
`GITLEAKS_INSTALL_DIR`). A download that fails verification is never installed — the
binary would go onto `PATH` and be executed by a pre-commit hook on every commit.

That path is idempotent on the *pinned version*, not merely on the name: a machine that
already has some other gitleaks still gets the version this plugin pins. Run it
directly:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/gitleaks-setup.sh"
```

The pinned version defaults to `8.30.1`; override with `GITLEAKS_VERSION=x.y.z` if a repo
needs a different one.

## Enabling this plugin in a consuming repo

Add the marketplace once, then enable the plugin:

```bash
claude plugin marketplace add lmchoi/coretex
claude plugin install env-setup@coretex
```

Or add it directly to the repo's `.claude/settings.json`:

```jsonc
{
  "enabledPlugins": {
    "env-setup@coretex": true
  }
}
```

## Not included: permissions

This plugin cannot inject `permissions.allow` / `permissions.deny` entries into a
consuming repo — Claude Code plugins have no mechanism for that. If your repo's settings
are locked down enough that the hook's `bash`/`curl`/`tar` calls would otherwise need
approval, add the necessary allow rules to that repo's own `.claude/settings.json` (or to
org-wide managed settings if you have admin access). That's out of scope for this plugin.

## Migrating off a project-local copy

If a repo currently has its own gitleaks-install logic — typically a project-local
setup script wired into its own `SessionStart` hook — enabling this plugin makes that
logic redundant. Drop the gitleaks block from the project-local script and keep only what
is genuinely project-specific (dependency install, etc.).

## Scripts

| Script | What it does |
|---|---|
| `gitleaks-setup.sh --session` | Reports whether gitleaks is available, looking on `PATH` and then in the install directory. Never downloads, never exits non-zero — a missing scanner must not stop a session. |
| `gitleaks-setup.sh` | Installs the pinned version, verified against the release checksums. Exits `1` rather than install anything unverified or unextractable; exits `0` when the environment simply cannot install (unsupported OS/arch, download failure). |
| `gitleaks-setup.sh --help` | Usage, including the pinned version and install directory in force. |

It has behaviour tests alongside it (`*.test.sh`), run by this repo's `test` command via
`tests/run.sh`. They run against a fake `curl` and a redirected `HOME`, so the suite never
reaches the network or installs anything on the machine running it.
