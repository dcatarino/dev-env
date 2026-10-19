---
name: odoo-ship
description: This skill should be used when the user asks to push a committed change and open its pull requests in a 360ERP Odoo repository — especially the usual pair, e.g. "create a PR to 18.0 and to 18.0-staging", "PR to 18.0 and staging", "push to the open PR and open a new staging PR". One script run pushes the feature branch, opens or reuses its PR, picks or creates the staging branch, cherry-picks (resolving the expected manifest-version conflict), opens the staging PR and posts /run-tests; a second script watches the CI run that /run-tests starts.
version: 1.0.0
---

# Ship to 18.0 and 18.0-staging

Use this only when the user **explicitly asks** for the PRs. It scripts the
push, PR, staging and `/run-tests` steps of `odoo-pr` and `odoo-staging-branch`;
those skills stay the reference for each rule.

## Which PRs

- `Integrations-<Customer>` repos: the user usually asks for both `18.0` and
  `18.0-staging`. When the request names only `18.0`, add `--no-staging`. When
  it names no base, ship to `18.0` only (`--no-staging`) and offer the staging
  PR in your closing line.
- `360_integrations`: `18.0` only (`--no-staging`). Customer staging gets a
  framework change through a submodule bump (see `odoo-staging-branch`).

## Steps

1. **Commit** with the `odoo-commit` skill. The script ships committed work
   only, and takes the identifier from the latest commit.
2. **Write the PR description** to a scratchpad file when a PR will be
   created: what changed, why, and how it was validated.
3. **Ship**, from inside the repository (`--dry-run` prints the plan and
   changes nothing):

   ```bash
   bash scripts/ship.sh --body-file <file> [--no-staging]
   ```

   It pushes the feature branch, opens or reuses its PR to `<version>`, then:
   - reuses the current `<version>-staging-<id>` branch, or creates the next
     `-N` one when it is stale (the `odoo-staging-branch` rule);
   - cherry-picks the feature commits staging does not have yet, including
     ones a squash-merged PR already brought;
   - resolves a conflict that touches only the manifest `version` by keeping
     staging's version and bumping it at the level the feature commit bumped;
   - opens or reuses the staging PR, titled `<feature PR title> (staging)`,
     with a body that starts "Staging counterpart of #N";
   - posts one `/run-tests` on each PR that was created or whose branch the
     push updated, then switches back to the feature branch.

   Rerunning it is safe.
4. **Watch CI.** Run the `Watch CI:` command the script printed as a
   background task. When it finishes, report PASS or FAIL per branch, with the
   failing log tail it prints. `/run-tests` dispatches the `test.yml` workflow
   on the PR's head branch, so the run never shows up in `gh pr checks`.

## When it stops

- **A real conflict** — it stops on the staging branch mid-cherry-pick and
  names the files. Resolve them, run `git cherry-pick --continue`, and rerun.
- **The feature branch was already merged** — PRs are squash-merged, so newer
  commits need a fresh branch. It prints the
  `git checkout -b <branch>-N origin/<version> && git cherry-pick …` command;
  run it, then rerun from the new branch.
- **Uncommitted changes, no identifier, or a non-360ERP origin** — fix the
  cause. Personal repositories follow the `odoo-pr` skill.

## After finishing

Report both PR URLs, the staging branch (and whether a new `-N` branch was
created because the previous one was stale), any version conflict it resolved,
where `/run-tests` was posted, and the CI result once the watcher finishes.
