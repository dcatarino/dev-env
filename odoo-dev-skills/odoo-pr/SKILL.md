---
name: odoo-pr
description: This skill should be used when the user asks to push a branch or open/update a GitHub pull request for an Odoo/360ERP repository — e.g. "open a PR", "create a PR against 18.0", or a PR request following a commit. Covers using the gh CLI, the target branch, the PR title convention, triggering CI with a /run-tests comment, and the GitHub auth model (org token vs personal repos).
version: 1.0.5
---

# Open a pull request

Use this only when the user **explicitly asks** to push or open a pull request.
Never push or open PRs on your own initiative.

## Prerequisites

- The change is committed (see the `odoo-commit` skill). The branch name does
  not have to match the commit's identifier — committing a different
  task/ticket/request on an existing branch is a normal workflow.
- Use the `gh` CLI (installed at `/usr/bin/gh`) — do not fall back to raw
  GitHub REST calls.

## Create the PR — 360ERP org repos

PRs target the Odoo version branch, normally `18.0`:

```bash
git push -u origin <feature_branch>
gh pr create --base 18.0 \
  --title "[task-XXXX] module_a,module_b: concise description" \
  --body "..."
```

- The title follows the commit subject format: identifier in brackets, affected
  module(s), concise description.
- The body briefly says what changed, why, and how it was validated.

Immediately after creating the PR, post one fresh `/run-tests` comment. The
initial push may have had no PR yet, so do not comment before creation and then
again after it; comment once after the PR exists:

```bash
gh pr comment <pr_number> --body "/run-tests"
```

## Push/update a PR — 360ERP org repos

After every explicitly authorized `git push` that succeeds **and updates the
remote branch**, locate an open PR for the current branch. If one exists, post
exactly one fresh `/run-tests` comment for that push action:

```bash
pr_number="$(gh pr list --head "$(git branch --show-current)" --state open --json number --jq '.[0].number')"
if [ -n "$pr_number" ]; then
  gh pr comment "$pr_number" --body "/run-tests"
fi
```

- Do nothing when the branch has no open PR.
- If the push is followed by PR creation, post the single comment immediately
  after creating the PR instead of commenting twice for the same push action.
- A `/run-tests` comment for an earlier commit never satisfies this rule for a
  later remote-updating push.

## Create the PR — personal repos (e.g. `dcatarino/*`)

PRs target `main`, use a plain descriptive title (no `[task-XXXX]` prefix,
no task identifier needed), and there is no `/run-tests` pipeline — skip the
CI comment, including after pushes. See the auth notes below for pushing.

## Auth model

- **360ERP org repos** (`360ERP/*`): the Codespace's injected token pushes and
  opens PRs directly — `git push` / `gh` just work.
- **Personal repos** (e.g. `dcatarino/*`): the injected token is read-only, so
  pushes fail with `403`. First check `gh auth status` — if a second (stored)
  account exists from an earlier `gh auth login`, bypass the injected token and
  use it directly:

  ```bash
  GITHUB_TOKEN= GH_TOKEN= git -c credential.helper= \
    -c credential.helper='!gh auth git-credential' push -u origin <branch>
  GITHUB_TOKEN= GH_TOKEN= gh pr create --base main ...
  ```

  Only if no stored login exists, ask the user to authenticate by typing
  `! gh auth login --web` in the session (interactive device flow), then use
  the commands above.
- **Never** probe the git credential helper, `gh auth token`, git config, or
  environment variables to extract tokens — this is blocked and wastes the
  session.

## After finishing

Report: the branch pushed, the PR URL, and whether `/run-tests` was commented.
