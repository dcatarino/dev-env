# dev-env — repository guide

This is my personal **development environment repository**, shared across Claude
Code, Codex, and Cursor. It is the source of truth for reusable skills, shared
Odoo agent instructions, and local development helpers. `setup.sh` symlinks the
local launchers and helpers into the command path, while
`remote-codespace-setup.sh` installs skills and agent instructions inside
Codespaces.

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
- **Exception:** `self-improvement-dev-env` is a workflow meant to run *on* this
  repo. It is manual-only (`disable-model-invocation: true`) — follow it when I
  invoke `/self-improvement-dev-env`.

## Layout

- `odoo-dev-skills/<skill-name>/SKILL.md` — one folder per skill (Odoo work).
- `meta-skills/<skill-name>/SKILL.md` — skills about the dev environment itself
  (`self-improvement-dev-env`, `capture-customer-knowledge`).
- `odoo-agent.md` — shared Odoo agent instructions.
  `remote-codespace-setup.sh` installs this as the global
  `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` inside Codespaces, so edits here
  change my agent behavior in other Codespace projects.
- `open-codespace-cursor` — opens a selected GitHub Codespace in Cursor with
  both the repository and `/workspaces`, then starts a detached, idempotent
  bootstrap.
- `open-codespace-cursor-ide` — opens the same workspace through Cursor's
  remote protocol handler in the classic IDE/editor window, which is the
  reliable Remote SSH layout.
- `open-codespace-cursor-mac` — opens the same workspace through macOS's
  Cursor URL handler, without requiring Cursor's shell command.
- `open-codespace-terminal` — starts the same detached bootstrap and connects
  the current terminal to `/workspaces` in the selected Codespace.
- `open-codespace-common.sh` — shared Codespace selection, SSH configuration,
  and remote bootstrap implementation. The bootstrap order is Claude Code,
  NVM/Node 22, Codex, then cloning and running this repository's remote setup.
  Its remote files live under `/tmp`; it must not change the selected project.
- `setup.sh` — local-only installer that symlinks the launchers into
  `~/.local/bin`. It must not install skills or agent instructions locally.
- `remote-codespace-setup.sh` — installs skills and shared agent instructions
  inside a Codespace, warms `pre-commit` environments for configured Git
  repositories under `/workspaces`, and persists agent memory. Both launchers
  update the remote `dev-env` checkout and invoke this script automatically.
- `persist-agent-memory.sh` — symlinks Claude Code's per-project auto-memory
  into `memory/` so it survives a Codespace rebuild. Invoked by
  `remote-codespace-setup.sh`; test hooks let `tests/` drive it against a fake
  tree.
- `memory/` — persisted agent memory, one directory per project.
  **This repository is private because of this directory** — it holds learned
  facts about customer Odoo environments. Read `memory/README.md` before
  changing the repository's visibility or the rules about what may be written
  there.
- `README.md` — human-facing overview.

## Editing development helpers

- Keep both launchers non-blocking. Cursor must launch before its detached
  bootstrap and synchronous port publication begin; terminal mode starts port
  publication and the bootstrap in the background, then connects immediately.
- Keep Odoo port 8069 private by default. Publish and report its public URL
  only when a launcher is invoked with `--public`; `test-odoo-ui` publishes it
  when browser verification needs it.
- Preserve the dedicated `~/.ssh/codespaces` include instead of appending
  generated host blocks repeatedly to `~/.ssh/config`.
- Keep the remote bootstrap safe to rerun and guarded against concurrent runs.
- Keep local and remote responsibilities separate: `setup.sh` installs only the
  launcher locally; `remote-codespace-setup.sh` owns agent setup remotely.
- `persist-agent-memory.sh` deletes the live memory directory after copying it
  into the store. Keep its test (`tests/persist-agent-memory-test.sh`) passing
  and never make the copy clobber an already-persisted file.
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
instructions (per-change ticket identifier, always-plan-mode, pre-commit,
`/run-tests` CI comments) do **not** apply to changes made here. Those
instructions only exist inside a Codespace, where `remote-codespace-setup.sh`
installs `odoo-agent.md` as the global agent file — they are never in force
while working on this repository. This repo has no CI pipeline; never comment
`/run-tests` on a `dev-env` push or PR.

Use plain, descriptive commit messages in the style of the existing history,
ending with a `Co-Authored-By` trailer naming the model that authored the
change. Only commit or push when I ask.
