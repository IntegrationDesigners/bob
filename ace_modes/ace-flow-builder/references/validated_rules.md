---
template_version: 0.4.0
last_updated: 2026-09-11
compatible_with: ACE Flow Builder v0.2.0+ / ACE Flow Refactor v1.0.0+
status: stable
---

# ACE Flow-Building Rules (User-Validated)

Corrections captured from real flow-building and refactor sessions, validated against
real ACE v13 installs. They override any conflicting guidance elsewhere in the
references. This file is the RULES layer: statement, idiom, scope and tags. The evidence
behind each rule (why it is a rule, the run or expert review it came from, the stamp
naming the install and the mechanism that proved it) lives in
`validated_rules_evidence.md` under the same number. The generation subagent never reads
that file.

**How to read this file (generation subagent):** read the index, then every rule tagged
`all` plus every group whose node family the brief names. Skip the rest. When unsure
whether a family is in scope, read it. Scope tokens: `v13` holds on any 13.0.x install;
`13.0.N+` names a mod-pack feature that is absent below that fix pack (take the older
path and record it in `flow_state.md`); another major version than the install means
verify against the install first (B0.5a puts the installed version in the brief).

## Index

| Tag | Applies when the flow has | Rules |
|---|---|---|
| `all` | every flow | 9, 13, 14, 15, 16, 17, 21, 24 |
| `mq` | any MQInput / MQOutput / MQReply / MQGet | 2, 3, 4, 6, 22, 23, 26 |
| `http` | HTTPInput / HTTPReply / HTTPRequest | 8, 10, 11 |
| `rest` | REST Request / REST API | 12 |
| `kafka` | KafkaProducer / KafkaConsumer | 25 |
| `db` | Database nodes or ESQL database statements | 20 |
| `timer` | TimeoutControl + TimeoutNotification pair | 7 |
| `validate` | Validate node / ResetContentDescriptor | 18 |
| `deploy` | server configuration, policies, credentials | 19, 22 |
| procedure | moved out of this file | 1 (`workflow.md` Phase B2), 5 (`generation.md` 3.2) |

**Adding a rule:** append the next number here (statement, idiom, scope line, tags) AND
its evidence under the same number in `validated_rules_evidence.md`; add a B3.7 item in
`generation.md` when the rule is checkable.

---

## 1. Route/Filter on upstream state - ask first

> Scope: v13 (asserted, not measured) | Tags: procedure | Evidence: `validated_rules_evidence.md` section 1

Moved to procedure. The design question (a Route or Filter decision value that exists in more than one place on the tree - ask, never pick silently) is asked in `workflow.md` Phase B2; `ace-flow-refactor` raises it with the user instead of fixing it. Kept here so references to rule 1 resolve.

---

## 2. Create MQRFH2 explicitly, in the correct tree position

> Scope: v13 | Tags: mq | Evidence: `validated_rules_evidence.md` section 2


Do **not** rely on `SET OutputRoot.MQRFH2.X = ...` to auto-create the
parser. Check `LASTMOVE` explicitly; when missing, create the header as
the **next sibling of MQMD** and update `MQMD.Format` so the MQ layer
knows an RFH2 follows:

```esql
DECLARE rfh2Ref REFERENCE TO OutputRoot.MQRFH2;
IF NOT LASTMOVE(rfh2Ref) THEN
    SET OutputRoot.MQMD.Format = MQFMT_RF_HEADER_2;
    CREATE NEXTSIBLING OF OutputRoot.MQMD DOMAIN 'MQRFH2';
    SET OutputRoot.MQRFH2.(MQRFH2.Field)Version        = 2;
    SET OutputRoot.MQRFH2.(MQRFH2.Field)Format         = 'MQSTR';
    SET OutputRoot.MQRFH2.(MQRFH2.Field)NameValueCCSID = 1208;
END IF;
SET OutputRoot.MQRFH2.usr.Action = Environment.Variables.Action;
```

Why: implicit creation via a folder-value SET can place the parser in the
wrong tree position, or leave `MQMD.Format` pointing at the body instead
of the RFH2 - producing an unreadable message on the downstream queue.

**A tree that did not come from MQ has no MQMD** (HTTP, File, Timer input). There the
snippet above fails quietly: `SET OutputRoot.MQMD.Format` creates a plain element, not
the header, the MQOutput node builds its own MQMD with the inbound format (`WSRoot` from
HTTP), and the consumer hands the RFH2 bytes to its body parser (BIP5719E / BIP5705E on
every message). Create the MQMD first, then the RFH2 after it:

```esql
IF NOT EXISTS(OutputRoot.MQMD[]) THEN
    CREATE NEXTSIBLING OF OutputRoot.Properties DOMAIN 'MQMD';
END IF;
```

Measured 2026-10-12, 13.0.8.1: an HTTP-to-MQ intake with an RFH2 parked every job until
this was added, then passed 9 of 9 front-door scenarios. If the consumer does not need an
RFH2, leave it out instead - the simplest message is a plain JSON body.

---

## 3. MQRFH2 header fields use the `(MQRFH2.Field)` typed prefix

> Scope: v13 | Tags: mq | Evidence: `validated_rules_evidence.md` section 3


The fixed-header fields are:
`Version`, `Format`, `NameValueCCSID`, `StrucLength`, `Encoding`,
`CodedCharSetId`, `Flags`.

Writing them without the typed prefix can place them into the wrong
parser slot.

```esql
-- correct
SET OutputRoot.MQRFH2.(MQRFH2.Field)Format = 'MQSTR';

-- wrong
SET OutputRoot.MQRFH2.Format = 'MQSTR';
```

Folder values (`MQRFH2.usr.<name>`, `MQRFH2.psc.<name>`, etc.) stay plain
`SET` - the typed prefix is only for fixed-header fields.

---

## 4. MQ format values use `MQFMT_*` constants, never string literals

> Scope: v13 | Tags: mq | Evidence: `validated_rules_evidence.md` section 4


ACE exposes every MQ header format as a built-in variable. Use those
instead of whitespace-sensitive 8-character literals.

| Use | Instead of |
|---|---|
| `MQFMT_RF_HEADER_2` | `'MQHRF2  '` |
| `MQFMT_STRING` | `'MQSTR   '` |
| `MQFMT_NONE` | `'        '` |
| `MQFMT_ADMIN` | `'MQADMIN '` |
| `MQFMT_DEAD_LETTER_HEADER` | `'MQDEAD  '` |

Why: the 8-char literals are easy to miscount (trailing spaces) and the
compiler will not catch the typo.

---

## 5. Review and improve draft ESQL before adopting it

> Scope: v13 (asserted, not measured) | Tags: procedure | Evidence: `validated_rules_evidence.md` section 5

Moved to procedure. The draft-ESQL checklist (schema declared, fields exist on the claimed domain, compute mode matches the writes, correlation names, whole-message copy, MQRFH2 prefixes, MQFMT constants) is in `generation.md` 3.2 and applies to refactor ports the same way. Kept here so references to rule 5 resolve.

---

## 6. Destination-list MQ Output nodes need explicit `DestinationData`

> Scope: v13 (asserted, not measured) | Tags: mq | Evidence: `validated_rules_evidence.md` section 6


When a `ComIbmMQOutput` node has `destinationMode="list"`, the inline
`queueName` attribute is **design-time display only**. The upstream
compute node must populate the destination list or the output will fail
at runtime.

```esql
SET OutputLocalEnvironment.Destination.MQ.DestinationData[1].queueName =
    'ADPT.TARGET.QUEUE';
```

For multiple destinations, populate additional `DestinationData[N]`
entries. The MQ Output node will put the message to every queue in the
list.

Check during refactor: an MQ Output node with `destinationMode="list"`
and no upstream `DestinationData` write is a bug - either switch the
node to `destinationMode="queueName"` or add the missing ESQL.

---

## 7. Timeout-pair identifier rule

> Scope: v13 | Tags: timer | Evidence: `validated_rules_evidence.md` section 7


When pairing `ComIbmTimeoutControl` with `ComIbmTimeoutNotification` for
delayed retry / scheduled redelivery / circuit-breaker patterns:

1. **Both nodes must declare the same literal `uniqueIdentifier`** -
   1-12 characters, alphanumeric or hex. Wildcard `*` on the
   Notification node is allowed but should not be the default; ask the
   user whether they want a fixed identifier (single-flight retry) or
   a per-message identifier with `*` wildcard (concurrent retries).
2. With a shared static identifier, the upstream Compute MUST set
   `OutputLocalEnvironment.TimeoutRequest.AllowOverwrite = TRUE` -
   otherwise re-scheduling fails when a previous SET is still pending.
3. The upstream Compute populates `OutputLocalEnvironment.TimeoutRequest.*`
   with `Action`, `Identifier` (matching the node `uniqueIdentifier`),
   `StartDate`, `StartTime`, `Count`, `IgnoreMissed`, `AllowOverwrite`.
   Action values: `'SET'` (schedule) or `'CANCEL'` (cancel pending).
   See `workflow.md` ESQL patterns "Timeout request schema".

Why: identifier mismatch causes the Notification never to fire;
missing `AllowOverwrite` causes the second retry attempt to silently
fail to schedule.

---

## 8. HTTPRequest terminal semantics - `out` vs `error` vs `failure`

> Scope: v13 | Tags: http | Evidence: `validated_rules_evidence.md` section 8


`ComIbmWSRequest` has three output terminals with distinct meanings.
**Never wire response classification on `out` alone** - HTTP error
responses (4xx/5xx) never reach `out`.

| Terminal | When | Body available? |
|---|---|---|
| `OutTerminal.out` | 2xx success | Full response message |
| `OutTerminal.error` | HTTP error response (4xx/5xx) returned by the server | Response body present; status code in `HTTPResponseHeader.X-Original-HTTP-Status-Code` and `LocalEnvironment.Destination.HTTP.ReplyStatusCode` |
| `OutTerminal.failure` | Connection-level failure (refused, DNS, timeout) | No response - exception details in `InputExceptionList` |

**Default wiring for retry-on-failure patterns:**
- `out` → success path (no classifier needed; already 2xx)
- `error` → classify-by-status (decide retry vs fatal)
- `failure` → retry directly (always retry connection-level errors)

The same three-way distinction applies to other request-style nodes
that distinguish protocol-level errors from system-level failures
(e.g. some database nodes). Apply this rule whenever `error` and
`failure` are both present.

---

## 9. Unify error/failure classification

> Scope: v13 | Tags: all | Evidence: `validated_rules_evidence.md` section 9


When a node has separate `error` (protocol-level) and `failure`
(system-level) output terminals **and** you want to apply the same
routing logic to both (e.g. retry vs fatal), wire **both** terminals
into one Compute and dispatch inside ESQL:

```esql
IF CARDINALITY(InputExceptionList.*[]) > 0 THEN
    -- arrived via 'failure' terminal - connection-level error
    -- always retryable; pull reason from InputExceptionList
    DECLARE reason CHARACTER 'Connection failure';
    -- ...
ELSEIF InputRoot.HTTPResponseHeader."X-Original-HTTP-Status-Code" IS NOT NULL
   OR InputLocalEnvironment.Destination.HTTP.ReplyStatusCode IS NOT NULL THEN
    -- arrived via 'error' terminal - HTTP error response
    -- classify by status code: 408/429/5xx → retry, else → fatal
    -- ...
ELSE
    -- defensive: treat as fatal
END IF;
```

The discriminator is `InputExceptionList`: the `failure` terminal
populates it with the connection-level exception, while the `error`
terminal does not (the message body is the HTTP error response and
the status code lives in the standard response-header fields).

Why: keeps routing rules in one place; ensures shared variables
(retry attempt counter, reason string, dead-letter annotations) are
always populated regardless of which path was taken; eliminates the
two-parallel-paths maintenance trap.

If the two terminals genuinely need different downstream logic
(e.g. failure → DLQ, error → user-facing reply), wire them separately.
This rule applies only when the *same* logic should run on both.

---

## 10. v13 HTTP input/reply node type is `ComIbmWSInput` / `ComIbmWSReply`

> Scope: v13 | Tags: http | Evidence: `validated_rules_evidence.md` section 10


For HTTP request-reply flows in ACE v13, use:

```xml
<nodes xmi:type="ComIbmWSInput.msgnode:FCMComposite_1" .../>
<nodes xmi:type="ComIbmWSReply.msgnode:FCMComposite_1" .../>
```

Do **NOT** use `ComIbmHTTPInput` / `ComIbmHTTPReply` - those reference a
LIL that is not shipped in v13, and the Integration Server fails to
load the flow with:

```
BIP2241E: A Loadable Implementation Library (.lil, .jar, or .par) is
not found for message flow node type 'ComIbmHTTPInputNode'.
```

The translation label on the node can still say "HTTP Input" - what
matters at runtime is the `xmi:type`.

Why this trips people up: older IIB documentation, AI-generated
snippets, and external migration tools occasionally reach for the
`ComIbmHTTPInput` / `ComIbmHTTPReply` names because they read more
naturally. They compile fine in the Toolkit (the namespace declarations
are valid XML), but the IS won't start the flow.

Useful attributes on `ComIbmWSInput.msgnode`:
- `URLSpecifier="/path*"` - use `/*` to catch all paths
- `useHTTPS="false"`
- `messageDomainProperty="JSON"` (or `XMLNSC`)
- `parseQueryString="true"`
- `faultFormat="JSON"`

---

## 11. `ComIbmWSInput` exposes the HTTP method and path via headers, not LocalEnvironment

> Scope: v13 | Tags: http | Evidence: `validated_rules_evidence.md` section 11


`InputLocalEnvironment.HTTP.Input.Method` and `.Path` are populated
only by the legacy `ComIbmHTTPInput` node - they are **empty** on
`ComIbmWSInput`. Reading them on a v13 WSInput-based flow returns
NULL and any subsequent string ops on it silently produce empty
results.

For `ComIbmWSInput`, read the HTTP method and path from the input
HTTP headers instead:

```esql
DECLARE cmdLine CHARACTER COALESCE(InputRoot.HTTPInputHeader."X-Original-HTTP-Command", '');
DECLARE method  CHARACTER UCASE(TRIM(SUBSTRING(cmdLine BEFORE ' ')));
DECLARE path    CHARACTER COALESCE(InputRoot.HTTPInputHeader."X-Original-HTTP-URL", '');
```

- `X-Original-HTTP-Command` is the request line: `<METHOD> <PATH> HTTP/<ver>`
  (e.g. `POST /orders HTTP/1.1`). Take the first whitespace-separated
  token for the method.
- `X-Original-HTTP-URL` is just the path portion (e.g. `/orders`).

Use these for routing logic that branches on HTTP method (`GET` vs
`POST` vs `PUT` vs `DELETE`) or on path-based dispatch.

Why: the v13 `ComIbmWSInput` populates the request line into HTTP
headers rather than into the `InputLocalEnvironment` tree. Code
written against the legacy LocalEnvironment shape will appear to
"work" - no errors, no crashes - but routing decisions silently
default to the empty-string branch, which is almost always the
wrong one.

---

## 12. REST Request node Basic auth - Security identity is pre-emptive, Security Profile is reactive

> Scope: v12+ | Tags: rest | Evidence: `validated_rules_evidence.md` section 12


For a `ComIbmRESTRequest` / `ComIbmRESTAsyncRequest` node calling a
Basic-auth endpoint, there are **two independent** credential
mechanisms with different behaviour. Validated empirically on ACE
v12.0.12 and v13.0.7 (identical on both - this is **not** a version
regression) **for the node Security identity and Security Profile
mechanisms only; the RESTRequest policy path was not in scope** and
behaves differently on 13.0.8.x (see the oauth2 note below).

| Mechanism | When `Authorization: Basic` is sent |
|---|---|
| **Node Security identity** - `securityIdentity="<id>"` attribute | **Pre-emptively** (first request) |
| **Security Profile** - `securityProfileName="{PolicyProject}:<profile>"`; `SecurityProfiles` policy with `propagation=true`, `idToPropagateToTransport=Static ID`, `transportPropagationConfig=<id>` | **Reactively** - only after the server replies `401` + `WWW-Authenticate: Basic` |

**Credential setup - lead with the vault (ACE 13 mechanism):**

```bat
ibmint set credential --work-directory <dir> --credential-type <type> --credential-name <id> --vault-key <key>
```

(singular `credential`; the per-work-directory vault must be created explicitly first with `mqsivault --work-dir <dir> --create --vault-key <key>` - full syntax and server-start `--vault-key`/`MQSI_VAULT_KEY` handling in `validation_runbook.md` §7).

**Legacy node-managed fallback (`mqsisetdbparms`)** - only when the user's estate is node-managed and already uses it. The resource-name prefix then determines which mechanism consumes the credential:

- Node Security identity: `mqsisetdbparms <node> -n rest::<id> -u <u> --password <p>` (the `rest::` prefix)
- Security Profile STATIC-ID propagation: `mqsisetdbparms <node> -n <id> -u <u> --password <p>` (plain name, **no** prefix)

1. **The node Security-identity path is IBM's documented REST-node
   mechanism.** It also requires the Swagger/OpenAPI to declare a
   security requirement of type `http` scheme `basic`/`bearer`, or
   `apiKey` (`oauth2` is **not** supported *for the node Security identity
   mechanism*, which is what this section covers). With that in place it
   sends Basic on the first request.
   **NOTE (13.0.8.x):** the RESTRequest *policy* path is a separate mechanism
   and DOES support `oauth2`, via a `rest` credential with `clientScoped` /
   `oauthScoped` / `oauthPasswordScoped`. Verified on an installed 13.0.8.1.
   Re-check against the version in front of you before quoting either.
2. **The Security-Profile path is reactive.** Against a downstream
   that returns `200` (or anything that isn't a `401` Basic
   challenge) on the first hit, it sends **no** `Authorization`
   header **and raises no error** - the classic "basic auth silently
   not sent" symptom. To make it pre-emptive:
   `mqsichangeproperties <node> -e <server> -o ComIbmSocketConnectionManager -n preemptiveAuthType -v Basic`
   then restart the server. Note `ComIbmSocketConnectionManager` is
   **server-wide** (affects all outbound HTTP/SOAP/REST from that
   server).
3. **Legacy path only: `mqsisetdbparms` credentials only activate
   after an integration *server* restart** (`mqsireload <node> -e
   <server>`) - an app redeploy is not enough. Testing too soon looks
   identical to "auth doesn't work."

When a user reports "REST node won't send basic auth, no error,
worked before": don't assume a bad policy and don't just tell them to
switch to the Security identity. Establish **whether the downstream
challenges with 401** and **whether pre-emptive auth is on** - that's
almost always the actual variable. Both mechanisms are valid; the
difference is pre-emptive vs reactive.

---

## 13. Build the output tree in the correct header order

> Scope: v13 | Tags: all | Evidence: `validated_rules_evidence.md` section 13


`OutputRoot` is serialized to the wire in **child order**, so the
children must be created in the order the receiving transport expects.
The canonical order is always:

1. **`Properties`** - first child, always.
2. **Transport / protocol headers**, in wire order. For MQ that is
   `MQMD`, then `MQMDE` (if present), then `MQRFH2` / other MQ headers.
   For HTTP that is the relevant `HTTPInputHeader` /
   `HTTPResponseHeader` / `HTTPRequestHeader`.
3. **Body parser** last - `XMLNSC`, `JSON`, `DFDL`, `BLOB`, `SOAP`, etc.

Why: the broker writes the tree top-to-bottom. If the body is created
before the headers, or `Properties` is not first, the headers land in
the wrong physical position or are silently dropped, producing an
unreadable message on the downstream queue or HTTP reply.

**ESQL** - the IBM copy helpers already emit the correct order; call them
*before* writing the body:

```esql
CALL CopyMessageHeaders();          -- Properties + all header domains, in order
-- ... set / adjust individual headers here ...
SET OutputRoot.JSON.Data.id = InputBody.Id;   -- body LAST
```

When building headers by hand, create `Properties` and the transport
headers before touching `OutputRoot.<body>`, and position `MQRFH2` as the
next sibling of `MQMD` (see rule 2). Never write the body folder first
and back-fill headers afterwards.

**Java** - the same order applies when assembling an `MbMessage`. Copy the
headers before building the body, and append with `addAsLastChild` so
source order is preserved:

```java
copyMessageHeaders(inMessage, outMessage);   // headers first, in input order
// ... build body parser tree here, added after the headers ...
```

The `copyMessageHeaders` loop in `java_compute_project.md` walks the input
children and stops before the last child (the body), so it copies every
header in order without dragging the body along. Do not `addAsFirstChild`
a header after the body has been added, and do not create the body parser
before the headers.

---

## 14. Schema-scope `DECLARE ... NAMESPACE` is global - declare it once, or make it local

> Scope: v13 | Tags: all | Evidence: `validated_rules_evidence.md` section 14


A `DECLARE <ns> NAMESPACE '...';` written at **`BROKER SCHEMA` scope** (outside any
`CREATE ... MODULE`) belongs to the whole broker schema, not to one file. If two `.esql`
files in the same schema each declare the same namespace at schema scope, deploy fails at
load with **BIP4128E**: *"Failed to deploy ESQL 'declare' called '<SCHEMA>#<ns>' ...
because it is already deployed in file '<other>.esql'."* Worse, that one duplicate
cascades - it takes the whole schema down, so you also get **BIP4127E** *"Failed to find
ESQL module …"* on unrelated modules, which sends you hunting in the wrong file.

Fix: declare each shared namespace **once** across the schema (a single common file), or
**function-local** inside each `Main()` that uses it. Prefer function-local for
self-contained modules - each file stays independently correct with no cross-file
coupling. The same collision applies to any schema-scope symbol (constants, procedures):
if it lives outside a module, one copy per schema.

---

## 15. MQ-input flows must preserve the payload on the error path

> Scope: v13 | Tags: all | Evidence: `validated_rules_evidence.md` section 15


On any MQ-input flow:

- The catch/error path **must write the original payload to an error or backout queue
  BEFORE the transaction commits.** A catch path that commits without preserving the
  message consumes it and loses it - the message is gone with no replay path.
- The `MQInput` **Failure terminal must be wired**, or its absence explicitly justified
  in the flow's README. `Failure` and `Catch` are different terminals for different
  classes of problem; leaving Failure dangling silently drops the ones Catch never sees.

**Reach of this rule (decided 2026-08-30).** The payload-preserving `HandleException`
(File 2 in the generation reference: `CopyEntireMessage()`, summary in
`MQRFH2.usr.Error` / `Environment.Variables.Error`) is the handler for EVERY generated
flow - destroying the payload in the handler is never right. What differs per input
transport is the sink and the Failure wiring:

| Input transport | Error sink | Failure terminal |
|---|---|---|
| MQ | error queue MQOutput (or backout queue) BEFORE the trace - mandatory | wired or justified - mandatory |
| HTTP request-reply | the HTTP Reply with an error body (the caller gets the answer; the payload is theirs) plus a trace | wired to the same handler |
| File, JMS, Kafka, MQTT, TCP/IP, Email, Database input | trace by default; an error queue, error directory or dead-letter topic when the brief or customer profile names one - state the choice in `flow_state.md`. **File input caveat (decision pending, raised by the 2026-08-30 template review):** FileInput's default action on success is Delete, so a handled failure that completes the branch deletes the input file while the trace carries no payload - the payload is gone. Proposed: templates set the FileInput to archive-with-timestamp and the row becomes "trace + archived input file". | wired to the same handler |

The 94 example templates follow this table; the non-MQ, non-HTTP ones carry the
preserving handler with a trace sink and a `[CONFIGURE: error sink]` marker.

---

## 16. `Environment` has no Input/Output variants - and `computeMode` gates propagation, it copies nothing

> Scope: v13 | Tags: all | Evidence: `validated_rules_evidence.md` section 16


Correlation names for the four trees in a Compute node are a closed set:

| Tree | Read | Write | Propagated onward when |
|---|---|---|---|
| Message | `InputRoot` | `OutputRoot` (there is no `OutputBody`) | mode includes Message |
| LocalEnvironment | `InputLocalEnvironment` | `OutputLocalEnvironment` | mode includes LocalEnvironment |
| ExceptionList | `InputExceptionList` | `OutputExceptionList` | mode includes Exception |
| Environment | `Environment` | `Environment` | always - one flow-wide tree |

`InputEnvironment` and `OutputEnvironment` **do not exist** - never generalise the
Input/Output prefix onto `Environment`. There is exactly one Environment tree per
message flow; every node addresses it by the same name, its changes are always
visible downstream, and the Compute mode has no effect on it (IBM: "The Environment
component of the message tree is not affected by the Compute Mode property setting").

For the mode-gated trees the converse holds: a `SET OutputLocalEnvironment...` in a
node whose mode does not include LocalEnvironment is **silently discarded** - the
input local environment propagates instead. Same for `OutputExceptionList` without
an Exception mode.

Valid `computeMode` literals in `.msgflow` XML (attribute absent = `message`, the
default): `message`, `destination`, `destinationAndMessage`, `exception`,
`exceptionAndMessage`, `exceptionAndDestination`, `all`. `destination` is the
serialized name for LocalEnvironment (its historic name). There is **no**
`localEnvironment*`, `none`, `copyMessageHeaders`, `local`, or `clone` literal - and
`computeMode` never copies trees: header/body copying is done in ESQL
(`CopyMessageHeaders()` / `SET OutputRoot = InputRoot;`, rule 17); the mode only
selects which output trees replace the input trees at propagation.

Generation rule of thumb:
- Flow-lifetime state (log/correlation values any later node may read):
  `Environment.Variables.*` - works in every mode.
- Routing/destination data (`Destination.MQ`, `Destination.HTTP`, `TimeoutRequest`,
  `ReplyStatusCode`): `OutputLocalEnvironment` + `destinationAndMessage` or `all`.

---

## 17. Whole-message copy is `SET OutputRoot = InputRoot;` - nothing else

> Scope: v13 | Tags: all | Evidence: `validated_rules_evidence.md` section 17


The complete input-to-output copy is a single assignment - exactly the body of the
Toolkit template's `CopyEntireMessage()`:

```esql
SET OutputRoot = InputRoot;
```

Do **not** emit:

```esql
CALL CopyMessageHeaders();
SET OutputRoot.* = InputRoot.*;   -- wrong: `*` addresses one child, not the tree
```

The wildcard `SET` is not a whole-tree copy (`*` resolves to a single element), and a
full-tree assignment supersedes a preceding header copy anyway - the pair is at best
redundant, at worst a partial copy that looks complete.

One idiom per compute module:
- Pass-through / annotate in place: `SET OutputRoot = InputRoot;` then modify
  individual output fields.
- New body, headers preserved: `CALL CopyMessageHeaders();` then build
  `OutputRoot.<body>` from scratch (body last - rule 13).
Never both in the same `Main()`.

**Transport-boundary clause.** A whole-message copy carries the INBOUND transport's
header folders with it, and the next transport will serialise them into the payload.
When the input and output transports differ, drop the inbound folders right after the
copy, before the output node:

```esql
SET OutputRoot = InputRoot;
SET OutputRoot.HTTPInputHeader = NULL;      -- HTTP in -> MQ/File/... out
SET OutputRoot.HTTPRequestHeader = NULL;    -- when an HTTPRequest response is copied
-- MQ in -> HTTP out: SET OutputRoot.MQMD = NULL; SET OutputRoot.MQRFH2 = NULL;
```

---

## 18. Validation placement: Validate node vs ResetContentDescriptor

> Scope: v13 | Tags: validate | Evidence: `validated_rules_evidence.md` section 18


**An RCD validates exactly what it causes to be parsed, at the node where that parse
happens.** A same-domain RCD parses nothing and therefore validates nothing - it only
stamps validation options that the next serializer inherits (Validate = `inherit`) or
discards. Measured on ACE 13.0.8.1 (four-revision harness run; parse-side failures are
BIP5025 at `ImbResetContentDescNode::evaluate`, write-side BIP5026). A validation that
never ran looks exactly like a validation that passed - this exact shape caused a
production incident.

Pick the node from the requirement:

| Requirement | Node choice |
|---|---|
| Validate against a schema/model (and route valid/invalid) | **Validate node** (`ComIbmValidate`) - it owns the valid/invalid decision; see `msgflow_format.md` "Validate node". Never a same-domain RCD. |
| Re-interpret the bitstream in a different domain (BLOB -> XMLNSC, ...) | **RCD** with `resetMessageDomain="true"`; no validation attributes unless validation was asked for. |
| Domain change AND reject bad input at that boundary | RCD with `validateMaster="contentAndValue"` AND **explicit** `validateTiming="complete"` - absent means On Demand, which validates lazily as elements are referenced and can pass a message whose untouched fields never get checked. Alternative: plain RCD followed by a Validate node. |
| Validate the OUTPUT message | Validation on the serializing/output node, or a Validate node just before it. Do not generate the same-domain-stamp-plus-`inherit`-serializer pattern - it works but is obscure. |

**Hard rule: never generate an RCD whose `messageDomain` equals the effective upstream
domain for validation purposes.** If the requirement is validation, the answer is the
Validate node; if it is re-interpretation, the domain changes by definition. The
Validate node also serialises internally, so it catches write-side classes (invalid
characters such as 0x1a) that RCD-triggered parse validation does not.

---

## 19. `node.conf.yaml` and `server.conf.yaml` are never edited - every change goes in `overrides/*.yaml`

> Scope: v13 | Tags: deploy | Evidence: `validated_rules_evidence.md` section 19


**ALL changes to `node.conf.yaml` and `server.conf.yaml` are applied ONLY in the
`overrides/*.yaml` file, never in the main one.** Locations: standalone server
`<work_dir>/overrides/server.conf.yaml`; node-managed server
`<node>/servers/<server>/overrides/server.conf.yaml`; the node itself
`<node>/overrides/node.conf.yaml`. The generated base files (`mqsicreateworkdir`,
`mqsicreatebroker`) are read-only reference material: they document every key with
its default, and operations expect to find them intact. `remoteDefaultQueueManager`,
port changes, trace settings, `policyProject` defaults - all of it goes in overrides.

---

## 20. Database access in ESQL: handle the error where it happens and capture the diagnostics

> Scope: v13 | Tags: db | Evidence: `validated_rules_evidence.md` section 20


**A Compute node that touches a database catches its own database errors with an ESQL
handler, records the SQL diagnostics, and propagates the failure with that context.**
It never lets a database exception fly back to the input node's catch terminal as the
normal error path - the catch path is the last resort for transport/parse errors.

Handler syntax (IBM doc "DECLARE HANDLER statement"; ESQL has no `FOR SQLEXCEPTION`):

```esql
-- Database exceptions carry SQLSTATE class 'D' (IBM doc "SQLSTATE function"); the block
-- holds ONLY the database statement(s), so the handler cannot swallow anything else.
BEGIN
  DECLARE CONTINUE HANDLER FOR SQLSTATE LIKE 'D%' BEGIN
    SET Environment.Variables.SQL.Failed      = TRUE;
    SET Environment.Variables.SQL.Code        = SQLCODE;
    SET Environment.Variables.SQL.State       = SQLSTATE;
    SET Environment.Variables.SQL.NativeError = SQLNATIVEERROR;
    SET Environment.Variables.SQL.ErrorText   = SQLERRORTEXT;
  END;
  INSERT INTO Database.{dsn}.{schema}.{table} (col1, col2) VALUES (v1, v2);
END;
IF Environment.Variables.SQL.Failed THEN
  PROPAGATE TO TERMINAL 'failure';   -- wired to HandleException
  RETURN FALSE;
END IF;
```

`DECLARE EXIT HANDLER FOR SQLSTATE VALUE '<code>' ...` is the form for a single known
state (retry loops). `'D%'` is the doc-verified class for database exceptions (the
Toolkit-generated DatabaseInput templates use the same); do not widen it to `'%'` inside a
block that holds more than the database statements. ESQL exposes no affected-row register
for INSERT - record `SQLCODE` after the statement and any count the statement form gives
you into the same `Environment.Variables.SQL` folder.
Trace nodes on both the success and error paths include `${Environment}` so those
variables reach the log.

---

## 21. Trace nodes: no hardcoded paths, no payloads in the system log

> Scope: v13 | Tags: all | Evidence: `validated_rules_evidence.md` section 21


- `destination="localError"` is the default for build/validate debugging;
  `"userTrace"` for diagnostics that stay in the flow.
- **Never a hardcoded absolute `filePath`** (`C:\temp\...` and friends). A file sink is
  generated only on request, and its path is a `[CONFIGURE: ...]` marker or a promoted
  property overridden at deploy - it breaks on Linux/containers and is invisible to
  operations otherwise.
- Success-path traces log context (`${Environment}`, selected fields), never
  `${Root}`/`${Body}` to `localError` - that writes every message, PII included, into
  the integration server's system log. Error-path traces may include `${ExceptionList}`.

---

## 22. MQ client connections: the shape is a house convention, the facts are not

> Scope: v13 | Tags: mq, deploy | Evidence: `validated_rules_evidence.md` section 22


**The choice between an MQEndpoint policy project and node-level connection properties
is a customer convention - `customer_profile.md` decides it when present. The skill has
no shape preference of its own.** Absent a profile, the brief decides: node-level
connection properties (`queueManagerHostname`, `listenerPortNumber`, `channelName`,
`securityIdentity` on the node) when the brief gives the connection facts for the flow
and says nothing about policies; an MQEndpoint policy project when the brief names one or
asks for environment-free flows; in Interactive mode, ask. **Under the policy shape
(profile or brief), connection facts given in the brief - host, port, channel, user - are
the VALUES for the policy, never a request for node-level configuration**, the policy is
applied server-wide with `remoteDefaultQueueManager: '{<PolicyProject>}:<Policy>'` in
`overrides/server.conf.yaml` (rule 19), and the flow carries only `queueName`. A recalled
digest of an earlier run describes that run, not the profile. Either way the choice is
recorded in `flow_state.md` and in the deploy steps.

Product facts - these hold whichever shape the profile picks, and a profile cannot
override them:

- The policy project is staged as a folder under `<work_dir>/run/`, never inside the
  BAR (`BIP1388E` otherwise).
- Policy shape: the skeleton in `msgflow_format.md` ("MQ client connections") is the
  shape Toolkit writes (`policyTemplate=""`, no `version` attribute); prefer a policy
  copied from the user's own workspace over the skeleton.
- `destinationQueueManagerName` is required on 13.0.8.1 - a policy without it crashes
  the MQ monitor thread and shuts the server down.
- `securityIdentity` names a vault credential, never a user/password in the policy, and
  only one the TARGET server can resolve: a name copied from another server's policy
  fails with BIP2688E when the target's vault lacks it. Unknown means empty, proven by
  the deploy check.
- A produced policy project that nothing applies (no overrides key, no node reference,
  no documented deploy step) is a defect.

---

## 23. MQ output nodes: `messageContext="default"` unless the identity has the authority

> Scope: v13 | Tags: mq | Evidence: `validated_rules_evidence.md` section 23


**Generate `MQOutput` / `MQReply` nodes with `messageContext="default"`.** The
Toolkit default `passAll` (and `setAll`, `passIdentity`, `setIdentity`) needs
`passall`/`setall` authority on the queue for the connecting identity; a typical
application user (`app` on `DEV.APP.SVRCONN`, or any least-privilege service identity)
has `put` only, and the first put fails `MQOPEN` with **MQRC 2035** - `AMQ8077W ...
unauthorized: passall` in the queue manager's error log. Generate `passAll`/`setAll`
only when the user asks for identity or context propagation AND names an identity that
holds that authority; never fix a 2035 by widening queue manager authority.

---

## 24. The tracking id is minted by the first flow, never read from the payload

> Scope: v13 | Tags: all | Evidence: `validated_rules_evidence.md` section 24


**When a brief asks the flow to return, log or correlate on an "event id", "request
id", "correlation id" or "tracking id", that id is an internal identifier for error
handling and tracing. The first flow that sees the request generates it; every later
flow and node carries it.** Concretely:

- The first Compute after the input node sets it once:
  `SET Environment.Variables.Tracking.Id = UUIDASCHAR;` (`UUIDASCHAR` with no argument
  returns a fresh UUID as CHARACTER).
- `HandleException` and every Trace include it (`${Environment}` already covers it when
  rule 21's trace pattern is followed); the reply carries it (202/200 body or a response
  header); an MQ or Kafka hop carries it forward in a header or message property so the
  next flow reuses it instead of minting a new one.
- A payload field with a similar name (`id`, `eventId`) is a business key: log it beside
  the tracking id when present. Its absence is never a reason to reject the request, and
  it is never substituted for the tracking id.

---

## 25. Kafka nodes: the connector-family types are the default

> Scope: v13; transactional exception 13.0.5+ | Tags: kafka | Evidence: `validated_rules_evidence.md` section 25


**Generate Kafka producers as `com/ibm/connector/kafka/ComIbmOutput.msgnode` and Kafka
consumers as `com/ibm/connector/kafka/ComIbmEventInput.msgnode`** (xmlns prefixes
`com_ibm_connector_kafka_ComIbmOutput.msgnode` / `com_ibm_connector_kafka_ComIbmEventInput.msgnode`,
`connectorName="Kafka"` on the node). The classic `ComIbmKafkaMsgProducer.msgnode` /
`ComIbmKafkaMsgConsumer.msgnode` types are generated only when the brief asks for
transactional publishing or consuming: for the producer the only properties the classic
type adds are `transactionMode`, `transactionalId` and `transactionTimeout`; everything
else (`topicName`, `bootstrapServers`, `clientId`, `acks`, `securityProtocol`,
`securityIdentity`, `policyUrl`, `schemaRegistryPolicyUrl`, the terminals) is identical.

---

## 26. `OutputRoot.MQMD` is not hand-built - the MQOutput node creates it

> Scope: v13 | Tags: mq | Evidence: `validated_rules_evidence.md` section 26


**On an MQOutput path, do not assemble the MQMD in ESQL.** When the output tree has no
MQMD the node creates one and fills it with the MQMD defaults (manual, "MQOutput node").
Persistence is the node's *Persistence mode* property (Automatic / Yes / No / As Defined
for Queue), not an ESQL write to `MQMD.Persistence`; new MsgId / CorrelId are node check
boxes; reply-to queue and queue manager are node properties. Set an individual MQMD field
only when the brief needs a header value the defaults cannot give:

- `MQMD.Format = MQFMT_RF_HEADER_2` when an MQRFH2 is added (rules 2, 4, 13) - on a tree
  that did not come from MQ the MQMD itself must be created first (rule 2), the one
  case where this rule's "the node creates it" does not hold - or a
  receiver-required `Format` (`MQFMT_STRING` for a consumer that relies on
  `MQGMO_CONVERT`).
- `CorrelId`, `Expiry`, `ReplyToQ` / `ReplyToQMgr` values the brief states.
- `CodedCharSetId` / `Encoding` only when the payload's encoding differs from the queue
  manager's and the brief says so.

Each such write is a deliberate override with a WHY comment (`esql_style.md` rule 11). A
block that sets Version / Format / CCSID / Encoding / Persistence "for completeness" is a
defect. When MQMD fields are set, rule 13's order holds (Properties, MQMD, other headers,
body last), and under rule 17 they are set after the whole-message copy.

---
