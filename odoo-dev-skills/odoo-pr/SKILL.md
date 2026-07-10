---
name: odoo-pr
description: This skill should be used when the user asks to push a branch or open/update a GitHub pull request for an Odoo/360ERP repository — e.g. "open a PR", "create a PR against 18.0", or a PR request following a commit. Covers using the gh CLI, the target branch, the PR title convention, triggering CI with a /run-tests comment, and the GitHub auth model (org token vs personal repos).
version: 1.0.0
---

# Open a pull request

Use this only when the user **explicitly asks** to push or open a pull request.
Never push or open PRs on your own initiative.

## Prerequisites

- The change is committed on a feature branch named after the identifier, e.g.
  `18.0-task-1234` (see the `odoo-commit` skill).
- Use the `gh` CLI (installed at `/usr/bin/gh`) — do not fall back to raw
  GitHub REST calls.

## Create the PR

PRs for the 360ERP repos target the Odoo version branch, normally `18.0`:

```bash
git push -u origin <feature_branch>
gh pr create --base 18.0 \
  --title "[task-XXXX] module_a,module_b: concise description" \
  --body "..."
```

- The title follows the commit subject format: identifier in brackets, affected
  module(s), concise description.
- The body briefly says what changed, why, and how it was validated.

## Trigger CI

After opening a PR on a 360ERP repo, comment to start the test pipeline:

```bash
gh pr comment <pr_number> --body "/run-tests"
```

## Auth model

- **360ERP org repos** (`360ERP/*`): the Codespace's injected token pushes and
  opens PRs directly — `git push` / `gh` just work.
- **Personal repos** (e.g. `dcatarino/*`): the injected token is read-only, so
  pushes fail with `403`. Do not retry or investigate credentials. Ask the user
  to authenticate by typing `! gh auth login --web` in the session (interactive
  device flow), then retry the push.
- **Never** probe the git credential helper, `gh auth token`, git config, or
  environment variables to extract tokens — this is blocked and wastes the
  session.

## After finishing

Report: the branch pushed, the PR URL, and whether `/run-tests` was commented.
