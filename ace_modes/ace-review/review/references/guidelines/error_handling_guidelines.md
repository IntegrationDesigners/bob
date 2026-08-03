---
template_version: 1.2.2
last_updated: 2026-07-09
compatible_with: ACE Review v1.0.0+
status: stable
---
# ACE Error Handling Guidelines

## Error Handling Strategy

### Three-Tier Approach

1. **Flow-level** - catch and handle errors within the flow
2. **Application-level** - common error handling across flows
3. **Integration server-level** - global error handling

### Hierarchy

```
Flow Error Handler (Specific)
    ↓
Subflow Error Handler (Reusable)
    ↓
Application Error Handler (Common)
    ↓
Integration Server Error Handler (Global)
```

---

## Try-Catch Pattern

Always implement error handling for operations that can fail. Use Try-Catch node wiring at the flow level and ESQL exception handling within compute nodes.

> **See also:** [Unconnected Node Terminals](flow_guidelines.md#unconnected-node-terminals) in `flow_guidelines.md` - when a node's Failure, Catch, or Timeout terminal is not connected, exceptions propagate upstream with potential transaction rollback. Review all terminal connections as part of the error handling assessment.

### ESQL Try-Catch Example

```esql
BEGIN
    CALL processMessage();
EXCEPTION
    WHEN SQLSTATE LIKE 'BIP%' THEN
        CALL handleBrokerError();
    WHEN SQLSTATE LIKE '23%' THEN
        CALL handleDatabaseError();
    WHEN SQLSTATE LIKE '42%' THEN
        CALL handleSQLError();
    ELSE
        CALL handleGenericError();
END;
```

---

## Standardized Error Response

Use a consistent error message structure across all flows.

```xml
<ErrorResponse>
    <ErrorCode>ERR_001</ErrorCode>
    <ErrorMessage>Invalid input format</ErrorMessage>
    <Timestamp>2025-12-01T10:30:00Z</Timestamp>
    <CorrelationId>12345-67890-ABCDE</CorrelationId>
    <Details>
        <Field>CustomerID</Field>
        <Reason>Must be numeric</Reason>
    </Details>
</ErrorResponse>
```

---

## Exception List Handling

Navigate the exception list using references, not direct subscripts.

```esql
CREATE PROCEDURE logExceptionList()
BEGIN
    DECLARE exRef REFERENCE TO InputExceptionList.*[1];
    WHILE LASTMOVE(exRef) DO
        CALL writeToLog('ERROR',
            'Number: ' || COALESCE(exRef.Number, 'N/A') ||
            ', Text: ' || COALESCE(exRef.Text, 'N/A'));
        MOVE exRef NEXTSIBLING;
    END WHILE;
END;
```

---

## Database Error Handling

Handle database errors with specific SQLSTATE codes.

```esql
EXCEPTION
    WHEN SQLSTATE = '23000' THEN
        SET OutputRoot.XMLNSC.Error.Code = 'DB_DUPLICATE';
    WHEN SQLSTATE LIKE '08%' THEN
        SET OutputRoot.XMLNSC.Error.Code = 'DB_CONNECTION';
    WHEN SQLSTATE = '40001' THEN
        SET OutputRoot.XMLNSC.Error.Code = 'DB_DEADLOCK';
    ELSE
        SET OutputRoot.XMLNSC.Error.Code = 'DB_ERROR';
        CALL writeToLog('ERROR', 'SQLSTATE: ' || SQLSTATE || ', SQLERRORTEXT: ' || SQLERRORTEXT);
END;
```

---

## HTTP Error Handling

Check HTTP response codes and handle errors by category.

```esql
DECLARE httpStatusCode INTEGER InputRoot.HTTPResponseHeader."X-Original-HTTP-Status-Code";

IF httpStatusCode >= 400 THEN
    CASE
        WHEN httpStatusCode = 401 THEN SET OutputRoot.XMLNSC.Error.Code = 'HTTP_UNAUTHORIZED';
        WHEN httpStatusCode = 403 THEN SET OutputRoot.XMLNSC.Error.Code = 'HTTP_FORBIDDEN';
        WHEN httpStatusCode = 404 THEN SET OutputRoot.XMLNSC.Error.Code = 'HTTP_NOT_FOUND';
        WHEN httpStatusCode = 408 THEN SET OutputRoot.XMLNSC.Error.Code = 'HTTP_TIMEOUT';
        WHEN httpStatusCode >= 500 THEN SET OutputRoot.XMLNSC.Error.Code = 'HTTP_SERVER_ERROR';
        ELSE SET OutputRoot.XMLNSC.Error.Code = 'HTTP_ERROR';
    END CASE;
END IF;
```

---

## Timeout Handling

Always set appropriate timeouts and handle timeout scenarios explicitly.

```esql
-- Set HTTP request timeout
SET OutputLocalEnvironment.Destination.HTTP.RequestTimeout = 30;

-- Handle timeout in error handler
IF InputExceptionList.*[1].Number = 3142 THEN
    -- BIP3142: Timeout occurred
    SET OutputRoot.XMLNSC.Error.Code = 'TIMEOUT';
END IF;
```

---

## Retry Logic

Implement retry with exponential backoff for transient failures.

```esql
DECLARE maxRetries INTEGER 3;
DECLARE retryCount INTEGER 0;
DECLARE success BOOLEAN FALSE;
DECLARE ignored BOOLEAN FALSE;

WHILE retryCount < maxRetries AND NOT success DO
    BEGIN
        CALL performOperation();
        SET success = TRUE;
    EXCEPTION
        WHEN SQLSTATE LIKE '08%' THEN
            SET retryCount = retryCount + 1;
            IF retryCount < maxRetries THEN
                -- Exponential backoff: the wait doubles each attempt (1s, 2s, 4s, ...).
                -- Note: 1000 * retryCount would be LINEAR backoff (1s, 2s, 3s), not exponential.
                SET ignored = SLEEP(1000 * CAST(POWER(2, retryCount - 1) AS INTEGER));
            ELSE
                THROW USER EXCEPTION MESSAGE 2951 VALUES('Max retry attempts exceeded');
            END IF;
        ELSE
            RESIGNAL;  -- non-retryable errors propagate immediately
    END;
END WHILE;
```

`SLEEP()` is a built-in ESQL function from ACE 12 onwards (it returns a BOOLEAN, so assign its result). On earlier versions, implement the wait in a helper (e.g., a JavaCompute utility) instead.

---

## Compensation and Rollback

For multi-step operations, implement compensation logic to undo partial changes.

```esql
DECLARE step1Complete BOOLEAN FALSE;
DECLARE step2Complete BOOLEAN FALSE;

BEGIN
    -- Handler runs when any statement in this block raises an exception:
    -- compensate in reverse order, then let the error propagate
    DECLARE EXIT HANDLER FOR SQLSTATE LIKE '%'
    BEGIN
        IF step2Complete THEN CALL releaseInventory(); END IF;
        IF step1Complete THEN CALL cancelOrder(); END IF;
        RESIGNAL;
    END;

    CALL createOrder();
    SET step1Complete = TRUE;
    CALL reserveInventory();
    SET step2Complete = TRUE;
    CALL processPayment();
END;
```

---

## Error Logging

Log all errors with sufficient context for troubleshooting:

- Error timestamp
- Error code and message
- Correlation ID
- Input context (sanitized - never log sensitive data)
- Exception detail from the exception list

---

## Testing Error Scenarios

Always test the full error matrix, not just the happy path:

- Invalid input data
- Database connection failures and constraint violations
- HTTP timeouts and 4xx/5xx responses
- Network failures
- Message parsing errors
- Resource exhaustion
- Concurrent access issues

---

## PROPAGATE Finalization in Error Paths

When a Compute node's ESQL calls `PROPAGATE TO LABEL` (e.g., to route a message to a LOG label) and then continues executing code afterwards, the default `PROPAGATE` behaviour finalizes and deletes the output trees after the propagation returns. This means any `OutputRoot`, `OutputLocalEnvironment`, or `OutputExceptionList` values your ESQL set before the `PROPAGATE` may be gone by the time the next statement runs.

### The Pattern

In shared AdapterLibrary flows and similar patterns, the standard is to use `FINALIZE NONE DELETE NONE` on every `PROPAGATE TO LABEL` that is followed by further processing:

```esql
-- WRONG - output trees may be finalized after this returns:
PROPAGATE TO LABEL 'LOG';
CALL CopyEntireMessage();  -- may operate on empty/stale trees

-- CORRECT - preserve trees so subsequent code can access them:
PROPAGATE TO LABEL 'LOG' FINALIZE NONE DELETE NONE;
CALL CopyEntireMessage();  -- trees intact, as expected
```

### How to Review This

- For every `PROPAGATE TO LABEL` call that is **not** the last statement in a module, check whether `FINALIZE NONE DELETE NONE` is present
- Compare against other flows in the same application - if the AdapterLibrary pattern uses `FINALIZE NONE DELETE NONE`, all calling flows should match
- If the ESQL after the `PROPAGATE` only reads `InputRoot` (not `OutputRoot`), the missing clause is lower risk - but it is still a best practice to include it for consistency

**Reference:** [IBM ACE - PROPAGATE statement](https://www.ibm.com/docs/en/app-connect/13.0.x?topic=statements-propagate-statement)

---

## Attributing side effects and judging severity across trust boundaries

When a finding involves an operation the reviewed code does not perform directly - a file write, network call, or database operation triggered via `PROPAGATE TO LABEL`, a subflow call, or any shared-library node - apply these three checks before writing the finding. They keep findings honest when the real work happens on the other side of a trust boundary (a subflow, a shared library, or the runtime itself).

### 1. Attribute the operation to where it actually happens

Do not say "this flow writes to X" when the reviewed code only **stages** the operation (sets a destination property, builds a payload) and a shared library or subflow outside the review's scope actually **performs** it. State both steps explicitly:
- which node/line **prepares** the operation, and
- which node/subflow actually **executes** it.

If the executing code is outside this review's scope, say so, and do not make claims about its internal behaviour (retries, transactionality, error handling) without verifying them - flag those as **unverified assumptions**, not facts.

### 2. Judge severity by blast radius, not just "this could fail"

Before assigning Medium or High to a reliability finding, reason through:
- Is data actually at risk of loss, or is the failure mode **contained** (parked on a backout / dead-letter queue, non-destructive, replayable)?
- Is the failing operation **inside or outside the transactional boundary** of the triggering event? (A file write under an MQInput-started transaction is typically **not** part of that transaction's own commit/rollback - a failure there has a different, usually smaller, blast radius than one that could corrupt shared transactional state.)
- What is actually **verified** versus **inferred** about any dependency involved in the failure path?

If the honest answer is "no data loss, contained failure, dependency behaviour unverified either way", the finding belongs at **Low** severity, phrased as something to **confirm** - not as a required fix.

### 3. Cite the literal evidence for factual claims

When a finding states a fact about configuration or environment ("this is a UNC file share", "this queue is non-persistent"), point to the **exact source value** that establishes it - e.g. `FinalOutputBaseDirectory = \\netwerk\dfs\...` - the `\\host\share` prefix is what makes it UNC. Never state an inference about a dependency's behaviour with the same confidence as something read directly from source. Separate **"verified from source"** from **"inferred"** in the finding text itself.

Repository and version-control state is one of these facts. "Committed to version control", "checked in", and "tracked" are claims about git, not about what is on disk - a file present in the working tree may be git-ignored and untracked. Verify with `.gitignore` and `git ls-files` / `git check-ignore` before asserting it (see `workflow.md` - Version-control hygiene). Presence on disk is not evidence of being committed.

Reading a node's `.msgflow` configuration has two traps that produce confident-but-wrong findings:

- **Do not guess the XML attribute name from the toolkit display label.** Several display names serialize to a differently-named attribute - "Parse Timing" is `validateTiming`, "Validate" is `validateMaster`, "Compute mode" is `computeMode` - and some guessed names do not exist at all (there is no `parseTiming`). Read the actual attributes present on the node; if you are unsure of the mapping, say so rather than asserting one.
- **An absent attribute is not evidence the property is unset.** ACE writes only *non-default* values into the `.msgflow` (and only *overridden* values into descriptors), so a missing attribute means the property is at its **default**, not "missing" or "not configured". Concluding "property X is not set / still at On Demand" because you cannot find its attribute is an inference, and usually a wrong one - state the default instead.

## Summary

1. Implement three-tier error handling
2. Use try-catch patterns consistently
3. Standardize error messages across all flows
4. Navigate exception lists properly using references
5. Handle database errors by SQLSTATE category
6. Check and handle HTTP response codes
7. Set appropriate timeouts
8. Implement retry logic with exponential backoff
9. Use compensation patterns for multi-step operations
10. Use `FINALIZE NONE DELETE NONE` on `PROPAGATE TO LABEL` when followed by further processing
11. Log errors comprehensively with context
12. Test error scenarios thoroughly
13. Attribute side effects to where they execute, judge severity by blast radius, and cite literal source evidence - especially across subflow / shared-library / PROPAGATE trust boundaries
