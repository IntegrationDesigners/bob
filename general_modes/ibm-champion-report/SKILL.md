---
name: ibm-champion-report
description: "Use this skill when the user wants to report or register an IBM Champion / Rising Champion activity (an 'act of advocacy') on the IBM Champion Program Activity Report form. Triggers on requests like 'report my IBM Champion activity', 'log a champion act of advocacy', 'fill in the champ-report form', 'register this blog/talk/repo for my IBM Champion badge', 'submit my champion activity', or when the user mentions the IBM Champion activity report, ibm.biz/champ-report, or the Airtable champion form. Produces a proven prefilled form URL plus a copy-paste field sheet; it does not auto-submit the web form."
metadata:
  version: 1.1.0
  status: stable
  last_updated: 2026-07-02
---

# IBM Champion Activity Report

You help the user report an IBM Champion (or Rising Champion) **act of advocacy** on
the IBM Champion Program Activity Report form. You assemble every value the user
needs, polish the free-text description to fit the 250-word limit, pull their identity
from a private `.env` file, and produce a proven prefilled form URL (8 of the form's
fields populate automatically) plus a copy-paste sheet for the fields that cannot be
prefilled.

If a browser-automation MCP is available you can open the form and fill it in place,
then verify each field. You never tick the consent checkbox and never submit - the
human does the final review, consent, and click. Without a browser MCP, your value is
the prefilled URL plus the copy-paste sheet that make that click take ten seconds.

- **Form:** https://airtable.com/appuwf3eOGdO6x1oS/pagF5IfVT7m6unCbG/form
- **Short URL:** https://www.ibm.biz/champ-report

**Before assembling anything**, read [`references/form_fields.md`](references/form_fields.md) -
it is the authoritative field spec: which values come from `.env`, the verified
dropdown option lists (Appendix A/B), date format, word limits, and the proven
prefilled-URL mechanism (which fields prefill by field ID, which by name, and which
are manual-only).

---

## Identity comes from `.env`, never from the chat

The user's stable identity (Champion Program ID, name, emails) lives in this skill's
`.env` file. It is gitignored and private.

1. Read `.env` from the skill folder. Use those values for the identity fields.
2. If `.env` is missing, read [`.env.sample`](.env.sample) for the shape and ask the
   user to copy it to `.env` and fill in their real values once. Do not paste real
   identity values into chat history or any committed file.

---

## Workflow

### 1. Load the field spec and identity

- Read [`references/form_fields.md`](references/form_fields.md).
- Read `.env`. Confirm the identity block silently (do not echo full emails unless
  the user asks); if a required key is missing, ask the user to fill `.env`.

### 2. Gather the activity (one act at a time)

Each submission carries 1 to 3 acts of advocacy. For each act, collect:

- **What they did** - enough to write a description and pick the activity type.
- **Act of Advocacy type** - map their description to the closest entry in the
  verified Appendix A list, then confirm it is the activity they mean.
- **Product(s) involved** - map to the verified Appendix B product list; anything not
  listed goes in via the form's **Other -> type the name** option.
- **Link** - push hard for one. "Lack of link may result in disqualification."
- **Date** - last 12 months; format `D/M/YYYY`; first-of-month if unknown.
- **Can IBM amplify?** - ask, do not assume.

If the user has more than 3 activities, tell them to submit the form again for the
overflow and set "How many MORE" accordingly (Zero / 1 / 2) for this run. **Warning:
the form DEFAULTS this field to 1** - it must be explicitly set to Zero when
reporting a single activity, or the form keeps an empty 2nd act open.

### 3. Write the description (<= 250 words each)

For each act, draft the "Description of this Activity":

- Lead with what was contributed and who it helps.
- Name the product(s) and the concrete artifact.
- Factual, no marketing fluff, no AI-tool signatures.
- Enforce the 250-word cap and report the actual word count.

### 4. Confirm the dropdown choices

The option lists in Appendix A/B of the field spec are verified verbatim from the live
form, so they are authoritative. Your job is to pick the right entry: present the exact
option you chose for each single-select / multi-select field and confirm it is the
activity/product the user means (e.g. "Blog or Article" vs "Blog on IBM property").
If the live form ever changes and an option no longer matches, update
[`references/form_fields.md`](references/form_fields.md).

### 5. Produce the output

Always provide these (they are the reliable fallback and the record). Build them
BEFORE any browser filling - the browser procedure in step 6 consumes the prefilled URL:

**A. Copy-paste field sheet** - the reliable path. One labelled block per field in
form order, ready to paste:

```
Champion Program ID: <from .env>
First name: <from .env>
Last name: <from .env>
Primary Email: <from .env>
Alternate Email: <from .env>
1st Act of Advocacy: <confirmed dropdown label>
Product(s) Involved: <comma-separated; note any 'Other -> type X'>
Description: <polished, <=250 words>  (word count: N)
Link: <url>
Can IBM Amplify this activity?: <Yes/No>
Date of activity: <D/M/YYYY>
How many MORE Acts of Advocacy: <Zero|1|2>  (form DEFAULTS to 1 - set Zero for a single act)
PRIVACY consent: [ ] tick manually before submitting
```

Repeat the act-specific block for acts 2 and 3 if present.

**B. Prefilled URL (proven)** - built per the prefill section of the field spec. It
pre-populates 8 fields (Champion Program ID, First/Last name, both emails, 1st Act of
Advocacy, Product(s), 1st-activity Date). The remaining fields - Description, Link,
Can IBM Amplify, How-many-more, and PRIVACY consent - cannot be prefilled and stay in
the copy-paste sheet for manual entry once the form opens.

### 6. Offer to fill the form in the browser (if a browser MCP is available)

Check the live tool list for a browser-automation MCP (Browser MCP, Playwright MCP,
Chrome DevTools MCP, etc.). If one is present, offer to fill the form directly - it
is the most convenient path since the form is on a logged-in site. Follow the
**Browser automation** section of [`references/form_fields.md`](references/form_fields.md):

- **Prefilled-URL-first:** navigate to the PROVEN prefilled URL built in step 5B, not
  the bare form URL - identity + Act + Product(s) + Date land automatically. Snapshot
  and confirm those 8 fields populated.
- Match fields by their visible label text, not brittle selectors.
- Automation only types the manual fields: Description and Link, plus the Amplify
  checkbox if the user explicitly allowed amplification. Handle a product not in the
  list via **Other -> type the name**.
- **"How many MORE Acts of Advocacy" defaults to 1, not Zero** (options: Zero / 1 / 2).
  For a single-act submission it MUST be explicitly set to Zero.
- **Fill + verify, never submit:** after filling, re-snapshot and report each field as
  set / not set / mismatch; retry failures once.
- **Do NOT tick the PRIVACY consent checkbox and do NOT click Submit.** Leave the
  filled form open and hand control back for the user to review, consent, and submit.

If **no** browser MCP is available, say so - the sheet + prefilled URL from step 5
already stand alone.

### 7. Final reminders

- The **PRIVACY consent** checkbox and (usually) the **Amplify** checkbox must be
  ticked by hand - you cannot consent for the user.
- Remind them only activities from the **last 12 months** are eligible.
- A link is effectively mandatory.

---

## Reference files

| File | When to read |
|---|---|
| [`references/form_fields.md`](references/form_fields.md) | **Read before assembling anything** - full field spec, dropdown option lists, date format, word limits, prefilled-URL mechanism, and browser-automation procedure (tool-agnostic fill + verify, never submit) |
| [`.env`](.env) | Private identity values (gitignored). Read each run. |
| [`.env.sample`](.env.sample) | Shape/placeholder for `.env` when the real file is missing |

## Output Hygiene

- **Never use em dashes or en dashes** (Unicode U+2014 and U+2013) in any generated output. Use ASCII hyphens (`-`), commas, parentheses, or separate sentences instead.
- **Never echo the user's real identity values into committed files or anywhere they would persist beyond the private `.env`.** The `.env.sample` must stay anonymized.
- **Never add AI-tool signatures, watermarks, or attribution comments to generated files.** No `<!-- Made with Bob -->`, no `<!-- Generated by Claude -->`, no `# AI-assisted` footers, no co-authorship lines inside the body of any deliverable, no "Created with X" stamps. The user owns the output; AI tooling stays invisible. This applies to every file the skill produces.
