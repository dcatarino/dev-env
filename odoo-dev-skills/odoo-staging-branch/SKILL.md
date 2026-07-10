---
name: odoo-staging-branch
description: This skill should be used when the user explicitly asks to create and commit on an Odoo staging branch — e.g. "commit the changes, ticket-XXXX, and create and commit on a staging branch". Covers determining the Odoo version, the staging branch naming convention, branching from the matching upstream staging branch, detecting when a local staging branch has gone stale (because the upstream staging branch advanced) and creating an incremented -N branch, and cherry-picking the feature-branch commit onto it (including repeated iterations).
version: 1.1.1
---

# Odoo staging branch workflow

Use this only when the user **explicitly asks** for a staging branch. Never
create or rename branches on your own initiative.

A typical request looks like:

```
commit the changes, ticket-XXXX, and create and commit on a staging branch
```

The identifier is always one of `ticket-XXXX`, `task-XXXX`, or `request-XXXX`
(the same identifiers as the `odoo-commit` skill). Use it exactly as the user
gave it.

## Step 1 — Commit on the feature branch first

Commit the change on the **current feature branch** first, using the
`odoo-commit` skill (it enforces the ticket identifier, pre-commit validation,
and the commit message format). Then **record the resulting commit hash** — you
will cherry-pick it.

```bash
git rev-parse HEAD
```

## Step 2 — Determine the Odoo version

Determine the version from the current branch name or the user's prompt.
Examples: `18.0`, `17.0`, `16.0`. If it is ambiguous, ask.

## Step 3 — Refresh upstream staging and pick the staging branch

The staging branch is named `<odoo_version>-staging-<identifier>`, e.g.
`18.0-staging-ticket-1234`.

First, refresh the matching upstream staging branch so the staleness check below
is accurate:

```bash
git fetch origin <odoo_version>-staging
```

Then decide which local branch to work on:

**a) No local staging branch for this identifier yet** — create it fresh from
upstream:

```bash
git checkout -b <odoo_version>-staging-<identifier> origin/<odoo_version>-staging
```

**b) A local staging branch already exists** — check whether it is stale before
reusing it. A branch is stale when upstream `<odoo_version>-staging` has advanced
past what the branch was built on — typically because a previous
`<...>-staging-<identifier>` branch was merged into staging. One command decides
it (fast, single exit-code check):

```bash
git merge-base --is-ancestor origin/<odoo_version>-staging <existing_staging_branch>
```

- **Exit code 0** → upstream staging is an ancestor → the branch is **current** →
  reuse it as-is and skip to Step 4.
- **Non-zero** → upstream staging has moved on → the branch is **stale** → create
  a new incremented branch (below). **Leave the old local branch untouched.**

### Creating an incremented branch when stale

Take the identifier's base staging name (strip any trailing `-N` iteration
suffix) and find the highest iteration already used, locally and remotely:

```bash
git branch --all --list "<odoo_version>-staging-<identifier>" "<odoo_version>-staging-<identifier>-*"
```

The new branch is the base name plus the next number, starting at `-2`. Create
it from the refreshed upstream staging:

```bash
git checkout -b <odoo_version>-staging-<identifier>-2 origin/<odoo_version>-staging
```

Examples of the progression (identifier `ticket-1`):

```
18.0-staging-ticket-1     # original
18.0-staging-ticket-1-2   # created after the original was merged / went stale
18.0-staging-ticket-1-3   # created after -2 was merged / went stale
```

## Step 4 — Cherry-pick the feature commit

```bash
git cherry-pick <commit_hash>
```

## Step 5 — Push (only when asked to always push)

If the user's working instructions for the session say to **always push** (or
they explicitly asked you to push this branch), push it after cherry-picking:

```bash
git push -u origin <staging_branch>
```

Otherwise leave pushing to the user.

## Iterations in the same session

If the user requests another change afterwards, repeat the cycle:

1. Commit first on the **feature** branch (record the new hash).
2. **Re-run the Step 3 staleness check before cherry-picking** — upstream staging
   may have advanced since the last iteration. Reuse the current branch, or create
   the next `-N` branch if it has gone stale.
3. Cherry-pick the new commit onto the chosen staging branch.
4. Push if the always-push rule applies.

## Branch naming reference

Feature branches:

```
18.0-ticket-1234
18.0-task-1234
18.0-request-891
16.0-ticket-5678
```

Staging branches:

```
18.0-staging-ticket-1234
18.0-staging-task-1234
18.0-staging-request-891
16.0-staging-ticket-5678
```

Stale-iteration staging branches:

```
18.0-staging-ticket-1234-2
18.0-staging-ticket-1234-3
```

## After finishing

Report: the commit hash created on the feature branch, the staging branch name
(noting if a new `-N` branch was created because the previous one was stale),
that the commit was cherry-picked onto it, and whether it was pushed.
