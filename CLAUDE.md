# coretex

> [!warning] 🔴 This repo is PUBLIC on GitHub
> Everything committed here is world-readable. Do not add client, prospect or personal-journal
> content — no real people's names, no pharma account names, no outreach drafts, no material
> copied from the sibling `noted/` repo. When in doubt, leave it out.

## Working in this repo

coretex holds Claude Code plugins. There is no application code — the deliverable is
instruction files, so "does it work" means the structure validates and the instructions
survive being followed.

### sp config

- test: `./scripts/check.sh`   # structural validation of every plugin, skill and agent
- plans: `docs/plans/`
- docs: `docs/`

Testing note: `scripts/check.sh` validates structure, not behaviour. Prose that instructs
an agent is tested by the consuming agent's behaviour, not by asserting the file contains
a line — a check that greps for its own wording only proves the source is the source.
