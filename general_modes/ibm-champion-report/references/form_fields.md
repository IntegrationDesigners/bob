# IBM Champion Activity Report - form field reference

Authoritative, **browser-verified** field spec for the **IBM Champion Program -
Activity Report** form (verified 2026-06-29, field by field, against the live form;
option lists in `act_options.md` / `product_options.md`, re-scraped 2026-09-15).

- **Form URL:** https://airtable.com/appuwf3eOGdO6x1oS/pagF5IfVT7m6unCbG/form
- **Short URL:** https://www.ibm.biz/champ-report

The form is an Airtable form; it cannot be submitted programmatically and the human
always does the final consent + click. The skill's job is to assemble every value,
polish the free text, and build a **proven** prefilled-form URL plus a copy-paste
sheet for the fields that cannot be prefilled.

> The option lists in [`act_options.md`](act_options.md) and
> [`product_options.md`](product_options.md) are scraped **verbatim** from the live
> dropdowns - they are authoritative, not guesses. Grep them for the entry you need;
> read the act list in full only when a grep misses, and never read the product list
> in full. The raw calibration record
> (field IDs, prefill landings, regression result) lives in the gitignored
> `../form-calibration.yaml`.

---

## How prefill works on this form (verified)

Airtable prefills via query params: `?prefill_<KEY>=<URLEncodedValue>`, joined with `&`.

- `<KEY>` is normally the underlying **column name**, URL-encoded (space -> `%20`).
  Where this form uses a **custom display label**, the column name differs and the
  label-based param silently fails - you must use the **field ID** instead
  (`prefill_fldXXXXXXXXXXXXXX`).
- Select values must match an option **exactly** (see `act_options.md` / `product_options.md`).
- Multi-select: comma-separate values inside one param.
- Email values: `@` -> `%40`. Date values: `yyyy-mm-dd` (the date fields render as
  `yyyy-mm-dd` text inputs and only that format lands - `D/M/YYYY` leaves the field empty).
- Some fields cannot be prefilled at all (no column-name match and no field ID is
  exposed on the public form). Those are **manual** - they go in the copy-paste sheet.

### Verified field-ID map (the form embeds exactly 9 IDs)

| Field ID | Field |
|---|---|
| `fldt6UIOXVxQBNSgl` | Champion Program ID |
| `fldjaFlaWxJJMsay9` | First name |
| `fldUOjGHPz2HUTMt7` | Last name |
| `fldr9AaDFiKuuZ7Bi` | Primary Email |
| `fldIlTk3tvYKw57x8` | 1st Act of Advocacy (single-select) |
| `fldTWgIi3n3KNErJJ` | Product(s) Involved, 1st activity (multi-select) |
| `fld0aJmUIrBMO2BWh` | 1st-activity Date (required) |
| `fldsYCztbwXKtlxiT` | 2nd-activity Date |
| `fldcB8jM6FBLQD14g` | non-prefillable (likely "How many MORE Acts"; rejects every value type) |

---

## Identity fields (from `.env` - never ask the user for these)

Load from the skill's `.env`; do not prompt for them.

| Form label | `.env` key | Type | Required | VERIFIED prefill param |
|---|---|---|---|---|
| Champion Program ID | `CHAMPION_PROGRAM_ID` | numeric | yes | `prefill_fldt6UIOXVxQBNSgl` (field ID; label does NOT work) |
| First name | `FIRST_NAME` | text | yes | `prefill_First%20name` |
| Last name | `LAST_NAME` | text | yes | `prefill_Last%20name` |
| Primary Email | `PRIMARY_EMAIL` | email | yes | `prefill_Primary%20Email` |
| Alternate Email | `ALTERNATE_EMAIL` | email | no | `prefill_Alternate%20Email` |

If `.env` is missing, fall back to the `.env.sample` shape and ask the user to copy it
to `.env` and fill real values once (it is gitignored and stays private).

`.env` also carries `ACTIVITY_LOG`, the path of the private activity log. It is not a
form field and never lands on the form - see SKILL.md step 5C.

---

## Per-activity fields

Each submission carries **1 to 3 acts of advocacy**: a 1st act, plus "how many more"
(Zero to 2). Only the **1st act** is reliably prefillable via URL; collect the fields
below for each act.

### 1. Act of Advocacy (single-select, required)

"What type of activity have you contributed?"

- **Prefill:** `prefill_1st%20Act%20of%20Advocacy=<exact option>` (label param works;
  field ID `fldIlTk3tvYKw57x8` also works). The **value must be one line of `act_options.md`
  exactly** - e.g. `Write a Blog or Article` is NOT an option; the real entry is
  `Blog or Article`, and a post on community.ibm.com is best logged as
  `Blog on IBM property`.
- Map the user's activity to the closest `act_options.md` entry, then confirm: "Closest
  match is *X* - right entry?"

### 2. Product(s) Involved (multi-select, required)

"Select all the product(s) involved. You may select more than one. If your product is
not listed, select **Other** and type the product name."

- **Prefill:** `prefill_fldTWgIi3n3KNErJJ=<opt>` (**field ID only** - the display-label
  param does NOT work). Multiple values: comma-separate in one param, e.g.
  `prefill_fldTWgIi3n3KNErJJ=IBM%20App%20Connect,IBM%20MQ`.
- Values must match a `product_options.md` line exactly (grep the exact name; on a
  miss grep a keyword and show the candidates). Since the 2026-09-15 re-scrape the list has
  **`App Connect Enterprise (ACE)`** next to **`IBM App Connect`** and **`IBM MQ`**
  (plus `App Connect`, `IBM App Connect (Developer)`, `IBM MQ (Developer)`); pick the
  entry that names the product the user actually means.
- Anything not in `product_options.md` goes via **Other -> type the name**; a free-typed Other
  value cannot be prefilled, so do it manually after the form opens.

### 3. Description of this Activity (free text, required, <= 250 words)

- **NOT prefillable** -> copy-paste / manual. This is where the skill adds the most
  value. Write it for a reviewer who has not seen the work:
  - Lead with what was contributed and who it helps.
  - Name the product(s) and the concrete artifact (post, talk, repo, video).
  - Factual, no fluff, no AI-tool signatures.
  - Hard limit 250 words; report the word count.

### 4. Link to material (URL, strongly recommended)

- **NOT prefillable** -> manual. "Lack of link may result in the disqualification of
  your activity." Always push for one (blog URL, repo, recording, slides, community post).

### 5. Can IBM Amplify this activity? (checkbox)

- **NOT prefillable** -> manual. Ask the user; do not assume.
- **browsermcp fallback:** `browser_click` on the checkbox ref lands on the outer
  wrapper and does not tick it. After typing the Link value the Link field is already
  focused - do NOT re-focus it with an empty `browser_type` (that clears the field).
  Press `Tab` once (focus moves to the checkbox), press `Space`.

### 6. Approximate date of activity (date, required)

- **Prefill:** `prefill_fld0aJmUIrBMO2BWh=<yyyy-mm-dd>` (field ID). The field renders as
  a `yyyy-mm-dd` text input and the prefill must use that exact format - `D/M/YYYY` leaves
  the field empty while the other prefills land (verified in-browser 2026-09-02).
- **Filling it manually is fiddly - two traps, both silent:**
  1. `form_input` / setting `.value` writes the DOM but not React state: the field looks
     right, then **clears the moment it loses focus**. Do not use form_input here.
  2. Typing into it **appends** rather than replaces (produced `2026-08-052026-08-05`).
     Triple-click to select the existing content first.
  Reliable sequence: triple-click the field -> type `yyyy-mm-dd` -> then **click the day
  cell in the open calendar** (gridcell named e.g. `Wed Aug 05 2026`) to commit. Re-read
  the field after committing; `find` does not always report its value, so screenshot it.
- "Only report activities contributed in the last year." First-of-month if unknown.

### 7. How many MORE Acts of Advocacy to add (single-select, required)

- Options: **Zero**, **1**, **2**. **NOT prefillable** (defaults to `1`); set manually.
- One act: set `Zero`. Two acts: leave the default `1` untouched - the 2nd-act block is
  already open (verified 2026-09-17). Three acts: set `2`.
- **browsermcp fallback:** `browser_click` does not open the option list in the a11y
  snapshot. After typing the Link value the Link field is already focused - do NOT
  re-focus it with an empty `browser_type` (that clears the field). Press `Tab` three
  times (Amplify, Date, then this combobox), type the option one key at a time with
  `browser_press_key` (`Z` `e` `r` `o`, or `1` / `2`), then `Enter`. No `browser_snapshot`
  between the Tab presses and `Enter` - a snapshot closes the dropdown.
- The 2nd/3rd-act fields are manual too, except the **2nd-activity Date**
  (`prefill_fldsYCztbwXKtlxiT=<yyyy-mm-dd>`, same input type as the 1st-activity
  date). If the user has more than 3 activities,
  tell them to submit the form again for the overflow.

### 8. PRIVACY consent (checkbox, required)

- The Credly / IBM data-use + privacy consent. **Manual must-tick** - the skill can
  never consent for the user. Flag it as the last manual step before submitting.

---

## Prefilled-form URL (PROVEN)

Verified in-browser (2026-09-02): all 8 prefillable fields land together. Build this from
`.env` identity + the assembled 1st-act values. URL-encode values (`@`->`%40`,
space->`%20`).

```
https://airtable.com/appuwf3eOGdO6x1oS/pagF5IfVT7m6unCbG/form?prefill_fldt6UIOXVxQBNSgl=<CHAMPION_PROGRAM_ID>&prefill_First%20name=<FIRST_NAME>&prefill_Last%20name=<LAST_NAME>&prefill_Primary%20Email=<PRIMARY_EMAIL>&prefill_Alternate%20Email=<ALTERNATE_EMAIL>&prefill_1st%20Act%20of%20Advocacy=<ACT_OPTION>&prefill_fldTWgIi3n3KNErJJ=<PRODUCTS_COMMA_SEP>&prefill_fld0aJmUIrBMO2BWh=<yyyy-mm-dd>
```

**Prefills (8):** Champion Program ID, First name, Last name, Primary Email, Alternate
Email, 1st Act of Advocacy, Product(s), 1st-activity Date (`yyyy-mm-dd` - see the
date-field note above).

**Second act (9th param):** append `&prefill_fldsYCztbwXKtlxiT=<yyyy-mm-dd>` for the
2nd-activity date; verified 2026-09-17 to land together with the other 8. No field ID
is exposed for a 3rd-activity date, so that one stays manual.

**Always manual after the URL opens (cannot be prefilled):** Description, Link, Can IBM
Amplify, How-many-more, PRIVACY consent, and all 2nd/3rd-act fields except their date.
Put these in the copy-paste sheet.

---

## Browser automation (fill the form in place)

If a browser-automation MCP is available, you can drive the form directly. The proven
prefilled URL lands the identity, Act, Product(s) and Date fields; automation adds the
manual fields (Description, Link, Amplify, How-many-more, a 2nd act) and verifies. Two
workflows share the open sequence, the second-act notes and the hard rules:

- **Normal** (default): snapshot-based, every check, end screenshot - "Normal workflow".
- **Lean** (`lean: on` in the request): selector-based, one read at the end - "Lean
  workflow". Needs `browser_evaluate` and selector targets, so Playwright MCP or a Claude
  surface; on browsermcp say so in one line and run the normal workflow.

If **no** browser MCP is present, skip this section, say so, and deliver the prefilled
URL + copy-paste sheet only.

### Which server

Playwright MCP (`@playwright/mcp`) is the primary server for Bob: refs from
`browser_snapshot` and CSS selectors both work as click/type targets, `browser_fill_form`
sets several fields in one call, `browser_evaluate` reads values back and
`browser_wait_for` handles the late-rendering form. browsermcp is the fallback (own
section below). Claude's surfaces (Claude-in-Chrome, the in-app Browser pane) map the
same steps onto `find` / `computer` / `javascript_tool`. Install and wiring:
`dependency.md` in the skill folder.

| Action | Playwright MCP | browsermcp | Chrome DevTools MCP | Claude-in-Chrome / Browser pane |
|---|---|---|---|---|
| Open a URL | `browser_navigate` | `browser_navigate` | `navigate_page` | `navigate` |
| Wait for the form | `browser_wait_for` (text) | `browser_wait` | - | `computer` wait |
| Read the page (a11y snapshot) | `browser_snapshot` | `browser_snapshot` | `take_snapshot` | `read_page` / `find` |
| Click an element | `browser_click` (ref or selector) | `browser_click` (ref) | `click` | `computer` left_click (ref) |
| Type into a field | `browser_type` / `browser_fill_form` | `browser_type` | `fill` | `computer` type |
| Read field values | `browser_evaluate` | - | `evaluate_script` | `javascript_tool` |
| Screenshot | `browser_take_screenshot` | `browser_screenshot` | `take_screenshot` | `computer` screenshot |

Playwright MCP and browsermcp share the `browser_` prefix but not the tool set
(`browser_take_screenshot` vs `browser_screenshot`, `browser_wait_for` vs `browser_wait`,
`browser_console_messages` vs `browser_get_console_logs`); never copy an auto-approve
list from one to the other.

### Open sequence (always clear; both workflows)

Airtable keeps an unsent draft of the fields you typed into, per browser profile, and
applies it AFTER the URL prefill: a stale draft re-fills Description and Link and, if the
date was touched in it, nulls the prefilled Date (seen 2026-09-15, reproduced
2026-09-17). Any persistent profile can carry one - the logged-in Chrome and Playwright's
own `--browser chrome` profile alike - so the form is always cleared first, without
reading it. A draft is discarded unseen; that is the accepted trade-off.

1. Navigate to the **bare** form URL; wait for the text "Clear form".
2. On a fresh profile a cookie banner covers the page: click "Reject All, Except Strictly
   Necessary" (Playwright selector `button:has-text("Reject All")`; skip if absent).
3. Click **Clear form** (`[role=button]:has-text("Clear form")`, bottom of the page next
   to Submit), then **Confirm** in the "Clear form?" dialog (`button:has-text("Confirm")`).
   If no dialog appears, click Clear form again - right after a navigate the renderer can
   still be busy and the first click is lost (seen in Claude-in-Chrome, 2026-09-17).
4. Navigate to the **prefilled** URL; wait for the text "Champion Program ID".

Clearing has to precede the prefilled navigation because Clear form wipes prefilled
values too. A fix pass later in the run never clears. Verified 2026-09-17: draft storage
empty after the sequence, Description and Link empty, all prefilled fields landed (8,
or 9 with a 2nd act); the whole sequence by selector through Playwright MCP in 7 calls.
Airtable renders after `navigate` returns - without the wait, a snapshot or evaluate
sees an empty shell titled "Interface Form".

### Normal workflow (fill + verify, never submit)

1. **Open** the form with the sequence above.
2. **Snapshot** (`browser_snapshot`) and confirm the prefilled fields populated: 8 for one
   act, 9 with a 2nd act. The refs of the manual fields come from this snapshot.
3. **Resolve every manual field by its accessibility label / name, NEVER by hardcoded
   pixel coordinates.** Airtable markup is generated, and - critically - once the
   Description textarea is filled the whole lower block shifts down (~50px), so any
   coordinate captured from an earlier screenshot silently misses (the URL lands
   nowhere, the checkbox stays empty). Use the browser MCP's find-by-label / ref
   mechanism and act on the returned ref. Verified stable names on this form:
   - Description textarea: accessible name **"A1_DESCRIPTION"** (label "Description of this
     Activity."). Verified 2026-08-05; it was "AoA1 Description" at the 2026-06-29 calibration,
     so match on the label text, not the name. It is a **contenteditable DIV, not a textarea** -
     `form_input` fails with `Element type "DIV" is not a supported form input`; click it and
     type instead.
   - Link input: labelled **"Please provide a link to this material if possible."**
   - Amplify checkbox: **"Can IBM Amplify this activity?"**
   - How-many-more dropdown: combobox **"How many MORE Acts of Advocacy..."**
4. **Type the manual fields:** Description (polished, <=250 words), Link (URL) -
   `browser_type` on the refs (add `slowly: true` if characters are dropped).
5. **Amplify checkbox:** tick **only** if the user explicitly allowed amplification -
   `browser_click` on the checkbox ref.
6. **How many MORE Acts of Advocacy defaults to `1`, not Zero.** For a single-act
   submission you MUST change it to **Zero** - otherwise the form keeps an empty 2nd act
   open and it is the easiest field to forget. Set `1`/`2` only when actually filling a
   2nd/3rd act. Click the combobox ref, type the option text so the list filters to one
   entry, then click that option's ref (or `Enter`). Refs change after any select changes
   value - re-snapshot before the next click.
7. **Re-snapshot and verify:** read every field back with `browser_evaluate` (see the
   readback in the lean workflow), take one `browser_take_screenshot` for the human,
   and report each field as set / not set / mismatch; retry failures once. Prefer
   reading values back via the a11y tree or the DOM over pixel-reading.
8. **Stop before submit.** Do **NOT** tick the **PRIVACY** consent checkbox and do
   **NOT** click **Submit**. Leave the filled form open and hand control back.

### Lean workflow (`lean: on`)

Same open sequence, then no snapshot and no screenshot: fill by selector, read once.
Verified 2026-09-17 through Playwright MCP against the live form (selector targets,
`browser_fill_form` on the contenteditable Description, the link input and the ARIA
checkbox, combobox by click + type + submit).

1. **Open** the form with the sequence above.
2. **One `browser_fill_form`** for every text field and checkbox of every act. Field
   shape (the tool's schema): `{ "target": <selector>, "name": <label>, "type":
   "textbox" | "checkbox", "value": <string, "true"/"false" for a checkbox> }`.
3. **Comboboxes last**, each in two calls: `browser_click` on the wrapper
   `[role=combobox] >> nth=N` (opens the list and focuses an `input[role=combobox]`
   with placeholder "Find an option"), then `browser_type` on `input[role=combobox]`
   with the exact option text and `submit: true`. `browser_type` on the wrapper itself
   fails ("not an input"). Order: 2nd-act type, 2nd-act product(s), then How-many-more
   (`Zero` for one act; untouched for two; `2` for three) - selecting a value re-renders
   the block, so nothing else is targeted after it.
4. **One `browser_evaluate`** returning every field, compared to the copy-paste sheet:

   ```
   () => { const tb=[...document.querySelectorAll("textarea, input[type=text]")].map(e=>e.value);
     const cb=[...document.querySelectorAll("[role=combobox]")].map(c=>c.innerText.trim());
     const chk=[...document.querySelectorAll("[role=checkbox]")].map(c=>c.getAttribute("aria-checked"));
     const d=l=>document.querySelector("[role=textbox][aria-label="+l+"]")?.innerText||"";
     const links=[...document.querySelectorAll("input[type=text]:not([placeholder=yyyy-mm-dd])")].slice(1).map(e=>e.value);
     return { championId: tb[0], act1: cb[0], desc1: d("A1_DESCRIPTION"), links,
       amplify: chk, howMany: cb[2], act2: cb[3], desc2: d("A2_DESCRIPTION"),
       dates: [...document.querySelectorAll("input[placeholder=yyyy-mm-dd]")].map(e=>e.value),
       chips: [...document.querySelectorAll("[aria-label*=Remove]")].length }; }
   ```

   Compare by position (`links[0]` is act 1, `links[1]` act 2) so a value that landed in
   the wrong field reads as two mismatches, never as a pass. Mismatches get one fix pass
   (re-issue only the failed calls) and one more evaluate;
   then stop. Report one status line per field group; print the sheet only if the fill
   was skipped or a mismatch remains.
5. **Stop before submit** - same rule as step 8 above.

Selector table (DOM order; observed 2026-09-15/17):

| Control | Selector |
|---|---|
| Description act 1 / act 2 | `[role=textbox][aria-label=A1_DESCRIPTION]` / `...A2_DESCRIPTION` |
| Link act 1 / act 2 | `input[type=text]:not([placeholder="yyyy-mm-dd"]) >> nth=1` / `nth=2` (nth=0 is the Champion ID; a plain `:not([placeholder])` drops it because that input carries an empty placeholder attribute, shifting the positions) |
| Amplify act 1 / act 2, PRIVACY | `[role=checkbox] >> nth=0` / `nth=1` / `nth=2` (PRIVACY is never touched) |
| Act 1, Products 1, How-many-more, Act 2, Products 2 | `[role=combobox] >> nth=0` .. `nth=4` |
| Date act 1 / act 2 | `input[placeholder="yyyy-mm-dd"] >> nth=0` / `nth=1` (prefilled; manual only if the URL lacked it) |

Budget: about 10 tool calls for one act, 13 for two; one read, no image. Claude
surfaces run the same plan with `javascript_tool` for the read and `find` + `computer`
for the actions.

### Second act (verified 2026-09-17, two acts)

When the submission carries a 2nd act, the prefilled URL adds its date
(`prefill_fldsYCztbwXKtlxiT=<yyyy-mm-dd>`, lands with the other 8) and "How many MORE"
stays at its default `1`, so the 2nd-act block is open from the first snapshot - do not
touch that field for two acts (set `2` for three). Fill the 1st act as above, then:

- **Type:** the combobox under the "2nd Act of Advocacy." label (the 4th combobox on the
  page, after 1st Act, 1st Product(s) and How-many-more). Click it, type the exact
  `act_options.md` entry, confirm the filtered list shows that one entry, `Enter`.
- **Product(s):** the empty multi-select combobox in the 2nd-act block. Click it, type the
  exact `product_options.md` name, then check the option list: `Enter` takes the **top**
  match, and typing `IBM MQ` lists `IBM MQ`, `IBM MQ (Developer)`, `IBM MQ on Cloud` in
  that order. Repeat per product; a chip with a Remove button appears for each.
- **Description:** textbox `A2_DESCRIPTION` (same contenteditable DIV as `A1_DESCRIPTION`,
  same 250-word cap). **Link:** the second textbox labelled "Please provide a link to
  this material if possible.". **Amplify:** the second "Can IBM Amplify this activity?"
  checkbox. **Date:** already prefilled; the manual sequence in field 6 applies only if
  the URL did not carry it.
- Verify both acts from the DOM before stopping: 2 links, 2 description word counts,
  checkbox states in order (Amplify 1, Amplify 2, PRIVACY), both `yyyy-mm-dd` inputs.

A 3rd act works the same way with the third block, except that no field ID is exposed
for its date - that one goes through the manual date sequence.

### browsermcp (fallback; normal workflow only; verified by Bob, 2026-09)

Deltas to the normal workflow when the browser MCP is **browsermcp**. Every other rule
above still applies - in particular step 3 (resolve by label / ref). No lean workflow
here: browsermcp has no `evaluate` and no selector targets.

- **Open sequence:** navigate, snapshot (binds the tab), click the "Clear form" ref,
  snapshot, click the "Confirm" ref, navigate to the prefilled URL, snapshot.
- **Tab binding:** call `browser_snapshot` immediately after `browser_navigate` and
  before the first `browser_type` / `browser_press_key`; without it those calls fail with
  "No tab with given id". Sequence: `browser_navigate` -> `browser_snapshot` -> type/key.
- **Step 4 (Description, Link):** `browser_type` on the refs from that snapshot.
- **Step 5 (Amplify):** `browser_click` on the checkbox ref lands on the outer wrapper.
  After typing the Link value the Link field is already focused - do NOT re-focus it
  with an empty `browser_type` (that clears the field). `Tab` once, `Space`.
- **Step 6 (How many MORE):** `browser_click` does not open the option list. The Link
  field is still focused after step 4 (or after the `Space` in step 5 if Amplify was
  ticked). `Tab` three times (Amplify, Date, combobox), then `browser_press_key` for
  each character of the option (`Z` `e` `r` `o`, or `1` / `2`) and `Enter`. No
  `browser_snapshot` between the Tab presses and `Enter` - it closes the dropdown.
- **Step 7 (verify):** re-snapshot only after `Enter`; retry failures once.

### Surface gotchas

- **Claude-in-Chrome: the first click after `navigate` may only focus the window.** A
  whole batch of clicks and typing was acknowledged and reached nothing because the
  page had no focus (`document.hasFocus()` false). After navigating, click the first
  target, read `document.activeElement`, and only then type; if the control is not
  focused, click it again (observed 2026-09-17).
- **In-app Browser pane: `key` sends keydown with an empty `key`/`code`**, so Space never
  toggles a checkbox and Enter never commits a filtered option; ref clicks work for
  both, including clicking the filtered option (observed 2026-09-15).
- **A filled Link field is rendered as a link:** clicking it tries to open the URL
  instead of focusing the input. Tab into it from the Description (tabbing selects
  the content, typing replaces it).
- Refs renumber after any select changes value; re-find before the next click. Airtable
  rewrites the tab URL with `+` and `%2C` after load - harmless.
- `--browser chrome` (Playwright) drives the installed Chrome under its own persistent
  profile, not the logged-in one; `--extension` attaches to the logged-in Chrome. The
  form is public, so either works; a login wall means stop and hand over.

### If the browser MCP starts erroring mid-fill

On CDP-based browser MCPs a form-filler or password-manager extension in the user's
Chrome (Grammarly, Bitwarden, etc.) can grab the active context right after a `type`
action, after which every CDP call fails with `Cannot access a chrome-extension:// URL
of different extension`. Recovery that works:

- **Re-navigate to the prefilled URL** to reset the page and the CDP attachment, then
  continue (identity + Act + Product + Date re-land automatically; re-type Description
  and Link). Suggest the user pause form-filler extensions for the tab if it recurs.
- If only screenshots are blocked, a **native OS screenshot** (computer-use MCP, with the
  browser granted at read tier) is a valid read-only fallback to verify field state.
- Targeting by label / ref (step 3) also sidesteps the stale-coordinate problem entirely.

### Hard rules for automation

- Never tick the PRIVACY / Credly consent checkbox on the user's behalf.
- Never click Submit. The human reviews, consents, and submits.
- Never type the user's identity values into anything other than the live form fields
  (no logs, no committed files).
- If the page is unrecognizable (redesign, login wall, captcha), stop and fall back to
  the copy-paste sheet.

---
