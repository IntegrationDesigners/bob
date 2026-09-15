# IBM Champion Activity Report - form field reference

Authoritative, **browser-verified** field spec for the **IBM Champion Program -
Activity Report** form (verified 2026-06-29, field by field, against the live form;
Appendix A/B option lists re-scraped 2026-09-15).

- **Form URL:** https://airtable.com/appuwf3eOGdO6x1oS/pagF5IfVT7m6unCbG/form
- **Short URL:** https://www.ibm.biz/champ-report

The form is an Airtable form; it cannot be submitted programmatically and the human
always does the final consent + click. The skill's job is to assemble every value,
polish the free text, and build a **proven** prefilled-form URL plus a copy-paste
sheet for the fields that cannot be prefilled.

> The option lists in Appendix A and Appendix B are scraped **verbatim** from the live
> dropdowns - they are authoritative, not guesses. The raw calibration record
> (field IDs, prefill landings, regression result) lives in the gitignored
> `../form-calibration.yaml`.

---

## How prefill works on this form (verified)

Airtable prefills via query params: `?prefill_<KEY>=<URLEncodedValue>`, joined with `&`.

- `<KEY>` is normally the underlying **column name**, URL-encoded (space -> `%20`).
  Where this form uses a **custom display label**, the column name differs and the
  label-based param silently fails - you must use the **field ID** instead
  (`prefill_fldXXXXXXXXXXXXXX`).
- Select values must match an option **exactly** (see Appendix A/B).
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
  field ID `fldIlTk3tvYKw57x8` also works). The **value must be one of Appendix A
  exactly** - e.g. `Write a Blog or Article` is NOT an option; the real entry is
  `Blog or Article`, and a post on community.ibm.com is best logged as
  `Blog on IBM property`.
- Map the user's activity to the closest Appendix A entry, then confirm: "Closest
  match is *X* - right entry?"

### 2. Product(s) Involved (multi-select, required)

"Select all the product(s) involved. You may select more than one. If your product is
not listed, select **Other** and type the product name."

- **Prefill:** `prefill_fldTWgIi3n3KNErJJ=<opt>` (**field ID only** - the display-label
  param does NOT work). Multiple values: comma-separate in one param, e.g.
  `prefill_fldTWgIi3n3KNErJJ=IBM%20App%20Connect,IBM%20MQ`.
- Values must match Appendix B exactly. Since the 2026-09-15 re-scrape the list has
  **`App Connect Enterprise (ACE)`** next to **`IBM App Connect`** and **`IBM MQ`**
  (plus `App Connect`, `IBM App Connect (Developer)`, `IBM MQ (Developer)`); pick the
  entry that names the product the user actually means.
- Anything not in Appendix B goes via **Other -> type the name**; a free-typed Other
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
- **Bob / browsermcp add-on:** `browser_click` on the checkbox ref lands on the outer
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
- **Bob / browsermcp add-on:** `browser_click` does not open the option list in the a11y
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

**Always manual after the URL opens (cannot be prefilled):** Description, Link, Can IBM
Amplify, How-many-more, PRIVACY consent, and all 2nd/3rd-act fields except their date.
Put these in the copy-paste sheet.

---

## Browser automation (fill the form in place)

If a browser-automation MCP is available, you can drive the form directly. The proven
prefilled URL already lands the 8 fields above; use automation to add the manual fields
(Description, Link, Amplify) and to verify.

### Tool-agnostic action vocabulary

Skills do not hardcode tool names - read the live tool list and use whatever browser MCP
is installed. Map these abstract actions onto the concrete tools you find:

| Action | Browser/Playwright MCP | Chrome DevTools MCP | Claude-in-Chrome MCP |
|---|---|---|---|
| Open a URL | `browser_navigate` | `navigate_page` | `navigate` |
| Read the page (a11y snapshot) | `browser_snapshot` | `take_snapshot` | `read_page` / `get_page_text` |
| Click an element | `browser_click` | `click` | `computer` (left_click) |
| Type into a field | `browser_type` | `fill` | `computer` (type) / `form_input` |
| Choose a select option | `browser_select_option` | click the option | click the option |
| Read field values / DOM | - | `evaluate_script` | `javascript_tool` |

If **no** browser MCP is present, skip this section, say so, and deliver the prefilled
URL + copy-paste sheet only.

### Why the real Chrome matters

Prefer a browser MCP that drives the user's **actual logged-in Chrome** (extension-based,
e.g. Claude-in-Chrome or browsermcp.io). The form sits behind `ibm.biz/champ-report`; a
fresh logged-out profile may hit a login wall. If it does, stop and ask the user to log
in (or switch to an extension-based MCP), then resume.

**Autosaved drafts override the prefill (verified 2026-09-15 in the logged-in Chrome).**
Airtable keeps an unsent draft of the manual fields per browser (`localStorage` key
`AirtableLocalPersister.formPageElementSavedFormDataByElementId.<app>.<page>.<element>`,
columns Description, Link and the 1st-activity Date) and applies it AFTER the URL
prefill: a stale draft re-fills Description and Link and nulls the prefilled Date, so the
snapshot shows 7 of 8 fields with the date empty. A fresh profile never has one. Before
typing anything, read the draft back and show it to the user (it may be an unfiled
activity); only with their go-ahead remove that key and re-navigate to the prefilled
URL. Typing into the form overwrites the draft in place.

### Fill procedure (fill + verify, never submit)

1. **Navigate** to the proven prefilled URL above (identity + Act + Product + Date land
   automatically).
2. **Snapshot** and confirm those 8 fields populated.
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
4. **Type the manual fields:** Description (polished, <=250 words), Link (URL).
5. **Amplify checkbox:** tick **only** if the user explicitly allowed amplification.
6. **How many MORE Acts of Advocacy defaults to `1`, not Zero.** For a single-act
   submission you MUST change it to **Zero** - otherwise the form keeps an empty 2nd act
   open and it is the easiest field to forget. Set `1`/`2` only when actually filling a
   2nd/3rd act.
7. **Re-snapshot and verify:** report each field as set / not set / mismatch; retry
   failures once. Prefer reading values back via the a11y tree over pixel-reading.
8. **Stop before submit.** Do **NOT** tick the **PRIVACY** consent checkbox and do
   **NOT** click **Submit**. Leave the filled form open and hand control back.

### Bob / Playwright MCP add-on (preferred; dry run completed from Bob 2026-09-15)

Use this section when the live tool list carries the Playwright MCP tools
(`browser_navigate`, `browser_snapshot`, `browser_find`, `browser_click`, `browser_type`,
`browser_press_key`, `browser_select_option`, `browser_fill_form`, `browser_evaluate`,
`browser_wait_for`, `browser_take_screenshot`). It is the preferred server for Bob: ref
clicks reach every control on this form and `browser_evaluate` reads values back. The
browsermcp add-on below is the fallback when these tools are absent. Install and wiring:
`dependency.md` in the skill folder.

Deltas to the generic procedure above:

- **Steps 1-2:** `browser_navigate` to the prefilled URL, then `browser_wait_for` with
  `text: "Champion Program ID"` before anything else - Airtable renders after navigate
  returns, and an early snapshot or evaluate sees an empty shell titled "Interface Form"
  (measured 2026-09-15). Then `browser_snapshot` and confirm the 8 prefilled fields.
- **Step 3:** targets are the refs from that snapshot (or from `browser_find`), never
  coordinates. Refs change after any select changes value - re-snapshot before the next
  click.
- **Step 4:** `browser_type` on the Description ref (a contenteditable DIV; add
  `slowly: true` if characters are dropped) and on the Link ref.
- **Step 5:** `browser_click` on the Amplify checkbox ref.
- **Step 6:** `browser_click` on the How-many-more combobox ref, `browser_type` the
  option text (`Zero`, `1` or `2`) so the list filters to one entry, then click that
  option's ref (or `browser_press_key` `Enter`).
- **Step 7:** verify with `browser_evaluate`, for example
  `() => ({ act: document.querySelector("[role=combobox]").innerText, amplify: document.querySelector("[role=checkbox]").getAttribute("aria-checked"), date: document.querySelector("input[placeholder=yyyy-mm-dd]").value, more: [...document.querySelectorAll("[role=combobox]")].at(-1).innerText })`
  and re-snapshot; retry failures once.
- Tool names differ from browsermcp's despite the shared prefix: `browser_take_screenshot`
  (not `browser_screenshot`), `browser_wait_for` (not `browser_wait`),
  `browser_console_messages` (not `browser_get_console_logs`). Do not copy an
  auto-approve list from one server to the other.
- With `--browser chrome` the server drives the installed Chrome under its own profile,
  not the logged-in one; the autosaved-draft note above does not apply there, but a
  cookie banner does appear on the first load. With `--extension` (logged-in Chrome) the
  draft note applies.

### Bob / browsermcp add-on (fallback; verified by Bob on browsermcp, 2026-09)

Deltas to the procedure above when the browser MCP is **browsermcp** (Bob's default).
Every other rule above still applies - in particular step 3 (resolve by label / ref).

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

## Appendix A: Act of Advocacy options (verified 2026-09-15, 40)

Map the user's activity to **one of these exactly**:

- All other videos (e.g. Youtube)
- Analyst Reference
- Attend User Group meeting
- Blog or Article
- Blog on IBM property
- Board Member or UG Leader
- Case Study (Contribute to an IBM Case Study, or Attributed Author, or Quoted)
- Contributing to community.ibm.com (Discussion Threads, Questions)
- Host or Organize IBM-Related Event (multi-customer, non-sales)
- Host or Organize IBM-Related Event (single customer/sales)
- Host Podcast
- Ideas portal
- LInkedIn Post with carousel, video, or 250+ words
- LinkedIn Posts
- LinkedIn reposts
- Mentoring/Coaching
- Newsletter
- Open Source Contributions
- Other Product Team Feedback
- Participate in Sponsor User Program
- Participate in writing an IBM product exam or certification
- Podcast Participant
- Publish or Contribute to a Book or Redbook
- Sales Reference / Participate in Sales Call for IBM Seller (not for your own company sales)
- Social media other (X, Facebook, Insta, TikTok, etc)
- Speak to press on IBMs behalf
- Speaker at IBM Conferences or Events (digital, webinars, regional events)
- Speaker at Non-IBM Conferences or Events (digital, webinars, regional events)
- Survey (from IBM teams)
- Teach courses in IBM Technology
- UG Volunteer
- UG Volunteer - Committee member
- Video with IBM
- Case Study (unattributed business/BP-published case study)
- Complete a Product Review
- Contribute Code, App, or Templates for Community use
- Participate on IBM-Sponsored Advisory Committees/Boards
- Share a Quote (Testimonial) for use by IBM
- Speaker at a User Group or Meetup
- Other

## Appendix B: Product(s) options (verified 2026-09-15, 1097)

Use one or more of these **exactly**. If a product is absent, select "Other" and type the name (manual; cannot be prefilled).

- AI Ops: Anomaly Analytics with Watson
- AI Ops: Application Performance Management Connect
- AI Ops: Batch Resiliency
- AI Ops: Chat Ops
- AI Ops: IMS
- AI Ops: Monitoring
- AI Ops: NetView
- AI Ops: Observability by Instana APM on zOS
- AI Ops: OMEGAMON (all)
- AI Ops: OMEGAMON for Storage
- AI Ops: Operational Log and Data Analytics (and CDP)
- AI Ops: Performance and Capacity Analytics
- AI Ops: Service Automation Suite
- AI Ops: Service Management Unite
- AI Ops: System Automation
- AI Ops: Systems Management
- AI Ops: Table Accelerator
- AI Ops: Tivoli
- AI Ops: Workload Interaction Navigator
- AI Ops: Workload Scheduler
- AI Ops: Zowe
- AIX
- Governance, Risk, and Compliance (GRC)
- Android
- Apache Kafka
- Apache OpenWhisk
- Apache Spark
- API Connect
- Application Performance Analyzer for z/OS
- Application Security Services
- Appsody
- Apptio
- Aspera
- Automation Document Processing
- BAW
- Blueworks Live
- BRMS
- Business Automation Content Analyzer on Cloud
- Business Process Management (IBM BPM)
- Call for Code
- Case Manager
- CICS
- Citrix DaaS for IBM Cloud
- Citrix Virtual Apps and Desktops for IBM Cloud
- ClearCase
- ClearQuest
- Cloud Foundry
- Cloud Identity
- Cloud Infrastructure as a Service
- Cloud Native Development Tools on IBM Z
- Cloud Pak for Business Automation
- Cloud Pak for Data
- Cloud Pak for Integration
- Cloud Pak for Network Automation
- Cloud Pak for Security
- Cloud Pak for Watson AIOps
- Cloud Platform as a Service
- Cloud Security Services
- CMC
- COBOL
- Cognos Analytics on Cloud
- Cognos Analytics with Watson
- Cognos Controller
- Container Registry
- Content Manager (CM8)
- Content Manager OnDemand (CMOD)
- Content Navigator
- Content Services
- Data Fabric
- Data Privacy Passports
- Data Replication
- Data Security Services
- Data Virtualization
- Datacap (Datacap Insight Edition)
- DataPower
- Db2
- Db2 13 for z/OS
- Db2 for i
- Db2 for IBM i
- Db2 for z/OS
- Db2 LUW
- Db2 Mirror
- DB2 Mirror for i
- Db2 on Cloud Paygo
- Db2 Tools for z/OS
- Db2 Tools LUW
- Db2 Warehouse on Cloud
- Db2 Warehouse on Cloud for AWS
- Db2 Warehouse on Cloud Paygo
- Db2 Web Query for i
- Decision Management
- Decision Optimization
- Developer for z/OS
- DevOps Platform
- Digital Health Pass
- Dizzion Managed DaaS on IBM Cloud
- Docker
- Eclipse Codewind
- Eclipse OpenJ9
- ECM System Monitor
- Elyra
- Engineering
- Enterprise COBOL for z/OS
- Enterprise Key Management Foundation
- Enterprise Video Streaming
- Environmental Intelligence Suite
- Envizi
- Event Streams
- Explorer for z/OS
- File Manager for z/OS
- FileNet
- Flexera One with IBM Observability
- Food Trust
- Fusion
- Galasa
- Governance
- Graphic Data Display Manager
- Guardium
- Guardium Data Protection
- Guardium Insights
- Guardium Vulnerability Assessment
- Helm
- High Level Assembler and Toolkit Feature
- HMC
- Hyperledger
- IAM Services
- IBM 100 Top Hospitals®
- IBM 3592 tape cartridges
- IBM 7226 Multimedia Storage Enclosure
- IBM AIX
- IBM Analytics Engine
- IBM API Connect
- IBM API Hub
- IBM App Connect
- IBM Application Discovery for IBM Z
- IBM Aspera on Cloud
- IBM Blockchain Platform
- IBM Bob
- IBM Center for Cloud Training
- IBM CICS Family and CICS Tools
- IBM Cloud
- IBM Cloud App Configuration
- IBM Cloud App ID
- IBM Cloud Backup
- IBM Cloud Bare Metal Servers
- IBM Cloud Block Storage
- IBM Cloud Certificate Manager
- IBM Cloud CLI
- IBM Cloud Code Engine
- IBM Cloud Continuous Delivery
- IBM Cloud Data Engine
- IBM Cloud Data Shield
- IBM Cloud Databases for Elasticsearch
- IBM Cloud Databases for EnterpriseDB
- IBM Cloud Databases for etcd
- IBM Cloud Databases for MongoDB
- IBM Cloud Databases for MySQL
- IBM Cloud Databases for PostgreSQL
- IBM Cloud Databases for Redis
- IBM Cloud File Storage
- IBM Cloud for Financial Services
- IBM Cloud for Skytap Solutions
- IBM Cloud for VMware Solutions
- IBM Cloud Functions
- IBM Cloud Hardware Security Module
- IBM Cloud Hyper Protect Services
- IBM Cloud Internet Services
- IBM Cloud Kubernetes Service
- IBM Cloud Management Console (CMC)
- IBM Cloud Mass Data Migration
- IBM Cloud Messages for RabbitMQ
- IBM Cloud Object Storage
- IBM Cloud Object Storage (on Premises)
- IBM Cloud Pak for Applications
- IBM Cloud Pak for Automation
- IBM Cloud Pak for Business Automation
- IBM Cloud Pak for Data
- IBM Cloud Pak for Integration
- IBM Cloud Pak for Multicloud Management
- IBM Cloud Pak for Network Automation
- IBM Cloud Pak for Security
- IBM Cloud Pak for Watson AIOps
- IBM Cloud Paks
- IBM Cloud Satellite
- IBM Cloud Schematics
- IBM Cloud Secrets Manager
- IBM Cloud Security Advisor
- IBM Cloud Security and Compliance Center
- IBM Cloud Virtual Server for VPC
- IBM Cloud Virtual Servers for Classic Infrastructure
- IBM Cloud VPS Hosting
- IBM Cloudant
- IBM Db2 Database
- IBM Db2 Event Store
- IBM Db2 for z/OS Data Gate
- IBM Db2 on Cloud
- IBM Db2 Warehouse
- IBM Db2 Warehouse on Cloud
- IBM DS8880F
- IBM DS8900
- IBM DS8900F
- IBM Edge Application Manager
- IBM Elastic Storage
- IBM Environmental Intelligence Suite
- IBM Event Streams
- IBM Financial Crimes Insight (FCI)
- IBM FlashSystem
- IBM FlashSystem 5000
- IBM FlashSystem 5200
- IBM FlashSystem 7300
- IBM FlashSystem 9500
- IBM Hyper Protect Crypto Services
- IBM Hyper Protect DBaaS
- IBM Hyper Protect Virtual Servers
- IBM i
- IBM i Modernization Engine for Lifecycle Integration (Merlin)
- IBM Informix on Cloud
- IBM InfoSphere Information Server on Cloud
- IBM Key Protect
- IBM Lift
- IBM Linear Tape-Open (LTO) Ultrium 6 Data Cartridge
- IBM Linear Tape-Open (LTO) Ultrium 7 Data Cartridge
- IBM Linear Tape-Open (LTO) Ultrium 8 Data Cartridge
- IBM LinuxONE
- IBM LinuxONE Emperor 4
- IBM LinuxONE Rockhopper 4
- IBM Master Data Management on Cloud
- IBM Maximo Application Suite
- IBM Maximo Application Suite: Remote monitoring
- IBM Maximo Asset Management
- IBM Maximo Remote Monitoring
- IBM Maximo Visual Inspection
- IBM Mobile Foundation
- IBM MQ
- IBM MQ on Cloud
- IBM Power
- IBM Power Systems Virtual Servers
- IBM SAN Volume Controller
- IBM SAP on Cloud
- IBM Security Access Manager
- IBM Security Guardium Data Encryption
- IBM Security Guardium Data Protection
- IBM Security Guardium Data Risk Manager
- IBM Security Guardium Discover & Classify
- IBM Security Guardium Insights
- IBM Security Guardium Key Lifecycle Manager
- IBM Security Guardium Vulnerability Assessment
- IBM Security Identity Governance & Intelligence
- IBM Security MaaS360
- IBM Security QRadar
- IBM Security QRadar EDR
- IBM Security QRadar Log Insights
- IBM Security QRadar SIEM
- IBM Security QRadar SOAR
- IBM Security QRadar XDR
- IBM Security Randori Recon
- IBM Security ReaQta
- IBM Security Secret Server
- IBM Security Trusteer
- IBM Security Verify
- IBM Security Verify Access
- IBM Security Verify Governance
- IBM Security Verify Privilege Manager
- IBM Security Verify Privilege Vault
- IBM Security Verify Trust
- IBM Security zSecure
- IBM Security zSecure Admin
- IBM Security zSecure Alert
- IBM Security zSecure Audit
- IBM Security zSecure CICS Toolkit
- IBM Security zSecure Command Verifier
- IBM Security zSecure Multi-factor Authentication
- IBM Security zSecure RACF/zVM
- IBM Security zSecure Visual
- IBM Spectrum Archive
- IBM Spectrum Control
- IBM Spectrum Copy Data Management
- IBM Spectrum Discover
- IBM Spectrum Protect
- IBM Spectrum Protect Plus
- IBM Spectrum Scale
- IBM Spectrum Software
- IBM Spectrum Storage Suite
- IBM Spectrum Virtualize
- IBM SPSS Modeler
- IBM SPSS Statistics
- IBM Sterling
- IBM Storage Insights
- IBM Storage Networking SAN
- IBM Storage Networking SAN18B-6
- IBM Storage Networking SAN24B-6
- IBM Storage Networking SAN32C-6 Fabric Switch
- IBM Storage Networking SAN42B-R
- IBM Storage Networking SAN48C-6
- IBM Storage Networking SAN50C-R Fabric Switch
- IBM Storage Networking SAN64B-6
- IBM Storage Networking SAN96C-6
- IBM Storage Networking SAN128B-6
- IBM Storage Networking SAN192C-6 Multilayer Director
- IBM Storage Networking SAN384C-6 Multilayer Director
- IBM Storage Networking SAN512B-6 and SAN256B-6
- IBM Storage Networking SAN768C-6 Director
- IBM Storage Suite for IBM Cloud Paks
- IBM Storage Utility
- IBM Streaming Analytics
- IBM Streams
- IBM Tape Drives
- IBM Tape Library
- IBM TradeLens
- IBM TRIRIGA
- IBM TS1070 Tape Drive
- IBM TS1130 Tape Drive
- IBM TS1150 Tape Drive
- IBM TS1160 Tape Drive
- IBM TS2250 Tape Drive
- IBM TS2260 Tape Drive
- IBM TS2270 Tape Drive
- IBM TS2280 Tape Drive
- IBM TS2900 Tape Autoloader
- IBM TS4300 Tape Library
- IBM TS4500 Tape Drive
- IBM TS7760 Virtual Tape Library
- IBM TS7770 Virtual Tape Library
- IBM Turbonomic Application Resource Management
- IBM Watson Assistant
- IBM Watson Discovery
- IBM Watson Knowledge Catalog
- IBM Watson Knowledge Studio
- IBM Watson Language Translator
- IBM Watson Machine Learning for z/OS (3.1)
- IBM Watson Natural Language Classifier
- IBM Watson Natural Language Understanding
- IBM Watson Speech to Text
- IBM Watson Studio
- IBM Watson Text to Speech
- IBM WebSphere Application Server
- IBM WebSphere Application Server on Cloud
- IBM WebSphere Hybrid Edition
- IBM Z Cyber Vault
- IBM z/OS
- IBM z/OS Connect
- IBM zSystems
- Information Analyzer/IGC
- Informix (on prem or cloud)
- InfoSphere DataStage-Data Integration
- Infrastructure and Endpoint Services
- Instana
- Integrated Analytics Systems
- Integrated Facility for Linux
- Istio
- Jakarta EE
- Java Platform
- Jupyter
- Knative
- Kubernetes
- KVM on Z
- Linux on IBM Power
- Linux on Z
- LinuxOne Community Cloud
- MaaS360 with Watson
- Machine Learning for z/OS
- Managed Detection and Response
- Master Data Management (MDM)
- Maximo
- MicroProfile
- MQ
- MQ for z/OS
- MQTT
- Multicloud Manager
- Netcool family (NOI, Netcool Insights, Netcool Omnibus, NPI)
- Netezza Performance Server
- Network security
- Node-RED
- Open Data Analytics for z/OS
- Open Enterprise Python for z/OS
- Open Horizon
- Open Liberty
- Open Shift
- Open Source Offerings
- OpenJDK
- Optim
- Other
- Palantir for IBM Cloud Pak for Data
- Partner Ecosystem (IPE)
- Pilotbrief
- Planning Analytics with Watson
- Power E1050
- Power E1080
- Power L1022
- Power L1024
- Power S1014
- Power S1022
- Power S1022s
- Power S1024
- Power Virtual Server
- PowerHA
- PowerSC
- PowerVC
- PowerVM
- Process Mining
- Qiskit
- Qiskit Runtime
- QRadar
- QRadar Advisor with Watson
- QRadar Incident Forensics
- QRadar Log Manager
- QRadar NDR
- QRadar Network Insights
- QRadar on Cloud
- QRadar SIEM
- QRadar SOAR
- QRadar Vulnerability Manager
- QRadar XDR Connect
- Quarkus
- RACF
- Rational
- Rational Developer for i
- React
- Real Time Payment
- Red Hat Ansible
- Red Hat Ansible Lightspeed
- Red Hat OpenShift on IBM Cloud
- Red Hat OpenShift on IBM Power
- RISE With SAP on Power Virtual Server
- Risk
- Robotic Process Automation (RPA)
- RocketCE
- RPG
- SAP HANA on IBM Power
- SAS Viya on IBM Power
- SDK for Node.js
- Secure gateway
- Security Expert Labs
- Security Intelligence Operations and Consulting Services
- Security Strategy
- SevOne
- Software-Defined Storage Services
- Spectrum
- Spectrum Discover
- Spring
- SPSS Modeller
- SPSS Statistics
- SSL certificates
- Sterling
- StoredIQ
- Streams
- Supply Chain
- Tailored Fit Pricing
- Tape Manager for z/VM
- TCP/IP
- Tekton
- TensorFlow
- Terraform
- Threat Management Services
- Tivoli
- Tririga
- Trusteer
- Trusteer Mobile SDK
- Trusteer Pinpoint Assure
- Trusteer Pinpoint Detect
- Trusteer Pinpoint Verify
- Trusteer Rapport
- Turbonomic
- Turbonomic Application Resource Management
- UrbanCode
- vHMC
- VM Recovery Manager
- Vmware on Cloud
- Watson API
- Watson APIs
- Watson Discovery
- Watson Knowledge Catalog
- Watson Knowledge Studio
- Watson Language Translator
- Watson Machine Learning
- Watson Machine Learning Accelerator
- Watson Natural Language Classifier
- Watson Natural Language Understanding
- Watson OpenScale
- Watson Query
- Watson Speech to Text
- Watson Studio
- Watson Text to Speech
- watsonx
- watsonx Assistant
- watsonx Code Assistant
- watsonx Code Assistant for Z
- watsonx Orchestrate
- watsonx.ai
- watsonx.data
- watsonx.governance
- Wave for z/VM
- Wazi
- Weather Company Data
- WebSphere Automation
- WebSphere Hybrid Edition
- WebSphere Open Liberty
- Workload Automation
- X-Force IRIS
- X-Force Red
- X-Force Threat Intelligence
- X-Force Threat Management
- z/OS
- z/OS Comm Server
- z/OS Container Extensions
- z/OS Containers
- z/OS DFSMS
- z/OS Integrated Cryptographic Service Facility (ICSF)
- z/OSMF
- z/TPF
- z/VM
- z/VSE
- z15
- z16
- zCX
- Zero Trust
- SKILL_SHORT
- AI Infrastructure IT Infrastructure
- AI on Power
- AIX (Developer)
- AIX/Oracle
- API Connect Essentials
- API Management
- API-Led Integration
- APM/Predictive Maintenance
- Access Management
- ActiveMQ
- Akamai API Security
- Akka
- Amazon Web Services (AWS)
- Analytics
- Analytics Content Hub
- Analytics for batch resiliency
- Angular
- Anomaly Analytics with Watson for Z
- Apache Cassandra
- Apache Cordova
- Apache Hadoop
- App Connect
- App Connect Enterprise (ACE)
- App Metrics
- Application Delivery Foundation for z/OS (ADFZ)
- Application Development
- Application Environment Deployment
- Application Integration
- Application Lifecycle Management
- Application Modernization
- Application Modernization Accelerator (AMA)
- Application Performance Management Connect for Z
- Application Server
- Apptio One
- Artificial Intelligence
- Assembler
- Assembly
- Asset Lifecycle Management
- Asset Maintenance (EAM)
- Asset Management (General)
- Automating your Business
- Azure
- Batch Resiliency for Z
- Big Data
- Blockchain
- Blockchain (Developer)
- Business Analytics
- Business Automation Manager Open Edition
- Business Automation Workflow
- Business Intelligence
- Business Process Management
- Business Process Management (IBM BPM, BAW, Case Manager)
- C
- C#
- C++
- CICS VSAM Recovery
- COBOL (Developer)
- CPACF
- Case Management
- Chat Ops for Z
- Chatbots
- Cloud
- Cloud Computing
- Cloud Infrastructure
- Cloud Integration
- Cloud Native Apps with AI on IBM Cloud
- Cloud Native Development
- Cloud Object Storage
- Cloud Pak for AIOps
- Cloud Pak for Applications (CP4Apps)
- Cloud security
- Cloudability
- Cloudera
- Code for IBM i
- Cognos Analytics
- Confidential Containers
- Connective Vehicle Insights
- Container registry
- Containers
- Content Management
- Content Management and Capture
- Continuous Availability
- Controller
- Crypto Analytics Tool (CAT)
- Crypto Express / TKE
- Crystal programming language
- Cybersecurity
- DB2 AI for z/OS
- DRA on PowerVS
- DS8K SafeGuarded Copy
- Dashbot
- Data Governance
- Data Management
- Data Privacy for Diagnostics
- Data Product Hub
- Data Protection
- Data Quality
- Data Science
- Data Security
- Data Stores
- Data Warehousing
- Data lake
- DataOps
- DataStage
- DataStax Astra DB
- Databases
- Datacap Open Editions
- Db2 (Developer)
- Db2 Analytics Accelerator for z/OS
- Db2 Event Store (Developer)
- Db2 Warehouse (Developer)
- Db2 for z/OS Data Gate
- Db2 tools for z/OS
- Deep Learning
- Deployable Architectures on IBM Cloud
- Detection and Response
- DevSecOps
- Developer Tooling
- Developer for z/OS (IDZ)
- Development on IBM LinuxONE (Developer)
- Digital Operational Resilience Act (DORA)
- Digital Process Automation
- Digital Transformation
- Digital Trust
- Disaster Recovery
- Distributed ledgers
- Document Exchange
- Edge Computing
- Encryption
- Encryption Facility
- Encryption everywhere
- Engineering Lifecycle Management (General)
- Enterprise Application Runtimes (EAR)
- Enterprise Application Service for Java (EASeJ)
- Enterprise Computing
- Envizi (Developer)
- Envizi ESG Suite
- Event-Led Integration
- Fabric for Deep Learning
- Flexible compute
- Food Trust (Developer)
- Fraud Protection
- Front End Development
- GDPR
- Go
- Google Cloud
- Grafana
- Groovy
- Guardium Data Encryption
- Guardium Data Security Center
- Guardium Discover and Classify
- Guardium S TAPs for z/OS
- HashiCorp Boundary
- HashiCorp Cloud Platform
- HashiCorp Consul
- HashiCorp Nomad
- HashiCorp Packer
- HashiCorp Terraform
- HashiCorp Vagrant
- HashiCorp Vault
- HashiCorp Waypoint
- High Availability
- High Performance Computing
- High Performance Computing - Spectrum LSF
- High Performance Computing - Spectrum Symphony
- Hybrid Cloud
- Hybrid Cloud Mesh
- Hyperledger Fabric
- IBM API Connect (Developer)
- IBM Access Manager
- IBM App Connect (Developer)
- IBM Apptio
- IBM Apptio Platform
- IBM Blockchain Platform  (Developer)
- IBM Cloud (Developer)
- IBM Cloud Code Engine (Developer)
- IBM Cloud Hyper Protect Services (Developer)
- IBM Cloud Logs
- IBM Cloud Monitoring
- IBM Cloud Object Storage (IaaS)
- IBM Cloud Pak for AIOps (Developer)
- IBM Cloud Pak for Applications (Developer)
- IBM Cloud Pak for Business Automation (Developer)
- IBM Cloud Pak for Data (Developer)
- IBM Cloud Pak for Integration (Developer)
- IBM Cloud Pak for Security (Developer)
- IBM Cloud Paks (Developer)
- IBM Cloud for SAP Certified Instances VMware VCF
- IBM Cloud for SAP in Classic with Certified Instances (Bare Metal)
- IBM Cloud for SAP on PowerVS with Certified Instances
- IBM Cloud for SAP on VPC with Certified Instances
- IBM Cloudability
- IBM Concert
- IBM Concert for Z
- IBM Content Manager
- IBM Crypto Discovery and Inventory
- IBM DS8A00
- IBM Databand
- IBM Db2 Mirror for i
- IBM Db2 Warehouse on Power
- IBM Db2 for i
- IBM Defender Data Protect
- IBM DevOps
- IBM DevOps Loop
- IBM DevOps Platform
- IBM Diamondback Tape Library
- IBM Encryption Platform
- IBM Engineering Requirements Management DOORS
- IBM Engineering Requirements Management DOORS Next
- IBM Engineering Test Management (ETM)
- IBM Engineering Workflow (EWM)
- IBM Enterprise COBOL for z/OS
- IBM Environmental Intelligence
- IBM Environmental Intelligence  APIs
- IBM Event Automation
- IBM Fusion
- IBM GDPS® for business continuity
- IBM Granite models (Developer)
- IBM Guardium Discover and Classify
- IBM Guardium Key Lifecycle Manager
- IBM Identity Governance & Intelligence
- IBM JSphere for Java
- IBM Knowledge Catalog
- IBM Kubecost
- IBM Kubernetes Services
- IBM Langflow
- IBM LinuxONE (Hardware)
- IBM LinuxONE Emperor 5
- IBM MQ (Developer)
- IBM Managed Security Services
- IBM Manta Data Lineage
- IBM Maximo Application Suite (General)
- IBM Maximo Application Suite - Assist
- IBM Maximo Application Suite - Field Service Management
- IBM Maximo Application Suite - Health
- IBM Maximo Application Suite - IT
- IBM Maximo Application Suite - Industry Solutions
- IBM Maximo Application Suite - Integration (ERP, CRM, or other third-party applications)
- IBM Maximo Application Suite - Manage
- IBM Maximo Application Suite - Mobile
- IBM Maximo Application Suite - Monitor
- IBM Maximo Application Suite - Predict
- IBM Maximo Application Suite - Reliability Strategies
- IBM Maximo Application Suite - Visual Inspection
- IBM Maximo Application Suite - Work Order Intelligence (GenAI)
- IBM Maximo Visual Inspection (Developer)
- IBM Power (Developer)
- IBM Power E1150
- IBM Power E1180
- IBM Power L1122
- IBM Power L1124
- IBM Power S1122
- IBM Power S1124
- IBM Power Virtual Server
- IBM Power with IBM Storage Solutions
- IBM PowerHA System Mirror
- IBM PowerSC
- IBM PowerVC
- IBM PowerVM
- IBM Rational Developer for i
- IBM Rhapsody Systems Engineering
- IBM Runtimes for Business (IRB)
- IBM Secret Server
- IBM Semeru Runtimes
- IBM Sterling B2B Integration (SaaS)
- IBM Sterling B2B Integrator
- IBM Sterling Managed File Transfer
- IBM Sterling Order Management
- IBM Sterling Secure File Transfer
- IBM Sterling Transformation Extender
- IBM Storage Archive
- IBM Storage Ceph
- IBM Storage Copy Data Management
- IBM Storage DS8000
- IBM Storage Deep Archive
- IBM Storage Defender
- IBM Storage Discover
- IBM Storage FlashSystem
- IBM Storage FlashSystem 5200
- IBM Storage FlashSystem 5300
- IBM Storage FlashSystem 7300
- IBM Storage FlashSystem 9500
- IBM Storage Protect
- IBM Storage Protect for Cloud
- IBM Storage Scale
- IBM Storage Scale System
- IBM Storage Sentinel
- IBM Storage Software
- IBM Storage Tape
- IBM Storage Virtualize
- IBM Storage for AI
- IBM TS7780 Virtual Tape Library
- IBM Targetprocess
- IBM Technical Expert Labs
- IBM Terraform Self-Managed for Z and LinuxONE 1.1
- IBM TradeLens (Developer)
- IBM Transformation Advisor (TA)
- IBM Trusteer
- IBM Trusteer Mobile
- IBM Trusteer Pinpoint Assure
- IBM Trusteer Pinpoint Detect
- IBM Trusteer Pinpoint Verify
- IBM Trusteer Rapport
- IBM VM Recovery Manager
- IBM Vault for Z (HashiCorp)
- IBM Verify Access
- IBM Verify Privilege Manager
- IBM Verify Privilege Vault
- IBM Verify Trust
- IBM Workload Automation
- IBM Z & IBM LinuxONE Hybrid Cloud Platform
- IBM Z (Hardware)
- IBM Z Decision Support
- IBM Z Digital Integration Hub
- IBM Z Enterprise AI
- IBM Z IntelliMagic Vision for z/OS
- IBM Z Multi-Factor Authentication (IBM Z MFA)
- IBM Z Open Editor (Developer)
- IBM Z Seucirty Portal
- IBM Z Skills
- IBM Z Test Accelerator
- IBM Z and LinuxONE Security and Compliance Center (zSCC)
- IBM Z and LinuxONE Sustainability
- IBM Z cryptographic hardware
- IBM developer for z/OS (Developer)
- IBM i (Developer)
- IBM i Development Pack
- IBM i Modernization Engine for Lifecycle Integration
- IBM z/OS Debugger (Developer)
- IBM zSecure
- IBM zSecure Admin
- IBM zSecure Alert
- IBM zSecure Audit
- IBM zSecure CICS Toolkit
- IBM zSecure Command Verifier
- IBM zSecure Manager for z/VM
- IBM zSecure Multi-factor Authentication
- IBM zSecure RACF/zVM
- IBM zSecure Visual
- IBM® Application Discovery and Delivery Intelligence (ADDI)
- ICSF
- IDZ (Developer)
- IMS
- IT Infrastructure
- Identity and Access Management (IAM)
- Industry Cloud and Solutions
- InfoSphere Master Data Management
- InfoSphere Optim
- Informix (On Prem or Cloud)
- Infrastructure and Endpoint Security
- Instana (Developer)
- InstructLab
- IntelliMagic with Apptio
- Intelligence Analysis and Investigations
- Internet of Things / IoT
- Ionic
- JanusGraph
- Java
- Java Development
- JavaScript
- Jenkins
- KServe
- Kabanero
- Keras
- Kitura
- Knowledge Discovery
- Knowledge Studio
- Kotlin
- Kubeflow
- Lenovo
- Linux
- Linux on IBM Power (Developer)
- LoopBack
- Lucky Application Framework
- Machine Learning
- Master Data Management
- Matlab
- Maximo Application Suite (Developer)
- Memory Encryption
- Messaging
- Microservices
- Mobile Development
- Mobile Security
- Modernized Runtime Extension for Java (MoRE)
- MongoDB
- Monitoring for Z
- NEC
- NS1
- NVIDIA
- Natural Language Processing
- NetView for Z
- Netcool Insights
- Netcool Omnibus
- Netcool family (NOI, NPI)
- Netezza Performance Server (Developer)
- Network Security
- Neural Network
- Nimbix Cloud Computing Platform
- NoSQL
- Node.js
- OCI
- ODPi
- OKD
- OMEGAMON (all) for Z
- OMEGAMON Grafana UI
- OMEGAMON for Storage on Z
- Objective-C
- Observability by Instana APM on z/OS
- Odata
- Open Neural Network Exchange
- Open Source
- Open Source Library Support
- OpenAPI
- OpenCAPI
- OpenCV
- OpenJ9
- Operating Systems
- Operational Decision Manager
- Operational Log and Data Analytics (and CDP) for Z
- Optimize Enterprise VMware Workloads
- Oracle on IBM Power
- PHP
- Partner Engagement Manager
- Performance and Capacity Analytics for Z
- Pervasive Encryption
- PixieDust
- Pixit Media
- Planning Analytics
- Platform as a Service
- Postgres
- Power Private Cloud
- Power Virtual Server (Iaas)
- PowerVS (Cloud)
- PowerVS AIX
- PowerVS Db2
- PowerVS IBMi
- PowerVS Linux
- PowerVS Networking
- PowerVS Networking Updates
- PowerVS Oracle
- Predictive Analytics
- Privacy and Security
- Process Automation
- Prometheus
- Provenance
- PyTorch
- Python
- QRadar EDR
- QRadar Log Insights
- QRadar Suite (Developer)
- Quantum Computing
- Quantum Safe System
- R
- RISE With SAP on IBM Power Virtual Server
- RabbitMQ
- React Native
- Reactive Systems
- Real Time Payment (Developer)
- Red Hat Ansible Automation Platform (Developer)
- Red Hat Ansible IBM Z and LinuxONE (Developer)
- Red Hat Enterprise Linux (Developer)
- Red Hat Open Shift IBM Z and LinuxONE
- Red Hat OpenShift (Developer)
- Red Hat OpenShift AI (Developer)
- Red Hat OpenShift on IBM Cloud (Developer)
- Red Hat OpenShift on IBM Power (Developer)
- Risk Quantification
- Robotic Process Automation
- Rohde & Schwarz
- Ruby
- SAP
- SAP RISE
- SIEM (Security Information and Event Management)
- SIOC
- SOAR (Security Orchestration
- SPSS Modeler (Developer)
- SQL
- Scala
- Secure Boot
- Secure Execution for Linux
- Security
- Security Operations
- Security Strategy and Risk
- Serverless
- Service Automation Suite for Z
- Service Management Unite for Z
- Smart Contracts
- Speech and Empathy
- Spyre Accelerator for IBM Z
- Sterling (Developer)
- Sterling Data Exchange (General)
- StreamSets
- Supply Chain Intelligence Suite - Blockchain
- Supply Chain Intelligence Suite - Control Tower
- Supply Chain Intelligence Suite - IBM Food Trust
- Supply Chain Intelligence Suite - MRO IO
- Sustainability
- Swift
- System Automation for Z
- Systems Management for Z
- TRIRIGA Application Suite (General)
- TRIRIGA Application Suite - Capital Planning Projects
- TRIRIGA Application Suite - Facilities Lease Management
- TRIRIGA Application Suite - Maintenance and Operations
- TRIRIGA Application Suite - Space Planning and Management
- Table Accelerator for Z
- Telum II for IBM Z
- Threat Detection
- Threat Detection for z/OS
- Threat Management
- Tivoli for IBM Z
- Tokenization
- Tools and Run-time Development
- Traceability
- Turbonomic (Developer)
- Twilio
- TypeScript
- UKO / EKMF Workstation
- Unified Governance
- Unix
- VMRM Solution Planning
- VMWare
- VMware Cloud Foundation (VCF) as a service
- VMware Cloud Foundation (VCF) for VPC
- VMware Cloud Foundation (VCF) for classic
- Validated Boot for z/OS
- Verify (Developer)
- Verify SaaS
- Vert.x
- Video
- Vim
- Virtualization
- Vision
- Visual Studio Code
- Vue Javascript Framework
- Watson Assistant
- Watson Studio (Developer)
- Wazi-as-a-service
- WebSphere Hybrid Edition (Developer)
- WebSphere Liberty
- Websphere Liberty Core
- Workload Interaction Navigator for Z
- Workload Scheduler for IBM Z
- XFTI​ Verify Access
- XForce Red Services
- Z Open Automation Utilities (ZOAU)
- Z Security and Compliance Center (ZSCC)
- Zipkin
- Zowe
- django
- perl
- watsonx (Developer)
- watsonx Assistant (Developer)
- watsonx Assistant for Z
- watsonx BI Assistant
- watsonx Code Assistant for Enterprise JAVA
- watsonx Code Assistant for Red Hat Ansible
- watsonx Code Assistant for Z (Developer)
- watsonx Data Lakehouse
- watsonx Discovery
- watsonx Orchestrate (Developer)
- watsonx. Governance (Developer)
- watsonx.ai (Developer)
- watsonx.data (Developer)
- webMethods
- z/OS Anomoly Analytics
- z/OS Change Tracker
- z/OS Connect
- z/OS Sysplex EDR
- z17
- zACS / zACM
- zERT
- zSecure
- zSecure Adaptors for SIEM
- zSecure Admin
- zSecure Alert
- zSecure Audit
- zSecure CICS Toolkit
- zSecure Command Verifier
- zSecure Manager for z/VM
