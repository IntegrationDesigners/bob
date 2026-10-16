# ACE Flow Builder - Generation Reference (Phase B3)

This file is read by the Phase B3/B4 generation subagent only - never by the main
conversation. It contains the full Phase B3 procedure plus the node/ESQL reference
appendices and the example flow patterns that generation depends on.

---

### Phase B3: Generate

**Iterative mode:** generate the smallest viable set of files (msgflow + main ESQL + HandleException ESQL + project files + `flow_state.md`) with the minimum viable info from B1. Use sensible defaults for everything else and mark them with `[CONFIGURE: ...]` placeholders. After generating, summarise what you assumed and ask the user to confirm/override before moving to refinement.

**Thorough mode:** generate all output files in sequence. The user has already confirmed the design in B2 - no further confirmation needed for the file content.

In both modes, run the **Phase B3 sanity check** (§3.7 below) before declaring done.

#### 3.1 Generate the `.msgflow` XML File

Produce the full `.msgflow` file using the **verified ACE v13 format** (see `references/msgflow_format.md` for full details and node type reference).

**Node labelling - every node gets a meaningful `<translation>`.**
The label that shows on the canvas should describe what the node *does in this flow*, not its type. Aim for a short verb phrase a reader can scan top-to-bottom and reconstruct the flow's intent.

| Bad (type name) | Good (action phrase) |
|---|---|
| `MQInput` | `Read APP.IN` |
| `HTTPRequest` | `POST to target endpoint` |
| `Compute` | `Classify HTTP response` |
| `MQOutput` | `Put to APP.ERROR` |
| `TimeoutControl` | `Schedule retry` |
| `TimeoutNotification` | `Fire scheduled retry` |

**Never emit Compute nodes as self-closing** - `<nodes ... computeExpression="..."/>` has no label at all. Always emit an open/close pair with a `<translation>` child:

```xml
<nodes xmi:type="ComIbmCompute.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_2"
  location="258,61" computeExpression="esql://routine/RetryHTTPDispatcher#Classify.Main">
  <translation xmi:type="utility:ConstantString" string="Classify HTTP response"/>
</nodes>
```

The `<translation>` `string` is independent of the node's `name=` attribute and the ESQL module name - it is purely the visual label on the canvas.

**Always check `references/examples/` first** - all 93 v13 patterns are available. Navigate to `references/examples/[PatternName]/` for the closest match and adapt names and configuration. The `.msgflow` file shows the real node wiring; the `_Compute.esql` (if present) shows the transformation logic.

**HTTP Request-Reply flow template (correct ACE v13 format):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ecore:EPackage xmi:version="2.0"
  xmlns:xmi="http://www.omg.org/XMI"
  xmlns:ComIbmWSInput.msgnode="ComIbmWSInput.msgnode"
  xmlns:ComIbmWSReply.msgnode="ComIbmWSReply.msgnode"
  xmlns:ComIbmCompute.msgnode="ComIbmCompute.msgnode"
  xmlns:ecore="http://www.eclipse.org/emf/2002/Ecore"
  xmlns:eflow="http://www.ibm.com/wbi/2005/eflow"
  xmlns:utility="http://www.ibm.com/wbi/2005/eflow_utility"
  nsURI="[FlowName].msgflow"
  nsPrefix="[FlowName].msgflow">

  <eClassifiers xmi:type="eflow:FCMComposite" name="FCMComposite_1" nodeLayoutStyle="RECTANGLE">
    <eSuperTypes href="http://www.ibm.com/wbi/2005/eflow#//FCMBlock"/>
    <translation xmi:type="utility:TranslatableString" key="[FlowName]" bundleName="[FlowName]" pluginId="[FlowName]"/>
    <colorGraphic16 xmi:type="utility:GIFFileGraphic" resourceName="platform:/plugin/[FlowName]/icons/full/obj16/[FlowName].gif"/>
    <colorGraphic32 xmi:type="utility:GIFFileGraphic" resourceName="platform:/plugin/[FlowName]/icons/full/obj30/[FlowName].gif"/>
    <composition>

      <!-- Input node -->
      <nodes xmi:type="ComIbmWSInput.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_1"
        location="72,61" URLSpecifier="/[url-path]" messageDomainProperty="XMLNSC">
        <translation xmi:type="utility:ConstantString" string="HTTP Input"/>
      </nodes>

      <!-- Compute node -->
      <nodes xmi:type="ComIbmCompute.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_2"
        location="258,61" computeExpression="esql://routine/[BrokerSchema]#[FlowName]_Compute.Main">
        <translation xmi:type="utility:ConstantString" string="Compute"/>
      </nodes>

      <!-- Reply node -->
      <nodes xmi:type="ComIbmWSReply.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_3"
        location="510,61">
        <translation xmi:type="utility:ConstantString" string="HTTP Reply"/>
      </nodes>

      <!-- Error handler node -->
      <nodes xmi:type="ComIbmCompute.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_4"
        location="258,130" computeExpression="esql://routine/[BrokerSchema]#[FlowName]_HandleException.Main">
        <translation xmi:type="utility:ConstantString" string="HandleException"/>
      </nodes>

      <!-- Happy path: Input → Compute → Reply -->
      <connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_1"
        targetNode="FCMComposite_1_2" sourceNode="FCMComposite_1_1"
        sourceTerminalName="OutTerminal.out" targetTerminalName="InTerminal.in"/>
      <connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_2"
        targetNode="FCMComposite_1_3" sourceNode="FCMComposite_1_2"
        sourceTerminalName="OutTerminal.out" targetTerminalName="InTerminal.in"/>

      <!-- Error path: catch → HandleException → Reply -->
      <connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_3"
        targetNode="FCMComposite_1_4" sourceNode="FCMComposite_1_1"
        sourceTerminalName="OutTerminal.catch" targetTerminalName="InTerminal.in"/>
      <connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_4"
        targetNode="FCMComposite_1_3" sourceNode="FCMComposite_1_4"
        sourceTerminalName="OutTerminal.out" targetTerminalName="InTerminal.in"/>
    </composition>
    <propertyOrganizer/>
    <stickyBoard/>
  </eClassifiers>
</ecore:EPackage>
```

**Key rules (see `references/msgflow_format.md` for full reference):**
- Namespace suffix is `.msgnode` - NOT `.msgflow`
- Node element format: `ComIbmWSInput.msgnode:FCMComposite_1`
- Node IDs are sequential: `FCMComposite_1_1`, `FCMComposite_1_2`, ...
- `computeExpression`: `esql://routine/[BrokerSchema]#ModuleName.Main` where `[BrokerSchema]` is the dotted package (e.g. `com.acme.orders`) - the part before `#` MUST equal the ESQL `BROKER SCHEMA` line (a bare `#ModuleName` is default-schema only - see §3.2 and `msgflow_format.md` *computeExpression Format*)
- `URLSpecifier` (capital U, capital S)
- Always wire BOTH `OutTerminal.catch` AND `OutTerminal.failure` of the input node to the `HandleException` compute node (unless the spec explicitly says no error handling - then omit the handler and both wirings). On MQ-input flows the HandleException output goes to an `ErrorQueue` MQOutput (`<FlowName>.ERROR`) BEFORE the Trace, so the original payload is persisted before the transaction commits - see `msgflow_format.md` "Standard Error Handling Pattern" and `validated_rules.md` §15
- For MQ input nodes: `queueName="QUEUE.NAME"` on `ComIbmMQInput.msgnode:FCMComposite_1`
- For File input: `inputDirectory="C:\path"` on `ComIbmFileInput.msgnode:FCMComposite_1`

After the file block, always add:
> ⚠️ **Note:** This is a real ACE v13 format `.msgflow` file. Import via ACE Toolkit: File → Import → General → Existing Projects into Workspace. Verify node positions visually after import.

#### 3.2 Generate the ESQL `.esql` Files

**Apply the readability rules in [`references/esql_style.md`](esql_style.md) while writing every `.esql` file.** Functional variable names (no `tmp`/`str`/`data`), verb-noun procedure names, no Hungarian prefixes, no opaque abbreviations, no single-use variables, one variable one purpose, declare close to first use, no single-use procedures (large-body exception for big mappings / multi-branch validators), don't reinvent ESQL built-ins (use `COALESCE`/`RIGHT`/`LEFT`/`TRIM`/etc. instead of custom helpers), fail-fast guards instead of deeply-nested success branches, comment the WHY not the WHAT, no commented-out code.

Always generate **two** ESQL files: the main compute module and the error handler. **Exception:** if the spec explicitly states *no error handling* (e.g. "happy path only", "no error handling"), omit the `_HandleException` module **and** the `OutTerminal.catch → HandleException` wiring - generate only the main compute module. When error handling is unspecified, include the handler (the default).

**Draft ESQL from outside (the user's snippet, a spec draft, a legacy port) is reviewed before it is adopted** - such code routinely carries compile-time bugs (signature mismatches, undefined references, parser-domain confusion). Walk it against a real sample message and fix the bugs in the port; never ship them. Checklist before calling draft ESQL complete: `BROKER SCHEMA` declared; every referenced field exists on the claimed input domain; the compute mode propagates what the ESQL writes (`OutputLocalEnvironment` / `OutputExceptionList` writes need a matching mode - `validated_rules.md` §16); correlation names from the closed set in §16 (`Environment`, never `InputEnvironment` / `OutputEnvironment`); whole-message copy is `SET OutputRoot = InputRoot;` alone (§17); no typed-prefix / folder-value confusion on `MQRFH2` (§3); no string-literal MQ format values (§4). (Former validated rule 5, moved here 2026-09-11; `ace-flow-refactor` applies the same checklist to legacy ports.)

##### `BROKER SCHEMA` ↔ directory layout (mandatory)

ESQL files declaring a non-default `BROKER SCHEMA <X>` must physically live under a directory matching that schema, relative to the project root. Mismatch causes ACE Toolkit to flag `Incorrect schema name` errors at build time.

| `BROKER SCHEMA` line | File path (relative to project root) | `computeExpression` URI |
|---|---|---|
| *(omitted, default schema)* | `<project>/MyModule.esql` | `esql://routine/#MyModule.Main` |
| `BROKER SCHEMA RetryHTTPDispatcher` | `<project>/RetryHTTPDispatcher/MyModule.esql` | `esql://routine/RetryHTTPDispatcher#MyModule.Main` |
| `BROKER SCHEMA com.id.reprocess.timeout` | `<project>/com/id/reprocess/timeout/MyModule.esql` | `esql://routine/com.id.reprocess.timeout#MyModule.Main` |

**Rule:** for every `BROKER SCHEMA <X>` declaration, the file must live at `<project>/<X with dots replaced by slashes>/<file>.esql`, and every `computeExpression` URI referencing that module must include `<X>` between `/` and `#`.

**Toolkit vs `ibmint package` asymmetry - important.** The two enforce this rule with different strictness:

- **`ibmint package`** is **lax**: it'll happily produce a BAR even when the schema and folder don't match, and the runtime *will* execute the flow correctly (the ESQL parser is forgiving at load time).
- **ACE Toolkit** is **strict**: it refuses to compile a project with a mismatched schema and surfaces two errors:
  1. `Incorrect schema name a.b.c` on the offending `.esql` file
  2. `Unable to locate URN esql://routine/a.b.c#Module.Function` on every `.msgflow` referencing a routine in that schema

So a flow that builds and runs cleanly via the CLI may still red-X in Toolkit. Don't trust "it ran via `ibmint package`" as proof the structure is right - Toolkit users will hit a wall. The skill must always emit a layout that satisfies both: dotted-schema folders matching the `BROKER SCHEMA` declaration, or omit the declaration entirely for files at the project root (default schema).

**Recommended default for generated flows:** use a **dotted-package** `BROKER SCHEMA` and place the flow's `.msgflow`, `.esql`, and any `.subflow` under the matching nested folder. **Assume the package from the flow's functionality** (e.g. a JSON-validation flow → `com.acme.jsonvalidation`), record it as an assumption in `flow_state.md`, and let the user redirect it later. Never use a bare single-word schema equal to the project name - that single folder reads as "just the project folder" and the files end up dropped at the project root. A dotted package forces a nested folder that *can't* be confused with the root, and matches real ACE projects (`JsonParser` → `com.mbl.json.parser`, `JsonValidation` → `com.ibm.test.jsv`).

**Always create a new project.** The path the user gives is the **workspace/parent** (the top `<workspace | git project>` row), *not* the project root. Always create a new `<AppName>/` folder inside it for the application; **never** write `.project` / `application.descriptor` / `.msgflow` / `.esql` directly into the given path. (`<AppName>` defaults to the flow's purpose/name if not supplied.)

**Expected project layout** - create the nested package folder *first*; the `.msgflow` and `.esql` live **inside** it (verified against `JsonParser` / `JsonValidation`):

```text
<workspace | git project>/
├─ <AppName>/                                  ACE application project (root); .project <name> = <AppName>
│  ├─ .project
│  ├─ application.descriptor
│  ├─ .settings/org.eclipse.core.resources.prefs   (optional - Toolkit recreates it)
│  ├─ <name>.schema.json                       (only if JSON-schema validation; at app root)
│  ├─ apispec.yaml                             (REST API track only)
│  └─ com/acme/orders/                         BROKER SCHEMA com.acme.orders (dotted package → nested dirs)
│     ├─ <FlowName>.msgflow
│     ├─ <FlowName>_Compute.esql               first line: BROKER SCHEMA com.acme.orders
│     ├─ <FlowName>_HandleException.esql
│     └─ <name>.subflow                        subflows preferred here in the schema folder (root also valid)
└─ <AppName>Java/                              sibling project - ONLY if a ComIbmJavaCompute node is used
```

`computeExpression` = `esql://routine/com.acme.orders#<FlowName>_Compute.Main`. `<AppName>` (the project) and `<FlowName>` (the flow) are independent - one app can hold several flows.

**File 1 - main compute module** (path: `<project>/com/acme/orders/[FlowName]_Compute.esql` - the dotted-package folder):
```esql
BROKER SCHEMA com.acme.orders

CREATE COMPUTE MODULE [FlowName]_Compute

    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        -- [transformation logic here]
        RETURN TRUE;
    END;

END MODULE;
```

The corresponding `computeExpression` in the `.msgflow` is `esql://routine/com.acme.orders#[FlowName]_Compute.Main` - the part before `#` is the `BROKER SCHEMA`, and the file lives in `<project>/com/acme/orders/`.

**File 2 - error handler (include by default, same content for every flow, only module name changes; omit only when the spec explicitly says no error handling). It preserves the ORIGINAL payload - the exception summary travels out-of-band in `MQRFH2.usr.Error` and `Environment.Variables.Error` (`validated_rules.md` §15):**
```esql
CREATE COMPUTE MODULE [FlowName]_HandleException
    -- Preserves the original payload for the error queue; the exception summary
    -- travels in MQRFH2.usr.Error and Environment.Variables.Error (validated_rules.md s15).
    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        DECLARE messageNumber INTEGER;
        DECLARE messageText CHAR;
        CALL GetLastExceptionDetail(InputExceptionList, messageNumber, messageText);
        CALL CopyEntireMessage();
        SET OutputRoot.MQRFH2.usr.Error.Number = messageNumber;
        SET OutputRoot.MQRFH2.usr.Error.Text   = messageText;
        SET OutputRoot.MQRFH2.usr.Error.Flow   = '[FlowName]';
        SET Environment.Variables.Error.Number = messageNumber;
        SET Environment.Variables.Error.Text   = messageText;
        -- SQL diagnostics, when a database Compute set them (validated_rules.md s20)
        IF Environment.Variables.SQL.Failed THEN
            SET OutputRoot.MQRFH2.usr.Error.SQLState = Environment.Variables.SQL.State;
            SET OutputRoot.MQRFH2.usr.Error.SQLCode  = Environment.Variables.SQL.Code;
        END IF;
        RETURN TRUE;
    END;

    CREATE PROCEDURE CopyEntireMessage() BEGIN
        SET OutputRoot = InputRoot;
    END;

    CREATE PROCEDURE GetLastExceptionDetail(IN InputTree REFERENCE, OUT messageNumber INTEGER, OUT messageText CHARACTER)
    BEGIN
        DECLARE ptrException REFERENCE TO InputTree.*[1];
        WHILE lastmove(ptrException) DO
            IF ptrException.Number IS NOT NULL THEN
                SET messageNumber = ptrException.Number;
                SET messageText = ptrException.Text;
            END IF;
            MOVE ptrException LASTCHILD;
        END WHILE;
    END;

END MODULE;
```

Fill in the transformation logic based on the confirmed design. Use these patterns:

**Set HTTP response status:**
```esql
SET OutputRoot.HTTPResponseHeader."X-Original-HTTP-Status-Code" = 202;
SET OutputRoot.HTTPResponseHeader."Content-Type" = 'application/json';
```

**Create JSON output:**
```esql
CREATE FIELD OutputRoot.JSON.Data;
DECLARE refOutput REFERENCE TO OutputRoot.JSON.Data;
SET refOutput.fieldName = 'value';
```

**Read XML input (XMLNSC domain):**
```esql
DECLARE refInput REFERENCE TO InputRoot.XMLNSC.RootElement;
SET refOutput.targetField = refInput.SourceField;
```

**Concatenate strings:**
```esql
SET refOutput.fullName = refInput.FirstName || ' ' || refInput.LastName;
```

**Calculate with rounding:**
```esql
SET refOutput.totalPrice = ROUND(refInput.Quantity * refInput.UnitPrice, 2);
```

**Add current timestamp:**
```esql
SET refOutput.processedAt = CAST(CURRENT_TIMESTAMP AS CHARACTER FORMAT 'IU');
```

**Handle missing/null fields safely:**
```esql
SET refOutput.fieldName = COALESCE(refInput.SourceField, 'DEFAULT_VALUE');
```

**Read JSON input:**
```esql
DECLARE refInput REFERENCE TO InputRoot.JSON.Data;
SET refOutput.targetField = refInput.sourceField;
```

**Create JSON Array output:**
```esql
CREATE FIELD OutputRoot.JSON.Data IDENTITY (JSON.Array)Data;
DECLARE refOutput REFERENCE TO OutputRoot.JSON.Data;
-- Set items via index:
SET refOutput.Item[1].name = 'value1';
```

**Iterate over repeating XML elements:**
```esql
DECLARE i INTEGER 1;
WHILE i <= CARDINALITY(InputRoot.XMLNSC.Items.Item[]) DO
    SET OutputRoot.JSON.Data.Item[i].name = InputRoot.XMLNSC.Items.Item[i].Name;
    SET OutputRoot.JSON.Data.Item[i].value = InputRoot.XMLNSC.Items.Item[i].Value;
    SET i = i + 1;
END WHILE;
```

**Copy all input headers to output (use before transforming in non-HTTP flows):**
```esql
-- Add this procedure to any compute module where you need to preserve message headers
CREATE PROCEDURE CopyMessageHeaders() BEGIN
    DECLARE I INTEGER 1;
    DECLARE J INTEGER;
    SET J = CARDINALITY(InputRoot.*[]);
    WHILE I < J DO
        SET OutputRoot.*[I] = InputRoot.*[I];
        SET I = I + 1;
    END WHILE;
END;
-- Then in Main(): CALL CopyMessageHeaders();
```

**Whole-message copy across a transport boundary (mandatory shape - `validated_rules.md` §17):**
```esql
SET OutputRoot = InputRoot;
-- drop the INBOUND transport's header folders, or the next transport serialises them into the payload
SET OutputRoot.HTTPInputHeader = NULL;      -- HTTP in -> MQ/File/JMS/... out
-- MQ in -> HTTP out instead: SET OutputRoot.MQMD = NULL; SET OutputRoot.MQRFH2 = NULL;
```

**Access MQ MQMD headers (for MQ input flows):**
```esql
DECLARE mqmd REFERENCE TO InputRoot.MQMD;
SET refOutput.msgId    = CAST(mqmd.MsgId AS CHARACTER);
SET refOutput.correlId = CAST(mqmd.CorrelId AS CHARACTER);
SET refOutput.replyTo  = mqmd.ReplyToQ;
```

**Set MQ MQMD headers on output:**
```esql
SET OutputRoot.MQMD.MsgType    = MQMT_DATAGRAM;   -- or MQMT_REPLY, MQMT_REQUEST
SET OutputRoot.MQMD.Persistence = MQPER_PERSISTENT;
SET OutputRoot.MQMD.ReplyToQ   = 'MY.REPLY.QUEUE';
SET OutputRoot.MQMD.CorrelId   = InputRoot.MQMD.MsgId;  -- correlate reply to request
```

**LocalEnvironment routing (for route/filter nodes):**
```esql
-- Set the label to route to (used with RouteToLabel node)
SET OutputLocalEnvironment.Destination.RouterList.DestinationData[1].labelName = 'RouteA';
-- Or set a dynamic MQ queue destination:
SET OutputLocalEnvironment.Destination.MQ.DestinationData[1].queueName = 'TARGET.QUEUE';
```

**Timeout request schema (for ComIbmTimeoutControl):**
```esql
-- The upstream Compute writes these fields; ComIbmTimeoutControl reads
-- them at requestLocation="InputLocalEnvironment.TimeoutRequest".
SET OutputLocalEnvironment.TimeoutRequest.Action         = 'SET';   -- or 'CANCEL'
SET OutputLocalEnvironment.TimeoutRequest.Identifier     = 'RETRY01';  -- must match TimeoutNotification.uniqueIdentifier (1-12 chars)
SET OutputLocalEnvironment.TimeoutRequest.StartDate      = CURRENT_DATE;
SET OutputLocalEnvironment.TimeoutRequest.StartTime      = CURRENT_TIME + INTERVAL '30' SECOND;
SET OutputLocalEnvironment.TimeoutRequest.Count          = 1;       -- fire once
SET OutputLocalEnvironment.TimeoutRequest.IgnoreMissed   = FALSE;
SET OutputLocalEnvironment.TimeoutRequest.AllowOverwrite = TRUE;    -- required when Identifier is static
```

`Action='SET'` schedules a fire; `Action='CANCEL'` cancels a pending one with the matching `Identifier`. See `validated_rules.md` §7 for the paired-node identifier rule.

**Timestamp arithmetic - adding durations:**

ESQL's `+` operator does NOT auto-cast strings to intervals. `BIP2420E: Invalid or incompatible data types for '+' operator` is the error you get when you concatenate a unit name onto an integer.

```esql
-- WRONG - string concatenation, no auto-cast
SET fireTime = fireTime + (CAST(backoffSec AS CHARACTER) || ' SECONDS');

-- WRONG - INTEGER has no implicit unit
SET fireTime = fireTime + backoffSec;

-- WRONG - INTERVAL constructor only accepts a literal
SET fireTime = fireTime + INTERVAL backoffSec SECOND;

-- CORRECT - fixed delay
SET fireTime = fireTime + INTERVAL '30' SECOND;

-- CORRECT - variable delay (INTERVAL × INTEGER is supported)
SET fireTime = fireTime + (INTERVAL '1' SECOND) * backoffSec;
```

For other units: `(INTERVAL '1' MINUTE) * mins`, `(INTERVAL '1' HOUR) * hours`, `(INTERVAL '1' DAY) * days`. Same pattern works for `CURRENT_TIMESTAMP`, `CURRENT_TIME`, `CURRENT_DATE`, and any `GMTTIMESTAMP` value.

**Distinguishing exception-list vs response-body errors (HTTPRequest unified handler):**

When `OutTerminal.error` (HTTP 4xx/5xx) and `OutTerminal.failure` (connection failure) are both wired into the same Compute, dispatch on `InputExceptionList`:

```esql
CREATE FUNCTION Main() RETURNS BOOLEAN
BEGIN
    DECLARE reason CHARACTER;
    DECLARE retryable BOOLEAN FALSE;

    IF CARDINALITY(InputExceptionList.*[]) > 0 THEN
        -- Arrived via 'failure' terminal - connection-level error.
        -- No HTTP response, exception details are in the list.
        SET reason = 'Connection failure';
        SET retryable = TRUE;   -- always retry connection failures
    ELSE
        -- Arrived via 'error' terminal - HTTP error response.
        -- Status code is in the standard response-header field.
        DECLARE statusCode INTEGER;
        SET statusCode = COALESCE(
            InputRoot.HTTPResponseHeader."X-Original-HTTP-Status-Code",
            InputLocalEnvironment.Destination.HTTP.ReplyStatusCode);
        SET reason = 'HTTP ' || CAST(statusCode AS CHARACTER);
        -- Classify: 408 timeout, 429 too many requests, 5xx server errors → retry
        IF statusCode IN (408, 429) OR (statusCode >= 500 AND statusCode < 600) THEN
            SET retryable = TRUE;
        END IF;
    END IF;

    SET Environment.Variables.Retry.Reason = reason;
    IF retryable THEN
        PROPAGATE TO TERMINAL 'out1';   -- retry branch
    ELSE
        PROPAGATE TO TERMINAL 'out2';   -- fatal branch
    END IF;
    RETURN FALSE;
END;
```

See `validated_rules.md` §8 (HTTPRequest terminal semantics) and §9 (Unify error/failure classification).

**BLOB domain - reparse BLOB as JSON:**
```esql
DECLARE CodedCharSetId INT 1208;
SET OutputRoot.Properties = InputRoot.Properties;
CREATE LASTCHILD OF OutputRoot DOMAIN('JSON')
    PARSE(InputRoot.BLOB.BLOB CCSID CodedCharSetId);
```

**JSON to BLOB (serialize):**
```esql
SET OutputRoot.Properties = InputRoot.Properties;
CREATE LASTCHILD OF OutputRoot DOMAIN('BLOB');
DECLARE options INTEGER BITOR(FolderBitStream, ValidateNone);
SET OutputRoot.BLOB.BLOB = ASBITSTREAM(InputRoot.JSON.Data
    OPTIONS options CCSID InputRoot.Properties.CodedCharSetId);
```

**DFDL domain (Fixed-Length or Delimited) - convert to XML:**
```esql
SET OutputRoot.Properties = InputRoot.Properties;
CREATE LASTCHILD OF OutputRoot DOMAIN('XMLNSC');
SET OutputRoot.XMLNSC.Message = InputRoot.DFDL.MessageFixedLength;  -- or MessageDelimited
```

**XML to DFDL (Fixed-Length):**
```esql
SET OutputRoot.Properties = InputRoot.Properties;
CREATE LASTCHILD OF OutputRoot DOMAIN('DFDL');
SET OutputRoot.DFDL.MessageFixedLength = InputRoot.XMLNSC.Message;
```

**Database SELECT (in a Compute node with database datasource configured):**
```esql
SET OutputRoot.XMLNSC.Results.Row[] =
    SELECT T.COL1, T.COL2, T.COL3
    FROM Database.MYSCHEMA.MYTABLE AS T
    WHERE T.KEY = refInput.KeyValue;
```

**Database UPDATE using PASSTHRU:**
```esql
PASSTHRU 'UPDATE MYSCHEMA.MYTABLE SET STATUS = ? WHERE ID = ?'
    VALUES(newStatus, recordId);
```
No parentheses around the SQL string when a separate `VALUES(...)` clause follows - that is the PASSTHRU *statement* form. The parenthesised `PASSTHRU(...)` *function* form only accepts comma-appended arguments, and mixing the two fails to load on 13.0.8.1 with `Syntax error: expected ; but found keyword Values`.

**Database access with error handling and diagnostics (mandatory shape - `validated_rules.md` §20):**
```esql
-- Doc-verified syntax (IBM "DECLARE HANDLER statement"): ESQL has no FOR SQLEXCEPTION.
-- Database exceptions carry SQLSTATE class 'D' (IBM doc "SQLSTATE function"); the block
-- holds ONLY the database statement(s).
SET Environment.Variables.SQL.Failed = FALSE;
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLSTATE LIKE 'D%' BEGIN
        SET Environment.Variables.SQL.Failed      = TRUE;
        SET Environment.Variables.SQL.Code        = SQLCODE;
        SET Environment.Variables.SQL.State       = SQLSTATE;
        SET Environment.Variables.SQL.NativeError = SQLNATIVEERROR;
        SET Environment.Variables.SQL.ErrorText   = SQLERRORTEXT;
    END;
    INSERT INTO Database.[DSN].dbo.[TABLE] (COL_A, COL_B) VALUES (valueA, valueB);
END;
IF Environment.Variables.SQL.Failed THEN
    PROPAGATE TO TERMINAL 'failure';   -- wired to HandleException; payload still intact
    RETURN FALSE;
END IF;
SET Environment.Variables.SQL.RowCount = 1;   -- or the count the statement form gives you
-- Trace nodes on both paths include ${Environment} so SQL.* reaches the log.
```

**Declare XML namespace:**
```esql
DECLARE myns NAMESPACE 'http://my.company.com/schema/v1';
SET OutputRoot.XMLNSC.myns:RootElement.myns:Field = 'value';
```

##### Filter modules - for `ComIbmFilter` nodes

A `ComIbmFilter` node uses a `FILTER MODULE` (not a `COMPUTE MODULE`). The function returns a boolean that drives the `true` / `false` terminal - the message itself is not modified.

File path rules are identical to compute modules (default schema at project root; named schema under `<project>/<X with dots → slashes>/`).

```esql
CREATE FILTER MODULE DlhFilter
    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        IF CARDINALITY(InputRoot.MQDLH[]) > 0
           AND InputRoot.MQDLH.DestQName IS NOT NULL
           AND TRIM(InputRoot.MQDLH.DestQName) <> ''
        THEN
            RETURN TRUE;
        END IF;
        RETURN FALSE;
    END;
END MODULE;
```

On the `.msgflow` side:
```xml
<nodes xmi:type="ComIbmFilter.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_2"
  location="260,140" filterExpression="esql://routine/#DlhFilter.Main">
  <translation xmi:type="utility:ConstantString" string="Has DLH?"/>
</nodes>
```

The Filter node has **three** output terminals: `true`, `false`, `unknown`. `unknown` fires when the filter function throws - wire it to an error path if you need defensive handling, otherwise leaving it unconnected is fine.

**Pick Filter over Route when** the routing decision is boolean and there are exactly two paths. Use a `ComIbmRouteToLabel` + Label nodes when there are 3+ paths or the decision is a string-match (REST operation dispatch, multi-way enrichment).

##### Fan-in via `PROPAGATE TO LABEL`

When several compute nodes need to feed the same downstream step (typically central logging or audit), don't wire N connections back to a single sink. Use a disconnected `ComIbmLabel` node and have each compute node propagate to it from ESQL.

1. Place a `ComIbmLabel` node with a `labelName` attribute (SHOUTY names by convention: `LOG`, `ERROR`, `AUDIT`) somewhere on the canvas, disconnected from the main pipeline.
2. Wire the Label's `out` terminal to the downstream step (Trace, Log subflow, MQOutput, whatever).
3. In every compute node that needs to fan in, set the data on `Environment.Variables.<topic>.*` and then:

```esql
SET Environment.Variables.Log.Entry.type   = 'INFO';
SET Environment.Variables.Log.Entry.status = 'triggered';
SET Environment.Variables.Log.Entry.guid   = Environment.Variables.ActivityId;
PROPAGATE TO LABEL 'LOG' DELETE NONE;
```

`DELETE NONE` keeps the outgoing message untouched so the normal propagation along the compute node's `out` terminal is unaffected - both happen. `DELETE DEFAULT` would consume the outgoing message, which is usually wrong for logging fan-in.

On the `.msgflow` side:
```xml
<nodes xmi:type="ComIbmLabel.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_6"
    location="40,340" labelName="LOG">
  <translation xmi:type="utility:ConstantString" string="LOG"/>
</nodes>
<nodes xmi:type="ComIbmTrace.msgnode:FCMComposite_1" xmi:id="FCMComposite_1_7"
    location="260,340" destination="localError" pattern="${Environment}">
  <translation xmi:type="utility:ConstantString" string="Log Trace"/>
</nodes>
<connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_6"
    targetNode="FCMComposite_1_7" sourceNode="FCMComposite_1_6"
    sourceTerminalName="OutTerminal.out" targetTerminalName="InTerminal.in"/>
```

**Use this pattern when ≥ 3 compute nodes need shared logging.** With only 2, drawing the wires is simpler. With many wires converging on a single logging node, the diagram becomes unreadable and the Label/PROPAGATE pattern wins.

#### 3.3 Generate Project Files

Provide the minimal project files needed to deploy as an ACE application. **Use exactly the templates below** - they are verified against a working ACE v13 Toolkit project (`C:\Users\<user>\IBM\ACET13\workspace\TestApp\`). Older Broker-era variants cause the project to import as **Independent Resource** instead of **Application Development**.

**If the flow uses a `ComIbmJavaCompute` node**, also generate a sibling `<AppName>Java` Java project - see [`references/java_compute_project.md`](java_compute_project.md) for the full layout: `.project` natures (`javanature` + `jcnnature` + `barnature`), `.classpath` template, third-party jar paths (`com.ibm.mq.allclient.jar` for `MQConstants.lookup`), Java source skeleton, and the application-side `<projects>` reference that links them.

**`.project` file:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<projectDescription>
	<name>[FlowName]</name>
	<comment></comment>
	<projects>
	</projects>
	<buildSpec>
		<buildCommand>
			<name>com.ibm.etools.mft.applib.applibbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.applib.applibresourcevalidator</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.connector.policy.ui.PolicyBuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.applib.mbprojectbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.msg.validation.dfdl.mlibdfdlbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.flow.adapters.adapterbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.flow.sca.scabuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.msg.validation.dfdl.mbprojectresourcesbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.esql.lang.esqllangbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.map.builder.mslmappingbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.flow.msgflowxsltbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.flow.msgflowbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.decision.service.ui.decisionservicerulebuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.pattern.capture.PatternBuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.json.builder.JSONBuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.restapi.ui.restApiDefinitionsBuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.policy.ui.policybuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.msg.assembly.messageAssemblyBuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.msg.validation.dfdl.dfdlqnamevalidator</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.bar.ext.barbuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
		<buildCommand>
			<name>com.ibm.etools.mft.unittest.ui.TestCaseBuilder</name>
			<arguments>
			</arguments>
		</buildCommand>
	</buildSpec>
	<natures>
		<nature>com.ibm.etools.msgbroker.tooling.applicationNature</nature>
		<nature>com.ibm.etools.msgbroker.tooling.messageBrokerProjectNature</nature>
	</natures>
</projectDescription>
```

The two natures `applicationNature` and `messageBrokerProjectNature` are what mark this as an ACE Application (visible under **Application Development** on import). The old `aceApplicationNature` value is wrong - projects with that nature show up under **Independent Resources**.

Use the buildSpec above **verbatim** - exactly these 21 buildCommands, in this order, no others. Do **not** invent or substitute builders: `coveragebuilder`, `psqlbuilder`, and an `org.eclipse.ui.externaltools.ExternalToolBuilder` (with a `LaunchConfigHandle`/`.launch` reference) are **not** part of this template and cause the Toolkit to report *"project description file is corrupted"* on import.

**REST API projects use a different `.project`** - they add the `com.ibm.etools.mft.restapi.ui.Nature` nature plus the `restApiBuilder` and `restApiDefinitionsBuilder` build commands. Use the variant in `references/restapi_build.md` §4.7, not the template above.

**`application.descriptor` file:**

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?><ns2:appDescriptor xmlns="http://com.ibm.etools.mft.descriptor.base" xmlns:ns2="http://com.ibm.etools.mft.descriptor.app"><references/></ns2:appDescriptor>
```

Single-line on purpose - that's how ACE v13 Toolkit emits it. The Broker-era namespace `com.ibm.broker.config.appdev.api.applicationDescriptor` is wrong for v13.

**`.settings/org.eclipse.core.resources.prefs` file** (Eclipse-required, in a `.settings/` subdirectory at the project root):

```
eclipse.preferences.version=1
encoding/<project>=UTF-8
```

The `<project>` is literal text, not a placeholder - Eclipse uses it as the key matching the project root. Without this file the Toolkit emits encoding warnings on every import. Verified against `C:\Users\<user>\IBM\ACET13\workspace\TestApp\.settings\org.eclipse.core.resources.prefs`.

#### 3.4 Deployment Note - written to `<project>/DEPLOY.md`

After all files, write the deployment steps to `<project>/DEPLOY.md` (a fixed artifact name: the test hop reads it by path) and summarise them in the manifest. Sections, in order: prerequisites the deployer must fill in (every `[CONFIGURE: ...]` marker in policies or overrides); vault creation and each `ibmint set credential` (names only, never values); package; server-level settings that go in `overrides/*.yaml` (never the base file - rule 19); deploy order (policy project before or with the application); verification (the BIP codes and one request to expect). Use the correct command form based on what the user has:

**Standard: package then deploy separately:**
```bash
# Package all projects in the workspace into a BAR file
ibmint package --compile-maps-and-schemas --input-path C:\MyWorkspace --output-bar-file [FlowName].bar

# (Optional) Apply property overrides before deploying
# Create a file like: [FlowName]#RuntimeProperty=value
ibmint apply overrides overrides.properties --bar-file [FlowName].bar

# Deploy BAR to integration server
ibmint deploy --input-bar-file [FlowName].bar --integration-server [ServerName] --work-directory work_dir/
```

**Alternative: single command (no separate BAR file):**
```bash
ibmint deploy --input-path C:\MyWorkspace --overrides-file overrides.properties --output-work-directory work_dir/
```

**Standalone Integration Server (no node required - start + deploy in one step):**
```bat
REM 1. Package the project into a BAR file
ibmint package --input-path . --output-bar-file [FlowName].bar --project [FlowName]

REM 2. Start a standalone Integration Server (picks up the BAR automatically from work_dir/run/)
xcopy /Y [FlowName].bar work_dir\run\
IntegrationServer --work-dir work_dir --name [ServerName] --admin-rest-api 7600 --http-port-number 7800 --console-log
```
This is the pattern used in the `SimpleHTTPResponse` demo. The server starts and immediately serves the deployed flow at `http://localhost:7800/[url-path]`.

**Verify deployment:**
```bash
# Admin REST API (integration node setup)
curl http://localhost:7600/apiv2/integrationservers/[ServerName]/applications

# Local integration server - check the console window for BIP2269I (application deployed)
```

In Toolkit: drag-and-drop the `.bar` file onto the integration server in the Integration Explorer view.

#### 3.5 Manual Configuration Reminder

List anything the user must configure manually in ACE Toolkit. The skill is responsible for everything that can be expressed in `.msgflow` XML and `.esql`. Genuine manual-config items are typically:

- Queue manager binding (per-server runtime decision)
- Credentials / vault entries (security boundary)
- Environment-specific URLs and hostnames (Toolkit overrides or BAR property overrides)

Do **not** hedge on attribute names, terminal names, or schema-directory layout - those are the skill's job and must be correct in the generated files. If something is uncertain, search the user's filesystem (Phase B0.5a) before guessing.

#### 3.6 (Iterative mode only) - Write `<FlowName>.flow_state.md`

In Iterative mode, every Build pass writes a state file to the project root capturing decisions made and open questions. This survives across turns and across sessions.

**Path:** `<project>/<FlowName>.flow_state.md`

**Template:**

```markdown
# <FlowName> - Flow Builder State

**Last updated:** <YYYY-MM-DD HH:MM>
**Build mode:** Iterative
**Iteration:** <N>

## Confirmed
- Flow name: <FlowName>
- Pattern: <pattern from B0>
- Project location: <path>
- Input: <source + format>
- Output: <destination + format>
- ...

## Assumed (please confirm or override)
- <assumption 1, with default chosen>
- <assumption 2>

## Open questions
- [ ] <question 1>
- [ ] <question 2>

## Iteration history
- v0.1 (<date>): initial generate from minimum viable info
- v0.2 (<date>): <delta>

## Validation Results
<!-- Phase B5 appends one entry per validation run (level 2 or level 3). -->
<!-- Credentials are NEVER recorded here - only the vault commands invoked, never the values. -->

### v<N> (<date>) - level: <build / build+deploy / build+deploy+run>
Commands run:
  - <list of ibmint package / ibmint apply overrides / IntegrationServer / amqsput / curl invocations actually executed>
Dependencies used: <local QM1 via dspmq, Docker MQ container <name>, mock URL http://localhost:7801, etc.>
Result: PASS / FAIL - <details + scenario-by-scenario summary if level 3>
TESTING.md: <project>/TESTING.md (updated)
Notes: <one-line follow-ups>
```

Update this file on every iteration. When the user asks for a refinement, read it first to recover context. Phase B5 appends to "Validation Results" - do not overwrite earlier entries.

#### 3.7 Phase B3 sanity check (mandatory)

Before declaring the build done, walk this checklist. Every item must be ✅ or the build is broken.

- [ ] **No tool signature/watermark in ANY file.** Open every generated file and delete any `<!-- Made with Bob -->` / `Generated by …` / `Created with …` comment - including ones the runtime/editor may auto-append. A signed `.project` / `application.descriptor` / `.msgflow` is a hard failure, not cosmetic.
- [ ] `.project` `<natures>` contains `com.ibm.etools.msgbroker.tooling.applicationNature` AND `com.ibm.etools.msgbroker.tooling.messageBrokerProjectNature` (NOT the old `aceApplicationNature`)
- [ ] `.project` `<buildSpec>` is **exactly** the verified 21 buildCommands from §B3.3, in order, with **no invented builders** (no `coveragebuilder` / `psqlbuilder` / `ExternalToolBuilder`) - an invented buildSpec makes the Toolkit report *"project description file is corrupted"* on import
- [ ] `application.descriptor` uses the `ns2:appDescriptor` namespace (NOT the Broker-era `com.ibm.broker.config.appdev.api.applicationDescriptor`)
- [ ] `.settings/org.eclipse.core.resources.prefs` is generated (optional - Toolkit recreates it if missing, and the real reference projects omit it; generate it anyway, it doesn't hurt) with `eclipse.preferences.version=1` + `encoding/<project>=UTF-8` (the `<project>` is literal Eclipse syntax, not a placeholder)
- [ ] Every attribute on every `<nodes xmi:type="...">` element appears in `references/msgflow_format.md` or in `references/examples/` - no invented attribute names
- [ ] Every `<nodes>` element has a `<translation xmi:type="utility:ConstantString" string="...">` child whose `string` describes the action, not the node type - no self-closing Compute nodes
- [ ] **Schema triple - state the values, don't just tick.** For each ESQL module, write out the triple and confirm the same `<X>` appears in all three: (a) `BROKER SCHEMA <X>`, (b) file path `<project>/<X with dots → slashes>/<file>.esql`, (c) URI `esql://routine/<X>#<Module>.Main`. An ESQL file at the project root while it declares a `BROKER SCHEMA` is a **FAILURE** - move it into the `<X>/` subfolder. A bare `esql://routine/#<Module>.Main` URI paired with a `BROKER SCHEMA` line is a **FAILURE** - qualify it. Each URI must also resolve to a real file containing a matching `CREATE COMPUTE MODULE <Module>`.
- [ ] **`nsURI` / `nsPrefix` = the `.msgflow`'s path relative to the project root** - the same `<X>` as the schema triple (dots→slashes) plus the filename, e.g. `com/acme/orders/OrderProcessor.msgflow`. Bare `FlowName.msgflow` is correct ONLY for a default-schema root flow. Mismatch imports as *"Namespace URI in flow does not match its location"* - see `msgflow_format.md` "nsURI / nsPrefix".
- [ ] **Every node's `<translation string="...">` label is unique within the flow** - duplicates import as *"Node name is not unique within the flow"*. Distinguish repeated shapes with a suffix. (This and the `nsURI` item are Toolkit-only: neither fails `ibmint`/runtime, so a clean deploy does NOT prove them - eyeball the XMI.)
- [ ] **Every `ComIbmX.msgnode` used in an `xmi:type` has a matching `xmlns:ComIbmX.msgnode="ComIbmX.msgnode"` on the EPackage root.** Adding a node type to an existing flow means adding its xmlns line in the same edit. The runtime does not need it - `ibmint` compiles and the flow serves every request - while the Toolkit silently DROPS those nodes and flags their connection endpoints as unlocatable. Toolkit-only, so a green deploy proves nothing.
- [ ] **`colorGraphic16` + `colorGraphic32` are present on the FCMComposite** (`platform:/plugin/<project>/icons/full/obj16|obj30/<flow>.gif`), with a `bundleName` qualified the same way as `nsURI` for a non-root schema. Without them the flow deploys and runs fine but the Toolkit editor cannot re-save it - `GIFFileGraphic.getResourceName` NPE - which locks the user out of editing their own flow.
- [ ] **No shared `DECLARE … NAMESPACE`/constant/procedure is declared at `BROKER SCHEMA` scope in more than one `.esql` of the same schema** - it is global; a duplicate is a load-time **BIP4128E** that cascades into spurious BIP4127E on other modules. Declare once, or function-local - see `validated_rules.md` §14.
- [ ] The application is in its OWN new `<AppName>/` subfolder of the given location - `.project` / `application.descriptor` / `.msgflow` / `.esql` are NOT written directly into the given path (which is the workspace/parent)
- [ ] If the user supplied a workspace path: project location is under that workspace, not under `D:\tmp\` or similar throwaway path
- [ ] `OutTerminal.catch` AND `OutTerminal.failure` are wired to a `HandleException` Compute node on every input/source node - **unless** the spec explicitly says no error handling (then no `_HandleException` module and no wiring is expected). An MQInput `failure` terminal left dangling without a written justification in `flow_state.md`/README is a **FAILURE** - see `validated_rules.md` §15
- [ ] **On MQ-input flows the error path persists the original payload before commit:** `HandleException` calls `CopyEntireMessage()` (never replaces the body with the exception summary) and its `out` terminal goes to an `ErrorQueue` MQOutput (`<FlowName>.ERROR`, `[CONFIGURE: error queue]` in Iterative mode) or the documented backout queue - `validated_rules.md` §15
- [ ] **Every Compute that touches a database has an ESQL handler** (`DECLARE CONTINUE HANDLER FOR SQLSTATE ...` around only the DB statements), captures `SQLCODE`/`SQLSTATE`/`SQLNATIVEERROR`/`SQLERRORTEXT` (and row count where the statement form allows) into `Environment.Variables.SQL.*`, propagates to its `failure` terminal (wired to `HandleException`) on failure, and the Trace nodes include `${Environment}` - `validated_rules.md` §20
- [ ] **No Trace node with a hardcoded absolute `filePath`** (`C:\temp\...`); debug traces use `destination="localError"`, and no success-path Trace writes `${Root}`/`${Body}` to `localError` - `validated_rules.md` §21
- [ ] **If a policy project was produced, something applies it** - `remoteDefaultQueueManager` in the documented `overrides/server.conf.yaml`, or a node reference, or a deploy step written in `DEPLOY.md`. An unreferenced policy project is a **FAILURE**; the policyxml follows the Toolkit shape in `msgflow_format.md` (`policyTemplate=""`, `destinationQueueManagerName` present) - `validated_rules.md` §22
- [ ] **A policy project has its `policy.descriptor`** next to `.project` and the `.policyxml` files - without it `ibmint package` reports BIP15214E "No valid resources found" (2026-10-11). Toolkit shape, write it verbatim:
  `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>` then `<ns2:policyProjectDescriptor xmlns="http://com.ibm.etools.mft.descriptor.base" xmlns:ns2="http://com.ibm.etools.mft.descriptor.policyProject"><references/></ns2:policyProjectDescriptor>`
- [ ] **No `overrides/` folder inside the application project** - everything under the project is packed into the BAR. Server overrides go to the sibling `<AppName>.server-overrides/server.conf.yaml`, and `DEPLOY.md` says to merge those keys into `<work_dir>/overrides/server.conf.yaml`
- [ ] **The customer profile's logging is wired, not just referenced:** when the profile names logging subflows (for example `LoggingLibrary` / `ActivityLogLib`), each flow carries them at the points the profile names (entry, exit, error, intermediate steps) and the libraries are in `.project` `<projects>`. A `<projects>` entry with no subflow node using it is a FAILURE; a library missing from the workspace is reported in the manifest, never silently left out of the flow. Check it by counting, not by reading comments: each msgflow contains `xmi:type="<Lib>_<Subflow>.subflow:FCMComposite_1"` nodes (shape in `msgflow_format.md`, "Subflow nodes from a shared library") at least as many times as the design places them, and each such namespace value names an existing `.subflow` in the library. `ibmint package` cannot catch this - it packages unresolved subflow references (2026-10-12)
- [ ] **Every `ComIbmMQOutput` / `ComIbmMQReply` carries an explicit `messageContext="default"`** (or `passAll`/`setAll` only with a named identity that holds the authority) - `validated_rules.md` §23
- [ ] **Cross-transport flows drop the inbound transport headers after any whole-message copy** (`SET OutputRoot.HTTPInputHeader = NULL` for HTTP in -> MQ/File out; `MQMD`/`MQRFH2` for MQ in -> HTTP out) - `validated_rules.md` §17
- [ ] **MQ client connection shape follows the customer profile when present, otherwise the brief, never a recalled run - and the choice is written in `flow_state.md`:** under the policy shape, host/port/channel/user in the brief populate an MQEndpoint policy applied via `overrides/server.conf.yaml` and the flow carries only `queueName`; node-level attributes when the profile or the brief says so - `validated_rules.md` §22
- [ ] **No hand-built `OutputRoot.MQMD` on an MQOutput path:** the node creates the default MQMD and persistence is its Persistence mode property; an MQMD field is set only for a brief-required override (MQRFH2 `Format`, receiver `Format`, `CorrelId` / `Expiry` / reply-to) with a WHY comment - `validated_rules.md` §26
- [ ] If a `ComIbmWSRequest` is present and retry/error-classification is in scope: `error` and `failure` terminals are wired (not just `out`) - see `validated_rules.md` §8
- [ ] **HTTP behaviour checks** (each one failed in a deployed agent-generated build on 2026-10-12 although the matched example showed the right shape - read the example's README "shapes that matter" and apply them, do not just read them):
  - every non-200 HTTP reply sets `OutputLocalEnvironment.Destination.HTTP.ReplyStatusCode` in a Compute whose `computeMode` includes the destination (`destinationAndMessage`) after copying `InputLocalEnvironment`; a status set in `HTTPResponseHeader` / `X-Original-HTTP-Status-Code` is ignored by WSReply. Grep: each WSReply on a 202/400/500 path is preceded by such a Compute
  - every HTTP reply body is a FRESH tree (`OutputRoot.Properties` then `OutputRoot.JSON.Data.*`), never `InputRoot` or the message that just went to MQ - a copied queue message comes back to the caller as raw MQMD/MQRFH2 bytes
  - JSON arrays are created with `CREATE LASTCHILD OF ref IDENTITY(JSON.Array)name` and one `Item` child per element; `SET ref.name.Item[i] = ...` without the array identity serialises as an object
  - a lookup call whose failure must not stop the work (enrichment) wires `out`, `error` AND `failure` onward to the same next node and computes a fallback there - nothing is left unwired
  - a final outbound call that fails (callback, notification) parks the ORIGINAL request (rebuilt from `Environment`) on the error queue and the flow ends normally; it never throws back to the MQ Input node, which would roll back and redeliver the same message until the backout threshold
  - the HTTP Input `catch` and `failure` terminals lead to a reply with an explicit 500 status (a non-JSON body fails the parse there)
  - a Validate node that checks a JSON schema (`checkSet="true"`, `set="<x>.schema.json"`) has the SAME schema bound on the upstream input node (`messageSetProperty="<x>.schema.json"` next to `messageDomainProperty="JSON"`, `msgflow_format.md` Validate section); without it every message, valid or not, fails with ERROR_CODE 4162 "Domain, set or type check failed" and the caller only ever gets the 400 (2026-10-12)
  Record each item pass/fail in the manifest; a fail is fixed before the deploy check.
- [ ] **MQ worker and ESQL tree checks** (each one broke valid traffic in a tune pass on 2026-10-12 while the deploy check stayed clean):
  - the body's parser is the MQ Input node's Message domain, UNLESS the message carries an MQRFH2 whose `mcd` folder names one - then that parser wins. A job from another ACE flow carries such an RFH2 (JSON), so a node set to BLOB still delivers `InputRoot.JSON.Data` and `InputRoot.BLOB` does not exist (measured 2026-10-12: `messageDomainProperty="BLOB"`, BIP2906E on the BLOB read). Read the body where the producer's messages put it, and when the flow must also take RFH2-less bytes, normalise both shapes in front of the parsing code (a ResetContentDescriptor to BLOB, then parse once)
  - an HTTP-to-MQ flow that adds an MQRFH2 creates `OutputRoot.MQMD` first (the HTTP tree has none; `validated_rules.md` §2), and does not carry the inbound schema binding onto the queue: `Properties.MessageSet` / `MessageType` / `MessageFormat` from the HTTP input end up in the RFH2 `mcd` and the consumer cannot parse the message. Prove it by dumping one queued message (`amqsbcg`) and reading MQMD Format and the `mcd` folder
  - no REFERENCE into a subtree is used after that subtree is deleted (`DELETE FIELD`, `SET ... = NULL`): copy what is still needed to `Environment` first and read the copy - a dangling reference yields NULL silently, not an error
  - an HTTP Request node whose URL is set at runtime (`LocalEnvironment.Destination.HTTP.RequestURL`) carries a static URL that cannot resolve (`http://unset.invalid/`), and the Compute that sets the URL throws when its inputs are NULL: a static URL pointing at a real endpoint turned a missing id into a quiet wrong answer
- [ ] If a paired `ComIbmTimeoutControl` + `ComIbmTimeoutNotification` is present: both nodes' `uniqueIdentifier` matches exactly, and the upstream Compute sets `AllowOverwrite = TRUE` - see `validated_rules.md` §7
- [ ] If a `ComIbmResetContentDescriptor` is present: `resetMessageDomain="true"` and its `messageDomain` differs from the effective upstream domain - otherwise the node does nothing, and if the intent was validation it MUST be a Validate node instead. If it carries `validateMaster`, `validateTiming="complete"` is written explicitly (absent = On Demand = lazy) - see `validated_rules.md` §18
- [ ] **Any id the flow returns, logs or correlates on is minted by the flow, not read from the payload:** the first Compute sets `Environment.Variables.Tracking.Id = UUIDASCHAR` once, the error path and the reply carry it, and a missing payload `id` never routes to `failure` - `validated_rules.md` §24
- [ ] **Kafka nodes use the connector-family types** (`com/ibm/connector/kafka/ComIbmOutput.msgnode` / `ComIbmEventInput.msgnode`, `connectorName="Kafka"`); `ComIbmKafkaMsgProducer` / `ComIbmKafkaMsgConsumer` only when the brief asks for transactional publishing or consuming - `validated_rules.md` §25
- [ ] (Iterative mode) `flow_state.md` is written and lists every assumption made
- [ ] **(REST API track only)** the REST-specific checks in `references/restapi_build.md` §6 all pass - descriptor consistent with the spec and subflows, three handler subflows, ESQL at project root with default schema (no `BROKER SCHEMA`), REST-natured `.project`, `gen/<Api>.msgflow` present with the auto-generated sticky note

If any item is ❌, fix it before reporting the build complete. Do not ask the user to "verify in Toolkit" what the skill should have got right.

#### 3.7b Final step - strip signatures (mandatory, every run)

After the sanity check and **before** returning your results, do an explicit signature-removal pass - every run, even if you added nothing yourself:

1. List every file you generated or touched (`.project`, `application.descriptor`, `.msgflow`, `.esql`, `.subflow`, `.json`, `.md`, `.settings/*`).
2. Search each for any tool/attribution footer or watermark: `Made with Bob`, `<!-- Made with Bob -->`, `Generated by`, `Created with`, `AI-assisted`, or similar.
3. **Delete** every match (and any empty trailing comment / blank line it leaves) - *including* footers the runtime/editor may auto-append **after** you write a file; re-open and remove them.
4. Re-scan to confirm **zero** matches remain anywhere. Only then return your results (file manifest + sanity-check outcomes); the main conversation presents the §3.8 close-out menu from `references/workflow.md`. In fallback mode (no subagent), present that menu yourself after this step.

The user owns the output - one surviving signature is a failed run.


---

## Node Type Reference

| Node Type | Use case | Key properties |
|-----------|----------|----------------|
| `ComIbmWSInput` | HTTP/HTTPS input | `urlSpecifier`, `requestMsgDomain`, HTTP methods |
| `ComIbmWSReply` | HTTP/HTTPS reply | response status via `HTTPResponseHeader` in ESQL |
| `ComIbmCompute` | ESQL transformation | `computeMode`, `esqlModule` |
| `ComIbmMQInput` | Read from MQ queue | `queueName`, `transactionMode` |
| `ComIbmMQOutput` | Write to MQ queue | `queueName` |
| `ComIbmMQGet` | Synchronous MQ get | `queueName`, used mid-flow |
| `ComIbmFilter` | Conditional routing | uses XPath-like expressions |
| `ComIbmRoute` | Pattern-based routing | `distributionMode` |
| `ComIbmFileInput` | Read from filesystem | `inputDirectory`, `fileNamePattern` |
| `ComIbmFileOutput` | Write to filesystem | `outputDirectory` |
| `ComIbmTryCatch` | Error handling wrapper | catches exceptions within a subflow |

---

## ESQL Compute Mode Reference

The Compute mode selects which trees the node **propagates** - it never copies
anything (see `validated_rules.md` rules 16-17). A tree not included in the mode
propagates its **input** version; writes to its `Output*` correlation are silently
discarded.

| `computeMode` literal (.msgflow) | Toolkit label | Output trees propagated |
|------|------|------|
| `message` (default - omit the attribute) | Message | `OutputRoot` |
| `destination` | LocalEnvironment | `OutputLocalEnvironment` |
| `destinationAndMessage` | LocalEnvironment and Message | `OutputRoot` + `OutputLocalEnvironment` |
| `exception` | Exception | `OutputExceptionList` |
| `exceptionAndMessage` | Exception and Message | `OutputRoot` + `OutputExceptionList` |
| `exceptionAndDestination` | Exception and LocalEnvironment | `OutputLocalEnvironment` + `OutputExceptionList` |
| `all` | All | all three |

There is no `Environment` compute mode: the `Environment` tree is one flow-wide tree
outside the mode system, addressed as `Environment` in every node -
`InputEnvironment` / `OutputEnvironment` do not exist. Flow-lifetime state goes in
`Environment.Variables.*` (works in any mode); routing/destination data goes in
`OutputLocalEnvironment` + `destinationAndMessage` or `all`.

---

## Example: HTTP Request-Reply Flow (from Demo)

This worked example can be used when the user asks for a flow matching this pattern: HTTP POST → compute (passthrough or XML-to-JSON transform) → HTTP 202 reply.

### Simple Passthrough Version

Accepts any request, returns HTTP 202 with a JSON acknowledgement.

**ESQL:**
```esql
BROKER SCHEMA SimpleHTTPResponse

CREATE COMPUTE MODULE SimpleHTTPResponse_Compute

    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        SET OutputRoot.HTTPResponseHeader."X-Original-HTTP-Status-Code" = 202;
        SET OutputRoot.HTTPResponseHeader."Content-Type" = 'application/json';

        CREATE FIELD OutputRoot.JSON.Data;
        DECLARE refOutput REFERENCE TO OutputRoot.JSON.Data;

        SET refOutput.status = 'accepted';
        SET refOutput.timestamp = CAST(CURRENT_TIMESTAMP AS CHARACTER FORMAT 'IU');

        RETURN TRUE;
    END;

END MODULE;
```

### XML-to-JSON Transformation Version

Accepts XML `OrderRequest`, maps fields, calculates total, returns JSON.

**Input XML structure:**
```xml
<OrderRequest>
    <OrderId>ORD-2026-0001</OrderId>
    <Customer>
        <FirstName>John</FirstName>
        <LastName>Smith</LastName>
        <Email>john@example.com</Email>
    </Customer>
    <Order>
        <ProductCode>PROD-001</ProductCode>
        <Quantity>2</Quantity>
        <UnitPrice>49.95</UnitPrice>
    </Order>
</OrderRequest>
```

**ESQL:**
```esql
BROKER SCHEMA OrderProcessor

CREATE COMPUTE MODULE OrderProcessor_Compute

    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        DECLARE refInput REFERENCE TO InputRoot.XMLNSC.OrderRequest;

        SET OutputRoot.HTTPResponseHeader."X-Original-HTTP-Status-Code" = 202;
        SET OutputRoot.HTTPResponseHeader."Content-Type" = 'application/json';

        CREATE FIELD OutputRoot.JSON.Data;
        DECLARE refOutput REFERENCE TO OutputRoot.JSON.Data;

        SET refOutput.orderId       = COALESCE(refInput.OrderId, 'UNKNOWN');
        SET refOutput.customerName  = refInput.Customer.FirstName || ' ' || refInput.Customer.LastName;
        SET refOutput.contactEmail  = refInput.Customer.Email;
        SET refOutput.product       = refInput.Order.ProductCode;
        SET refOutput.quantity      = refInput.Order.Quantity;
        SET refOutput.totalPrice    = ROUND(refInput.Order.Quantity * refInput.Order.UnitPrice, 2);
        SET refOutput.status        = 'accepted';
        SET refOutput.processedAt   = CAST(CURRENT_TIMESTAMP AS CHARACTER FORMAT 'IU');

        RETURN TRUE;
    END;

END MODULE;
```

**Test Case - happy path:**
```bash
curl -X POST http://localhost:7800/message \
  -H "Content-Type: application/xml" \
  -d '<OrderRequest>
    <OrderId>ORD-2026-0001</OrderId>
    <Customer>
      <FirstName>John</FirstName>
      <LastName>Smith</LastName>
      <Email>john@example.com</Email>
    </Customer>
    <Order>
      <ProductCode>PROD-001</ProductCode>
      <Quantity>2</Quantity>
      <UnitPrice>49.95</UnitPrice>
    </Order>
  </OrderRequest>'
```

**Expected response:**
```json
{
  "orderId": "ORD-2026-0001",
  "customerName": "John Smith",
  "contactEmail": "john@example.com",
  "product": "PROD-001",
  "quantity": 2,
  "totalPrice": 99.90,
  "status": "accepted",
  "processedAt": "2026-..."
}
```

---

## Non-HTTP Flow Patterns

### MQ Input → Compute → MQ Output

Use `references/examples/IBMMQtoFile/` or any MQ→X pattern as a starting point. Key pattern:

**ESQL (transform JSON from MQ queue, write to output queue):**
```esql
BROKER SCHEMA OrderForwarder

CREATE COMPUTE MODULE OrderForwarder_Compute

    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        -- Copy MQ headers so the output message retains message properties
        CALL CopyMessageHeaders();

        -- Read from JSON input (MQ message body parsed as JSON)
        DECLARE refInput REFERENCE TO InputRoot.JSON.Data;

        -- Build output JSON
        CREATE FIELD OutputRoot.JSON.Data;
        DECLARE refOutput REFERENCE TO OutputRoot.JSON.Data;
        SET refOutput.orderId     = refInput.orderId;
        SET refOutput.status      = 'processed';
        SET refOutput.processedAt = CAST(CURRENT_TIMESTAMP AS CHARACTER FORMAT 'IU');

        RETURN TRUE;
    END;

    CREATE PROCEDURE CopyMessageHeaders() BEGIN
        DECLARE I INTEGER 1;
        DECLARE J INTEGER;
        SET J = CARDINALITY(InputRoot.*[]);
        WHILE I < J DO
            SET OutputRoot.*[I] = InputRoot.*[I];
            SET I = I + 1;
        END WHILE;
    END;

END MODULE;
```

**Node configuration:**
- `ComIbmMQInput.msgnode:FCMComposite_1` - `queueName="INPUT.QUEUE"`, `messageDomainProperty="JSON"`
- `ComIbmCompute.msgnode:FCMComposite_1` - `computeExpression="esql://routine/#OrderForwarder_Compute.Main"`
- `ComIbmMQOutput.msgnode:FCMComposite_1` - `queueName="OUTPUT.QUEUE"`

**Manual configuration required:** Queue manager name must be configured on the MQ Input/Output nodes in ACE Toolkit (not settable in `.msgflow` XML without a policy). Set via node properties or use an MQEndpoint policy.

**MQ queue setup (ACE console):**
```bash
crtmqm TESTQM
strmqm TESTQM
runmqsc TESTQM
  define ql(INPUT.QUEUE)
  define ql(OUTPUT.QUEUE)
  end
```

---

### File Input → Compute → File Output

Use `references/examples/IBMMQtoFile/` or `references/examples/FiletoIBMMQ/` as starting point.

**Key node types:**
- `ComIbmFileInput.msgnode:FCMComposite_1` - `inputDirectory="C:\input"`, `fileNamePattern="*.xml"`
- `ComIbmFileOutput.msgnode:FCMComposite_1` - `outputDirectory="C:\output"`, `outputFilename="processed_%TimeStamp%.xml"`

**ESQL (read XML file, transform, write to output):**
```esql
CREATE FUNCTION Main() RETURNS BOOLEAN
BEGIN
    SET OutputRoot.Properties = InputRoot.Properties;
    CREATE LASTCHILD OF OutputRoot DOMAIN('XMLNSC');

    DECLARE refInput REFERENCE TO InputRoot.XMLNSC.RootElement;
    DECLARE refOutput REFERENCE TO OutputRoot.XMLNSC;

    CREATE FIELD refOutput.ProcessedRecord;
    SET refOutput.ProcessedRecord.Id          = refInput.Id;
    SET refOutput.ProcessedRecord.ProcessedAt = CAST(CURRENT_TIMESTAMP AS CHARACTER FORMAT 'IU');
    SET refOutput.ProcessedRecord.Status      = 'done';

    RETURN TRUE;
END;
```

---

### HTTP → MQ (Fire and Forget)

Use `references/examples/HTTPtoIBMMQ/` as starting point.

Pattern: HTTP Input → [optional Compute] → MQ Output → HTTP Reply (202 Accepted immediately).

**Key consideration:** The HTTP reply should happen before (or separately from) MQ processing. In the IBM pattern, the HTTP reply comes from the `OutTerminal.out` path which exits to HTTP Reply immediately after the MQ Output node.

**Manual configuration:** The MQ Output `queueName` must be set in ACE Toolkit or via an MQEndpoint policy.
