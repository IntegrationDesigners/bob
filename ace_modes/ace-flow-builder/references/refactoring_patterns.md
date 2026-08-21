# ACE Flow Refactoring Patterns

Reference for `ace-flow-refactor` mode. Covers what to look for, how to fix it, and compute mode selection.

---

## 1. Compute Mode Matrix

The compute mode controls what ACE puts in `OutputRoot` before your ESQL runs. Getting this wrong causes silent data corruption or unnecessary overhead.

| Mode | What ACE initialises in OutputRoot | Use when |
|------|------------------------------------|----------|
| `none` | Nothing - OutputRoot is empty | You build the entire output yourself (most common for transformations) |
| `copyMessageHeaders` | All headers (MQMD, HTTPReplyHeader, etc.) copied, no body | You want headers preserved but will build the body; avoids manual `CopyMessageHeaders()` |
| `local` | Copy of the whole message tree (input + headers + body) | Use only for simple field overrides; wastes memory on large messages |
| `clone` | Deep clone of entire input tree | Rarely correct - effectively same as `local` but explicit; avoid unless you need to modify a copy without affecting input |

**Default in IBM patterns:** `none` - you control all output explicitly.

**Common mistake:** Using `local` when you only need to transform the body. This copies the entire input tree unnecessarily. Switch to `none` + explicit `SET OutputRoot.Properties = InputRoot.Properties`.

**In .msgflow XML**, compute mode appears as `computeMode` attribute on the Compute node:
```xml
<nodes xmi:type="ComIbmCompute.msgnode:FCMComposite_1"
  xmi:id="FCMComposite_1_2"
  computeExpression="esql://routine/#MyFlow_Compute.Main"
  computeMode="none"/>   <!-- omit attribute entirely for "none" (it's the default) -->
```

---

## 2. Node Consolidation

### 2.1 When to Combine Adjacent Compute Nodes

Combine when:
- Two consecutive Compute nodes with no branching between them
- No monitoring / user trace checkpoint needed between them
- Both operate on the same message domain

Do NOT combine when:
- There is a route/filter node between them
- One node writes to a different terminal (e.g., `OutTerminal.out` vs `OutTerminal.alternate`)
- A transaction boundary exists between them
- The separation is intentional for readability on complex flows

**Before:**
```
HTTP Input → ValidateCompute → TransformCompute → HTTP Reply
```
**After:**
```
HTTP Input → ValidateAndTransformCompute → HTTP Reply
```

### 2.2 CopyMessageHeaders Anti-Pattern

**Bad pattern:** Manually coding `CopyMessageHeaders()` inside every compute module.
```esql
-- Repeated in every compute module
CREATE PROCEDURE CopyMessageHeaders() BEGIN
    DECLARE I INTEGER 1;
    DECLARE J INTEGER;
    SET J = CARDINALITY(InputRoot.*[]);
    WHILE I < J DO
        SET OutputRoot.*[I] = InputRoot.*[I];
        SET I = I + 1;
    END WHILE;
END;
```

**Better:** Use `computeMode="copyMessageHeaders"` on the Compute node - ACE copies headers automatically before your ESQL runs. You then only need to set the body:
```esql
CREATE COMPUTE MODULE MyFlow_Compute
    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        -- Headers already copied by computeMode=copyMessageHeaders
        SET OutputRoot.XMLNSC.Response.Field = InputRoot.XMLNSC.Request.Field;
        RETURN TRUE;
    END;
END MODULE;
```

Exception: keep the `CopyMessageHeaders()` procedure in `HandleException` modules - the error handler still needs it there since error paths don't go through normal compute.

---

## 3. Error Handling Upgrade

### 3.1 Unwired Catch/Failure Terminals

Every input node has `OutTerminal.catch` and `OutTerminal.failure` terminals. If unwired, unhandled exceptions silently drop messages (MQ) or return 500 with no body (HTTP).

**Detection in .msgflow:** Search for connections where `sourceTerminalName="OutTerminal.catch"` - if none exist, catch is unwired.

**Standard fix - add HandleException path:**
```xml
<!-- Add HandleException compute node -->
<nodes xmi:type="ComIbmCompute.msgnode:FCMComposite_1"
  xmi:id="FCMComposite_1_4"
  location="258,200"
  computeExpression="esql://routine/#MyFlow_HandleException.Main">
  <translation xmi:type="utility:ConstantString" string="HandleException"/>
</nodes>

<!-- Wire catch terminal -->
<connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_3"
  targetNode="FCMComposite_1_4" sourceNode="FCMComposite_1_1"
  sourceTerminalName="OutTerminal.catch" targetTerminalName="InTerminal.in"/>

<!-- Wire HandleException to Reply (HTTP) or DLQ (MQ) -->
<connections xmi:type="eflow:FCMConnection" xmi:id="FCMConnection_4"
  targetNode="FCMComposite_1_3" sourceNode="FCMComposite_1_4"
  sourceTerminalName="OutTerminal.out" targetTerminalName="InTerminal.in"/>
```

**Standard HandleException ESQL:**
```esql
CREATE COMPUTE MODULE MyFlow_HandleException
    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        DECLARE messageNumber INTEGER;
        DECLARE messageText CHAR;
        CALL GetLastExceptionDetail(InputExceptionList, messageNumber, messageText);
        CALL CopyMessageHeaders();
        SET OutputRoot.XMLNSC.Error.MessageNumber = messageNumber;
        SET OutputRoot.XMLNSC.Error.MessageText = messageText;
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

### 3.2 HTTP Error Response Code

For HTTP flows, the HandleException should also set the status code:
```esql
SET OutputRoot.HTTPResponseHeader."X-Original-HTTP-Status-Code" = 500;
SET OutputRoot.HTTPResponseHeader."Content-Type" = 'application/json';
CREATE FIELD OutputRoot.JSON.Data;
SET OutputRoot.JSON.Data.error = messageText;
SET OutputRoot.JSON.Data.errorCode = messageNumber;
```

---

## 4. Common Anti-Patterns with Fixes

### 4.1 Full Tree Copy Instead of Selective Copy

```esql
-- BAD: copies everything including unwanted fields
SET OutputRoot = InputRoot;
SET OutputRoot.XMLNSC.Response.AddedField = 'value';

-- GOOD: copy only what you need
SET OutputRoot.Properties = InputRoot.Properties;
SET OutputRoot.XMLNSC.Response.Field1 = InputRoot.XMLNSC.Request.Field1;
SET OutputRoot.XMLNSC.Response.AddedField = 'value';
```

### 4.2 Hardcoded Queue Names in ESQL

```esql
-- BAD: hardcoded
SET OutputLocalEnvironment.Destination.MQ.DestinationData[1].queueName = 'PROD.TARGET.QUEUE';

-- GOOD: use promoted properties or environment variables
-- In Compute node, read from node-level property (set via ibmint overrides)
-- Or use a LocalEnvironment variable set at startup
```

### 4.3 Missing BROKER SCHEMA Declaration

```esql
-- BAD: missing schema declaration (compiles but may cause classpath issues)
CREATE COMPUTE MODULE MyFlow_Compute
    ...

-- GOOD
BROKER SCHEMA MyFlow

CREATE COMPUTE MODULE MyFlow_Compute
    ...
```

### 4.4 Unnecessary PROPAGATE

```esql
-- BAD: using PROPAGATE when just RETURN TRUE suffices
CREATE FUNCTION Main() RETURNS BOOLEAN
BEGIN
    SET OutputRoot.JSON.Data.result = 'ok';
    PROPAGATE TO TERMINAL 'out';  -- redundant, RETURN TRUE does this
    RETURN FALSE;  -- then FALSE stops default propagation - confusing
END;

-- GOOD
CREATE FUNCTION Main() RETURNS BOOLEAN
BEGIN
    SET OutputRoot.JSON.Data.result = 'ok';
    RETURN TRUE;  -- propagates to OutTerminal.out automatically
END;
```

Use `PROPAGATE` explicitly only when routing to non-standard terminals or sending to multiple outputs.

### 4.5 Multi-wire logging fan-in

```
-- BAD: 4+ explicit wires converging on one Trace/Log node
[Compute A] ─┐
[Compute B] ─┼─→ [Log]
[Compute C] ─┤
[Compute D] ─┘
```

Every compute node gets an out-of-band connection back to the shared logging node, cluttering the diagram and making the dependency hard to read in Toolkit.

```
-- GOOD: a disconnected Label node + PROPAGATE TO LABEL from each compute
[Compute A] ──→ [next step]
[Compute B] ──→ [next step]   (each does: PROPAGATE TO LABEL 'LOG' DELETE NONE)
[Compute C] ──→ [next step]
[Compute D] ──→ [next step]

[Label LOG] ──→ [Log]   (disconnected from the main pipeline)
```

The Label node sits off the main flow with a single wire to the logging step. Every compute node fans in via ESQL `PROPAGATE TO LABEL 'LOG' DELETE NONE`. See `workflow.md` §3.2 "Fan-in via PROPAGATE TO LABEL" for the worked pattern.

Rule of thumb: with ≥ 3 contributors, refactor to Label + PROPAGATE. With 2, the wires are cleaner.

---

## 5. Before/After Example - HTTP Flow Refactor

### Before (common issues)

```
[HTTP Input] → [ValidateCompute (computeMode=local)] → [TransformCompute (computeMode=local)] → [HTTP Reply]
(catch terminal unwired, no error handling, two adjacent compute nodes)
```

**ValidateCompute.esql:**
```esql
CREATE COMPUTE MODULE ValidateCompute
    -- Full CopyMessageHeaders() procedure duplicated here (30 lines)
    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        CALL CopyMessageHeaders();
        IF InputRoot.XMLNSC.Request.OrderId IS NULL THEN
            THROW USER EXCEPTION MESSAGE 2500 VALUES('Missing OrderId');
        END IF;
        SET OutputRoot = InputRoot;  -- full copy
        RETURN TRUE;
    END;
    CREATE PROCEDURE CopyMessageHeaders() BEGIN ... END;
END MODULE;
```

**TransformCompute.esql:**
```esql
CREATE COMPUTE MODULE TransformCompute
    -- Full CopyMessageHeaders() procedure duplicated again
    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        CALL CopyMessageHeaders();
        SET OutputRoot.XMLNSC.Response.OrderId = InputRoot.XMLNSC.Request.OrderId;
        SET OutputRoot.XMLNSC.Response.Status = 'ACCEPTED';
        RETURN TRUE;
    END;
    CREATE PROCEDURE CopyMessageHeaders() BEGIN ... END;
END MODULE;
```

### After (refactored)

```
[HTTP Input] → [ValidateAndTransformCompute (computeMode=none)] → [HTTP Reply]
               [HandleException (computeMode=none)] ↗ (from catch)
```

**ValidateAndTransformCompute.esql:**
```esql
BROKER SCHEMA OrderFlow

CREATE COMPUTE MODULE ValidateAndTransformCompute
    CREATE FUNCTION Main() RETURNS BOOLEAN
    BEGIN
        -- Validate
        IF InputRoot.XMLNSC.Request.OrderId IS NULL THEN
            THROW USER EXCEPTION MESSAGE 2500 VALUES('Missing OrderId');
        END IF;
        -- Transform (build output explicitly)
        SET OutputRoot.Properties = InputRoot.Properties;
        SET OutputRoot.HTTPResponseHeader."Content-Type" = 'application/xml';
        SET OutputRoot.XMLNSC.Response.OrderId = InputRoot.XMLNSC.Request.OrderId;
        SET OutputRoot.XMLNSC.Response.Status = 'ACCEPTED';
        RETURN TRUE;
    END;
END MODULE;
```

**Changes made:**
- Merged two adjacent compute nodes into one (eliminated redundant node)
- Removed `computeMode=local` - both used full tree copy unnecessarily
- Eliminated duplicated `CopyMessageHeaders()` procedure
- Added `BROKER SCHEMA` declaration
- Added error handling (HandleException node + wired catch terminal)
- Output built explicitly instead of `SET OutputRoot = InputRoot` + overrides
