---
name: self-improvement-dev-env
description: Manual-only skill (invoke with /self-improvement-dev-env) that improves the dev-env repo based on recent agent sessions. Covers mining auto-memory and Claude session transcripts for recurring errors and corrections, deciding what belongs in the always-loaded prompt vs a skill vs an on-demand reference, the editing conventions, and the commit/push/PR workflow specific to the personal dev-env repo (gh auth bypass).
version: 1.2.0
disable-model-invocation: true
---

# Self-improve the dev-env repo

This skill is never invoked automatically — it runs only when explicitly
invoked with `/self-improvement-dev-env`.

Improve `/workspaces/dev-env` (the shared agent prompts and skills) using
evidence from recent sessions. The three goals, in order:

1. **Agents get smarter** — encode real environment knowledge and conventions.
2. **Agents commit fewer errors** — turn observed mistakes into guardrails.
3. **Agents stay token-efficient** — the always-loaded prompt stays lean;
   detail lives in on-demand skills, and skill detail in on-demand references.

Auto-memory already captures per-session learnings, but it is local to one
machine and one project path. This repo is the versioned, shared artifact that
reaches Claude, Codex, and Cursor across every Codespace — promoting a lesson
here is what makes it durable.

## Step 1 — Mine recent evidence

Bound the window to sessions since the last self-improvement run — find the
previous self-improvement commit by its message (not just the latest commit,
which may be unrelated):

```bash
git -C /workspaces/dev-env log --oneline -15
```

If no prior self-improvement commit is identifiable, ask the user which window
to mine (or default to the last two weeks).

**Read auto-memory first.** It is already distilled, already states a *why*,
and is far higher signal than string-matching raw transcripts:

```bash
cat ~/.claude/projects/*/MEMORY.md
grep -l "type: feedback\|type: project" ~/.claude/projects/*/memory/*.md
```

`feedback` entries are corrections the user gave, with the reasoning attached —
they map almost directly onto guardrails. `project` entries often reveal
conventions not yet encoded anywhere.

**Then fill the gaps from transcripts** — memory only records what was worth
writing down at the time, so recurring *tool-level* friction (retries,
permission denials, wrong paths) usually is not in it. Transcripts are large:
**never read them fully in the main context**; spawn Explore/general-purpose
subagents that grep/jq-sample them and return only conclusions.

- `~/.claude/projects/<project>/*.jsonl` — session transcripts, by mtime.
- `~/.claude/history.jsonl` — raw user prompts.

Look for:

- **Recurring agent errors**: failed/retried tool calls, permission denials,
  wrong paths, misused APIs, blocked actions.
- **Friction**: anything that burned multiple turns (auth thrashing, broken
  validators, slow commands handled badly).
- **User corrections** not already in memory: grep user messages for `"no,"`,
  `"don't"`, `"instead"`, `"actually"`, `"I stopped you"`.

A lesson earns a change only if it **recurred or cost significant turns**, and
it must be generalized (a rule, not an anecdote).

## Step 2 — Review the current dev-env state

- Read `odoo-agent.md` and every `SKILL.md`; read `CLAUDE.md` for the repo's
  editing rules.
- Check the install wiring: symlinks in `~/.claude/skills/` and
  `~/.claude/CLAUDE.md` must resolve into `/workspaces/dev-env`. If not,
  re-run `bash /workspaces/dev-env/remote-codespace-setup.sh`.

## Step 3 — Decide placement

Three tiers, cheapest first. Push everything as far down as it will go.

| Tier | Cost | What belongs there |
| --- | --- | --- |
| `odoo-agent.md` | every turn, every session | role, workspace map, short guardrails, the gated-actions table |
| `SKILL.md` | on trigger, in full | the decision-shaped part of one workflow |
| `references/`, `scripts/` | only when opened or run | field lists, long procedures, commands |

Current models need far less than they used to. Before adding anything, check
it is not one of these:

- **Self-verification scaffolding** — completion criteria, verification
  checklists, "double-check your work". The model does this unprompted.
- **Restating a rule that a skill already owns.** Say it once, where the
  action happens. The skill's `description` is what routes to it — invest
  there instead.
- **Baseline careful-agent behaviour** — "don't fabricate", "ask if unclear",
  "don't overengineer".
- **Style rules that a judgment framing covers better** — prefer "match the
  surrounding code's idiom" over an enumerated ban list.
- **Structure the model can read off the filesystem** — directory trees,
  dependency lists.

What does earn a place: non-obvious gotchas, this-environment facts, the
user's actual preferences, and hard guardrails with real blast radius.

Prefer thin routers over duplication — point to the source of truth (e.g.
`360_integrations/.agents/*.md`) instead of copying it; copies drift. Don't
encode what a project-level `AGENTS.md`/`.agents/` file already records.

**Removing** an over-constraint is as valid an improvement as adding a rule.

Present the proposed changes as a plan and get approval before editing.

## Step 4 — Edit

Follow `CLAUDE.md` in this repo: keep `name`/`description`/`version`
frontmatter, bump `version` on any behavior change, match the existing tone,
KISS — don't refactor unrelated skills. Update the README skill list when
adding a skill.

## Step 5 — Verify

- Re-run `remote-codespace-setup.sh`; confirm every symlink resolves and new
  skills appear in `~/.claude/skills/`.
- Read each edited file end-to-end: valid frontmatter, no stray tool markup
  (`grep -rn "</invoke[>]\|</content[>]" --exclude-dir=.git .` must be empty —
  the bracketed pattern keeps the check from matching itself), versions
  bumped.
- `bash -n` any touched shell script; `shellcheck` when available.

## Step 6 — Commit and PR (dev-env-specific — differs from Odoo work)

This repo is **not** an Odoo project; the `odoo-commit`/`odoo-pr` rules do not
apply here:

- Plain descriptive commit messages (no `[task-XXXX]` prefix), ending **with**
  a `Co-Authored-By` trailer naming the model (opposite of the Odoo rule).
- Work on a feature branch off `main`; the PR targets `main`.
- No CI pipeline — never comment `/run-tests`.

**Push/PR auth**: `dcatarino/dev-env` is a personal repo — follow the
personal-repos section of the `odoo-pr` skill (bypass the injected read-only
token with the stored `gh` login; interactive `gh auth login --web` only if
none exists; never probe credential helpers).

**Leave the feature branch checked out** until the PR merges: the installed
symlinks point into this checkout, so switching back to `main` before the
merge would revert the live prompts/skills. After the merge:
`git checkout main && git pull`, then re-run the installer if skills were
added or removed.

## Memory persistence

Memory survives Codespace rebuilds: `persist-agent-memory.sh` symlinks
`~/.claude/projects/*/memory/` into `dev-env/memory/`, so Step 1 can mine memory
written in earlier Codespaces, not just the current one. The repository is
private because that directory holds customer facts — never make it public
again while it tracks memory, and never write credentials or personal contact
details into a memory file (`memory/README.md` has the rules).

If Step 1 finds no memory at all, check that the store is wired up before
concluding there was nothing to learn:

```bash
bash /workspaces/dev-env/persist-agent-memory.sh
ls /workspaces/dev-env/memory/*/
```

## After finishing

Report: the lessons found (and whether each came from memory or a transcript),
what changed in which files, the PR URL, and that the live symlinks still
resolve.
