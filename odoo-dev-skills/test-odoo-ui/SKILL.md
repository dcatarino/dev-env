---
name: test-odoo-ui
description: This skill should be used when testing an Odoo user-interface feature end to end in a Codespace. It prepares or reuses a test database through odoo-bin, installs or upgrades the affected modules, ensures Odoo is running, resets the test administrator to admin/admin, verifies web authentication, and hands the ready database URL to browser automation.
version: 1.1.0
---

# Test Odoo UI end to end

Prepare the Odoo database and authenticated web entry point before exercising
the requested feature with browser automation.

## Prepare the environment

1. Identify the Odoo project root and the addon modules affected by the change.
   Derive these from the checked-out code when possible.
2. Choose a dedicated reusable database name. Default to `odoo_ui_e2e`; use a
   feature-specific name when parallel or isolated state is useful.
3. Run the bundled script from this skill's directory:

   ```bash
   bash scripts/prepare_odoo_ui.sh \
     --project-dir /workspaces/<project> \
     --database odoo_ui_e2e \
     --modules module_a,module_b
   ```

   Omit `--modules` only when no custom addon needs installation or upgrade.
   The script creates a database without demo data on its first run and upgrades
   the named modules on later runs, so keep and reuse the database during normal
   iteration.

The script uses the project's `.codespace-env/odoo.conf`, runs setup with the
checked-out `/workspaces/odoo/odoo-bin`, starts Odoo through
`.devcontainer/scripts/task_start_odoo.sh` when port 8069 is not ready, and
prints `ODOO_UI_URL` after an `admin/admin` web login succeeds.

## Exercise the UI

1. Open the printed `ODOO_UI_URL` with the available browser automation. Prefer
   a native browser tool when one is exposed. Otherwise, use the Playwright and
   Chromium runtime installed by the Codespace bootstrap; run a feature-specific
   Node script that imports `playwright` with:

   ```bash
   NODE_PATH="$(npm root -g)" node /tmp/odoo-ui-e2e.js
   ```

2. If GitHub first shows the one-time **Codespaces Access Port** warning, choose
   **Continue** and wait for the Odoo login form.
3. If the login form is shown, select the prepared database when necessary and
   sign in with `admin` / `admin`.
4. Navigate through the actual user workflow requested by the user. Assert the
   visible behavior and capture concise evidence for failures.
5. Report the database, tested flow, and result. Keep the database unless the
   user explicitly asks for cleanup.

The script's authentication probe verifies readiness; it is not a substitute
for exercising the requested feature in a browser.
