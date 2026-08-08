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
instructions, GitHub CLI, and the Playwright/Chromium browser runtime
automatically. It also installs `pre-commit` when needed and warms the hook
environments for every Git repository under `/workspaces` with a root
`.pre-commit-config.yaml` or `.yml`, including nested submodules. The remote
installer does not need to be run on the local computer. Tool installation is
best-effort so a temporary package-source failure does not prevent the agent
configuration from being refreshed.

The setup keeps one hash of every `SKILL.md` plus `odoo-agent.md`. If that hash
changed since the previous Codespace opening, the bootstrap log says to start a
new Claude, Codex, or Cursor chat; running chats cannot reload context that was
read at startup. If the hash is unchanged, no reload is needed.

By default, the launcher makes Odoo port `8069` private. To make the already
forwarded port public for browser-capable agents, pass `--public`. Cursor
receives its open request and starts the detached bootstrap before publishing
the port, so this GitHub API request cannot delay the application opening.
Terminal mode publishes the port in the background so its connection is not
held up. Odoo is then available at:

```text
https://CODESPACE_NAME-8069.app.github.dev/
```

When `--public` is used, the launcher reports an error after Cursor starts, or
in the terminal background, if port `8069` is not forwarded or a GitHub
organization policy prevents public ports. A public port can be reached by
anyone who knows its URL, so Odoo's own authentication remains important.

Follow the background bootstrap from a Codespace terminal with:

```bash
tail -f /tmp/open-codespace-bootstrap.log
```

Pass a Codespace name or URL to skip the selector:

```bash
open-codespace-cursor CODESPACE_NAME
open-codespace-cursor --public CODESPACE_NAME
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
open-codespace-terminal --public CODESPACE_NAME
open-codespace-terminal https://CODESPACE_NAME.github.dev/
open-codespace-terminal https://github.com/codespaces/CODESPACE_NAME
```

## Sync the Claude Code token to Codespaces

Codespaces run `claude` non-interactively via the sandboxed alias installed by
`remote-codespace-setup.sh`; without a token it falls back to an interactive
login. To give it one, run `claude setup-token` locally, then:

```bash
sync-claude-token-to-codespace
```

This lists the repositories behind your current Codespaces, lets you pick one
(or all), and pushes the token to GitHub as a **Codespaces user secret**
scoped to the chosen repositories, using `gh secret set --user`. GitHub then
injects it into matching Codespaces as the `CLAUDE_CODE_OAUTH_TOKEN`
environment variable — the same variable `claude` reads for headless auth.

This is deliberately the only sync path:

- The token is never accepted as a command-line argument (that would leak
  into shell history and `ps`); the script reads it from an already-exported
  `CLAUDE_CODE_OAUTH_TOKEN` or a hidden prompt, then pipes it straight into
  `gh secret set`'s stdin.
- `gh` encrypts the value locally before it leaves this machine — it is never
  written to this repository, copied over SSH, or held in a file anywhere.
- It's scoped with `--repos` to only the repositories you select, not your
  whole account.

Codespaces already running must be stopped and restarted (not just
reconnected) to pick up the secret as an environment variable. To rotate a
token, run `claude setup-token` again and re-run this command; to revoke
access entirely, remove the secret from
https://github.com/settings/codespaces or with `gh secret delete
CLAUDE_CODE_OAUTH_TOKEN --user`.

Pass one or more repositories to skip the selector:

```bash
sync-claude-token-to-codespace owner/repo
```

## Persisted agent memory

Claude Code writes auto-memory per project under
`~/.claude/projects/<encoded-path>/memory/`. Inside a Codespace that is
discarded on every rebuild, taking with it everything the agent learned about a
customer's Odoo environment.

`remote-codespace-setup.sh` runs `persist-agent-memory.sh`, which symlinks those
directories into `memory/` in this checkout. Memory then survives rebuilds and
follows you to any Codespace that runs the installer. It adopts memory Claude
already wrote, pre-seeds a link for every Git repository under `/workspaces`,
never overwrites an already-persisted file with a Codespace-local one, and is
safe to rerun.

**This repository is private because of that directory.** It holds learned facts
about customer Odoo versions, module sets, and integration quirks. Credentials,
tokens, and personal contact details must never be written there — see
`memory/README.md` for the full rules.

## Layout

- `open-codespace-cursor` — local Cursor/GitHub Codespaces launcher.
- `open-codespace-terminal` — terminal-based Codespaces launcher.
- `open-codespace-common.sh` — shared SSH and remote bootstrap implementation.
- `sync-claude-token-to-codespace` — pushes the local Claude Code OAuth token
  to Codespaces as a scoped GitHub user secret.
- `setup.sh` — local-only installer for the launcher and sync commands.
- `remote-codespace-setup.sh` — remote installer for skills, shared agent
  instructions, GitHub CLI, browser automation, and memory persistence,
  invoked automatically by both launchers.
- `persist-agent-memory.sh` — symlinks Claude Code's auto-memory into `memory/`.
- `memory/` — persisted agent memory (private; see `memory/README.md`).
- `odoo-agent.md` — shared Odoo instructions installed for Claude and Codex.
- `<category>/<skill-name>/SKILL.md` — reusable agent skills.

Current skills (`odoo-dev-skills/`): `development-request`, `odoo-commit`,
`odoo-staging-branch`, `odoo-pr`, `odoo-integrations`, `run-odoo-tests`,
`test-odoo-ui`. `development-request` produces evidence-backed implementation
plans with confirmed ownership, observable slices, and explicitly gated test
execution.
Meta skills (`meta-skills/`): `self-improvement-dev-env` — improves this repo's
prompts/skills from recent agent session history; `capture-customer-knowledge` —
scans the three most recent sessions (or the ones you name) for durable facts
about a customer's Odoo environment and writes them to persisted memory, with
credentials and personal data stripped; `simplify-last-response` — manually
rewrites the immediately previous assistant response in shorter, plainer
language.

In Claude or Cursor, invoke `/development-request <record-ID-or-URL>` to retrieve
and analyse a live 360 ERP request. The skill expects the 360 ERP Odoo MCP to be
configured and authenticated in the Codespace; if it is unavailable, it reports
the blocker and continues from supplied context and repository evidence when
possible.

To rewrite the immediately previous assistant response more simply, invoke it as:

```text
Claude or Cursor: /simplify-last-response
Codex:            $simplify-last-response
```

Skills are grouped into category folders, with one folder per skill containing
a `SKILL.md`. A skill may also ship supporting files: `references/` holds detail
the agent loads only when it needs it, and `scripts/` holds executable helpers.

```
<category>/
└── <skill-name>/
    ├── SKILL.md
    ├── references/    # optional — loaded on demand, not with the skill
    └── scripts/       # optional — executable helpers
```

The whole skill folder is symlinked, so supporting files travel with it.

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
