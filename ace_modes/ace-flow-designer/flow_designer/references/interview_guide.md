# Interview Guide - Question Bank & Defaults

The per-topic questions to ask during phases D2-D7, the plain-language framing for a junior
developer, and the **default to suggest** for each. Read this during the interview. Ask one topic
per turn; within a topic, batch the sub-questions. Every question must offer a default the user can
accept with "default" / "tbd" / "you pick".

The golden rule: **a junior developer should be able to answer every single question with "default"
and still get a buildable spec.** The defaults below are chosen to produce a sensible, conservative,
production-reasonable flow.

---

## D0 - Goal & use case

| Ask | Junior-friendly framing | Default if unsure |
|---|---|---|
| Goal | "In one sentence, what should this do?" | - (must be answered; help them phrase it) |
| Trigger | "What starts it off - a message, a file, an HTTP call, a timer?" | Infer from the source system |
| Definition of done | "When it has worked, what has happened?" | "the output was produced and nothing errored" |
| Endpoints | "What system sends the input, and what system receives the output?" | - |

If the user can't phrase the goal, offer a draft from the trigger + endpoints and let them correct it.

---

## D1 - Pattern

No question bank - this is a recognition step. Match against
`../flow_builder/references/ace_patterns_catalog.md` and name the pattern. Only ask a question if the
description is genuinely ambiguous between two patterns ("are you *reading from* a queue, or
*exposing* an endpoint that writes to one?").

---

## D2 - Scope & shape

| Ask | Junior-friendly framing | Default |
|---|---|---|
| One flow or many | "Is this one flow, or several near-identical ones (e.g. one per queue)?" | Single flow |
| Shared subflow | "If several, do they share logic worth putting in one place?" | Extract a subflow only when 2+ flows reuse it |
| Subflow terminals | **(ask ONLY if a shared subflow is chosen)** "Does the subflow have a separate happy path and error path - and where do the parent flow's normal output and its error outputs go?" | Separate happy/error inputs: parent's `out` → subflow happy input; parent's `catch`/`failure` → subflow error input |
| One app project | "Should everything live in one ACE application?" | Yes, one application project |
| Out of scope | "Anything this flow should explicitly *not* do?" | Nothing extra |

A *subflow* = a reusable mini-flow you wire into several parent flows so the shared logic lives once.

When a subflow is chosen, the terminal wiring is a flow_builder blocker (it otherwise guesses how the
parent's success and error paths enter the subflow). Capture it in the *Shape* section: the subflow's
input terminals (e.g. happy + error) and which parent-flow output goes to each - exactly as the
MQEventReader gold-standard spec does ("`out` → happy input; `failure`/`catch` → error input").

---

## D3 - Interfaces

### Input
| Ask | Framing | Default |
|---|---|---|
| Transport + locator | "Where does the input come from - which queue / URL path / directory / topic?" | `[CONFIGURE: input locator]` |
| Format | "What format is it - JSON, XML, CSV, fixed-length, plain text, binary?" | Infer from source system; else JSON |
| Structure | "Can you paste one representative example?" | `[CONFIGURE: sample payload]` |

### Output
| Ask | Framing | Default |
|---|---|---|
| Transport + locator | "Where does the result go?" | Symmetric with the trigger unless the goal says otherwise |
| Format | "What format should the output be?" | Same family as input unless transformation is the goal |
| HTTP success shape | (HTTP only) "What status + body on success?" | `200`/`202` + a small JSON ack |
| Output contract / target shape | "What should the output actually look like - can you sketch the structure or paste a sample of the target?" | `[CONFIGURE: target shape]` (offer to derive it from the mapping in D4) |
| Filename (File output) | "Same filename every time, or computed per message (e.g. with a date/id)?" | Static |

A *contract / target shape* is the **data structure** to produce (a sample payload or field list) -
this is design, not code. You never write ESQL/Java here; you describe the shape flow_builder must hit.

If there is more than one input or output, capture each as its own labelled block.

*Routing-source check (a flow_builder BLOCKER - must be answered, never defaulted):* if a later
routing/filter decision reads a value that could exist in more than one place (MQRFH2 folder vs HTTP
header vs `Environment.Variables` vs `LocalEnvironment`), ask which single source is authoritative.
flow_builder stops and asks this if the spec doesn't pin it down.

---

## D4 - Processing logic (plain English only - no ESQL)

| Ask | Framing | Default |
|---|---|---|
| Field mapping | "Which input fields become which output fields?" (offer a 2-col table) | 1:1 passthrough with matching names |
| Enrichment | "Any added values - constants, timestamps, generated ids, lookups?" | None |
| Calculations | "Any totals, rounding, derived numbers?" | None |
| Routing / branching | "Do some messages take a different path? On what condition?" | Single path |
| Filtering | "Any messages to drop or skip?" | Process all |
| Implementation language | "Can this be ESQL, or do you need **Java**? (Default ESQL. Java is rare - only if you already have a Java library to reuse, or need special MQ parsing.)" | ESQL |

For a junior who can't articulate the mapping: offer to assume a 1:1 passthrough with field renames,
show it, and let them correct. Record the result as a plain-English per-compute description.

**Default to ESQL** and don't dwell on the language question - most flows are ESQL. Only ask further
if the user names a concrete Java trigger (an existing Java library, parsing MQ PCF / MQ-constants
event messages, or genuinely heavy logic), or if an earlier answer already hinted at one. **If Java
is confirmed:** capture the intended **class name** (e.g. `shared.HandleEvent_JavaCompute`) and pair
it with the **output contract** from D3 - still no code, just the class, the shape it produces, and a
one-line note on what it does. If unsure, mark `[CONFIGURE: compute language]` and let flow_builder
help decide during the build.

---

## D5 - Error handling

| Ask | Framing | Default |
|---|---|---|
| Failure modes | "What could go wrong - downstream down, bad input, timeout, auth?" | Downstream unreachable + malformed input |
| Action per failure | (offer the menu below) | Catch → HandleException + log; poison → backout/DLQ where one exists |
| Retry | "Retry transient failures? How many times, how far apart?" | Retry only a named transient dependency; else no retry |
| Retry params | (if retry) "Attempts and interval?" | 3 attempts, fixed 30s, then DLQ |
| HTTP retry classification | **(ask ONLY if the flow calls an HTTP API)** "When the API call fails, should the flow retry on timeouts and connection problems, or stop right away?" | Timeouts / connection loss / HTTP 408, 429, 5xx → retry; other 4xx → stop |
| Timer / delayed-retry | **(ask ONLY if retry is delayed, or the flow is timer-driven)** "How long between tries, how many tries, and one retry at a time or several at once?" | Single-flight; interval + count as stated. Identifier *value* is flow_builder's job - strategy only. |

The HTTP and timer rows are **conditional** - skip them entirely for a flow with no outbound HTTP
call and no timer, and write "n/a" in those spec sections. Behind the friendly HTTP question:
flow_builder sees two failure kinds on separate terminals - a *connection failure* (no response at
all) and an *HTTP error response* (a 4xx/5xx came back) - and needs the split so it wires and handles
both. You don't need to explain that to a junior; the default classification is the standard
transient-vs-fatal split.

**Action menu** (read to the user):
- **Retry** - immediate, or delayed/backoff via a timer pair (good for transient downstream outages).
- **Dead-letter / backout** - send the poison message to a DLQ/backout queue.
- **Log and drop** - record it and carry on.
- **Fail fast** - stop and surface the error (HTTP 5xx / exception).

A *backout queue* = where a message goes after failing too many times, so one bad message doesn't
block the queue.

---

## D6 - Logging & observability

| Ask | Framing | Default |
|---|---|---|
| What to log | "Log everything, just errors, or key checkpoints?" | Errors + one entry/exit line |
| Where | "To the server console, a log file, syslog, or a Log node?" | Integration server console |
| Level | "How chatty - debug, info, warn, error?" | info for lifecycle, error for failures |
| Correlation id | "Is there a business id (order id, etc.) to stamp on every log line?" | MQMD MsgId / HTTP request id if no business id |

If the user says "log everything", warn briefly about PII and payload size before accepting it.

---

## D7 - Non-functional notes

**Don't ask all of these.** Only two are always asked; the rest are conditional on the flow type.
Default every one to "standard / not specified". Keep this phase short for a junior on a simple flow.

**Always ask:**

| Ask | Framing | Default |
|---|---|---|
| Integration server name | "Which integration server will this run on? (a name like `TestServer` / `PROD_IS`)" | `[CONFIGURE: integration server]` |
| Per-environment values | "Which values differ between DEV/TEST/PROD?" | URLs, queue managers, hostnames → promoted properties (note whether promoted on the main flow or a subflow) |

**Ask only if relevant:**

| Ask | When | Framing | Default |
|---|---|---|---|
| Security & credentials | any external call (HTTP / DB / Kafka) | "TLS? Auth scheme? Which credentials are needed?" | TLS on external calls; credentials in the ACE vault |
| Idempotency | any retry in scope | "Safe to process the same message twice?" | Assume not safe → note dedup/retry caution |
| Scheduling | timer-driven flows | "Interval, calendar, what if a fire is missed?" | As stated in the trigger |
| Throughput / ordering | high-volume or order-sensitive flows | "How many messages? Must they stay in order?" | Not specified / no strict ordering |

(Timer / delayed-retry parameters are asked in **D5**, not here - they belong with error handling.)

**Credentials rule to record in the spec:** credentials go in the **ACE vault**
(`ibmint set credential`), never in the project tree or a properties file, and never via
`mqsisetdbparms` on a v13 server-managed runtime (legacy IIB path).

*A promoted property* = a setting exposed at the flow/app level so it can be overridden per
environment at deploy time without editing the flow.

---

## DR - REST API branch (replaces D3-D4 when the pattern is REST API)

When D1 identifies a **REST API** (the user wants to *expose* HTTP operations / has an OpenAPI or
Swagger file), do NOT run the normal Input/Output (D3) and Processing (D4) topics - a REST API has a
different shape and flow_builder builds it on a dedicated track. Run this branch instead, then
continue with D5-D8 as normal. This mirrors flow_builder's **two-question gate**.

| Ask | Junior-friendly framing | Default |
|---|---|---|
| Spec source | "Do you have an OpenAPI/Swagger file already, or are we starting from scratch?" | From scratch (we draft a minimal OpenAPI 3 doc from the operations) |
| Operations | "List each operation: method + path, and what each one does." (offer the table) | `[CONFIGURE: operations]` |
| Request shape | (per operation) "What does the request body look like?" | `[CONFIGURE: req shape]` |
| Response shape | (per operation) "What does a success response look like?" | `[CONFIGURE: resp shape]` |
| Business logic | (per operation) "What should each operation do?" | Stub (mark `[CONFIGURE: logic]`) |
| Handler error pattern | "Do the error handlers (Catch/Failure/Timeout) need a specific pattern / fault-JSON shape, or generate stubs?" | Stubs |

Capture the operations as a table (operation | method | path | request shape | response shape |
business logic) in the spec's *REST API* section. If the user has an existing spec file, record its
path and note flow_builder should drive generation from it.

An *operation* = one method+path the API exposes (e.g. `GET /things/{id}`). A *handler* = one of the
three shared error subflows (Catch / Failure / Timeout) flow_builder always generates for a REST API.
