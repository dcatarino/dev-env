---
name: run-odoo-tests
description: This skill should be used when running Odoo unit tests, in a local 360-work environment or a Codespace — e.g. to verify the modules just changed, when the user asks to run or verify tests for an Odoo module/addon, confirm a fix or PR passes, or set up a test database. Covers `360-work odoo test` locally, the bundled runner script in a Codespace, the persistent test-DB workflow, targeting a specific test class or method, and the queue_job behaviour that affects test assertions.
version: 1.2.0
---

# Run Odoo unit tests

Tests run at module install/upgrade time via `odoo-bin` with `--test-enable`
and `--stop-after-init`, in a reusable test database (default `odoo-test-1`).

## Local 360-work environment

The workspace has a `context/task.json`, and its `CLAUDE.md` describes the
local Odoo runtime. Run the tests of the modules you changed before reporting
the work done. From inside the repository folder:

```bash
360-work odoo test --modules MODULE[,MODULE]
```

| Option | Purpose |
| --- | --- |
| `--test-tags /MODULE:TestClass.test_05_x` | Run one class or method instead of the whole suite. |
| `--fresh` | Recreate the test database — after an install-time change (manifest dependencies, XML data, security). |
| `--database NAME` | Use a different reusable database. |

It prints `PASSED` or `FAILED` with the log path and exits non-zero on
failure. **The first run builds the Docker image and installs the dependency
chain, which takes minutes:** launch that one as a background task and wait
for its completion notification. Later runs are fast. When `360-work` is not on
PATH, use the path the environment's `CLAUDE.md` gives.

`--fresh` cannot drop the database while another connection holds it, such as
the server `360-work odoo up` started. Run `360-work odoo down` first, and
`360-work odoo up` again afterwards.

## Codespace

Only when the user explicitly asks — the user normally runs these manually.

### Run them

From the project root (e.g. `/workspaces/<project>`), run the bundled script
from this skill's directory:

```bash
bash scripts/run_odoo_tests.sh --modules MODULE
```

It creates the reusable database on first use, re-runs the module's tests on
every later invocation, prints a parsed `PASSED`/`FAILED` summary, and exits
non-zero on failure. Options:

| Option | Purpose |
| --- | --- |
| `--modules a,b` | Technical module names (required). Dependencies install automatically. |
| `--test-tags /MODULE:TestClass.test_05_x` | Run one class or method instead of the whole suite. |
| `--database NAME` | Use a different reusable DB (default `odoo-test-1`). |
| `--upgrade` | Use `-u` instead of `-i` — forces a code/schema reload when a test isn't picking up a model or field change. |
| `--project-dir PATH` | If not running from the project root. |

**The first run installs the dependency chain and takes minutes.** Launch that
one as a background task and wait for its completion notification — never
foreground-`sleep` or poll. Later runs are fast; run them normally.

The script always binds free HTTP and gevent ports, so a running dev server
cannot cause the `Address already in use` failure that otherwise makes
`odoo-bin` exit before a single test runs.

### Environment facts

- Python:   `/home/odoo/.pyenv/shims/python3` (override with `ODOO_PYTHON`)
- odoo-bin: `/workspaces/odoo/odoo-bin` (override with `ODOO_BIN`)
- Config:   `<project>/.codespace-env/odoo.conf` — holds `addons_path` and
  `db_user = odoo`
- Postgres: local, `-h 127.0.0.1 -U odoo`, no password

Recreate the database from scratch only after an install-time change (manifest
deps, XML data, security):

```bash
dropdb -h 127.0.0.1 -U odoo odoo-test-1
```

## Reading a failure

Both runners tail the relevant lines and print the full log path. Open that log
for anything they did not surface — do not re-derive the grep, and do not read
a bare `0 failed, 0 error(s)` as success without checking the test count was
non-zero (the runners do this).

## queue_job (OCA) in tests

Modules depending on `queue_job` enqueue jobs via `with_delay()`. Under tests
these are recorded as `queue.job` rows and not executed inline unless the test
sets `queue_job__no_delay=True` in context (or the env enables no-delay). To
assert a job was or wasn't enqueued, patch `with_delay` (e.g.
`unittest.mock.patch.object(type(record), "with_delay")`) and check the mock.
