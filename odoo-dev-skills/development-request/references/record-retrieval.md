# Retrieving the record and its environment

Read this only after explicit live-data authorization (see `SKILL.md`). If the
connected MCP is unavailable or unauthenticated, report that exact blocker and
continue from supplied context and repository evidence when possible.

Use the connected MCP tools that correspond to Odoo `fields_get`, `read`,
`search_count`, and `search_read`. Tool names can differ between Claude and
Cursor; use the available 360 ERP Odoo MCP tools rather than assuming a literal
tool prefix.

## Resolve the primary record

A URL such as:

```text
https://www.360erp.com/odoo/action-2928/790?debug=1
```

may contain record ID `790` as its final numeric path component. Treat that as a
candidate and verify it by reading the expected model. Do not infer the model
from an action number when the user identifies another model.

If the model is unknown:

1. Use the URL and request wording to narrow it to
   `helpdesk.development.request`, `helpdesk.ticket`, or `project.task`.
2. Verify the candidate by reading it.
3. If the same ID could validly refer to multiple models and the evidence does
   not distinguish them, ask one model-selection question instead of guessing.

Use `fields_get` before making model or field claims or when a requested field is
not accepted. Odoo databases and custom modules can expose different fields.

## Read the record and its direct relations

Read the fields below when they exist. If `fields_get` shows a field is absent,
omit it and record the limitation instead of repeatedly calling it.

### Development request

For `helpdesk.development.request`, read at least:

- `id`, `name`, `ticket_id`, `task_id`;
- `dev_description`, `customer_environment_id`, `project_id`;
- `state`, `priority`, `message_ids`;
- `create_date`, `write_date`.

A development request can relate to a ticket, a task, or both. Follow every
direct relation that can materially affect the current requirement.

### Helpdesk ticket

For `helpdesk.ticket`, read at least:

- `id`, `name`, `description`, `dev_description`;
- `message_ids`, `development_request_ids`;
- `project_id`, `customer_environment_id`;
- `stage_id`, `priority`, `partner_id`;
- `create_date`, `write_date`.

The ticket description is normally the initial request, not necessarily the
current one.

### Project task

For `project.task`, read at least:

- `id`, `name`, `description`, `dev_description`;
- `message_ids`, `development_request_ids`;
- `project_id`, `parent_id`, `child_ids`;
- `stage_id`, `state`, `priority`;
- `customer_environment_id`, `create_date`, `write_date`.

Expand parent tasks, subtasks, dependencies, sibling requests, or project records
only when they materially change scope.

## Resolve the customer environment

When `customer_environment_id` exists, inspect its relation model and fields,
then read safe structured values such as:

- `id`, `name`, `hosting_type`;
- `production_odoo_major_version`;
- `github_repo`, `github_branch_ids`;
- `staging_url`;
- `installed_module_ids`.

Do not read credential fields, API-key relations, database identifiers, or
infrastructure command history. Do not dump large installed-module ID lists;
resolve only modules relevant to the feature.

Use the structured environment record to establish the Odoo major version,
repository, branch context, and hosting type. Do not assume Odoo 18 merely
because the default Codespace workspace contains Odoo 18 source. If ticket prose
conflicts with the environment record, report the mismatch.
