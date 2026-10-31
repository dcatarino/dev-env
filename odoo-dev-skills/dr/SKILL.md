---
name: dr
description: This skill should be used when the user invokes /dr with a 360ERP development request ID or URL, optionally followed by plan, ship or merge — e.g. "/dr 2171", "/dr 2171 plan", "/dr 2171 ship", "/dr https://www.360erp.com/odoo/action-2929/2171 ship merge". It runs the whole ticket loop in one go — read the request and its chatter, work in the request's own task worktree on a `<version>-request-<id>` branch, implement, test, and with ship commit, open the `<version>` and `<version>-staging` PRs and end with the consultant handoff — reporting its progress as a lane the chief agent can see.
version: 1.0.0
---

# `/dr` — one development request, start to finish

```
/dr <id or URL> [plan | ship] [merge]
```

The user types this instead of restating the same flow in every ticket ("read
the request and chatter, use a worktree, create a PR to X and X-staging, squash
merge when CI passes, ask me if something isn't clear"). The defaults below are
that flow. Anything else the user writes after the arguments overrides them.

## What each form authorizes

| Form | Does | Stops after |
| --- | --- | --- |
| `/dr 2171` | read, plan, implement, test | tested change, uncommitted; asks "ship?" |
| `/dr 2171 plan` | read, plan | the plan |
| `/dr 2171 ship` | the above, then commit and `odoo-ship` to `<version>` and `<version>-staging` | PRs open, CI watched |
| `/dr 2171 ship merge` | the above, then `odoo-ship --merge` | both PRs squash-merged once CI passed |

- Invoking `/dr` is the explicit request the `development-request` live-data
  gate asks for: read that record, its ticket or task, its chatter and its
  customer environment through the 360 ERP Odoo MCP. Nothing else in 360.
- `ship` is the explicit request for commit, push, both PRs and `/run-tests`.
  `merge` is the explicit "squash merge when CI passes" for exactly those PRs.
  A merge to `<version>-staging` deploys staging; say so when it happens.
- Never, whatever the form: write to 360 (chatter, stage, timesheets), merge
  anything you did not ship in this run, or touch production — deploys, module
  installs, cron runs or data fixes there stay with the user.
- The identifier is `request-<id>`, from the argument. Never invent another.

## Lane status

When `360-work` is on the PATH and the session runs in a 360-work workspace,
report each transition so the chief agent and the user's notifications follow
the request without reading this session:

```bash
360-work lane set <state> --request <id> --summary "<one line>" [--pr <url>]...
```

`working` at the start; `needs-decision` right before asking the user anything;
`working` again once answered; `watching` after starting the CI watcher;
`ready` when the run stops for the user (plan ready, tested and not shipped, or
PRs open); `merged` after `--merge` merged everything; `failed` with the reason
when blocked. `needs-decision`, `ready`, `merged` and `failed` notify the user.
Elsewhere (a Codespace) skip this step; it is never a reason to stop.

## Steps

1. **Read the request.** Follow `development-request` (retrieval, evidence
   hierarchy, verifying earlier analysis). When the chatter is long (more
   than ~15 messages or large attachments), hand the reading to a subagent on
   a small model (Claude: `haiku`) and ask it for the decisions in date order,
   the newest requirement, open questions and quoted evidence. Keep the raw
   thread out of this session.
2. **Pick the workspace.** In a local 360-work setup, work in the request's
   own task so other agents on the same customer are never disturbed:
   - Already in a task whose `context/task.json` name ends in
     `request-<id>`: use it (the chief's `360-work dr start` created it).
   - Otherwise resolve the preset from the customer environment
     (`360-work presets`; `<data root>/chief/aliases.json` maps 360 names such
     as `VytaHealth` to presets when it exists), then run
     `360-work update <preset>` and
     `360-work task <preset>-request-<id> --env <preset> --primary <role>`,
     and work in that folder. Name the path in your first reply.
   - In a Codespace, use the checkout `development-request` resolves.
3. **Branch.** In each repository you change, fetch and start
   `<version>-request-<id>` from `origin/<version>`, where `<version>` is that
   repository's Odoo version (`context/task.json`, or its branches). This is the
   name `odoo-ship` reads the version from.
4. **Decide.** Ask only when no safe default exists, the request contradicts
   itself, or the answer changes the design. Set `needs-decision`, then put
   every question in one message (one `AskUserQuestion`), each with your
   recommended answer. Otherwise state assumptions in the plan and continue.
   Size the plan as `odoo-agent.md` says. With `plan`, stop here.
5. **Implement and test.** Smallest maintainable change, the
   `development-request` new-module checklist for a new module, and the tests
   of the changed modules with `run-odoo-tests`. Browser checks follow
   `test-odoo-ui` when the change is visible in the UI.
6. **Ship** (only with `ship`). Commit with `odoo-commit`, then ship each
   changed repository with `odoo-ship` (`--merge` with `merge`;
   `360_integrations` stays `18.0` only, as that skill says). Start its CI
   watcher in the background and set `watching`.
7. **Write the progress note.** In the task folder, write `context/dr.md`:
   the request in two lines, decisions and assumptions with who made them,
   branches, PR URLs, test results, open questions, next step. A new session
   in any harness or account resumes from this file, so keep it current at
   each stop.
8. **Report and hand off.** Set the final lane state with the PR URLs. Lead
   with the result: PR URLs (or "tested, not shipped — `ship` to open the
   PRs"), what was run and its result, anything not verified. Then the
   `odoo-ship` handoff, and without `ship` the consultant message only once
   the PRs exist.

## Gotchas

- **Asking what the command already said.** `/dr 2171 ship` already asked for
  both PRs; never ask "should I create the PRs?". Without `ship`, ask once at
  the end, not before testing.
- **Working in the environment checkout.** The user usually has other agents
  on the same customer; a task worktree is the default, not an option.
- **Shipping from `work/<task>`.** Task worktrees start on `work/<name>`;
  create `<version>-request-<id>` before the first commit or `odoo-ship`
  cannot read the version.
- **Losing state on compaction or a limit.** Update `context/dr.md` before a
  long step, not only at the end.
