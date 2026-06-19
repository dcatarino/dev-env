# my-skills

Personal skills repository, shared between **Claude Code** and **Codex**.

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

This finds every `SKILL.md` and symlinks its folder into both tools' skill directories:

- Claude → `~/.claude/skills/<name>/`
- Codex  → `~/.agents/skills/<name>/`

Symlinks (not copies) are used, so edits in this repo are picked up by both tools immediately. Re-run `setup.sh` after adding a new skill.
