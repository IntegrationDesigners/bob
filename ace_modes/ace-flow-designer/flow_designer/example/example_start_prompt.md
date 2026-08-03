# `OrderEventForwarder` - flow-builder start prompt

> Worked example output for ace-flow-designer (illustrative; values are invented, not from any real
> client). It shows the shape a finished start prompt takes after a full interview.

Build an ACE v13 application that reads order-event messages off MQ queue `ORDER.EVENTS`, transforms
each event to JSON, and POSTs it to an internal orders API - retrying transient failures and
dead-lettering poison messages.

## Goal
Forward every order event from MQ to the orders REST API as JSON, reliably and in near real time.

## Use case
- **Trigger:** a message arriving on `ORDER.EVENTS`.
- **Definition of done:** the event was accepted by the orders API (HTTP 2xx) and removed from the queue.
- **Source system → target system:** upstream order system (MQ) → orders API (HTTP).

## Pattern
**IBM MQ to HTTP** - protocol-transformation pattern (read off a queue, transform, call an HTTP endpoint).

## Scope
- **In scope:** read, transform XML→JSON, POST, handle retry and dead-letter.
- **Out of scope:** no response is sent back to MQ; no enrichment from other systems.
- **Build mode hint for flow_builder:** Iterative (catalog pattern matched).

## Shape
Single flow, one application project.

`MQInput (ORDER.EVENTS) → Compute (transform) → HTTPRequest (POST orders API)`, with the input node's
`catch`/`failure` terminals routed to a `HandleException` compute and a backout queue.

## Interfaces

### Input - order event
- **Transport + locator:** MQ queue `ORDER.EVENTS`.
- **Format:** XML.
- **Structure / example:** `<OrderEvent><OrderId/><Customer><First/><Last/></Customer><Total/></OrderEvent>`

### Output - orders API
- **Transport + locator:** HTTP POST `https://[CONFIGURE: orders API host]/orders`.
- **Format:** JSON.
- **Success shape:** HTTP 202 acknowledging acceptance.

**Routing source:** n/a (single path).

## Processing logic
| Input field | → | Output field | Note |
|---|---|---|---|
| `OrderEvent/OrderId` | → | `orderId` | rename |
| `Customer/First` + `Customer/Last` | → | `customerName` | concatenate with a space |
| `OrderEvent/Total` | → | `totalPrice` | round to 2 dp |

- **Enrichment:** add `processedAt` timestamp.
- **Calculations:** round `totalPrice` to 2 decimals.
- **Routing / branching:** single path.
- **Filtering:** process all.

## Error handling
| Failure | Action |
|---|---|
| Orders API unreachable (connection failure) | Retry - transient |
| Orders API returns 5xx / 408 / 429 | Retry - transient |
| Orders API returns other 4xx | Fail → backout queue |
| Malformed input XML | Log + route to backout queue |

- **Retry policy:** 3 attempts, fixed 30s, then backout.
- **Backout / DLQ:** `ORDER.EVENTS.BACKOUT`.
- **Catch path:** `OutTerminal.catch` → `HandleException` (logs the exception detail).

## Logging & observability
- **What to log:** errors + one entry/exit line per message.
- **Where:** integration server console.
- **Level:** info for lifecycle, error for failures.
- **Correlation id:** `OrderId` (falls back to MQMD MsgId if absent).

## Non-functional notes
- **Throughput / volume:** ~5 msg/s peak; not specified precisely.
- **Ordering:** no strict ordering required.
- **Idempotency:** orders API is idempotent on `orderId` - safe to retry.
- **Security:** TLS to the orders API; bearer token.
- **Scheduling:** n/a (event-driven).

## Promoted properties / config
- `ordersApiUrl` - the orders API base URL - differs DEV/TEST/PROD.
- `retryCount` / `retryIntervalSeconds` - retry tuning - may differ per environment.
- **Credentials:** orders-API bearer token held in the ACE vault (`ibmint set credential`), never in
  the project tree.

## Deployability requirements
- **Application project natures:** `applicationNature` + `messageBrokerProjectNature`.
- **Java / shared-library dependencies:** none.
- **`ibmint package` must succeed** against the application project.

## flow_builder Phase B1 answers
- **Flow name:** `OrderEventForwarder`
- **Project location:** `[CONFIGURE: ACE workspace path]`
- **Flow type:** MQ Input-Output (with outbound HTTP)
- **Input:** MQ queue `ORDER.EVENTS`, XML
- **Output:** HTTP POST orders API, JSON
- **Processing logic:** map 3 fields, add timestamp, round total - see Processing section
- **Integration server name:** `[CONFIGURE: integration server]`

## Open questions for the build
- [ ] `[CONFIGURE: orders API host]`
- [ ] `[CONFIGURE: ACE workspace path]`
- [ ] `[CONFIGURE: integration server]`
