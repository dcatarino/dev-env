---
name: followup
description: This skill should be used when the user asks for a message about work on a ticket, task or development request — "prepare a follow up", "message to the customer", "hand off to the consultant", "what do I tell the client", "reply to my colleague", "status update for the customer" — or invokes /followup [customer|consultant|colleague] [record ID] [language]. It writes one short, plain message, saves it in the ticket's notes folder and shows it: what was done or found, what the reader has to do, and what happens if nobody decides. Not for researching an answer to a new customer question; that is 360-brain where the session has it.
version: 1.0.0
---

# `/followup` — one message about work you own

```
/followup [customer | consultant | colleague] [ticket, task or request ID] [language]
```

The user talks to customers and consultants themselves and sends the message
by hand. This skill writes it so they do not have to restate, in every
session, who the reader is, how short it must be, and that the draft belongs
in a file.

## When it is another skill's job

- **A new question that needs research** (why does Odoo do this, is it
  standard, was it solved before): `360-brain` reads the customer's setup and
  360's history and drafts the reply. Use it when the session has the
  `360-support` plugin; come back here only to save the agreed text.
- **Right after `odoo-ship`**: its handoff already contains the consultant
  message. Save that message with step 4 instead of writing a second one.

## Steps

1. **Collect what the message is about**, cheapest source first: the ticket's
   `brief.md` (see "Ticket notes" in the agent instructions), this session,
   the open PRs. When a record ID is given and the brief is missing or older
   than the last chatter, read the record with `development-request`: the
   newest messages show what was last said, by whom, and what is still
   unanswered. Do not re-read a long thread the brief already summarises.
2. **Pick the reader** from the argument. Without one: the consultant when a
   consultant other than the user is the contact on the record, otherwise the
   customer. Say which one you picked in your reply.

   | Reader | Knows | Wants |
   | --- | --- | --- |
   | `customer` | their business and screens, not Odoo internals | what changes for them, what to do, what you need |
   | `consultant` | functional Odoo, the customer | what to configure, what to test, what to tell the customer |
   | `colleague` | the code | the finding, the evidence, the exact ask |

3. **Write it.** In this order, leaving out what does not apply:
   1. The state, in one or two sentences: what is done, found or decided.
   2. What the reader has to do: numbered steps, with the menu path as the
      screen shows it and the expected result.
   3. Open points, at most three. State each as what happens today and what
      you will do unless they say otherwise ("Orders without a delivery date
      stay in draft. I will leave that as it is unless you want them
      confirmed automatically."). Ask a plain question only when there is no
      sensible default.
   4. The next step and who takes it.
4. **Save and show.** Write the message to
   `<ticket notes folder>/messages/<YYYY-MM-DD>-<reader>.md` (add `-2`, `-3`
   when the name exists), then show the same text in your reply with the
   path. A spreadsheet or guide that goes with it is saved in the same
   folder. When the user already edited a file there, change their file;
   never regenerate it.
5. **Update `brief.md`**: add what the message says under "Promised" and
   "Open questions", marked as drafted on today's date. It becomes "sent"
   when the user says they sent it.

## How it reads

- English, unless a language is given or `brief.md` records one for this
  reader. The chatter being Dutch is not a reason to write Dutch.
- The user's voice: "I" and "we", casual, short. Three to eight sentences
  plus the numbered steps. No headings in a short message, no bullet walls.
- Say the thing, say what to do, stop. No greeting formulas, no restating
  their question, no "I hope this helps", no closing offer.
- Plain words for a customer: a field by its label, a screen by its menu
  path, no model or field names, no module names, no Git or CI words. For a
  consultant or colleague, put technical names (modules, `model.field`,
  groups) in one list at the end.
- Facts only from the brief, the record or the code. No hours, price or date
  the user did not give. Mark anything you could not verify as not verified.
- Do not offer custom development or Odoo Studio. When configuration cannot
  do it, say what is possible today and leave the proposal to the user.
- Never mention AI or agents. Never name another customer. First names only;
  no e-mail addresses or phone numbers.

## Boundaries

Never send, post or e-mail the message, and never write it to 360 (chatter,
notes): the user does that. A file for the customer in 360's look goes through
`360-housestyle` with the PDF, Word or Excel skill when the session has them.
