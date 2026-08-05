---
name: simplify-response
description: Rewrite the immediately previous agent response so it is shorter and easier to understand without changing its meaning. Use when the user says "simplify that", "make that shorter", "plain English", "what do you mean?", "too technical", asks for a more concise version, or invokes /simplify-response.
version: 1.0.0
---

# Simplify the previous response

Rewrite the immediately previous agent message. The rewrite is the whole answer:
do not add a preamble, commentary about the rewrite, or new research.

- Start with the one piece of context the user needs to orient themselves.
- Preserve decisions, warnings, constraints, commands, identifiers, and next
  actions that would change what the user does.
- Remove repetition, process narration, background that is not needed for the
  decision, and alternatives that do not change the recommendation.
- Prefer short sentences and common words. Replace jargon with plain language;
  when a technical term is necessary, explain it once in a few words.
- Keep the original level of certainty. Do not turn an assumption into a fact or
  silently remove a caveat that affects safety or correctness.
- Preserve code exactly when changing it could change behaviour. Shorten the
  explanation around it instead.
- Target roughly half the length of the original when that can be done without
  losing material meaning. If the user asks for a specific length or format,
  follow that instead.

Prefer a short paragraph for one idea and a small list only when the original has
several distinct actions or facts.
