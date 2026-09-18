---
name: ibm-champion-report
description: "Use this skill when the user wants to report or register an IBM Champion / Rising Champion activity (an 'act of advocacy') on the IBM Champion Program Activity Report form. Triggers on requests like 'report my IBM Champion activity', 'log a champion act of advocacy', 'fill in the champ-report form', 'register this blog/talk/repo for my IBM Champion badge', 'submit my champion activity', or when the user mentions the IBM Champion activity report, ibm.biz/champ-report, or the Airtable champion form. Produces a proven prefilled form URL plus a copy-paste field sheet and appends the reported activity to a private activity log; it does not auto-submit the web form."
metadata:
  version: 1.2.0
  status: stable
  last_updated: 2026-09-15
---

# IBM Champion Activity Report

You help the user report an IBM Champion (or Rising Champion) **act of advocacy** on
the IBM Champion Program Activity Report form. You assemble every value the user
needs, polish the free-text description to fit the 250-word limit, pull their identity
from a private `.env` file, and produce a proven prefilled form URL (8 of the form's
fields populate automatically) plus a copy-paste sheet for the fields that cannot be
prefilled. Every reported activity is also appended to a private activity log (one
local markdown file, path in `.env`) so the user can see what has already been reported.

If a browser-automation MCP is available you can open the form and fill it in place,
then verify each field. You never tick the consent checkbox and never submit - the
human does the final review, consent, and click. Without a browser MCP, your value is
the prefilled URL plus the copy-paste sheet that make that click take ten seconds.

- **Form:** https://airtable.com/appuwf3eOGdO6x1oS/pagF5IfVT7m6unCbG/form
- **Short URL:** https://www.ibm.biz/champ-report

**Before assembling anything**, read [`references/form_fields.md`](references/form_fields.md) -
it is the authoritative field spec: which values come from `.env`, date format, word
limits, and the proven prefilled-URL mechanism (which fields prefill by field ID,
which by name, and which are manual-only). The verified dropdown option lists live
next to it: [`references/act_options.md`](references/act_options.md) (grep it; read
it whole only when a grep misses) and
[`references/product_options.md`](references/product_options.md) (grep only - 1097
lines, never read in full).

---

## Identity and the activity log path come from `.env`, never from the chat

The user's stable identity (Champion Program ID, name, emails) and the path of their
activity log live in this skill's `.env` file. It is gitignored and private.

1. Read `.env` from the skill folder. Use those values for the identity fields.
2. If `.env` is missing, read [`.env.sample`](.env.sample) for the shape and ask the
   user to copy it to `.env` and fill in their real values once. Do not paste real
   identity values into chat history or any committed file.
3. `ACTIVITY_LOG` is the absolute path (forward slashes, no quotes) of ONE local
   markdown file that receives every reported activity - a note inside an Obsidian
   vault, a file on a mapped or synced drive, any path this machine can write. If the
   key is missing or empty, ask the user where the log should live, append
   `ACTIVITY_LOG=<path>` to `.env`, and continue. Do not ask again on later runs.
4. `IBM_COMMUNITY_PROFILE_URL` and `ACE_COMMUNITY_BLOG_URL` are the user's IBM
   Community profile page and the ACE community blog listing. When navigating to
   the user's community profile or blog list (e.g. to retrieve a latest post for
   reporting), use these values directly; do not ask the user for the URL.
   **Navigation note:** `IBM_COMMUNITY_PROFILE_URL` redirects to an IBMid login
   wall even though the content is public, so do not use it for browser navigation.
   Use `ACE_COMMUNITY_BLOG_URL` instead, type the value of `LAST_NAME` from `.env`
   into the blog search box, then sort by date to find the latest post.
5. `FILL_MODE` is the default workflow for the run: `normal` (every check, end
   screenshot) or `lean` (one read at the end - see "Lean mode"). A request that
   says `lean: on` / "lean" or `normal` overrides it for that run; missing or empty
   means `normal`. Do not ask which workflow to use - read it.

---

## Workflow

### 1. Load the field spec and identity

- Read [`references/form_fields.md`](references/form_fields.md) - the spec only; the
  option lists are separate files looked up by grep in steps 2 and 4.
- Read `.env`. Confirm the identity block silently (do not echo full emails unless
  the user asks); if a required key is missing, ask the user to fill `.env`. Take
  the workflow from `FILL_MODE` unless the request names one, and say which one
  is running in one line.
- Resolve `ACTIVITY_LOG` (ask and write it back if missing, see above). If the file
  exists, read it: its entries are what has already been reported and feed the
  duplicate check in step 2. A missing file is normal on first use - it is created
  in step 5C.

### 2. Gather the activity (one act at a time)

Each submission carries 1 to 3 acts of advocacy. For each act, collect:

- **What they did** - enough to write a description and pick the activity type.
- **Act of Advocacy type** - map their description to the closest entry in the
  verified list in `references/act_options.md`, then confirm it is the activity they mean.
- **Product(s) involved** - grep `references/product_options.md` for the exact name
  (keyword grep on a miss, show the candidates); anything not
  listed goes in via the form's **Other -> type the name** option.
- **Link** - push hard for one. "Lack of link may result in disqualification."
- **Date** - last 12 months; format `yyyy-mm-dd`; first-of-month if unknown.
- **Can IBM amplify?** - ask, do not assume.

Before drafting anything, check the activity against the log, link first:

1. Normalise the new link (lower-case scheme and host, drop a trailing slash and any
   `utm_*`, `trk` or `ref` query parameters) and compare it the same way with every
   `Link:` line in the log. A match is a certain duplicate: say so, quote that entry's
   date and type, and ask whether to continue.
2. No link match: compare the description against the entries as prose (same post,
   talk, repo, video) and raise a likely duplicate the same way. Entries written
   before 2026-09-17 carry no `Link:` line and can only match this way.

The point of the log is that nothing gets reported twice.

If the user has more than 3 activities, tell them to submit the form again for the
overflow and set "How many MORE" accordingly (Zero / 1 / 2) for this run. **Warning:
the form DEFAULTS this field to 1** - it must be explicitly set to Zero when
reporting a single activity, or the form keeps an empty 2nd act open. For two
activities leave it at 1; for three set it to 2.

### 3. Write the description (<= 250 words each)

For each act, draft the "Description of this Activity":

- Lead with what was contributed and who it helps.
- Name the product(s) and the concrete artifact.
- Factual, no marketing fluff, no AI-tool signatures.
- Enforce the 250-word cap and report the actual word count.

### 4. Confirm the dropdown choices

The option lists in `references/act_options.md` and `references/product_options.md`
are verified verbatim from the live form, so they are authoritative. Your job is to pick the right entry: present the exact
option you chose for each single-select / multi-select field and confirm it is the
activity/product the user means (e.g. "Blog or Article" vs "Blog on IBM property").
If the live form ever changes and an option no longer matches, regenerate the option
file with the re-scrape recipe in its header.

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
Date of activity: <yyyy-mm-dd>
How many MORE Acts of Advocacy: <Zero|1|2>  (form DEFAULTS to 1 - set Zero for a single act)
PRIVACY consent: [ ] tick manually before submitting
```

Repeat the act-specific block for acts 2 and 3 if present.

**B. Prefilled URL (proven)** - built per the prefill section of the field spec. It
pre-populates 8 fields (Champion Program ID, First/Last name, both emails, 1st Act of
Advocacy, Product(s), 1st-activity Date). The remaining fields - Description, Link,
Can IBM Amplify, How-many-more, and PRIVACY consent - cannot be prefilled and stay in
the copy-paste sheet for manual entry once the form opens. With a 2nd act the URL
also carries the 2nd-activity date (`prefill_fldsYCztbwXKtlxiT`, 9 fields in total);
the 2nd act's type, product(s), description, link and amplify stay manual.

**C. Activity log entry** - append one entry per act to the file at `ACTIVITY_LOG`.
Create the file with a `# IBM Champion activity log` title line if it does not exist.
The entry carries the activity date (yyyy-mm-dd, the same value as on the form), the
confirmed Act of Advocacy type, the link exactly as typed on the form, and the
description exactly as it goes on the form - nothing else:

```
## <yyyy-mm-dd activity date> - <Act of Advocacy type>
Link: <url as on the form>

<description as submitted, <=250 words>
```

Two links (slides and a recording) are two `Link:` lines; no link at all is a `Link:`
line left empty. Keep a blank line between entries. Do not write the products, the
amplify answer, the identity block, or the prefilled URL - the log exists so the user
can see what has been reported and so step 2 can match on the link, not to mirror
the form. If the file cannot
be written (path unreachable, permission denied), print the entry block and say so,
so the user can paste it themselves.

### 6. Offer to fill the form in the browser (if a browser MCP is available)

Check the live tool list for a browser-automation MCP. Playwright MCP
(`browser_navigate`, `browser_snapshot`, `browser_fill_form`, `browser_evaluate`, ...) is
the primary server; browsermcp is the fallback; Claude's own surfaces map the same
steps. Installing and wiring: [`dependency.md`](dependency.md). If one is present, offer
to fill the form directly and follow the **Browser automation** section of
[`references/form_fields.md`](references/form_fields.md) - the **Normal workflow** by
default, the **Lean workflow** when lean mode is on:

- **Always clear first:** open the bare form URL, click **Clear form**, confirm the
  dialog, then navigate to the PROVEN prefilled URL built in step 5B - identity + Act +
  Product(s) + Date land automatically (8 fields, 9 with a 2nd act). Airtable restores
  unsent drafts from the browser profile on top of the prefill; clearing first is what
  keeps them out.
- Match fields by their accessibility label / ref, or a selector on that label - never
  by screen coordinates.
- Automation only types the manual fields: Description and Link, plus the Amplify
  checkbox if the user explicitly allowed amplification. Handle a product not in the
  list via **Other -> type the name**.
- **"How many MORE Acts of Advocacy" defaults to 1, not Zero** (options: Zero / 1 / 2).
  For a single-act submission it MUST be explicitly set to Zero; leave it at 1 for two
  acts; set 2 for three.
- **Fill + verify, never submit.** Normal workflow: snapshot after the prefill,
  re-snapshot after each select, read every field back at the end, one screenshot for
  the user, report each field as set / not set / mismatch, retry failures once. Lean
  workflow: one read at the end, one fix pass.
- **Do NOT tick the PRIVACY consent checkbox and do NOT click Submit.** Leave the
  filled form open and hand control back for the user to review, consent, and submit.

If **no** browser MCP is available, say so - the sheet + prefilled URL from step 5
already stand alone.

### 7. Final reminders

- The **PRIVACY consent** checkbox and (usually) the **Amplify** checkbox must be
  ticked by hand - you cannot consent for the user.
- Remind them only activities from the **last 12 months** are eligible.
- A link is effectively mandatory.
- The log entry from step 5C was written before the click. If the user decides not to
  submit after all, remove that entry so the log stays true.

## Lean mode (`lean: on`)

The default comes from `FILL_MODE` in `.env` (`normal` unless set to `lean`); a request
switches it for one run with `lean: on` / "lean" / "economy" / "save coins" or with
"normal". It trades checks for spend - fewer reads, fewer
round trips - and never skips: identity from `.env`, the 250-word cap, the always-clear
open sequence, the end check, the log append, stop before PRIVACY and Submit.

| Step | Lean behaviour |
|---|---|
| 1 | `.env` and the field spec as usual; the activity log is grepped for the normalised link and the artifact's name instead of read in full |
| 2-4 | option lookups by grep only; one consolidated confirmation message carrying the whole sheet and the mapped option values, skipped when the user named the exact option; proceed on a single "ok" |
| 5 | sheet, URL and log entry as usual |
| 6 | the **Lean workflow** in the field spec: open sequence, one `browser_fill_form`, comboboxes by click + type with submit, one `browser_evaluate` compared to the sheet, one fix pass; no snapshot, no screenshot |
| 7 | URL plus one status line per field group; the sheet is repeated only if the browser fill was skipped or a mismatch remains |

Lean needs `browser_evaluate` and selector targets (Playwright MCP or a Claude surface).
On browsermcp say so in one line and run the normal workflow.

---

## Reference files

| File | When to read |
|---|---|
| [`references/form_fields.md`](references/form_fields.md) | **Read before assembling anything** - field spec, date format, word limits, prefilled-URL mechanism, and the browser-automation procedures (fill + verify, never submit) |
| [`references/act_options.md`](references/act_options.md) | The 40 Act of Advocacy entries, verbatim. Grep in step 2; read whole only on a miss. |
| [`references/product_options.md`](references/product_options.md) | The 1097 Product entries, verbatim. Grep only, never read in full. |
| [`.env`](.env) | Private identity values and the `ACTIVITY_LOG` path (gitignored). Read each run. |
| [`.env.sample`](.env.sample) | Shape/placeholder for `.env` when the real file is missing |
| the file at `ACTIVITY_LOG` | Private activity log, outside the skill folder. Read in step 1 for the duplicate check, appended in step 5C. |

## Output Hygiene

- **Never use em dashes or en dashes** (Unicode U+2014 and U+2013) in any generated output. Use ASCII hyphens (`-`), commas, parentheses, or separate sentences instead.
- **Never echo the user's real identity values into committed files or anywhere they would persist beyond the private `.env`.** The `.env.sample` must stay anonymized.
- **The activity log carries only the activity date, the Act of Advocacy type, the activity link, and the description.** No identity values, no products, no prefilled URL, no other form fields.
- **Never add AI-tool signatures, watermarks, or attribution comments to generated files.** No `<!-- Made with Bob -->`, no `<!-- Generated by Claude -->`, no `# AI-assisted` footers, no co-authorship lines inside the body of any deliverable, no "Created with X" stamps. The user owns the output; AI tooling stays invisible. This applies to every file the skill produces.
