# Evidence-first implementation plans

Use this format for planning-only requests. Inspect the supplied context and any
authorized local repository before writing the plan. Do not retrieve live data,
edit code, run tests, publish a ticket, commit, push, open a pull request,
deploy, or write to an external system merely to produce a plan.

## Plan schema

1. **Confirmed goal and behaviour**
   - State the confirmed user goal, current behaviour, and expected behaviour.
   - Separate confirmed facts from assumptions and open decisions. Cite the
     inspected source, repository location, or supplied context for each
     material fact.
2. **Acceptance criteria and exclusions**
   - List observable acceptance criteria.
   - State the work deliberately outside scope.
3. **Implementation slices**
   - Order dependency-aware vertical slices from prerequisite to completed
     behaviour.
   - For every slice, include its independently observable outcome, confirmed
     component or module owner, highest stable test seam, and verification.
   - Name exact filenames, classes, routes, models, or methods only after
     inspecting them. Otherwise name the confirmed ownership boundary and label
     the missing detail as an inspection task.
4. **Operational considerations**
   - Cover material risks and, where relevant, migration, deployment, and
     rollback.
5. **Open decisions**
   - Ask only for decisions that materially change behaviour, stored data, API
     contracts, or scope. Batch them and include a recommended answer and its
     consequence.

## Investigation and verification rules

Discover inspectable facts yourself before asking questions: trace the relevant
call path, identify the owning module, and check the available repository and
version context. Do not ask the user to supply facts that can be established by
inspection.

Propose focused tests when they strengthen the plan, but mark their execution as
gated. Describe the strongest static or observational verification available
when a runnable environment is absent. Keep evidence, assumptions, and pending
decisions visibly distinct so the plan is executable without overstating
certainty.
