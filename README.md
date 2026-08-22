# coretex

Reusable [Claude Code plugins](https://code.claude.com/docs/en/plugins) extracted from
working repos. Five plugins, installable independently:

| Plugin | What it gives you | Assumes |
|---|---|---|
| `sp` | Guarded slice workflow: `/sp:refine` → `/sp:start` → `/sp:implement` → `/sp:commit` → `/sp:push` → `/sp:done`, plus `/sp:fix` for bugs. TDD, atomic commits, worktree per slice. Ships `plan-reviewer` and `skill-auditor` agents and a post-edit lint hook. | Any repo. Needs an `### sp config` section in the host `CLAUDE.md` (see `sp/README.md`). |
| `pm` | `/pm:doc-interview` — builds a PRD or any contested living document section by section, interview-style, with Open → Drafted → Agreed statuses. | Any repo with docs worth interrogating. |
| `evalcraft` | `/evalcraft:refine-scorer` (deterministic-first scorer design), `/evalcraft:report-fact-check` (verify report claims against sources and logs), and the `eval-methodology-reviewer` agent. | An [Inspect AI](https://inspect.aisi.org.uk) eval repo. |
| `sitecheck` | `/sitecheck:ai-visibility` — audits a site's `robots.txt`, `llms.txt` and sitemap, tests whether live crawler access matches the stated policy, and cross-checks any growth claim against the Wayback Machine so a self-reported number (e.g. a sitemap `lastmod` spike) can't pass as fact unchecked. Ships as one deterministic script (`scripts/audit.py`, stdlib-only) plus interpretation guidance. | Nothing beyond internet access — works against any public website. |

## Install

```bash
claude plugin marketplace add lmchoi/coretex
claude plugin install sp@coretex
claude plugin install evalcraft@coretex   # etc.
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
