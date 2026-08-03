---
template_version: 0.3.0
last_updated: 2026-07-02
compatible_with: ACE Flow Builder v0.2.0+ / ACE Flow Refactor v1.0.0+
status: stable
---

# ACE Flow-Building Rules (User-Validated)

Corrections captured from real flow-building and refactor sessions. Apply
these when designing new flows (`ace-flow-builder`) or when refactoring
existing ones (`ace-flow-refactor`).

These rules override any conflicting guidance elsewhere in the references -
they have been validated against real-world ACE v13 deployments.

---

## 1. Route/Filter on upstream state - ask first

If the routing value is available in more than one place on the message
tree (an `MQRFH2` folder, an HTTP header, `Environment.Variables.*`,
`LocalEnvironment`, etc.), **do not silently pick one**. Ask the user
which source the Route or Filter node should read from.

Both choices can be valid depending on:
- What the compute nodes between the source and the Route do to the
  message tree
- Whether the value must survive a transport hop (HTTP call, MQ put) that
  strips some headers

**Question to surface, in Phase B2 (design) or during refactor analysis:**

> "The routing value is present on `MQRFH2.usr.<X>` from the input
> message. Should the Route node filter directly on
> `$Root/MQRFH2/usr/<X>`, or should a pre-Route compute copy it into
> `Environment.Variables.*` and have the Route filter on
> `$Environment/Variables/<X>`?"

Record the decision in the design summary before generating the flow.

---

## 2. Create MQRFH2 explicitly, in the correct tree position

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

---

## 3. MQRFH2 header fields use the `(MQRFH2.Field)` typed prefix

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

Unvalidated ESQL from external sources - spec drafts, AI-generated
snippets, legacy flow ports - routinely contains compile-time bugs:
signature mismatches, undefined references, parser-domain confusion.

Walk the code against a real sample message before declaring done. Fix
bugs in the port - don't ship them. This applies to both Build (when the
user hands you an existing snippet to build around) and Refactor (when
cleaning up legacy ESQL).

Checklist before calling draft ESQL complete:
- [ ] `BROKER SCHEMA` declared
- [ ] All referenced fields exist on the claimed input domain
- [ ] Compute mode (`none` / `copyMessageHeaders` / `local`) matches
      what the ESQL actually builds in `OutputRoot`
- [ ] No typed-prefix / folder-value confusion on `MQRFH2`
- [ ] No string-literal MQ format values (see rule 4)

---

## 6. Destination-list MQ Output nodes need explicit `DestinationData`

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

For a `ComIbmRESTRequest` / `ComIbmRESTAsyncRequest` node calling a
Basic-auth endpoint, there are **two independent** credential
mechanisms with different behaviour. Validated empirically on ACE
v12.0.12 and v13.0.7 (identical on both - this is **not** a version
regression).

| Mechanism | When `Authorization: Basic` is sent |
|---|---|
| **Node Security identity** - `securityIdentity="<id>"` attribute | **Pre-emptively** (first request) |
| **Security Profile** - `securityProfileName="{PolicyProject}:<profile>"`; `SecurityProfiles` policy with `propagation=true`, `idToPropagateToTransport=Static ID`, `transportPropagationConfig=<id>` | **Reactively** - only after the server replies `401` + `WWW-Authenticate: Basic` |

**Credential setup - lead with the vault (ACE 13 mechanism):**

```bat
ibmint set credential --work-directory <dir> --credential-type <type> --credential-name <id> --vault-key <key>
```

(singular `credential`; the per-work-directory vault is created implicitly on the first call - full syntax and server-start `--vault-key`/`MQSI_VAULT_KEY` handling in `validation_runbook.md` §7).

**Legacy node-managed fallback (`mqsisetdbparms`)** - only when the user's estate is node-managed and already uses it. The resource-name prefix then determines which mechanism consumes the credential:

- Node Security identity: `mqsisetdbparms <node> -n rest::<id> -u <u> --password <p>` (the `rest::` prefix)
- Security Profile STATIC-ID propagation: `mqsisetdbparms <node> -n <id> -u <u> --password <p>` (plain name, **no** prefix)

1. **The node Security-identity path is IBM's documented REST-node
   mechanism.** It also requires the Swagger/OpenAPI to declare a
   security requirement of type `http` scheme `basic`/`bearer`, or
   `apiKey` (`oauth2` is **not** supported). With that in place it
   sends Basic on the first request.
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

## 14. Schema-scope `DECLARE ... NAMESPACE` is global - declare it once, or make it local

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
