# Persisted agent memory

Claude Code writes auto-memory to `~/.claude/projects/<encoded-project-path>/memory/`.
Inside a Codespace that path is discarded on every rebuild, so everything the
agent learned about a customer environment is lost.

`remote-codespace-setup.sh` symlinks those directories into this one, so memory
survives rebuilds and follows you to any Codespace that runs the installer.

## Layout

One directory per project, named the way Claude Code encodes the project path
(`/workspaces/360_generic` → `-workspaces-360_generic`):

```
memory/
└── -workspaces-<project>/
    ├── MEMORY.md          # index — one line per memory
    └── <slug>.md          # one fact per file, with frontmatter
```

## This repository is private

It is private **because of this directory**. These files describe customer Odoo
versions, module sets, integration quirks, and project decisions. Do not make
the repository public again while it tracks memory.

## What must never be written here

Memory files are for durable technical facts. Never write:

- access tokens, API keys, passwords, cookies, or authorization headers;
- URLs containing `access_token` or any other credential parameter;
- customer email addresses, phone numbers, or personal contact details;
- database names, infrastructure identifiers, or private hostnames.

A fact that cannot be recorded without one of the above does not get recorded.
Strip the sensitive part and keep the reusable shape of the lesson — "this
customer's staging rebuilds drop `ir.config_parameter` overrides" rather than
the URL and credentials you used to find that out.

The `capture-customer-knowledge` skill applies these rules when it writes here.
They apply equally to memories Claude writes on its own.
