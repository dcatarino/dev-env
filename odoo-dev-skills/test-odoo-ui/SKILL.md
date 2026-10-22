---
name: test-odoo-ui
description: This skill should be used when testing an Odoo user-interface feature end to end, in a local 360-work environment or a Codespace. It prepares or reuses a dedicated test database, installs or upgrades the affected modules, ensures Odoo is running, signs in as admin/admin, and hands the ready database URL to browser automation.
version: 1.3.0
---

# Test Odoo UI end to end

Prepare the Odoo database and authenticated web entry point before exercising
the requested feature with browser automation. Identify the addon modules
affected by the change from the checked-out code, and use a dedicated reusable
database: `odoo_ui_e2e` by default, or a feature-specific name when isolated
state is useful. Never use the unit-test database.

## Local 360-work environment

From inside the repository folder:

1. Create the database on first use, or upgrade the modules on later runs:

   ```bash
   360-work odoo bin -- -d odoo_ui_e2e -i module_a,module_b --stop-after-init   # first run
   360-work odoo bin -- -d odoo_ui_e2e -u module_a,module_b --stop-after-init   # later runs
   ```

   On Odoo 19 and later, add `--with-demo` to the first run when demo records
   help the scenario; older versions load demo data by default. A new database
   signs in with `admin` / `admin`.
2. Start the server with `360-work odoo up`; it prints the URL
   (`http://localhost:<port>`). After a Python change, restart it with
   `360-work odoo down` and `360-work odoo up`.
3. Open `<URL>/web/login?db=odoo_ui_e2e` with the available browser
   automation (for example Claude in Chrome) and sign in.

When a click by coordinates does not register, click the element by
reference or from JavaScript (`element.click()`), and check the network
requests before concluding that the UI is broken.

## Codespace

### Prepare the environment

Run the bundled script from this skill's directory:

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
`.devcontainer/scripts/task_start_odoo.sh` when port 8069 is not ready, makes
the forwarded Odoo port public, and prints `ODOO_UI_URL` after an `admin/admin`
web login succeeds. If GitHub cannot make the port public (for example because
it is not forwarded or organization policy disallows public ports), it stops
with a clear error instead of returning an unusable browser URL.

### Open it

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

The script's authentication probe verifies readiness; it is not a substitute
for exercising the requested feature in a browser.

## Exercise the UI

1. Navigate through the actual user workflow requested by the user. Assert the
   visible behavior and capture concise evidence for failures.
2. Report the database, the URL, the tested flow, and the result. Keep the
   database unless the user explicitly asks for cleanup.
