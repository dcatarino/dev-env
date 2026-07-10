# dev-env — repository guide

This is my personal **development environment repository**, shared across Claude
Code, Codex, and Cursor. It is the source of truth for reusable skills, shared
Odoo agent instructions, and local development helpers. `setup.sh` symlinks them
into each tool's global locations.

## What working in this repo means

When you're in this repo, the task is to **author, edit, review, or improve the
development environment artifacts** — not to perform the workflows that its
skills describe.

- **Do not invoke these skills as workflows just because a request seems to match
  their description.** Here, each `SKILL.md` is an artifact to maintain, not a
  procedure to run. (If I explicitly type `/<skill-name>`, that's different —
  honor it.)
- Treat the skills' own instructions (e.g. the Odoo `[ticket-XXXX]` commit format,
  the staging-branch steps) as content you maintain, not rules you must follow
  while editing this repo.

## Layout

- `odoo-dev-skills/<skill-name>/SKILL.md` — one folder per skill.
- `odoo-agent.md` — shared Odoo agent instructions. `setup.sh` installs this as
  the global `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`, so edits here change
  my global agent behavior in other projects.
- `open-codespace` — opens a selected GitHub Codespace in Cursor with both the
  repository and `/workspaces`, then starts a detached, idempotent bootstrap.
  The bootstrap order is Claude Code, NVM/Node 22, Codex, then cloning and
  running this repository's setup. Its remote files live under `/tmp`; it must
  not change the selected project repository.
- `setup.sh` — installs the launcher, skills, and agent instructions via
  symlinks. Re-run after adding a skill or on a new development machine.
- `README.md` — human-facing overview.

## Editing development helpers

- Keep `open-codespace` non-blocking: Cursor must launch before the detached
  tool/bootstrap installation begins.
- Preserve the dedicated `~/.ssh/codespaces` include instead of appending
  generated host blocks repeatedly to `~/.ssh/config`.
- Keep the remote bootstrap safe to rerun and guarded against concurrent runs.
- Preserve the intentional sandboxed Claude alias unless explicitly asked to
  change it.
- Validate shell changes with `bash -n`; run `shellcheck` when available.

## Editing skills

- Keep the `SKILL.md` frontmatter intact: `name`, `description`, `version`.
- Bump `version` when you change a skill's behavior.
- Match the existing tone and structure of the other skills, and keep each
  `description` specific enough that the right skill stays discoverable.
- Keep changes focused (KISS/YAGNI) — don't refactor unrelated skills.

## Commits in this repo

This meta-repo is not an Odoo project, so the Odoo rules from my global agent
instructions (per-change ticket identifier, always-plan-mode, pre-commit) do
**not** apply to changes made here. Use plain, descriptive commit messages in the
style of the existing history, ending with a `Co-Authored-By` trailer naming the
model that authored the change. Only commit or push when I ask.
