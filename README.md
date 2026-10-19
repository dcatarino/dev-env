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
open-codespace-cursor-ide CODESPACE_NAME
open-codespace-cursor --public CODESPACE_NAME
open-codespace-cursor https://CODESPACE_NAME.github.dev/
open-codespace-cursor https://github.com/codespaces/CODESPACE_NAME
```

Use `open-codespace-cursor-ide` when you want Cursor's regular IDE/editor
window. It opens the workspace through Cursor's remote protocol handler, which
forces classic IDE routing instead of the newer Agents/Glass window. The
launcher also focuses the new workspace window when `xdotool` is available.

On macOS, use the dedicated launcher:

```bash
open-codespace-cursor-mac
```

It uses macOS's `open -a Cursor` handoff for the `cursor://vscode-remote` URL,
so it does not depend on the Linux-style `cursor --remote` command or on
`xdotool`. It accepts the same `--public` flag and Codespace name/URL argument
as the other launchers.

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

## Set up a Codespace opened in the browser

When a Codespace is opened directly from GitHub in the browser editor, no local
launcher runs. Install the same setup from a Codespace terminal with:

```bash
curl -fsSL https://raw.githubusercontent.com/dcatarino/dev-env/main/codespace-bootstrap.sh | bash
```

This runs `codespace-bootstrap.sh`, the same script the launchers upload and run
in the background, so it installs Claude Code, NVM and Node.js 22, Codex, and
the shared `dev-env` setup in the same order. Progress is shown in the terminal.
It is safe to rerun and exits early if a launcher-started bootstrap is already
running. Afterwards, open a new terminal (or run `exec "$SHELL"`) so the
`claude` alias, Codex, and Node.js are loaded.

Claude Code normally signs in through a `http://localhost:<port>/callback`
redirect. The browser editor cannot forward that to the Codespace, so the tab
it opens ends on an unreachable localhost page. In browser editor terminals the
setup therefore points `BROWSER` at `codespace-browser`, which declines to open
that one URL and passes every other link to VS Code. To sign in:

1. Run `claude` and choose a login method.
2. Open the URL shown under "Browser didn't open?" and sign in.
3. Copy the code the page shows and paste it at "Paste code here if prompted".

Cursor terminals keep the automatic sign-in, because Cursor forwards the
localhost callback.

## Run and watch agents with Herdr

The step-by-step workflow is in [docs/herdr-workflow.md](docs/herdr-workflow.md).

[Herdr](https://herdr.dev) is a terminal multiplexer that recognises coding
agents. The Codespace setup installs it with its Claude Code and Codex
integrations, plus the `herd` command. Start agents with `herd` instead of
`claude`/`codex` from any terminal, including Cursor's:

```bash
herd                          # Claude Code in this folder, named after it
herd codex                    # Codex instead
herd claude request-1929      # choose the agent name
herd claude -- --resume       # pass arguments to the agent
herd ls                       # list agents and their state
herd attach request-1929      # reattach
```

`herd` runs the agent in the Codespace's Herdr server and shows it in the
current terminal through a Herdr client with the sidebar and tab row hidden
(`herd-client.toml`). It uses the same sandboxed `claude` alias as a normal
terminal. The agent takes the size of the terminal or window you used last, so
it also fills the `herdr-codespaces` window. Starting or attaching an agent
switches every Herdr view of that Codespace to it. Detach with `ctrl+b q`; the
agent keeps running when the terminal or Cursor closes.

### See every Codespace's agents in one window

On any Linux or macOS computer or VPS where you run `setup.sh` (it needs `gh`,
`jq`, and Herdr 0.9.5 or newer):

```bash
curl -fsSL https://herdr.dev/install.sh | sh     # once; or: brew install herdr jq
herdr-codespaces
```

Several computers can run it at the same time; each opens its own window on the
same agents.

It adds every running Codespace as a Herdr SSH machine and opens Herdr. The
sidebar lists the agents of all Codespaces and marks each one `working`,
`blocked` (waiting for an answer or approval), `done`, or `idle`. Select an
agent to read it and answer it in place. While the window is open, the list is
synced every two minutes: new Codespaces appear, stopped ones are disabled, and
deleted ones are removed. `herdr-codespaces sync` syncs once without opening
the window.

To leave, detach with `ctrl+b q`: the window closes and every agent keeps
running in its Codespace. To drop one Codespace from the window, run
`herdr-codespaces hide Integrations-Pauw` (its repository, or its Codespace
name as the sidebar shows it); its agents keep running and the sync does not
add it back. `herdr-codespaces show Integrations-Pauw` brings it back, and
`herdr-codespaces show` lists the hidden ones. `herdr machine disable <id>`
only greys a Codespace out in the sidebar.

Notes:

- Only agents started with `herd` (or inside `herdr`) are visible; a plain
  `claude` in a Cursor terminal is not.
- A Codespace appears once its bootstrap has installed Herdr. If it was not
  ready, the open window retries it after 10 minutes; `herdr-codespaces sync`
  retries it immediately.
- Several windows on one computer show the same session and sync one at a
  time. A Codespace that two syncs added at once (before this was fixed)
  appears twice; the next sync removes the extra machine.
- Herdr never starts a stopped Codespace: its SSH connection goes through a
  guard that refuses Codespaces that are not `Available`. Open the Codespace
  with a launcher first.
- An open SSH connection may keep a Codespace from stopping on its idle
  timeout. Close the window, or stop Codespaces you no longer need.
- The window uses its own local Herdr session, `codespaces`, so it does not
  touch a Herdr session you already run on that computer.
- The generated SSH hosts live in `~/.ssh/herdr-codespaces`, included from
  `~/.ssh/config`, next to the launchers' `~/.ssh/codespaces`.

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
- `open-codespace-cursor-ide` — local launcher that forces Cursor's classic
  IDE/editor window for Remote SSH.
- `open-codespace-cursor-mac` — macOS launcher that hands the remote URL to
  Cursor through LaunchServices.
- `open-codespace-terminal` — terminal-based Codespaces launcher.
- `open-codespace-common.sh` — shared Codespace selection and SSH
  implementation.
- `codespace-bootstrap.sh` — remote bootstrap uploaded by the launchers, also
  runnable directly from a browser Codespace terminal.
- `codespace-browser` — `BROWSER` wrapper for browser editor terminals that
  keeps Claude Code's sign-in on its paste-a-code flow.
- `herd` — starts Claude Code or Codex inside the Codespace's Herdr server.
- `herd-client.toml` — Herdr client settings for `herd`: no sidebar or tab row.
- `herdr-codespaces` — local command that shows every running Codespace's
  Herdr agents in one window.
- `docs/herdr-workflow.md` — daily workflow for running and watching agents
  with Herdr.
- `setup.sh` — local-only installer for the launcher commands.
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
