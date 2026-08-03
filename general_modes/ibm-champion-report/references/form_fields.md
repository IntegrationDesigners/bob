# IBM Champion Activity Report - form field reference

Authoritative, **browser-verified** field spec for the **IBM Champion Program -
Activity Report** form (verified 2026-06-29, field by field, against the live form).

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
- Email values: `@` -> `%40`. Date values: `D/M/YYYY` (leading zeros optional).
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
- Values must match Appendix B exactly. There is **no** "App Connect Enterprise" / "ACE"
  entry - the closest is **`IBM App Connect`**.
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

### 6. Approximate date of activity (date, required)

- **Prefill:** `prefill_fld0aJmUIrBMO2BWh=<D/M/YYYY>` (field ID).
- Format `D/M/YYYY` slash-separated; **leading zeros optional** (`22/5/2026` and
  `22/05/2026` both land; display normalizes to `22/5/2026`).
- "Only report activities contributed in the last year." First-of-month if unknown.

### 7. How many MORE Acts of Advocacy to add (single-select, required)

- Options: **Zero**, **1**, **2**. **NOT prefillable** (defaults to `1`); set manually.
- The 2nd/3rd-act fields are manual too, except the **2nd-activity Date**
  (`prefill_fldsYCztbwXKtlxiT=<D/M/YYYY>`). If the user has more than 3 activities,
  tell them to submit the form again for the overflow.

### 8. PRIVACY consent (checkbox, required)

- The Credly / IBM data-use + privacy consent. **Manual must-tick** - the skill can
  never consent for the user. Flag it as the last manual step before submitting.

---

## Prefilled-form URL (PROVEN)

Regression-verified in-browser: all 8 prefillable fields land together. Build this from
`.env` identity + the assembled 1st-act values. URL-encode values (`@`->`%40`,
space->`%20`).

```
https://airtable.com/appuwf3eOGdO6x1oS/pagF5IfVT7m6unCbG/form?prefill_fldt6UIOXVxQBNSgl=<CHAMPION_PROGRAM_ID>&prefill_First%20name=<FIRST_NAME>&prefill_Last%20name=<LAST_NAME>&prefill_Primary%20Email=<PRIMARY_EMAIL>&prefill_Alternate%20Email=<ALTERNATE_EMAIL>&prefill_1st%20Act%20of%20Advocacy=<ACT_OPTION>&prefill_fldTWgIi3n3KNErJJ=<PRODUCTS_COMMA_SEP>&prefill_fld0aJmUIrBMO2BWh=<D/M/YYYY>
```

**Prefills (8):** Champion Program ID, First name, Last name, Primary Email, Alternate
Email, 1st Act of Advocacy, Product(s), 1st-activity Date.

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
   - Description textarea: **"AoA1 Description"** (label "Description of this Activity.")
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

## Appendix A: Act of Advocacy options (verified, 40)

Map the user's activity to **one of these exactly**:

- All other videos (e.g. Youtube)
- Analyst Reference
- Attend in-person User Group meeting
- Blog or Article
- Blog on IBM property
- Board Member or UG Leader
- Case Study (Contribute to an IBM Case Study, or Attributed Author, or Quoted)
- Contributing to community.ibm.com (Discussion Threads, Questions)
- Host or Organize IBM-Related Event (multi-customer/non-sales)
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
- Participate in IBM-Sponsored Advisory Committees/Boards
- Share a Quote (Testimonial) for use by IBM
- Speaker at User Group or Meetup
- Other

## Appendix B: Product(s) options (verified, 516)

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
