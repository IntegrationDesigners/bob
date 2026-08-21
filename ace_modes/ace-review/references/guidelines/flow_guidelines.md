---
template_version: 1.2.1
last_updated: 2026-07-09
compatible_with: ACE Review v1.0.0+
status: stable
---
# ACE Message Flow Design Guidelines

## Long vs Short Message Flows

There is no "ideal" length for a message flow, but it's good to use your common sense.

### Trade-offs

**Too Many Short Flows:**
- More overhead on connecting, message handling, and commit phases
- Increased system resource usage for flow management

**Too Few Long Flows:**
- Transactions run past their optimal time
- Impacts the messaging system and any other transactional resources
- Decreases overall throughput

### Recommendation

Balance flow length based on logical business boundaries, transaction requirements, performance characteristics, and maintainability needs.

---

## Number of Nodes

There is no upper or lower limit to the number of nodes that is ideal for a general flow, but **don't use nodes you don't actually need**.

### Examples of Unnecessary Nodes

1. **RCD and Validate Node Together** - The RCD can validate as well; no need for a separate validate node.
2. **Multiple Compute Nodes for Routing or Propagation** - Multiple propagations can be handled in a single compute node.
3. **Redundant Transformation Nodes** - Combine transformations where possible.

---

## Consecutive (ESQL) Compute Nodes

**Avoid having consecutive ESQL (or Java) Compute nodes as much as possible.**

### Why This Matters

Each Compute node parses the message, loads a copy (for rollback and error handling) of the message tree in memory, increases memory and CPU usage, extends processing time, and results in longer running transactions.

### Solution

Combine the functionality of multiple Compute nodes by using `PROPAGATE` statements, routines and functions, and consolidating logic into a single compute node.

### Example

**Inefficient (Multiple Compute Nodes):**
```
Input → Compute1 (Validate) → Compute2 (Transform) → Compute3 (Enrich) → Output
```

**Efficient (Single Compute Node):**
```
Input → Compute (Validate + Transform + Enrich) → Output
```

---

## Message Trees (Compute Mode)

The Compute Mode on a Compute node controls which trees are "owned" by the node and propagated from it. **The setting must match what your ESQL actually does** - getting this wrong either wastes resources (mode too broad) or silently drops trees you expected to pass through (mode too narrow).

### How It Works

For each tree component (message body, LocalEnvironment, ExceptionList):

- **If included in the mode** - the Output version of that tree is propagated. The Input version is **discarded** unless your ESQL explicitly copies it (e.g. `SET OutputRoot = InputRoot`)
- **If not included in the mode** - the Input version passes through unchanged. Any changes your ESQL makes to the Output version are local to the node and are lost

Reference: [IBM ACE 13 - Compute node: Setting the mode](https://www.ibm.com/docs/en/app-connect/13.0.x?topic=nodes-compute-node#ac04660_mode)

### What Gets Propagated Per Mode

This table shows exactly which tree version (Input or Output) is propagated for each mode:

| Compute Mode | Message body | LocalEnvironment | ExceptionList |
|---|---|---|---|
| `Message` *(default)* | OutputRoot | InputLocalEnvironment | InputExceptionList |
| `LocalEnvironment` | InputRoot | OutputLocalEnvironment | InputExceptionList |
| `LocalEnvironment And Message` | OutputRoot | OutputLocalEnvironment | InputExceptionList |
| `Exception` | InputRoot | InputLocalEnvironment | OutputExceptionList |
| `Exception And Message` | OutputRoot | InputLocalEnvironment | OutputExceptionList |
| `Exception And LocalEnvironment` | InputRoot | OutputLocalEnvironment | OutputExceptionList |
| `All` | OutputRoot | OutputLocalEnvironment | OutputExceptionList |

*Output = your ESQL changes are used. Input = original passes through unchanged.*

### Decision Matrix - How to Choose the Right Mode

| What the ESQL does | Correct Compute Mode |
|--------------------|----------------------|
| Modifies the message body only | `Message` |
| Only sets values in `OutputLocalEnvironment` | `LocalEnvironment` |
| Modifies the message body AND sets LocalEnvironment values | `LocalEnvironment And Message` |
| Only routes or filters - no changes to message or LocalEnvironment | `Exception` |
| Modifies the message body AND writes to the ExceptionList | `Exception And Message` |
| Sets LocalEnvironment AND writes to the ExceptionList | `Exception And LocalEnvironment` |
| Modifies all three trees | `All` |

### `SET OutputRoot = InputRoot`, `CopyEntireMessage()`, and Compute Mode

Because **Message mode discards InputRoot**, your ESQL must explicitly copy the input to the output if you want to preserve it before making changes. `SET OutputRoot = InputRoot` (or calling `CopyEntireMessage()`) is the standard way to do this - it is correct and expected under `Message` mode.

The issue is not the copy itself, but doing a **full tree copy when only a few headers or fields are needed**. Copying the entire tree and then changing one field is wasteful. The efficient alternative is targeted copying:

```esql
-- Full copy (wasteful if you only need to change one field)
SET OutputRoot = InputRoot;
SET OutputRoot.XMLNSC.Body.Status = 'Processed';

-- Targeted copy (efficient - only copy what you actually need)
CALL CopyMessageHeaders();  -- copies Properties, MQMD, etc.
SET OutputRoot.XMLNSC = InputRoot.XMLNSC;
SET OutputRoot.XMLNSC.Body.Status = 'Processed';
```

**For `All` mode**, the InputRoot, InputLocalEnvironment, and InputExceptionList are all discarded. You must copy everything you want to preserve:
```esql
SET OutputRoot = InputRoot;
SET OutputLocalEnvironment = InputLocalEnvironment;
SET OutputExceptionList = InputExceptionList;
```
Note: `CopyEntireMessage()` only copies the message body - it does NOT copy LocalEnvironment or ExceptionList. If you use `All` mode and call only `CopyEntireMessage()`, LocalEnvironment and ExceptionList are lost.

### How to Review This

For each Compute node, cross-reference the mode setting (in the .msgflow) against the ESQL method it calls:

1. Read what the ESQL actually writes: does it touch `OutputRoot`, `OutputLocalEnvironment`, `OutputExceptionList`, or none?
2. Check the Compute Mode set on the node
3. Flag mode too broad: e.g., mode is `Message` but ESQL only sets `OutputLocalEnvironment` - the message passes through as an empty output tree, which is likely a bug, and the full tree copy is unnecessary
4. Flag mode too narrow: e.g., mode is `Exception` but ESQL sets `OutputLocalEnvironment` - those LocalEnvironment changes will be silently discarded
5. Flag inefficient full copies: `SET OutputRoot = InputRoot` or `CopyEntireMessage()` when only a few headers are needed - suggest targeted copies instead
6. Account for shared library and helper routine calls: if a helper sets LocalEnvironment, the mode must include `LocalEnvironment`
7. Do not flag `SET OutputRoot = InputRoot` under `Message` mode as wrong - it is how you preserve the input before modifying it

### Examples

**Correct - routing only, no trees modified:**
```esql
-- ESQL only propagates to a specific terminal, no output tree changes
IF InputBody.Type = 'A' THEN
   PROPAGATE TO TERMINAL 'out1';
ELSE
   PROPAGATE TO TERMINAL 'out2';
END IF;
RETURN FALSE;
-- Correct compute mode: Exception
```

**Incorrect - mode too broad:**
```esql
-- ESQL only sets a routing value in LocalEnvironment
SET OutputLocalEnvironment.Variables.CorrelationId = InputLocalEnvironment.Variables.Id;
-- Compute mode set to: Message
-- Problem: OutputRoot is propagated but ESQL never sets it - empty message body
-- Correct compute mode: LocalEnvironment
```

**Correct - Message mode with targeted copy:**
```esql
-- Compute mode: Message
CALL CopyMessageHeaders();              -- copy Properties, MQMD, etc.
SET OutputRoot.XMLNSC = InputRoot.XMLNSC;  -- copy body
SET OutputRoot.XMLNSC.Body.Status = 'Processed';  -- modify one field
-- LocalEnvironment and ExceptionList pass through automatically (not in mode)
```

---

## Message Parsing

It's always better to use the minimum amount of message parsing and to try and identify the message type as quickly as possible.

### When Parsing/Validation is Required

Think about where in the flow parsing/validation is needed:

1. Before publishing a message on a bus with a specific data contract
2. Upon receiving data from an external source
3. When retrieving data from a volatile source (files can be subject to layout changes)
4. At integration boundaries where data quality must be guaranteed

### Parsing Optimization

- **Don't use immediate or complete parsing** where it is not required
- Use **On Demand** parsing when possible
- Specify the message format explicitly to avoid parser detection overhead
- Use message sets to define structure upfront

### Parsing Settings

These are values of the **Parse Timing** property. Parse Timing controls *when the body is parsed*; it is not the same as validation (see the next section).

| Setting | Description | Use Case |
|---------|-------------|----------|
| **On Demand** | Parses only what is accessed, lazily (the default) | Best for most scenarios; lowest overhead |
| **Immediate** | Overrides on-demand and parses the whole message up front | When you need the full tree early |
| **Complete** | Overrides on-demand and fully parses the body at the node (well-formedness enforced there, so a malformed body fails at this node) | When bad input must be rejected at the boundary rather than lazily downstream |

Note: **Complete parses fully; it does not by itself validate against a schema.** A full parse checks well-formedness (e.g. syntactically valid JSON); checking a message against a schema/model is separate validation (see below).

### Parse Timing, Validate, and Message model - three knobs, not one

A common review mistake is to conflate parsing with validation, or to guess `.msgflow` attribute names. These are three distinct properties, on the **Parser Options** and **Validation** tabs, available on any parser-capable node - not just the RCD. Per IBM's "Validation properties" topic they apply to all input nodes (HTTPInput, MQInput, FileInput, SOAPInput, JMSInput, KafkaConsumer, TCPIP\*, .NETInput, FTEInput, MQTTSubscribe) and the "Other nodes" that parse input (Compute, DatabaseRetrieve, HTTPRequest, FileRead, JavaCompute, Mapping, MQGet, ResetContentDescriptor, SOAPRequest, SOAPAsyncResponse, Validate, XSLTransform). Output nodes carry them too, but Parse Timing does not affect output-message validation, so the reasoning below is for the input/parser side.

| Toolkit label (tab) | `.msgflow` attribute | Values (default first) | What it does |
|---|---|---|---|
| **Parse Timing** (Parser Options) | `validateTiming` | `onDemand` / `immediate` / `complete` | Controls *when* the body is parsed, independent of validation; also sets the timing of validation *if* validation is on. `immediate`/`complete` override on-demand and fully parse at the node. |
| **Validate** (Validation) | `validateMaster` | `none` / `content` / `contentAndValue` / `inherit` | The on/off switch for schema/model validation only. For JSON, enable with Content and Value. |
| **Message model** (Basic/Parser Options) | model reference | (a schema/model name) | Names the schema/model to validate against (JSON schema / OpenAPI / message set). |

Key facts (IBM "Validation properties" and "JSON validation", ACE 13):

- The **"Parse Timing" property serializes as `validateTiming`** - the toolkit writes `validateTiming="complete"` when you set Parse Timing to Complete. **There is no `parseTiming` attribute** - never look for one, and never conclude parse timing is unset because you cannot find `parseTiming`.
- **Parsing is not validation.** "When parsing, the JSON parser always checks that the input document is well-formed JSON... If validation is enabled, the JSON parser also checks that the JSON document obeys the rules in the JSON schema." So malformed/syntactically-invalid input is caught by *parsing alone* (no schema needed); structural/value violations need *validation*.
- To actually validate content you need the **full trio**: `validateMaster` not `none` (for JSON, Content and Value) **plus** a deployed schema **plus** the Message model naming it. Parse Timing only controls *when* that validation runs (`onDemand` defers it per-field, `complete` runs it fully up front). Parsing itself needs no schema (JSON/XMLNSC are self-describing).

**Reviewer rules:**

- Read `validateTiming` and `validateMaster` from the `.msgflow`; do not guess attribute names from the toolkit labels.
- Separate **parse errors** (malformed body -> caught by Parse Timing; `complete` catches at the node, `onDemand` defers) from **validation errors** (structure/value violations -> require the full trio above).
- Do not report "invalid input can slip through because parse timing is On Demand" without reading `validateTiming`; if it is `immediate`/`complete`, malformed input is already caught at the node.
- "No schema validation configured" is a separate, correctly-attributed observation (often intentional) - not a parse-timing finding, and fixing it needs all three knobs, not just Parse Timing.

**Absent attribute = default value, not missing.** ACE serializes only *non-default* property values into the `.msgflow` (and only *overridden* values into BAR override / deployment-descriptor files). An attribute that is not present means the node is using that property's **default** - it is not "unset", "missing", or "not configured". So `validateTiming` absent means Parse Timing is at its default **On Demand**; `validateMaster` absent means Validate is at its default **None**. Never flag a property as missing because its attribute is not in the XML - state the default instead. (This is the same principle the promoted-properties cross-check relies on: node default vs descriptor override vs expected value.)

The RCD node type in the `.msgflow` is `ComIbmResetContentDescriptor.msgnode` (from the node's `xmi:type`). For any other node, read the actual `xmi:type` from the `.msgflow` rather than assuming the type string - the same discipline as reading the property attributes.

### JSON Schema Version Compatibility

ACE's schema validation nodes support **JSON Schema draft 4** only. Schemas using draft 6, draft 7, or 2019-09 features will not validate correctly at runtime - unsupported keywords are silently ignored or cause errors.

**Check:** For any `.json` schema file referenced by a validation node:
1. The `$schema` field (if present) should reference `http://json-schema.org/draft-04/schema`
2. No draft 6/7/2019-09 keywords are used: `contains`, `if`, `then`, `else`, `$defs`, `propertyNames`, `$id` (use `id` for draft 4), `examples`
3. Pattern properties and `additionalProperties` follow draft 4 semantics

---

## Data Formats

Custom internal data formats can lead to additional memory and CPU usage. Each time a message is transformed from one format to another, the flow needs to make this transformation.

**Even though the internal format brings standardization, it's best not to use it if you don't really require it.**

**When to Use Internal Format:**
- Working with a message bus or publication system
- Benefits of standardization outweigh the costs
- Multiple consumers need the same format

**When to Avoid Internal Format:**
- Point-to-point integrations
- Simple transformations
- Performance-critical paths

---

## Synchronous vs Asynchronous

**If an external application is slow to respond, an asynchronous approach is better.**

With synchronous calls to slow systems, you keep memory occupied, processing threads are blocked, other messages cannot be processed, and overall throughput decreases.

### Implementation Patterns

**Synchronous (Request-Reply):**
```
Input → HTTPRequest → Process Response → Output
```

**Asynchronous (Fire and Forget):**
```
Input → MQOutput → [Separate Flow] → MQInput → Process → Output
```

**Asynchronous (Callback):**
```
Flow 1: Input → MQOutput (with ReplyTo) → Continue Processing
Flow 2: MQInput (Reply Queue) → Process Response → Output
```

---

## Additional Instances (Threading)

ACE allows each message flow to run with multiple parallel instances. Misconfiguring this setting is a common performance issue that is invisible in low-volume testing but causes problems at production volumes.

### How It Works

Each integration server has a pool of threads. The **Additional Instances** setting on each flow controls how many threads can process messages in parallel for that flow. The default is 0, meaning only a single instance (one thread at a time).

### When to Change It

- **High-volume flows** - set Additional Instances to match expected throughput; a single-threaded flow becomes a bottleneck under load
- **Flows with slow external calls** - a higher instance count allows other messages to be processed while one thread waits for a database or HTTP response
- **Single-threaded by design** - some flows must be single-threaded (e.g., ordered processing, non-thread-safe shared state); in those cases, explicitly keep it at 0 and document why

### Checks

- Review the Additional Instances setting on each flow's message flow properties
- For high-volume or async flows, verify that the setting is not left at the default of 0
- For flows that must be single-threaded, verify there is a comment or documentation explaining this constraint
- If Java compute nodes are used, verify that the Java code is thread-safe before increasing instances (see java_guidelines.md - single instance rule)

---

## Promoted Node Properties

In ACE, node properties can be promoted to the BAR file and overridden at deployment time via a properties file (`*.properties` or `*.yaml`). This is the standard pattern for environment-specific configuration (queue names, directories, hostnames, etc.).

### Three Values, Not Two

When reviewing a node that has promoted properties, there are always three distinct values to consider:

| Column | Where to find it | What it means |
|--------|-----------------|---------------|
| **Hardcoded default** | The node property in the `.msgflow` file | What the node uses if no override is applied at deployment |
| **Promoted property value** | The deployment properties file (`*.properties` / `*.yaml`) | What the node actually uses at runtime in that environment |
| **Expected / correct value** | Your knowledge of what it should be for this application | What it should say - used to spot mismatches |

### Why All Three Matter

- The hardcoded default may be stale (copy-pasted from another adapter, never updated)
- The promoted override may itself be wrong, pointing to the wrong queue or environment
- Without the properties file value, a reviewer can only flag the default as suspicious - they cannot confirm whether the runtime behaviour is actually correct

### How to Review This

When reporting on promoted property mismatches, always produce a four-column table:

| Node | File | Hardcoded default | Promoted property value | Expected value |
|------|------|-------------------|------------------------|----------------|
| (node name) | (file:line) | (value in .msgflow) | (value in .properties/.yaml) | (what it should be) |

- If the promoted property value matches the expected value, the runtime behaviour is correct even if the hardcoded default is stale - note this explicitly (the default is misleading but not a runtime bug)
- If the promoted property value also does not match the expected value, that is a runtime misconfiguration and should be flagged at higher severity
- If no properties file was provided for review, note that the hardcoded defaults could not be cross-checked against runtime overrides and recommend including the properties file in future reviews

---

## REST API Projects - OpenAPI Spec Completeness

When reviewing a REST API ACE project (one that uses `restapi.descriptor` and an OpenAPI spec file such as `hr-system.yaml` or `*.yaml`), check the spec for ACE-specific completeness requirements in addition to reviewing the generated and operation subflows.

### operationId Requirement

Every operation in the spec must have an `operationId` defined. ACE's REST API toolkit uses `operationId` to generate the routing label name for `RouteToLabel`. Without it, ACE falls back to a default name derived from the HTTP method and path - this can be fragile if the spec is regenerated.

```json
// MISSING operationId - ACE derives a default, which may change on spec regeneration:
"/employee": {
  "post": {
    "tags": ["HRSystem"],
    "requestBody": { ... }
  }
}

// CORRECT - operationId explicitly set, matches the subflow name:
"/employee": {
  "post": {
    "operationId": "postRecord",
    "tags": ["HRSystem"],
    "requestBody": { ... }
  }
}
```

Verify that the `operationId` value matches the corresponding entry in `restapi.descriptor`:

```xml
<ns2:operation name="postRecord" implementation="postRecord.subflow"/>
```

### Generated Flow

The `gen/` directory contains the auto-generated root flow. This file must never be edited manually - changes are silently overwritten when the spec is regenerated. Flag it if there is no `DEFINE SUB` comment, sticky note, or CI guard preventing manual edits.

**Reference:** [IBM ACE - REST API projects](https://www.ibm.com/docs/en/app-connect/13.0.x?topic=toolkit-creating-rest-api)

---

## Unconnected Node Terminals

In ACE, processing nodes (Compute, Database, HTTPRequest, SOAPRequest, MQ Get, etc.) can have a **Failure**, **Catch**, or **Timeout** terminal. When any of these terminals is not connected, exceptions thrown by the node propagate upstream to the nearest TryCatch node or input node, and transactional changes already made may be rolled back.

This is not always wrong - but it must be **deliberate**, not accidental.

### When Unconnected Is Acceptable

- The flow has a TryCatch node upstream that catches all downstream exceptions (the unconnected terminal is handled at the flow level)
- The exception propagation and rollback behaviour is the intentional design (e.g., MQInput with BOTHRESH configured for automatic backout)
- A sticky note or comment explicitly documents why the terminal is deliberately left unconnected
- The reviewer independently traces the wiring and confirms it genuinely reaches an intentional error-handling framework (e.g., backout via MQInput/MQRetry/MQDrop), even without a sticky note. Report this in the Remarks section (see REVIEW_TEMPLATE.md - Remarks/Notes) rather than as a finding: the verified-correct behaviour means this is not a defect, but a one-time review check is not a substitute for durable documentation, so record the gap as a remark.

### When to Flag

- **🟡 Medium:** A processing node (Compute, Database, HTTPRequest) has an unconnected Failure terminal and there is no TryCatch node upstream - any exception will propagate to the input node with potential rollback
- **🟠 High:** A Timeout terminal on an external call node (HTTPRequest, SOAPRequest, MQ Get) is unconnected - timeout exceptions propagate upstream silently with no local handling or logging
- **🟠 High:** Both Catch and Failure terminals on a TryCatch node are unconnected - the node exists but provides no local error handling

### Do Not Flag

- Unconnected Failure terminals when a TryCatch node is present upstream covering the full path
- Flows that intentionally rely on integration server-level error handling (provided this is documented)

### How to Review This

For every node in the flow that has a Failure, Catch, or Timeout terminal:
1. Check whether the terminal is wired to a downstream node
2. If unconnected, check whether a TryCatch node covers the path upstream
3. Apply the severity rules above - flag only what is genuinely unhandled without justification

**Reference:** [IBM ACE 13 - Handling errors in message flows](https://www.ibm.com/docs/en/app-connect/13.0.x?topic=flows-handling-errors-in-message)

---

## MQ Header Node (MQMD / MQDLH)

The `ComIbmMQHeader.msgnode` (MQHeader node) adds, modifies, or deletes **only** the `MQMD` (MQ Message Descriptor) and `MQDLH` (MQ Dead Letter Header) headers. It does **not** handle `MQRFH2` or `MQMDE` - those are built in ESQL/Java or by other nodes, and their ordering is covered by the output-tree header-order checks in `esql_guidelines.md` / `java_guidelines.md` and by `MQRFH2`-as-next-sibling-of-`MQMD` rules. The node has terminals `In` / `Out` / `Failure` (no Catch), no mandatory properties, and manages the tree position of the header it writes itself, so it is **not** the usual source of a header-after-body sequence.

Its real, statically visible settings are the **MQMD header options** / **MQDLH header options** (default `Carry forward...`), **Inherit from header** (default Selected), **Coded Character Set Identifier**, **Format**, and the individual MQMD/MQDLH field values. The two failure modes worth flagging are documented behaviours, not parser-order guesses.

### Flag: MQMD changes silently lost on a non-MQ-sourced tree

- **🟡 Medium:** An MQHeader node (or ESQL `SET OutputRoot.MQMD.*`) **sets MQMD values on a flow sourced from a non-MQ transport** (HTTPInput, user-defined input, etc.). On such a tree the `Properties` folder was populated from the transport headers, not from an MQMD, so value propagation runs **Properties to MQMD** - the `Properties` folder **overwrites** the MQMD values and the change is silently lost. Affected fields: `CorrelId`, `Encoding`, `CodedCharSetId`, `Persistence`, `Expiry`, `Priority`. The correct approach is to set the `Properties` field (for example `SET OutputRoot.Properties.ReplyIdentifier` to drive `MQMD.CorrelId`). When sourced from an `MQInput` node the precedence is the other way (MQMD to Properties) and this is not an issue.

### Flag: writing an MQ header with no Properties folder

- **🟡 Medium:** An MQHeader node writes `MQMD` / `MQDLH` on a path where **no `Properties` folder is present** (for example immediately after a BLOB build or a `ResetContentDescriptor` that did not carry Properties). A missing Properties folder when an MQ header is written is a known overwrite-the-message-body defect (APAR `IT32965`), so confirm a `Properties` folder is established first.

### Do Not Flag

- An MQHeader node on an `MQInput`-sourced flow setting MQMD values - precedence runs MQMD to Properties there, so the values stand.
- Header/body construction done in ESQL/Java compute code - that path is covered by the output-tree header-order checks in `esql_guidelines.md` and `java_guidelines.md`.

### How to Review This

1. Identify each `ComIbmMQHeader` node (and any `SET OutputRoot.MQMD.*` in ESQL) and read which MQMD/MQDLH fields it writes.
2. Trace the **input node** that sources the flow: `MQInput` (MQMD has precedence, fine) versus HTTP/SOAP/user-defined (Properties has precedence, MQMD writes are lost).
3. Confirm a `Properties` folder is present on the path before the MQ header is written.
4. Flag the two cases above. The non-MQ-sourced precedence trap is the high-value one - it produces no error, the message simply goes out with the wrong MQMD values.

**Reference:** IBM ACE 13 docs (offline set) - `How the message tree is populated.pdf` ("Properties versus MQMD folder behavior for various transports") and `MQHeader node.pdf`. APAR [IT32965](https://www.ibm.com/support/pages/apar/IT32965).

---

## Summary

Key message flow design guidelines:

1. **Balance flow length** - Not too short, not too long
2. **Minimize node count** - Only use nodes you need
3. **Avoid consecutive compute nodes** - Combine logic where possible
4. **Optimize compute mode** - Only copy what you need
5. **Minimize parsing** - Use on-demand parsing when possible
6. **Avoid unnecessary transformations** - Question the need for internal formats
7. **Use asynchronous patterns** - For slow or unreliable external systems
8. **Configure Additional Instances** - Don't leave high-volume flows single-threaded by default
9. **REST API projects** - Verify all operations have `operationId` in the OpenAPI spec
10. **Check unconnected terminals** - Flag unhandled Failure/Catch/Timeout terminals on processing and external-call nodes
11. **JSON Schema compliance** - Verify schema files use JSON Schema draft 4 (ACE does not support draft 6/7/2019)
12. **MQ Header node (MQMD/MQDLH)** - Flag MQMD writes on non-MQ-sourced flows (Properties overwrites MQMD, change silently lost) and MQ-header writes with no Properties folder (APAR IT32965)
