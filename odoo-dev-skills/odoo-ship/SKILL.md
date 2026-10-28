---
name: odoo-ship
description: This skill should be used when the user asks to push a committed change and open its pull requests in a 360ERP Odoo repository — especially the usual pair, e.g. "create a PR to 18.0 and to 18.0-staging", "PR to 20.0 and staging", "push to the open PR and open a new staging PR", optionally with "squash merge when CI passes". One script run pushes the feature branch, opens or reuses its PR, picks or creates the staging branch, cherry-picks (resolving the expected manifest-version conflict), opens the staging PR and posts /run-tests; a second script watches the CI run that /run-tests starts in the background and, when asked, squash-merges once everything passed. Ends with a handoff for the consultant.
version: 1.1.0
---

# Ship to `<version>` and `<version>-staging`

Use this only when the user **explicitly asks** for the PRs. It scripts the
push, PR, staging and `/run-tests` steps of `odoo-pr` and `odoo-staging-branch`;
those skills stay the reference for each rule.

## Which PRs

`<version>` is the Odoo version the feature branch starts with (`18.0`,
`20.0`, ...); the script reads it from the branch name.

- Customer repos: the user usually asks for both `<version>` and
  `<version>-staging`. When the request names only `<version>`, add
  `--no-staging`. When it names no base, ship to `<version>` only
  (`--no-staging`) and offer the staging PR in your closing line.
- `360_integrations`: `18.0` only (`--no-staging`). Customer staging gets a
  framework change through a submodule bump (see `odoo-staging-branch`).
- **Merge** only when the user asked for it in this request ("squash merge
  when CI passes", "auto merge", "merge when green"): add `--merge`. Never
  merge on your own initiative, and never merge a PR the user did not name or
  ship in this request.

## Steps

1. **Commit** with the `odoo-commit` skill. The script ships committed work
   only, and takes the identifier from the latest commit. For a new module,
   check the `development-request` new-module checklist first: a missing icon
   or README costs a second commit and, after a merge, a new staging PR.
2. **Write the PR description** to a scratchpad file when a PR will be
   created: what changed, why, how it was validated, and for new or changed
   modules the technical names (see "Handoff").
3. **Ship**, from inside the repository (`--dry-run` prints the plan and
   changes nothing):

   ```bash
   bash scripts/ship.sh --body-file <file> [--no-staging] [--merge]
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
4. **Watch CI in the background.** Start the `Watch CI:` command the script
   printed as a background task (`run_in_background`), write the handoff
   while it runs, and report when it finishes. Never wait for CI in the
   foreground with `sleep` or polling loops. `/run-tests` dispatches the
   `test.yml` workflow on the PR's head branch, so the run never shows up in
   `gh pr checks`.

   With `--merge`, the watcher then waits for each PR's own checks and
   squash-merges every PR, in the order given, only when all test runs and
   checks passed; otherwise it prints `NOT MERGED` and the reason. GitHub's
   auto-merge can't do this here: the 360ERP branches are unprotected and the
   `/run-tests` run is not a PR check.

   A merge to `<version>-staging` deploys staging; tell the user it is merged
   so they can watch the Odoo.sh build.

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
where `/run-tests` was posted, the CI result once the watcher finishes, and
what was merged (or `NOT MERGED` and why). Then add the handoff.

## Handoff

End every ship with a short handoff, so the user does not have to ask for it
in follow-up turns. Skip a part that does not apply (e.g. no configuration).

1. **Message for the consultant** — ready to paste, in the user's voice:
   casual and short (3–6 sentences), plain words, no headings, no bullet
   walls, no "I've implemented". What changed for the customer, what they
   must configure, and what to test. Match the language of the ticket's
   chatter (English or Dutch); never mention AI.
2. **Configuration** — numbered UI steps (menu path, setting, group to
   assign) needed before the change is visible.
3. **Test steps** — 3–6 numbered steps from the simplest scenario to the edge
   case, each with the expected result, usable by the consultant or by a
   browser-testing agent.
4. **Technical names** — for new or changed modules: module names, new
   fields (`model.field_name`), groups (`module.group_xml_id`), menus and
   scheduled actions. Also put this list in the PR description.

Do not post the message to Odoo or send it anywhere; the user does that.
