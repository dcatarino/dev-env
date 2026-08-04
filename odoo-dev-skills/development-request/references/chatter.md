# Reconstructing chatter, and handling privacy and attachments

Read this only after explicit live-data authorization (see `SKILL.md`).

## Reconstruct the complete chatter

Never trust the order of `message_ids`. Query the chatter for each relevant
record explicitly:

1. Count `mail.message` records with this domain:

   ```text
   model = <record model>
   res_id = <record ID>
   ```

2. Search-read the same domain ordered by `date asc, id asc`.
3. Retrieve `id`, `date`, `author_id`, `body`, `message_type`, `subtype_id`,
   `model`, `res_id`, and `attachment_ids`.
4. Paginate until the number retrieved equals the count. A default result limit
   is not proof that all chatter was read.
5. Convert HTML bodies into readable text before analysing or quoting them.

If search-read is unavailable, read every ID from `message_ids` and sort the
results locally by `(date, id)` ascending.

When the user identifies a date or message as the relevant starting point, focus
the functional chronology from that boundary forward. Read older material only
when needed to resolve references in the newer messages.

Retrieve first, filter second. Usually omit these from the final chronology:

- empty messages;
- assignment-only tracking;
- stage changes with no explanatory body;
- record-created notifications and standard receipt acknowledgements;
- duplicate bot progress messages;
- signatures and quoted email boilerplate.

Keep any message whose body contains a requirement, decision, correction,
reproduction step, technical finding, test result, blocker, or implementation
detail, regardless of its message type or subtype.

Identify:

- the original reported behaviour;
- later corrections or scope changes;
- failed reproduction attempts and why they may have failed;
- staging-versus-production or other environment differences;
- country, company, user-role, or configuration differences;
- the latest explicit acceptance criteria;
- unanswered questions that materially change implementation.

## Privacy

Never expose:

- access tokens or URLs containing `access_token`;
- API keys, passwords, cookies, or authorization headers;
- unnecessary email addresses, phone numbers, or customer contact details;
- database names, infrastructure identifiers, private URLs, or operational
  commands unless explicitly needed and authorized.

Strip sensitive query parameters before showing a useful URL. Do not quote
automated portal acknowledgement links.

## Attachments

For each substantive message with attachments:

1. Read safe `ir.attachment` metadata such as `id`, `name`, `mimetype`,
   `file_size`, `description`, `res_model`, `res_id`, and `create_date`.
2. Decide whether the attachment can change the requirement or diagnosis.
3. Inspect its content only when useful and supported by the available tools.
4. Never print binary or base64 content.

Screenshots, logs, sample files, and documents can be requirement evidence. A
filename alone is not evidence of its contents.
