---
name: odoo-integrations
description: This skill should be used when working on Odoo integration code — nexus_* modules in 360_integrations, customer Integrations-<Customer> repos (e.g. matrabike_integrations, pauw_integrations), syncs with external systems (Shopify, Plytix, Picqer, Magento, WooCommerce, ...), or OCA queue_job flows. Covers where the nexus framework knowledge lives, verifying external-API capabilities, Shopify GraphQL validation in this environment, and queue_job behavior.
version: 1.0.0
---

# Odoo integration work (nexus framework)

## Where the knowledge lives — read first

The nexus framework is documented in the platform repo itself. Before designing
or editing integration code, read:

- `/workspaces/360_integrations/.agents/architecture.md` — module naming
  (`nexus_base`, `nexus_base_<system>`,
  `nexus_sync_<source>_<target>_<datatype>`), core models, standard layout.
- `/workspaces/360_integrations/.agents/connectors.md` — available connectors
  and the secrets abstraction (never hardcode credentials).
- `/workspaces/360_integrations/.agents/testing.md` and `code-quality.md` —
  test setup, version-bump rule, lint stack, hard guardrails.

Customer repos (`/workspaces/Integrations-<Customer>`, one module named
`<customer>_integrations`) build on this same framework. Another customer's
module is often the intended reference implementation — check with the user
which one to mirror before inventing a new pattern.

## External APIs: verify, don't assume

Never build a plan on an external-API capability you haven't confirmed. Check
the official API docs or the existing connector code and query documents first.
If a needed capability doesn't exist, say so and propose an alternative instead
of designing around a guess.

## Shopify specifics

- The connector is `nexus_base_shopify` (GraphQL Admin API). Query documents
  live as `.gql` files inside the sync modules (e.g. `data/graphql/`).
- **Do not run the `shopify-admin` plugin's `validate.mjs` validator** — its
  schema `data/` directory is missing in this environment, so it always fails
  with ENOENT before checking anything. Validate fields against the
  shopify.dev docs or the existing `.gql` documents instead; don't retry the
  validator.

## queue_job notes

- Sync flows enqueue work via `with_delay()`; jobs become `queue.job` rows.
- `identity_key` deduplicates only pending/enqueued jobs — a **failed** job
  does not block re-enqueueing the same key.
- Job descriptions are user-facing; keep the established style, e.g.
  `odoo -> shopify stock: [SKU]` for single-record batches.
- For asserting jobs in tests, see the queue_job note in the `run-odoo-tests`
  skill.
