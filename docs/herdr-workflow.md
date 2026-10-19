# Working with several agents through Herdr

This is the day-to-day workflow for running Claude Code (or Codex) in several
Codespaces at once and keeping track of all of them from one window on the VPS
or the Mac.

```text
 Codespace A ── herdr server ── agents started with `herd`  ┐
 Codespace B ── herdr server ── agents started with `herd`  ├─ SSH ─ herdr-codespaces window
 Codespace C ── herdr server ── agents started with `herd`  ┘        (VPS and/or Mac)
```

Each Codespace runs its own Herdr server. The agents live there, so closing
Cursor, a terminal, or the overview window never stops them.

## One-time setup

**Codespaces:** nothing to do. The launchers' bootstrap
(`remote-codespace-setup.sh`) installs Herdr, its Claude Code and Codex
integrations, and the `herd` command.

**Each computer that shows the overview** (VPS, Mac):

```bash
# macOS
brew install herdr jq gh
# Linux
curl -fsSL https://herdr.dev/install.sh | sh     # jq and gh from your package manager

gh auth login -s codespace       # skip if open-codespace-* already works
cd dev-env && git pull && bash setup.sh
```

`herdr --version` must be 0.9.5 or newer. An older Herdr updates itself with
`herdr update`; running agents in an existing local session keep running.

## Daily flow

### 1. Open a Codespace as usual

```bash
open-codespace-cursor-mac          # or open-codespace-cursor / -terminal
```

Wait for the bootstrap to finish (`tail -f /tmp/open-codespace-bootstrap.log`)
the first time; after that Herdr is already installed.

### 2. Start agents with `herd` in Cursor's terminal

Use `herd` where you used to type `claude`:

```bash
cd /workspaces/<repo>
herd                              # Claude Code, named after the folder
herd claude request-1929          # choose the name (lowercase, digits, - or _)
herd codex                        # Codex instead
herd claude -- --resume           # arguments after -- go to the agent
```

The terminal opens the agent in a Herdr client with the sidebar and tab row
hidden (`herd-client.toml`), so it looks and behaves like a normal Claude
session, including `--dangerously-skip-permissions`. A terminal narrower than
about 80 columns gets a two-line Herdr header above the agent. Starting or
attaching an agent switches every open Herdr view of that Codespace, including
the overview window, to that agent. Start as many
agents as you want, each in its own terminal tab, in the same or different
folders. Two agents in the same folder share the same working tree, so give
parallel agents different worktrees or branches.

The first time Claude opens a folder it asks whether you trust it. Herdr shows
that as `blocked` until you answer.

### 3. Watch everything from one window

On the VPS (over SSH or Tailscale) or on the Mac:

```bash
herdr-codespaces
```

It connects every running Codespace and opens Herdr. In the sidebar each
Codespace appears as `<repository> (<codespace>)` with its agents and their
state:

| State | Meaning | What to do |
| --- | --- | --- |
| `working` | The agent is busy. | Nothing. |
| `blocked` | It asks a question or needs approval. | Open it and answer. |
| `done` | It finished a turn you have not looked at yet. | Read the result, give the next task. |
| `idle` | Waiting for input, already seen. | Nothing, or give it work. |

Select an agent to see its terminal and type into it, exactly as in Cursor.
Cursor and the window can show the same agent at the same time. The agent takes
the size of whichever one you selected or typed in last, so it fills the window
as soon as you use it there.

While the window is open the list refreshes every two minutes: newly opened
Codespaces appear, stopped ones are disabled, deleted ones disappear. The
window retries a Codespace without Herdr yet (bootstrap still running) after
ten minutes; `herdr-codespaces sync`, or reopening the window, retries it
immediately.

### 4. Detach

| You want to | Do |
| --- | --- |
| Close the overview window | `ctrl+b q` — all agents keep running. |
| Leave an agent in a Cursor terminal | `ctrl+b q`, or just close the terminal or Cursor. |
| Return to an agent in a Codespace | `herd ls`, then `herd attach <name>`. |
| Remove one Codespace from the window | `herdr-codespaces hide <repository>` (or its Codespace name). Its agents keep running and the sync does not add it back; `herdr-codespaces show <repository>` brings it back. `herdr machine disable <id>` only greys it out. |
| Send a literal `ctrl+b` to the agent | `ctrl+b ctrl+b`. |

### 5. Finish an agent

Exit the agent normally (for example `/exit`). Its pane returns to a shell;
type `exit` there to close it, so the workspace leaves the sidebar.

### 6. Stop the Codespace

Stop Codespaces you no longer need with `gh codespace stop -c <name>`. An open
overview window keeps an SSH connection to every running Codespace, which can
prevent the idle timeout from stopping it.

Herdr never starts a stopped Codespace: the window's SSH connections go through
a guard that refuses Codespaces that are not `Available`. Reopen one with a
launcher; it reappears within two minutes.

## Useful commands

```bash
# In a Codespace
herd ls                                  # agents and their state
herd attach <name>                       # attach to one agent
herdr                                    # full Herdr UI for this Codespace

# On the VPS or Mac
herdr-codespaces                         # sync and open the overview
herdr-codespaces sync                    # sync only
herdr-codespaces hide <repository>       # remove a Codespace from the window
herdr-codespaces show [<repository>]     # bring it back, or list hidden ones
herdr machine list                       # connected Codespaces
herdr machine status                     # reachability check
herdr --machine "<label>" agent list     # one Codespace's agents, as JSON
```

## Troubleshooting

- **An agent is missing from the window.** Only agents started with `herd` (or
  inside `herdr`) are visible; a plain `claude` in a Cursor terminal is not.
  Restart it with `herd claude -- --resume` to continue the conversation.
- **An agent is narrow in the window and does not fill it.** A terminal
  attached directly to the agent decides its size: a `herd` older than this
  fix, `herdr agent attach`, or `herdr terminal attach`. Press `ctrl+b q` in
  that terminal (or close it) and the agent fills the window; reopen it there
  with `herd attach <name>`.
- **A Codespace is missing.** Check that it is `Available`
  (`gh codespace list`), that its bootstrap finished, and run
  `herdr-codespaces sync` to see the error. Background sync output is in
  `~/.cache/herdr-codespaces/sync.log`.
- **A Codespace keeps showing `reconnecting`.** `herdr machine status` prints
  the SSH error. A `herdr-codespaces` older than this fix wrote host entries
  that Herdr 0.9.5 rejects (`Host key verification failed`); pull dev-env and
  run `herdr-codespaces sync`.
- **A Codespace appears twice.** Two open overview windows synced at the same
  time with a `herdr-codespaces` older than this fix, and both added it. The
  next sync removes the extra machine. Close windows that were opened before
  you pulled the fix: they keep running the old sync.
- **A Codespace shows `! error` after it stopped.** It is disabled at the next
  sync; reopen it with a launcher if you need it.
- **`herdr-codespaces` says saved machines are unsupported.** The local Herdr
  is older than 0.9.5: run `herdr update`, or point `HERDR_BIN` at a newer
  binary.
- **The overview uses the local session `codespaces`.** It does not touch
  another Herdr session on the same computer. Use `HERDR_SESSION=<name>` to
  choose a different one.
