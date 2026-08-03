# `ProductCatalogApi` - flow-builder start prompt

> Worked example output for ace-flow-designer's REST API branch (Phase DR). Illustrative; values are
> invented, not from any real client. Shows the shape a finished REST start prompt takes.

Build an ACE v13 REST API that exposes two operations over HTTP - look up a product by id and create a
product - backed by a product datastore, with standard fault-JSON error handling.

## Goal
Expose a small product-catalog REST API on ACE so internal apps can read and create products over HTTP.

## Use case
- **Trigger:** an HTTP call to one of the API operations.
- **Definition of done:** the operation returned the correct JSON response (2xx) or a structured fault.
- **Source system → target system:** internal client apps (HTTP) → product datastore.

## Pattern
**REST API** - exposes HTTP operations. flow_builder builds this on its dedicated REST track.

## Scope
- **In scope:** two operations (get-by-id, create); request validation; structured error responses.
- **Out of scope:** auth (handled by the gateway in front); pagination; bulk import.
- **Build mode hint for flow_builder:** Thorough (REST track, multi-operation).

## REST API
flow_builder builds REST APIs on a separate track (OpenAPI spec + `restapi.descriptor` +
builder-generated `gen/ProductCatalogApi.msgflow` + one subflow per operation +
Catch/Failure/Timeout handler subflows + a REST-natured project).

- **Spec source:** from scratch - draft a minimal OpenAPI 3 doc from the operations below, write
  `rest-api.yaml`, confirm, then generate.
- **Handler error pattern:** standard fault JSON `{ "error": { "code": <int>, "message": <string> } }`
  in all three handlers (Catch / Failure / Timeout).

**Operations:**

| Operation | Method | Path | Request shape | Response shape | Business logic |
|---|---|---|---|---|---|
| `getProduct` | GET | `/products/{id}` | (none - path param `id`) | `{ "id": "...", "name": "...", "price": 0.0 }` | look up product by `id`; 404 fault if not found |
| `createProduct` | POST | `/products` | `{ "name": "...", "price": 0.0 }` | `{ "id": "...", "name": "...", "price": 0.0 }` | validate body; persist; return created product with generated `id` |

## Processing logic
Per operation, in plain English (see the table above). Both operations:
- **Enrichment:** `createProduct` generates the `id`.
- **Calculations:** none.
- **Routing / branching:** none beyond operation dispatch (flow_builder's RouteToLabel handles that).
- **Filtering:** none.
- **Implementation language:** ESQL.

## Error handling
| Failure | Action |
|---|---|
| Product not found (`getProduct`) | Return 404 with fault JSON |
| Invalid request body (`createProduct`) | Return 400 with fault JSON |
| Datastore unreachable | Return 503 with fault JSON (Failure handler) |
| Unhandled exception | Catch handler → 500 with fault JSON |

- **Retry policy:** none (synchronous API; client retries).
- **Backout / DLQ:** n/a (HTTP, not queue-based).
- **Catch path:** the three REST handler subflows (Catch / Failure / Timeout) per the pattern above.
- **Outbound HTTP retry classification:** n/a (no outbound HTTP call in scope).

## Logging & observability
- **What to log:** errors + one entry/exit line per request.
- **Where:** integration server console.
- **Level:** info for lifecycle, error for failures.
- **Correlation id:** HTTP request id.

## Non-functional notes
- **Throughput / volume:** not specified.
- **Ordering:** n/a (stateless requests).
- **Idempotency:** `getProduct` idempotent; `createProduct` not (generates a new id each call).
- **Security:** TLS terminated at the gateway; no auth inside the flow.
- **Scheduling:** n/a.

## Promoted properties / config
- `datastoreUrl` - product datastore base URL - differs DEV/TEST/PROD - promoted on: main flow.
- **Credentials:** datastore credential held in the ACE vault (`ibmint set credential`), never in the
  project tree.

## Deployability requirements
- **Application project natures:** REST API natures (`com.ibm.etools.mft.restapi.ui.Nature` +
  `applicationNature` + `messageBrokerProjectNature`) - flow_builder's REST `.project` variant.
- **Java / shared-library dependencies:** none.
- **`ibmint package` must succeed** against the REST API project.

## flow_builder Phase B1 answers
- **Flow name:** `ProductCatalogApi`
- **Project location:** `[CONFIGURE: ACE workspace path]`
- **Flow type:** REST API
- **Input:** HTTP - two operations (see REST API section)
- **Output:** JSON responses per operation
- **Processing logic:** get-by-id + create, ESQL - see REST API section
- **Integration server name:** `[CONFIGURE: integration server]`

## Open questions for the build
- [ ] `[CONFIGURE: ACE workspace path]`
- [ ] `[CONFIGURE: integration server]`
- [ ] `[CONFIGURE: datastore persistence mechanism]` (DB table? downstream service? in-memory stub?)
