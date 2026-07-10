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

`setup.sh` installs the shared skills and instructions, then symlinks the
`open-codespace` helper into `~/.local/bin`.

## Open a Codespace in Cursor

Run from any local directory:

```bash
open-codespace
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
4. This `dev-env` repository and its shared setup

Follow the background bootstrap from a Codespace terminal with:

```bash
tail -f /tmp/open-codespace-bootstrap.log
```

Pass a Codespace name to skip the selector:

```bash
open-codespace CODESPACE_NAME
```

## Layout

- `open-codespace` — local Cursor/GitHub Codespaces launcher and remote bootstrap.
- `setup.sh` — installs all helpers, skills, and shared instructions.
- `odoo-agent.md` — shared Odoo instructions installed for Claude and Codex.
- `<category>/<skill-name>/SKILL.md` — reusable agent skills.

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

Symlinks (not copies) are used, so edits in this repo are picked up by all tools immediately. Re-run `setup.sh` after adding a new skill.

## Agent instructions

`setup.sh` also installs the shared Odoo agent instructions (`odoo-agent.md`) into
each tool's global location:

- Claude → `~/.claude/CLAUDE.md` (symlink)
- Codex  → `~/.codex/AGENTS.md` (symlink)

An existing real file at either path is backed up to `*.bak.*` before linking.

### Cursor

Cursor has no reliable global rules *file* (its reliable global "User Rules" live
in the Settings UI, not on disk). So instructions are installed two ways:

- **Project rule** — pass an Odoo project directory and a generated rule is written
  to `<project>/.cursor/rules/odoo-agent.mdc` (with `alwaysApply: true`):

  ```bash
  bash setup.sh /workspaces/<project>
  ```

  It's generated (not symlinked) because the `.mdc` needs frontmatter; re-run after
  editing `odoo-agent.md`.
- **Global rule** — paste `odoo-agent.md` into **Cursor Settings → Rules** (User
  Rules) for a rule that applies across all projects.
