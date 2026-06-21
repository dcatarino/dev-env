# my-skills

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
