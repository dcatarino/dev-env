---
name: capture-customer-knowledge
description: This skill should be used when the user asks to capture, save, or record what was learned about a customer from recent work — e.g. "/capture-customer-knowledge", "save what we learned about this customer", "record the facts from the last few sessions". Scans the three most recent Claude sessions by default (or the sessions the user names), extracts durable facts about the customer's Odoo environment, and writes them to persisted agent memory with credentials and personal data stripped.
version: 1.0.0
---

# Capture what was learned about a customer

Sessions end and their findings die with them. This turns recent session
history into durable memory: the customer's Odoo version, module set,
integration quirks, and working conventions, written where the next session
will load them.

Memory lives at `~/.claude/projects/<encoded-project-path>/memory/`, which
`persist-agent-memory.sh` symlinks into `dev-env/memory/`, so anything written
here survives a Codespace rebuild.

## Step 1 — Choose the sessions

Default to the **three most recent sessions**. Only deviate when the user names
a different scope ("the last 10", "today's sessions", "the Acme ones", a session
id).

```bash
bash scripts/scan_sessions.sh --list --count 3
```

Add `--project <substring>` to restrict to one customer's checkout. Show the
user the list and which sessions you are about to scan — a wrong window wastes
the whole pass.

## Step 2 — Scan them

Transcripts are hundreds of KB, mostly tool output. `--extract` strips each one
to the conversation (typically a 50x reduction):

```bash
bash scripts/scan_sessions.sh --extract 1
```

**Never read raw `.jsonl` into the main context.** For more than one session,
spawn a subagent per session that runs `--extract` and returns only candidate
facts, so the transcripts never enter this context at all.

## Step 3 — Keep only durable customer facts

A fact earns a memory file when it is **specific to this customer** and **still
true next month**. What qualifies:

- Odoo major version, hosting type, repository and branch conventions.
- Which custom modules own which behaviour, and the reference implementation to
  mirror.
- External systems in play and their real, verified quirks — an endpoint that
  does not exist, a field that behaves unlike the docs, a sync that must run in
  a given order.
- Environment differences that repeatedly bite: staging-versus-production
  behaviour, multi-company or multi-website setup, locale and currency.
- Decisions and constraints the customer has settled, with the reasoning.
- Recurring blockers and their resolved workaround.

What does not qualify: anything derivable by reading the repo, one-off task
detail, what the code already documents, or a fact you inferred but never
confirmed. If it was never verified, either say so in the body or leave it out.

## Step 4 — Strip before writing

Never write into a memory file:

- access tokens, API keys, passwords, cookies, or authorization headers;
- URLs containing `access_token` or any other credential parameter;
- customer email addresses, phone numbers, or personal contact details;
- database names, infrastructure identifiers, or private hostnames.

A fact that cannot be stated without one of those does not get written. Keep the
reusable shape and drop the sensitive part — "staging rebuilds drop
`ir.config_parameter` overrides" rather than the URL and credentials that proved
it. Name roles, not people.

## Step 5 — Write the memory

Write into the memory directory of the project the session belongs to (the
`project:` line from `--list`), one fact per file:

```markdown
---
name: <short-kebab-case-slug>
description: <one line — this is what future sessions match on>
metadata:
  node_type: memory
  type: project
  originSessionId: <session id it came from>
---

<the fact>

**Why:** <the reasoning, so a future session can tell when it stops applying>
**How to apply:** <what to actually do differently>
```

Use `type: project` for customer and environment facts, `type: reference` for
pointers to external docs or dashboards, `type: feedback` for how the user wants
work done. Convert relative dates to absolute ones.

Then add one line per new memory to `MEMORY.md` in the same directory:

```markdown
- [Title](file.md) — short hook
```

Before writing, read the existing files: update the one that already covers the
topic rather than adding a near-duplicate, and delete any that this session
proved wrong.

## Step 6 — Report

List each fact captured, which session it came from, and whether it created a
new file or updated an existing one. Call out anything you deliberately dropped
for being unverified or unstrippable — that is the useful half of the report.
