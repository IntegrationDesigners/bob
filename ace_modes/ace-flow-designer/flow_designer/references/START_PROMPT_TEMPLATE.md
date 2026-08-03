# `<FlowName>` - flow-builder start prompt

> Output template for ace-flow-designer. Fill every section from the interview. Replace each
> `<…>` placeholder. Anything still unknown stays as an explicit `[CONFIGURE: …]` line - never
> silently omitted. Delete this quote block in the produced file.

A one- or two-sentence statement of what to build, suitable as the opening line of a message to
ace-flow-builder. Example: *"Build an ACE v13 application that reads order events off MQ queue
`ORDER.EVENTS`, transforms each to JSON, and POSTs it to the orders API."*

## Goal
<The single-sentence business outcome from D0.>

## Use case
- **Trigger:** <what kicks it off>
- **Definition of done:** <what a successful run looks like>
- **Source system → target system:** <from> → <to>

## Pattern
<Named IBM ACE pattern from D1, plain-language.> <If novel: "No catalog match - flow_builder should
run in Thorough mode.">

## Scope
- **In scope:** <what this flow does>
- **Out of scope:** <non-goals captured in D2>
- **Build mode hint for flow_builder:** <Iterative if a catalog pattern matched; Thorough if novel/multi-flow>

## Shape
<Single flow, or several. For several, a table:>

| Flow file | Input | Output |
|---|---|---|
| `<path>/<Flow>.msgflow` | `<input locator>` | `<output locator>` |

<If a shared subflow: describe its terminals and the happy/error split, mirroring the worked example.>

## REST API (only when the pattern is REST API - otherwise delete this whole section)
flow_builder builds REST APIs on a **separate track** (OpenAPI spec + `restapi.descriptor` +
builder-generated `gen/<Api>.msgflow` + one subflow per operation + Catch/Failure/Timeout handlers).
This section answers its two-question gate up front. When this section is present, the per-operation
detail below replaces the single Input/Output blocks in *Interfaces*.

- **Spec source:** <existing OpenAPI/Swagger file at `<path>` - OR - from scratch (draft a minimal
  OpenAPI 3 doc from the operations below)>
- **Handler error pattern:** <a shared error pattern / fault-JSON convention to implement in the
  Catch/Failure/Timeout handlers - OR - "stubs" (default)>

**Operations:**

| Operation | Method | Path | Request shape | Response shape | Business logic |
|---|---|---|---|---|---|
| `<getThing>` | GET | `/things/{id}` | `[CONFIGURE: req]` | `{ ... }` | <plain English, or stub> |
| `<createThing>` | POST | `/things` | `{ ... }` | `{ ... }` | <…> |

## Interfaces

### Input - `<name>`
- **Transport + locator:** <MQ queue / HTTP path / directory+pattern / topic / timer>
- **Format:** <JSON | XML | CSV | DFDL fixed/delimited | text | BLOB>
- **Structure / example:** <short description or example payload, or `[CONFIGURE: sample payload]`>

### Output - `<name>`
- **Transport + locator:** <destination>
- **Format:** <format>
- **Success shape:** <HTTP status + body, or message structure>
- **Output contract / target shape:** <the structure to produce - a sample payload or a field list.
  Design-level data shape, NOT code. Use a fenced block for a sample, or `[CONFIGURE: target shape]`.>
- **Filename (File output only):** <static name, or dynamic - describe how it's derived per message.
  Default: static.>

<Repeat the blocks if there is more than one input or output endpoint.>

**Routing source (if any) - MUST be decided, not guessed:** <which single place on the message tree
the routing/filter value is read from - MQRFH2 folder / HTTP header / Environment.Variables /
LocalEnvironment. flow_builder blocks on this when the value exists in more than one place.>

## Processing logic
<Per compute step, in plain English. Field mapping as a table where it helps:>

| Input field | → | Output field | Note |
|---|---|---|---|
| `<in>` | → | `<out>` | <rename / calc / constant> |

- **Enrichment:** <lookups, constants, timestamps, generated ids - or "none">
- **Calculations:** <totals/rounding/derived - or "none">
- **Routing / branching:** <conditions and paths - or "single path">
- **Filtering:** <messages dropped/skipped - or "process all">
- **Implementation language:** <ESQL (default), or Java - name the step(s). If Java: give the
  intended class (e.g. `shared.HandleEvent_JavaCompute`) and the output contract above. Reason for
  Java if not obvious (existing Java libs, PCF / MQ-constants parsing, heavy logic).>

## Error handling
| Failure | Action |
|---|---|
| <downstream unreachable> | <retry / DLQ / log+drop / fail fast> |
| <malformed input> | <…> |
| <timeout / auth / mapping error> | <…> |

- **Retry policy:** <attempts + interval, or "none">
- **Backout / DLQ:** <queue name or `[CONFIGURE: DLQ name]`, or "n/a">
- **Catch path:** <wire OutTerminal.catch to a HandleException that logs - default unless stated>
- **Outbound HTTP retry classification (HTTPRequest only):** <how to split error vs failure -
  default: connection failure → retry; HTTP 408/429/5xx → retry; other 4xx → fatal. Both the `error`
  and `failure` terminals must be handled when retry is in scope.>

## Timer / delayed retry (timer flows only)
- **Interval:** <fixed delay or backoff schedule>
- **Count:** <number of fires, or "until success">
- **Retry identity:** <single-flight (one retry at a time) or per-message (concurrent retries).
  The identifier *value* is flow_builder's job; state the strategy only.>

## Logging & observability
- **What to log:** <errors only / +entry-exit / key ids / full payload>
- **Where:** <IS console / log file / syslog / Log node>
- **Level:** <info lifecycle, error failures - or as stated>
- **Correlation id:** <business id, or MQMD MsgId / HTTP request id>

## Non-functional notes
- **Throughput / volume:** <… or "not specified">
- **Ordering:** <required? / no strict ordering>
- **Idempotency:** <safe to reprocess? dedup needed?>
- **Security:** <TLS, auth scheme>
- **Scheduling:** <interval / calendar / missed-fire - timer flows only>

## Promoted properties / config
<Values that differ per environment and should be promoted / BAR-overridable:>
- `<property>` - <what it controls> - <DEV/TEST/PROD differs> - <promoted on: main flow | subflow>
- **Credentials:** held in the ACE vault (`ibmint set credential`), never in the project tree -
  list which credentials are needed: <…>

## Deployability requirements
- **Application project natures:** `applicationNature` + `messageBrokerProjectNature` (+ `barnature`
  where a BAR is built in-project).
- **Java / shared-library dependencies:** <sibling Java project, shared libs, PolicyProject - or "none">
- **`ibmint package` must succeed** against the application project with dependencies resolvable on
  the workspace.

## flow_builder Phase B1 answers (so the build can start without re-asking)
- **Flow name:** `<FlowName>`
- **Project location:** `<path - never D:\tmp>`
- **Flow type:** <HTTP Request-Reply | MQ Input-Output | File Input | Scheduled | REST API | Other>
- **Input:** <one line - source + format>
- **Output:** <one line - destination + format>
- **Processing logic:** <one line summary; full detail in the Processing section above>
- **Integration server name:** `<server>` or `[CONFIGURE: integration server]`

## Open questions for the build
- [ ] <`[CONFIGURE: …]` item 1>
- [ ] <`[CONFIGURE: …]` item 2>
