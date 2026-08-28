# env-setup — gitleaks bootstrap

Idempotent `SessionStart` hook that makes sure [gitleaks](https://github.com/gitleaks/gitleaks)
is available, so a repo's fail-closed secret-scan pre-commit hook (e.g. a `.husky/pre-commit`
that shells out to `gitleaks protect --staged`) actually has the binary it needs.

Generic on purpose: this plugin only deals with gitleaks. It does not install project
dependencies (`npm install`, `pnpm install`, etc.) — that stays project-local because
different repos use different package managers and lockfiles.

## What the hook does

On every `SessionStart` (`startup` or `resume`) it runs `scripts/gitleaks-setup.sh --session`:

- If `gitleaks` is already on `PATH`, it no-ops.
- If not, it prints a warning with install instructions and exits `0` — a missing
  gitleaks binary never blocks a session from starting; it's the consuming repo's own
  pre-commit hook that should fail closed if the scan can't run.

The same script also has a fuller, non-`--session` path meant for provisioning a
sandbox/environment from scratch (e.g. a Dockerfile build step, or a one-off setup
script you run yourself): it downloads the pinned gitleaks release tarball that matches
the current OS/arch from GitHub releases and installs it to `~/.local/bin` (override
with `GITLEAKS_INSTALL_DIR`). Run it directly:

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

If a repo currently has its own gitleaks-install logic (e.g. dassie-dashboard's
`scripts/claude-env-setup.sh`, wired into its `SessionStart` hook), enabling this plugin
makes that logic redundant. Once enabled here, drop the gitleaks block from the
project-local script and keep only what's genuinely project-specific (dependency install,
etc.).
