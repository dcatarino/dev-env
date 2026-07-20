# dev-env

Personal development environment shared between **Claude Code**, **Codex**, and
**Cursor**. It contains reusable agent skills, shared instructions, and local
development helpers.

## Setup

Clone the repository and run:

```bash
git clone https://github.com/dcatarino/dev-env
bash dev-env/setup.sh
```

`setup.sh` is only for the local computer. It symlinks the Cursor and terminal
Codespace helpers into `~/.local/bin`; it does not install agent skills or
instructions locally.

## Open a Codespace in Cursor

Run from any local directory:

```bash
open-codespace-cursor
```

The helper lets you select a GitHub Codespace, refreshes its dedicated SSH
configuration, and opens a temporary Cursor multi-root workspace containing
both `/workspaces/<repository>` and `/workspaces`. It does not modify the
selected repository.

After Cursor is launched, a detached bootstrap installs missing tools in this
order:

1. Claude Code
2. NVM and Node.js 22
3. Codex
4. This `dev-env` repository and its remote Codespace setup

The final step clones or updates `dev-env` inside the Codespace and runs
`remote-codespace-setup.sh` there. This installs the shared skills and agent
instructions automatically; the remote installer does not need to be run on
the local computer.

Every time either launcher opens a Codespace, it also makes the already
forwarded Odoo port `8069` public. Cursor receives its open request and starts
the detached bootstrap before publishing the port, so this GitHub API request
cannot delay the application opening. Terminal mode publishes the port in the
background so its connection is not held up. Odoo is then available to
browser-capable agents at:

```text
https://CODESPACE_NAME-8069.app.github.dev/
```

The launcher reports an error after Cursor starts, or in the terminal
background, if port `8069` is not forwarded or a GitHub organization policy
prevents public ports. A public port can be reached by anyone who knows its
URL, so Odoo's own authentication remains important.

Follow the background bootstrap from a Codespace terminal with:

```bash
tail -f /tmp/open-codespace-bootstrap.log
```

Pass a Codespace name or URL to skip the selector:

```bash
open-codespace-cursor CODESPACE_NAME
open-codespace-cursor https://CODESPACE_NAME.github.dev/
open-codespace-cursor https://github.com/codespaces/CODESPACE_NAME
```

## Open a Codespace in the terminal

From Warp or any other terminal, run:

```bash
open-codespace-terminal
```

The helper performs the same Codespace selection, SSH configuration, and
background setup as the Cursor launcher, then connects the current terminal to
the Codespace and starts an interactive shell in `/workspaces`. Cursor is not
required.

Setup runs in the background, so the terminal connects immediately. Follow its
progress from the Codespace with:

```bash
tail -f /tmp/open-codespace-bootstrap.log
```

Pass a Codespace name or URL to skip the selector:

```bash
open-codespace-terminal CODESPACE_NAME
open-codespace-terminal https://CODESPACE_NAME.github.dev/
open-codespace-terminal https://github.com/codespaces/CODESPACE_NAME
```

## Layout

- `open-codespace-cursor` — local Cursor/GitHub Codespaces launcher.
- `open-codespace-terminal` — terminal-based Codespaces launcher.
- `open-codespace-common.sh` — shared SSH and remote bootstrap implementation.
- `setup.sh` — local-only installer for both launcher commands.
- `remote-codespace-setup.sh` — remote installer for skills and shared agent
  instructions, invoked automatically by both launchers.
- `odoo-agent.md` — shared Odoo instructions installed for Claude and Codex.
- `<category>/<skill-name>/SKILL.md` — reusable agent skills.

Current skills (`odoo-dev-skills/`): `odoo-commit`, `odoo-staging-branch`,
`odoo-pr`, `odoo-integrations`, `run-odoo-tests`.
Meta skills (`meta-skills/`): `self-improvement-dev-env` — improves this repo's
prompts/skills from recent agent session history.

Skills are grouped into category folders, with one folder per skill containing
a `SKILL.md`:

```
<category>/
└── <skill-name>/
    └── SKILL.md
```

This finds every `SKILL.md` and symlinks it into each tool's skills/rules directory:

- Claude  → `~/.claude/skills/<name>/` (folder symlink)
- Codex   → `~/.agents/skills/<name>/` (folder symlink)
- Cursor  → `~/.cursor/skills/<name>/` (folder symlink)

Symlinks (not copies) are used, so edits in the Codespace checkout are picked up
by all tools immediately. Both Codespace launchers update the checkout and rerun
the remote installer whenever a Codespace is opened.

## Agent instructions

`remote-codespace-setup.sh` installs the shared Odoo agent instructions
(`odoo-agent.md`) into each tool's global location:

- Claude → `~/.claude/CLAUDE.md` (symlink)
- Codex  → `~/.codex/AGENTS.md` (symlink)

An existing real file at either path is backed up to `*.bak.*` before linking.

### Cursor

Cursor has no reliable global rules *file* (its reliable global "User Rules" live
in the Settings UI, not on disk). So instructions are installed two ways:

- **Project rule** — pass an Odoo project directory and a generated rule is written
  to `<project>/.cursor/rules/odoo-agent.mdc` (with `alwaysApply: true`):

  ```bash
  bash remote-codespace-setup.sh /workspaces/<project>
  ```

  It's generated (not symlinked) because the `.mdc` needs frontmatter; re-run after
  editing `odoo-agent.md`.
- **Global rule** — paste `odoo-agent.md` into **Cursor Settings → Rules** (User
  Rules) for a rule that applies across all projects.
