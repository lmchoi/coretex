# env-setup-browser — Playwright Chromium bootstrap

Optional `SessionStart` hook that installs Playwright's Chromium browser (with OS-level
deps) for repos that do browser-based visual UI verification.

This is a separate plugin from `env-setup` on purpose: not every repo that wants a pinned
gitleaks binary also needs a browser, and vice versa. Enable whichever one(s) a given repo
actually needs.

## What the hook does

On every `SessionStart` (`startup` or `resume`) it runs
`scripts/playwright-chromium-setup.sh`, which:

- Skips (with a warning) if `npx` isn't on `PATH`, or if `node_modules` doesn't exist yet
  (i.e. dependencies haven't been installed — that step stays project-local).
- Otherwise runs `npx playwright install chromium --with-deps`, which Playwright already
  makes idempotent — an already-installed Chromium is a fast no-op.

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
for the hook's `npx`/`playwright` calls, add the allow rules in that repo's own
`.claude/settings.json`.
