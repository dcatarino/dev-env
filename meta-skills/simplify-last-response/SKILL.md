---
name: simplify-last-response
description: Manually rewrite the immediately previous assistant response in shorter, plainer language. Use only when the user explicitly invokes /simplify-last-response or $simplify-last-response to simplify the last answer without changing its meaning.
version: 1.0.0
disable-model-invocation: true
---

# Simplify the last response

Rewrite only the immediately previous assistant response. Respond only with the
rewrite: add no preamble, explanation, facts, decisions, certainty, or actions.

Default to shorter, plainer language. Preserve the original meaning, outcome or
status, commands and code blocks, file paths, links, identifiers, numbers,
choices, warnings, blockers, caveats, and uncertainty. Remove repetition,
tangents, and unexplained jargon; briefly define jargon that cannot be removed.

If no previous assistant response exists, state that plainly and ask the user to
paste the text to simplify.
