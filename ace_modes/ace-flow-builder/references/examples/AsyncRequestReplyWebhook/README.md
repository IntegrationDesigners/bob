# AsyncRequestReplyWebhook - HTTP intake, MQ hand-off, webhook callback

A complete, deployed-and-tested two-flow application (ACE 13.0.8.1, 2026-10-12): the
reference for "accept a request over HTTP, answer 202 at once, process it from a queue,
call the caller back on a webhook". Unlike the single-flow IBM examples next to it, this
one carries the whole application: both flows, their ESQL, the application descriptor
with its shared-library reference, and the MQEndpoint policy project.

Business case: a product price quote. `POST /quotes` with `{sku, quantity, customerId,
requestId, callbackUrl}` -> 202 `{quoteId, state: queued}`; a worker looks up the unit
price (`GET <PricingServiceUrl>/prices/<sku>`), applies a volume discount and POSTs the
quote to `callbackUrl`.

**Naming here is the example's own, not a house style** (`QuoteIntake` / `QuoteWorker`,
schema `com.example.shop`, queues `SHOP.QUOTE.REQUEST` / `SHOP.QUOTE.FAILED`, path
`/quotes`, policy `{ShopPolicies}:LocalQM`, module names `_Start`, `_Check`, `_Fail`).
Take the SHAPES from this example; take every name, queue, path, log status and error
body from the customer profile and the start prompt.

| File | What it shows |
|---|---|
| `QuoteService/com/example/shop/QuoteIntake.msgflow` | WSInput -> Compute -> LogEntry subflow -> Compute (two out terminals) -> MQOutput -> Compute -> WSReply; 400 and 500 paths through their own WSReply |
| `QuoteService/com/example/shop/QuoteWorker.msgflow` | MQInput -> LogEntry -> Compute -> WSRequest GET (out/error/failure all continue) -> Compute -> WSRequest POST -> LogEntry; failure path parks the original request on a queue; a flow-level user-defined property (`PricingServiceUrl`, ESQL `EXTERNAL`) |
| `QuoteIntake.esql`, `QuoteWorker.esql`, `QuoteRules.esql` | one module per node; schema-level functions shared by both flows |
| `QuoteService/application.descriptor` | `sharedLibraryReference` for LoggingLibrary - without it every LogEntry node fails at deploy with BIP1360E "requires subflow ... which is not deployed" |
| `ShopPolicies/` | Toolkit-shape MQEndpoint policy and `policy.descriptor` |

## The shapes that matter (each one broke a generated build)

- **HTTP reply status** goes in `OutputLocalEnvironment.Destination.HTTP.ReplyStatusCode`
  from a Compute with `computeMode="destinationAndMessage"` that first copies
  `InputLocalEnvironment` (it carries the reply identifier). A status set in
  `HTTPResponseHeader` is ignored by WSReply - every reply comes back 200.
- **Per-call URLs** for WSRequest likewise: `OutputLocalEnvironment.Destination.HTTP.RequestURL`
  in a destination-mode Compute. Before the second call, `SET
  OutputLocalEnvironment.Destination.HTTP = NULL` so nothing from the first call carries over.
- **The HTTP calls replace the message body.** Anything needed after them (the request,
  the correlation id) is saved in `Environment` first and rebuilt from there - including
  the payload parked on the failure queue.
- **A fresh output tree** before each outbound call and reply: Properties, then the body.
  Copying `InputRoot` drags the previous transport's headers (HTTPResponseHeader,
  HTTPInputHeader) into the next one.
- **JSON arrays**: `CREATE LASTCHILD OF ref IDENTITY(JSON.Array)name;` then one `Item` child
  per element.
- **ESQL has no regular expressions** (no MATCHES, no REGEXP): validate positionally
  (`POSITION`, `SUBSTRING`, `TRANSLATE(v, 'ABC...', '')`) as `QuoteRules.esql` does. A
  `MATCHES` line made a whole ESQL file fail to load (BIP2401E) and the flow not start.
- **No timer pair for callback retries** unless every value the retry needs survives the
  timer: a TimeoutNotification fire starts a new Environment. Parking the failed request
  on a queue (with the reason in `MQRFH2.usr`) is the robust default.
- **LoggingLibrary.LogEntry** is an inline subflow node (shape in `msgflow_format.md`,
  "Subflow nodes from a shared library"); `Uuid="$Environment.Variables.ActivityId"`
  once the correlation id is set, `$InputRoot.MQRFH2.usr.ActivityId` before that.

## Verified behaviour

12 x ABC-1234 -> 202, webhook receives `unitPriceCents 1999, discountPercent 10,
totalCents 21590, lines [gross 23988, discount 10%], state priced`; invalid SKU -> 400;
unknown SKU (pricing answers 404) -> quote delivered with `state unpriced`; webhook
unreachable -> original request on `SHOP.QUOTE.FAILED` with `MQRFH2.usr.FailReason`;
non-JSON body -> 500 with a reference id. Deployed with `ibmint deploy`, the policy
project folder in `run/` and `remoteDefaultQueueManager: '{ShopPolicies}:LocalQM'` at the
top level of the server's `overrides/server.conf.yaml`.
