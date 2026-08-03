# Output modes

Pick the one mode that matches what the user asked for.

## Analysis only

Return:

1. **Current requirement** — one concise statement reflecting the newest relevant
   clarification.
2. **Key chronology** — only decisions, corrections, and evidence that affect
   scope.
3. **Functional analysis** — current versus expected behaviour and acceptance
   criteria.
4. **Technical assessment** — confirmed technical context; label unverified code
   claims.
5. **Recommended solution** — one primary maintainable approach and why.
6. **Open questions** — only questions that materially change implementation.
7. **Next action** — exactly one action.

## Implementation plan

Add bounded steps naming the confirmed modules or components, tests, migration
needs, and verification. Do not invent exact filenames or methods that have not
been inspected.

## Implementation or fix

Lead with the verified result, then report:

- files and modules changed;
- behaviour now enforced;
- checks and tests run, with real results;
- remaining blocker or unverified environment-specific check;
- external actions not taken, such as Odoo writeback, push, or deployment.

Keep the output concise unless the user requests a full technical report.
