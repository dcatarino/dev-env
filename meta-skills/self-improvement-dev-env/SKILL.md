---
name: self-improvement-dev-env
description: Manual-only skill (invoke with /self-improvement-dev-env) that improves the dev-env repo based on recent agent sessions. Covers mining Claude session transcripts for recurring errors and corrections, deciding what belongs in the system prompt vs a skill (token efficiency), the editing conventions, and the commit/push/PR workflow specific to the personal dev-env repo (gh auth bypass).
version: 1.0.0
disable-model-invocation: true
---

# Self-improve the dev-env repo

This skill is never invoked automatically — it runs only when explicitly
invoked with `/self-improvement-dev-env`.

Improve `/workspaces/dev-env` (the shared agent prompts and skills) using
evidence from recent sessions. The three goals, in order:

1. **Agents get smarter** — encode real environment knowledge and conventions.
2. **Agents commit fewer errors** — turn observed mistakes into guardrails.
3. **Agents stay token-efficient** — always-loaded prompt stays lean; detail
   lives in on-demand skills.

## Step 1 — Mine recent session history

Bound the window to sessions since the last self-improvement:

```bash
git -C /workspaces/dev-env log -1 --format=%ci
```

Sources (transcripts are large — **never read them fully in the main
context**; spawn Explore/general-purpose subagents that grep/jq-sample them
and return only conclusions):

- `/home/odoo/.claude/projects/<project>/*.jsonl` — session transcripts,
  sorted by mtime.
- `/home/odoo/.claude/history.jsonl` — raw user prompts.

Extract, with evidence quotes:

- **User corrections**: grep user messages for patterns like `"no,"`,
  `"don't"`, `"instead"`, `"actually"`, `"you should"`, `"I stopped you"`,
  `"no need to overthink"`.
- **Recurring agent errors**: failed/retried tool calls, permission denials,
  wrong paths, misused APIs, blocked actions.
- **Friction**: anything that burned multiple turns (auth thrashing, broken
  validators, slow commands handled badly).
- **New conventions**: workflows the user repeated that aren't encoded yet.

A lesson earns a change only if it **recurred or cost significant turns**, and
it must be generalized (a rule, not an anecdote).

## Step 2 — Review the current dev-env state

- Read `odoo-agent.md` and every `SKILL.md`; read `CLAUDE.md` for the repo's
  editing rules.
- Check the install wiring: symlinks in `~/.claude/skills/` and
  `~/.claude/CLAUDE.md` must resolve into `/workspaces/dev-env`. If not,
  re-run `bash /workspaces/dev-env/remote-codespace-setup.sh`.

## Step 3 — Decide placement (token efficiency)

- **`odoo-agent.md`** (always loaded): only what is relevant to *every*
  session — role, workspace map, short guardrails, one-line skill pointers.
  Keep it lean (roughly ≤120 lines); every line here is paid on every turn of
  every session.
- **Skills** (loaded on demand): operational detail, commands, workflows. One
  concern per skill; write the frontmatter `description` so the right skill
  triggers on the right request.
- **Prefer thin routers over duplication**: point to the source of truth
  (e.g. `360_integrations/.agents/*.md`) instead of copying it — copies
  drift.
- Don't encode what project-level `AGENTS.md`/`.agents/` files already record.

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
  (`grep -rn "</invoke>\|</content>" .` must be empty), versions bumped.
- `bash -n` any touched shell script.

## Step 6 — Commit and PR (dev-env-specific — differs from Odoo work)

This repo is **not** an Odoo project; the `odoo-commit`/`odoo-pr` rules do not
apply here:

- Plain descriptive commit messages (no `[task-XXXX]` prefix), ending **with**
  a `Co-Authored-By` trailer naming the model (opposite of the Odoo rule).
- Work on a feature branch off `main`; the PR targets `main`.

**Push/PR auth**: unlike the 360ERP org repos (where the injected Codespaces
token just works), `dcatarino/dev-env` is a personal repo — the injected
`GITHUB_TOKEN` is read-only and pushes fail with `403`. Check
`gh auth status`; if a stored account exists from an earlier `gh auth login`,
bypass the injected token:

```bash
GITHUB_TOKEN= GH_TOKEN= git -c credential.helper= \
  -c credential.helper='!gh auth git-credential' push -u origin <branch>
GITHUB_TOKEN= GH_TOKEN= gh pr create --base main --title "..." --body "..."
```

Only if no stored login exists, ask the user to type `! gh auth login --web`,
then retry. Never probe credential helpers or extract tokens.

**Leave the feature branch checked out** until the PR merges: the installed
symlinks point into this checkout, so switching back to `main` before the
merge would revert the live prompts/skills. After the merge:
`git checkout main && git pull`, then re-run the installer if skills were
added or removed.

## After finishing

Report: the lessons found (with which sessions they came from), what changed
in which files, the PR URL, and that the live symlinks still resolve.
