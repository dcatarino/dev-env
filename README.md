# dev-env

Personal skills repository, shared between **Claude Code**, **Codex**, and **Cursor**.

## Layout

Skills are grouped into category folders, with one folder per skill containing a `SKILL.md`:

```
<category>/
└── <skill-name>/
    └── SKILL.md
```

## Setup

Clone the repo and run:

```bash
bash setup.sh
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
