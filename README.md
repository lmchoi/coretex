# coretex

Reusable [Claude Code plugins](https://code.claude.com/docs/en/plugins) extracted from
working repos. Five plugins, installable independently:

| Plugin | What it gives you | Assumes |
|---|---|---|
| `sp` | Guarded slice workflow: `/sp:refine` → `/sp:start` → `/sp:implement` → `/sp:commit` → `/sp:push` → `/sp:done`, plus `/sp:fix` for bugs. TDD, atomic commits, worktree per slice. Ships `plan-reviewer` and `skill-auditor` agents and a post-edit lint hook. | Any repo. Needs an `### sp config` section in the host `CLAUDE.md` (see `sp/README.md`). |
| `pm` | `/pm:doc-interview` — builds a PRD or any contested living document section by section, interview-style, with Open → Drafted → Agreed statuses. | Any repo with docs worth interrogating. |
| `evalcraft` | `/evalcraft:refine-scorer` (deterministic-first scorer design), `/evalcraft:report-fact-check` (verify report claims against sources and logs), and the `eval-methodology-reviewer` agent. | An [Inspect AI](https://inspect.aisi.org.uk) eval repo. |
| `env-setup` | `SessionStart` hook that keeps a pinned [gitleaks](https://github.com/gitleaks/gitleaks) binary available for a fail-closed secret-scan pre-commit hook — fast check-and-warn on session start, fuller from-scratch install on demand. | Any repo whose pre-commit hook shells out to `gitleaks`. |
| `env-setup-browser` | `SessionStart` hook that installs Playwright's Chromium (with OS deps) for browser-based visual UI verification. Independent of `env-setup` — enable only if needed. | Any repo using Playwright for visual verification. |

## Install

```bash
claude plugin marketplace add lmchoi/coretex
claude plugin install sp@coretex
claude plugin install evalcraft@coretex   # etc.
claude plugin install env-setup@coretex
claude plugin install env-setup-browser@coretex   # optional, only if you need a browser
```

## Design conventions shared by all plugins

- **Guards over guesses.** Skills refuse loudly when a precondition is missing
  (no plan file, no worktree, unmerged PR, missing config) instead of improvising.
- **Host config lives in the host.** Plugins never hardcode a repo's test command or
  paths; they read them from the host repo's `CLAUDE.md` (see each plugin's README).
- **Reviewer agents start cold** and read the artifact named in their task prompt in
  full; they end with a verdict first, findings second, and never invent findings to
  seem thorough.
- **Skills are maintained like code.** If a skill instruction fails because the repo
  changed under it, fix the skill file as part of the current slice — the `sp` plugin's
  `skill-auditor` agent exists to catch this drift.
