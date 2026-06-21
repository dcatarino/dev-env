---
name: odoo-commit
description: This skill should be used when committing changes in an Odoo project — e.g. the user explicitly asks to commit, or to "commit ticket-XXXX / task-XXXX". Covers the required ticket/task identifier, running pre-commit validation before committing, the exact commit message format (identifier + affected modules + concise description), and the no-co-authors rule.
version: 1.0.0
---

# Commit Odoo changes

Use this only when the user **explicitly asks to commit**. Never commit changes
on your own initiative.

## Prerequisite: ticket/task identifier

Every commit must be associated with a `task-XXXX`, `ticket-XXXX`, or
`request-XXXX` identifier. If the user did not provide one, **ask for it before
committing** — do not guess. Use the identifier exactly as given.

```
task-1234
ticket-5678
request-891
```

## Step 1 — Validate with pre-commit (required)

Before creating the commit, run:

```bash
pre-commit run --all-files
```

If it fails:

1. Fix the reported issues.
2. Rerun `pre-commit run --all-files`.
3. Only commit once it passes — unless the user explicitly tells you to commit
   anyway.

Do **not** run Odoo unit tests as part of committing. The user runs those
manually (see the `run-odoo-tests` skill if asked).

## Step 2 — Commit message format

The message must start with the identifier in brackets, then the affected
module(s), then a blank line, then a concise description:

```
[task-XXXX] module_a,module_b:

Concise description of the change
```

Rules:

- Start with `[task-XXXX]` / `[ticket-XXXX]` / `[request-XXXX]`.
- List the affected module(s) after the bracket, comma-separated, no spaces.
- Description is concise but useful — say what changed and why if non-obvious.
- **Do not add co-authors** (no `Co-Authored-By` trailer).

Examples:

```
[task-1234] custom_sale,custom_sale_stock:

Add delivery status synchronization for external orders
```

```
[ticket-5678] custom_account:

Fix invoice export payload for refunded payments
```

## After committing

Report: which modules were affected, that `pre-commit run --all-files` was run
(and passed), and that the commit was created. If a staging branch was also
requested, hand off to the `odoo-staging-branch` skill.
