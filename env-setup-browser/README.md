# env-setup-browser — Playwright Chromium bootstrap

Optional `SessionStart` hook that installs Playwright's Chromium browser (with OS-level
deps) for repos that do browser-based visual UI verification.

This is a separate plugin from `env-setup` on purpose: not every repo that wants a pinned
gitleaks binary also needs a browser, and vice versa. Enable whichever one(s) a given repo
actually needs.

## What the hook does

On every `SessionStart` (`startup` or `resume`) it runs
`scripts/playwright-chromium-setup.sh`, which:

- Skips (with a warning) unless `node_modules/.bin/playwright` exists — the plugin
  bootstraps a browser for repos that already depend on Playwright, and never installs
  the Playwright package itself. In a workspace, start the session from the package that
  depends on Playwright; a nested `node_modules` is not found from the repo root.
- Otherwise runs that binary as `playwright install chromium --with-deps`, which
  Playwright already makes idempotent — an already-installed Chromium is a fast no-op.

The hook is given a `timeout` of 900 seconds rather than the 600-second default for
command hooks. A cold Chromium download plus OS packages can outrun ten minutes on a slow
link, and a hook killed mid-download leaves a partial install to be redone next session.
That cost is first-run only; afterwards the hook is a no-op.

> [!warning] `--with-deps` installs OS packages through `sudo`
> On Linux, Playwright shells out to `sudo apt-get install …` for the browser's system
> dependencies. From a `SessionStart` hook there is no TTY, so on most machines sudo
> simply fails and the script degrades to a warning — but on a machine with NOPASSWD
> sudo this performs privileged package installation without asking. Set
> `ENV_SETUP_BROWSER_WITH_DEPS=0` to install the browser only and leave OS packages alone.

## Enabling this plugin in a consuming repo

```bash
claude plugin marketplace add lmchoi/coretex
claude plugin install env-setup-browser@coretex
```

Or directly in `.claude/settings.json`:

```jsonc
{
  "enabledPlugins": {
    "env-setup-browser@coretex": true
  }
}
```

## Not included: permissions

Same caveat as `env-setup`: this plugin can't inject `permissions.allow` /
`permissions.deny` entries into a consuming repo. If your settings would otherwise prompt
for the hook's `bash`/`playwright` calls, add the allow rules in that repo's own
`.claude/settings.json`.

## Scripts

| Script | What it does |
|---|---|
| `playwright-chromium-setup.sh` | Runs the repo's own `node_modules/.bin/playwright install chromium`, adding `--with-deps` unless `ENV_SETUP_BROWSER_WITH_DEPS=0`. Skips with a warning if Playwright is not a dependency. Never exits non-zero — a browser it cannot install must not stop a session. |

It has behaviour tests alongside it (`*.test.sh`), run by this repo's `test` command
via `tests/run.sh`.
