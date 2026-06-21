---
name: odoo-staging-branch
description: This skill should be used when the user explicitly asks to create and commit on an Odoo staging branch — e.g. "commit the changes, ticket-XXXX, and create and commit on a staging branch". Covers determining the Odoo version, the staging branch naming convention, branching from the matching upstream staging branch, and cherry-picking the feature-branch commit onto it (including repeated iterations).
version: 1.0.0
---

# Odoo staging branch workflow

Use this only when the user **explicitly asks** for a staging branch. Never
create or rename branches on your own initiative.

A typical request looks like:

```
commit the changes, ticket-XXXX, and create and commit on a staging branch
```

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

## Step 3 — Create the staging branch from upstream

Branch off the matching upstream staging branch, naming it
`<odoo_version>-staging-<ticket_or_task>`:

```bash
git checkout -b <odoo_version>-staging-<ticket_or_task> origin/<odoo_version>-staging
```

Example:

```bash
git checkout -b 18.0-staging-ticket-1234 origin/18.0-staging
```

## Step 4 — Cherry-pick the feature commit

```bash
git cherry-pick <commit_hash>
```

## Iterations in the same session

If the user requests another change afterwards, repeat the cycle:

1. Commit first on the **feature** branch (record the new hash).
2. Cherry-pick the new commit onto the existing staging branch.

## Branch naming reference

Feature branches:

```
18.0-ticket-1234
18.0-task-1234
16.0-ticket-5678
```

Staging branches:

```
18.0-staging-ticket-1234
18.0-staging-task-1234
16.0-staging-ticket-5678
```

## After finishing

Report: the commit hash created on the feature branch, the staging branch name,
and that the commit was cherry-picked onto it.
