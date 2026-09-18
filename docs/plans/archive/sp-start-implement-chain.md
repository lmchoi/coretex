# Plan: chain sp:start directly into sp:implement

## Goal

`/sp:start` runs `/sp:implement` itself once the worktree is created, instead of telling
the user to run it as a separate step.

## Out of scope

- The "ledger" (a per-slice progress file) named as part of slice 2 in the archived
  `sp-guard-scripts` plan. Not needed for a same-conversation handoff; revisit only if a
  real cross-session resume need shows up.
- Teaching `/sp:implement` to bootstrap its own worktree when none exists (the
  "implement without start" case). Real gap, deliberately deferred to its own
  `/sp:refine`.
- Any change to `/sp:fix`, which already creates its own worktree inline for its own,
  simpler (no-plan, single-commit) workflow — unaffected by this slice.
- Auditing the sp skills for other stale/unimplemented references (separate backlog
  item, tracked outside this plan — `sp:skill-auditor` is the tool for it).

## Design

`/sp:implement`'s own Step 3.4 already instructs the agent to "Run `/sp:commit`"
mid-loop, with no user step in between — proof this pattern already works inside the sp
plugin. This slice applies the same pattern one level up: `/sp:start`'s closing step
changes from telling the user to run `/sp:implement` to running it directly.

`sp:start` keeps its `model: haiku` frontmatter — cheap for its own worktree-creation
work. Verified in this session: invoking a skill via the Skill tool switches the running
model to that skill's declared model, mid-conversation, not just on a user-typed slash
command (observed when `/sp:refine`, `model: opus`, was invoked from a Sonnet-running
turn). So no model unification is needed — sonnet applies automatically once
`/sp:implement` loads.

No new interfaces, scripts, or config keys. Two-word change in imperative mood, plus
docs to match.

### Files affected

- `sp/skills/start/SKILL.md`
- `sp/README.md`
- `sp/.claude-plugin/plugin.json`

## Commits

1. `feat: chain sp:start directly into sp:implement` — edit `start/SKILL.md` Step 3 so
   it reports the worktree path/branch, then runs `/sp:implement` instead of telling the
   user to run it.
   test: none automated — this is agent-facing prose, not code (same known limitation
   the archived `sp-guard-scripts` plan accepted for its own prose-only commits).
   `check.sh` stays green (structural validation only). Manually verified by running
   `/sp:start` against a real plan and confirming it proceeds into the TDD loop without
   stopping.

2. `docs: update sp README for the start->implement handoff` — update the workflow
   diagram and the `start` row of the skills table to show the automatic chain instead
   of a manual handoff.
   test: none — docs only; `check.sh` green.

3. `chore: bump sp plugin version` — patch bump in `sp/.claude-plugin/plugin.json`,
   following the precedent in the archived `sp-guard-scripts` plan (the plugin cache is
   keyed by version; without a bump, installed machines can keep serving the old build).
   test: `check.sh` green (validates `version` is present).
