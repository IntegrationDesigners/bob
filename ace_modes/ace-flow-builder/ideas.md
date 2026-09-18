# ACE Flow Builder - Ideas & Future Work

## Current Status

Skill created from demo example (ACE_DEMO_DESIGN.md) and enriched with real IBM ACE v13 templates extracted from official pattern zips (September 2024).

**Real example flows available in `references/examples/`:**
All 93 IBM ACE v13 patterns extracted from official v1.0.0 release zips (September 2024):
- **72 Protocol Transformation** patterns (all From/To combinations across Database, Email, File, HTTP, IBM MQ, JMS, Kafka, MQTT, TCP/IP)
- **20 Format Transformation** patterns (BLOB/JSON/XML/FixedLength/Delimited ↔ all formats)
- **1 AI/RAG** pattern (Pinecone + IBM watsonx.ai)

Scatter-Gather, Messaging, and Enterprise Integration patterns are NOT in the v1.0.0 release zip.

**Repos cloned at `<local-clone-dir>`:**
- `ace-patterns` (ragpattern branch) - pattern descriptions and zip releases at `/releases/download/v1.0.0/`
- `ace-tutorials` (RAGpattern branch) - tutorial content in `v13/en/tutorials_data.json`

The full IBM ACE patterns catalog is in `references/ace_patterns_catalog.md` - all 93 extracted patterns marked ✅.

---

## What's Missing / To Add

### .msgflow XML Format ✅ RESOLVED
- Real ACE v13 format confirmed from official pattern zips - documented in `references/msgflow_format.md`
- `workflow.md` template corrected: `.msgnode` namespaces, `eflow:FCMComposite` top-level, sequential node IDs
- All 6 example flows in `references/examples/` are real IBM ACE v13 files
- HandleException ESQL module now standard for every generated flow

### More Flow Types ✅ PARTIALLY RESOLVED
Real templates for all 93 patterns are in `references/examples/`. Non-HTTP examples and MQ ESQL patterns added to `references/workflow.md`.
Still not covered in detail:
- [ ] HTTP Input → route to multiple outputs (conditional routing with ComIbmFilter)
- [ ] Scheduled flow (Timeout Notification node pattern)
- [ ] Request-reply with TryCatch wrapper pattern

### Example Flows ✅ RESOLVED (93 patterns)
`references/examples/` contains real IBM ACE v13 templates for all 93 v1.0.0 patterns.
Not available as templates (not in IBM release):
- [ ] Scatter-Gather patterns (Splitter, Aggregation, Collector)
- [ ] Messaging patterns (Fire-and-Forget, Request-Reply, Publication)
- [ ] Enterprise Integration patterns (Circuit Breaker, Scheduling, Routing, etc.)

### ESQL Patterns Library ✅ RESOLVED
Added to `references/workflow.md` section 3.2:
- MQMD header read/write (MsgType, CorrelId, ReplyToQ)
- CopyMessageHeaders() procedure
- LocalEnvironment label routing
- BLOB→JSON (PARSE), JSON→BLOB (ASBITSTREAM)
- DFDL domain (Fixed-Length, Delimited)
- JSON Array creation
- Repeating elements (CARDINALITY + WHILE loop)
- Database SELECT and PASSTHRU UPDATE
- DECLARE NAMESPACE

Still not covered:
- [ ] MQRFH2 header manipulation
- [ ] Calling a subflow (FlowOrder + FlowLabel nodes)
- [ ] DECLARE CONDITION / BEGIN WHEN END error handling blocks

### Test Feature - Non-HTTP Flows
Current test plan generation assumes HTTP. Need to extend for:
- MQ flows - how to inject test messages (MQ Explorer, mqput command, rfhutil)
- File flows - how to drop test files
- Scheduled flows - how to trigger manually

### ace-tutorials Content ✅ RESOLVED (partially)
Explored `tutorials_data.json` (145 tutorials). The JSON contains UI-driven Toolkit walkthrough text, not embedded ESQL code. Key findings extracted:
- ibmint commands confirmed: `ibmint package`, `ibmint apply overrides`, `ibmint deploy` - added to workflow.md
- MQ setup commands confirmed: `crtmqm`, `strmqm`, `runmqsc`, `define ql(...)` - documented in workflow.md Non-HTTP examples section

Remaining potential value from tutorials:
- [ ] Test guidance for MQ flows (rfhutil, mqput test patterns) - in Test Feature gap
- [ ] Specific tutorial for TryCatch pattern (has curl examples we could use)

### HTTP Request-Reply Starter Example ✅ RESOLVED
Added `references/examples/SimpleHTTPResponse/` from the `ace_http_response_flow` demo project:
- `SimpleHTTPResponse.msgflow` - 3-node flow: ComIbmWSInput → ComIbmCompute → ComIbmWSReply, URL `/message`, JSON domain
- `SimpleHTTPResponse_Compute.esql` - Sets Content-Type JSON, builds `{ status, message, timestamp }` response
- `application.descriptor` - minimal app descriptor
- Standalone IntegrationServer startup command added to `workflow.md` Phase B3.4 and `ace_patterns_catalog.md` Starter Patterns section

### .bobmodes - Root Registration
The root `.bobmodes` at `d:\GIT\bob_modes\.bobmodes` is currently empty. Once this skill is stable, register it there (or confirm the project uses folder-level discovery).

---

## Observations from Demo Design

Source: `ACE_DEMO_DESIGN.md` (C:\Users\Bmatt\Desktop\bob_projects\ace_demo_design\)

This is **one specific example** - not a universal template. Key points captured:
- ComIbmWSInput node: urlSpecifier=/message, domain=JSON for simple flow / XMLNSC for transformation
- HTTP status set via `X-Original-HTTP-Status-Code` header in ESQL (not via node property directly)
- Integration server ports: HTTP 7800, Admin REST 7600
- ibmint CLI for packaging and deployment
- BAR file contains both .msgflow and .esql
- File structure: Application folder → .project, application.descriptor, .msgflow, .esql

---

## Skill Gaps to Revisit

- The skill doesn't yet handle multi-flow applications (one BAR, multiple message flows)
- No guidance on shared libraries (library projects)
- No guidance on policy files (endpoint, credential, WS-Security)
- No guidance on promoted properties / deployment properties files
- No guidance on ACE Toolkit workspace vs. command-line-only development
- Error handling is mentioned but no dedicated patterns exist yet
