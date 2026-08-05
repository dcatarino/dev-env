---
name: plan-development
description: Create a thorough, implementation-ready development plan before coding. Use when the user asks to plan or design a non-trivial change, wants requirements stress-tested, or needs an ambiguous development request turned into bounded implementation steps. Resolves material decisions, inspects the real codebase, chooses verification seams, and slices the work vertically without making code changes.
version: 1.0.0
---

# Plan a development

Turn a request into a plan that another developer or agent can implement without
guessing. Planning is the deliverable: do not edit production code, commit, push,
or open a PR while running this skill unless the user separately asks for those
actions.

## 1. Ground the request

State the outcome in one sentence, then gather facts before asking questions:

- Read the repository guidance and the code around the affected behaviour.
- Find the owning module and trace the current path from the highest relevant
  public or user-visible boundary inward.
- Read existing tests, nearby implementations, project knowledge files, and
  architectural decisions when present.
- For Odoo work, confirm the target Odoo version and customer/project context;
  do not assume the default Codespace version is the customer's version.
- For external APIs, verify capabilities in official documentation or existing
  connector code before making them part of the design.

Do not ask the user for facts that the repository or available tools can answer.

## 2. Resolve decisions, not trivia

Build a small decision map around the outcome: expected behaviour, scope,
ownership, data/contracts, compatibility, security/permissions, failure
behaviour, and rollout or migration when relevant.

If a missing answer would materially change the implementation, ask the user.
Ask only currently answerable decisions: do not ask a question whose answer
depends on another unresolved question. Group independent questions into a short
round and include a recommended answer with the trade-off.

Stop asking when the remaining uncertainty can be resolved safely during
implementation or does not change the design. If nothing material is ambiguous,
ask nothing.

For Odoo changes, explicitly consider only the relevant hazards: extension hook
versus duplication, server-side enforcement behind UI behaviour, access rules
and `sudo()`, multi-company/multi-website behaviour, queue-job boundaries, and
upgrade/migration effects.

## 3. Choose verification seams

A verification seam is the highest stable boundary where behaviour can be
observed without coupling tests to internals. Prefer an existing seam over
creating a new one and minimize the number of seams.

For each important behaviour, define:

- the observable input and outcome;
- the focused check that can fail before the change and pass after it;
- whether it is best verified by an existing unit/integration test, an Odoo
  test, a deterministic script, or end-to-end UI verification.

Do not invent tests merely to mirror implementation details. Respect the
repository's rules about whether test execution requires explicit user approval.

## 4. Slice the implementation vertically

Plan the smallest coherent change that delivers the outcome. When the work is
too large for one coherent change, split it into vertical slices: each slice
should make a narrow behaviour work end to end and be independently verifiable.
Name dependencies between slices.

Use a preparatory refactor only when it clearly makes the requested change safer
or simpler. Keep speculative cleanup out of scope.

## 5. Return the plan

Keep the report compact and implementation-ready:

1. **Outcome** — the user-visible result and current/expected behaviour.
2. **Decisions** — confirmed choices and the reasoning that changes the design.
3. **Implementation** — ordered vertical steps naming confirmed modules or
   components. Name exact files or methods only when they were inspected.
4. **Verification** — the selected seams and concrete checks.
5. **Risks / out of scope** — only material compatibility, migration, security,
   or scope boundaries.
6. **Open questions** — only unresolved decisions that still block a safe plan;
   omit the section when there are none.

The plan is complete when every implementation step is supported by repository
evidence, every material decision is either resolved or explicitly open, and
every user-visible behaviour has a verification path.
