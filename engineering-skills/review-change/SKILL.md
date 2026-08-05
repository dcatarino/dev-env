---
name: review-change
description: Review a branch, PR, commit range, or work-in-progress development change for both requirement fidelity and engineering risk. Use when the user asks for a code review, PR review, diff review, or wants to verify that an implementation matches its plan or ticket. Separates intent/spec findings from code-quality, Odoo, compatibility, security, and test-evidence findings.
version: 1.0.0
---

# Review a development change

Review the change as two independent questions: **did we build the right thing?**
and **did we build it safely?** Do not modify code unless the user separately
asks for fixes.

## 1. Pin the change

Resolve the fixed point and inspect the complete diff plus commit list. Use the
user's requested base when supplied. Otherwise infer the repository's normal
base only when it is unambiguous; ask if choosing a base would change what is
reviewed.

Read repository guidance before judging the diff. Ignore formatting or style
rules already enforced mechanically unless they reveal a real behavioural risk.

## 2. Recover the intended behaviour

Use the strongest available source of intent: the current conversation, supplied
ticket/spec, explicit acceptance criteria, then commit/PR description. For Odoo
requests with live 360 ERP data, preserve the `development-request` live-data
gate; a review request alone is not permission to read live records.

Write down the observable behaviours and scope boundaries the change is meant to
satisfy. When no reliable spec exists, say so rather than inventing one.

## 3. Review requirement fidelity

Trace each intended behaviour through the diff and report only actionable gaps:

- missing or partially implemented acceptance behaviour;
- behaviour that contradicts a newer clarification;
- extra behaviour or refactoring outside the requested scope;
- a test that proves a different behaviour than the requirement;
- assumptions about an external API, Odoo version, or customer environment that
  are not supported by evidence.

## 4. Review engineering risk

Run a separate pass over the same diff. Match the repository's documented
patterns first, then check for risks that matter in this codebase:

- correctness at the actual extension point rather than duplicated framework
  behaviour;
- access rights, record rules, `sudo()`, portal/public boundaries, and secrets;
- multi-company or multi-website leakage;
- queue-job idempotency, retries, transaction boundaries, and user-facing job
  behaviour when relevant;
- stale computed/cache state, schema/data migrations, upgrade safety, and target
  Odoo-version compatibility;
- external API contracts verified against primary documentation or established
  connector code;
- unnecessary abstraction, duplicated logic, or scattered changes that make the
  requested behaviour harder to maintain.

Treat these as judgement prompts, not a checklist to manufacture findings.

## 5. Check verification evidence

Inspect relevant tests and validation results. Prefer tests through stable public
or user-visible seams; flag implementation-coupled or tautological tests only
when they weaken confidence in the change.

Do not claim a command or test passed unless there is evidence it actually ran.
Respect the environment's user-approval gates for running Odoo tests or external
actions.

## Report

Lead with findings, ordered by severity. Each finding must include the affected
location, the concrete failure scenario, and the smallest useful direction for a
fix. Label findings as **Requirement** or **Engineering** so the user can see
which axis failed.

If there are no actionable findings, say so directly and list any important
verification gap that still limits confidence. Avoid praise, generic summaries,
and speculative nits that would not change the implementation.
