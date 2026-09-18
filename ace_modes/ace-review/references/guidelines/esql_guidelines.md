---
template_version: 1.1.0
last_updated: 2026-07-09
compatible_with: ACE Review v1.0.0+
status: stable
---
# ACE ESQL Coding Guidelines

## ESQL File Structure - Review Approach

Before applying any of the guidelines below, **map the structure of the ESQL file first**.

An ESQL file typically contains a `CREATE COMPUTE MODULE` block with multiple function/procedure definitions inside it:

```esql
BROKER SCHEMA com.example.myapp;

CREATE COMPUTE MODULE MyFlow_Compute

   -- Entry point called by the message flow node
   CREATE FUNCTION Main() RETURNS BOOLEAN
   BEGIN
      CALL validate();
      CALL transform();
      RETURN TRUE;
   END;

   -- Helper procedure - called from Main or from other helpers
   CREATE PROCEDURE validate()
   BEGIN
      ...
   END;

   -- Another helper procedure
   CREATE PROCEDURE transform()
   BEGIN
      ...
   END;

END MODULE;
```

Identify these before reviewing:
1. **`CREATE FUNCTION Main()`** - the entry point called directly by the message flow compute node
2. **All other `CREATE PROCEDURE` / `CREATE FUNCTION` blocks** - helpers and supporting functions

**Scope every finding to its correct function.** A pattern that is a performance concern in `Main()` may be correct and intentional in a helper procedure, and vice versa. Code snippets in findings must show the specific function/procedure containing the issue - not a combined block mixing `Main()` with helper code.

---

## Using References

**Rule:** If you think you should use references, use them!

References make the processing/handling of arrays and message trees with repeating records (basically also arrays) a LOT less memory and CPU intensive than it would be by directly accessing these elements.

### Why References Matter

When accessing repeating or nested structures, the code has to navigate over all previous elements until it finds the one it needs. You can imagine that with big messages this can make a huge difference and can negatively impact performance.

For reference variables, the statement navigates to the main parent, which maintains a pointer directly to the correct field in the message tree.

Specifically for arrays, every usage of subscripts (`[]`) is an expensive operation. Replacing subscripts with a single reference and moving between siblings will increase processing time significantly.

### Consecutive Fields Example

```esql
SET OutputRoot.XMLNSC.Test.OutMessage.item1 = 'item1';
DECLARE outRef REFERENCE TO OutputRoot.XMLNSC.Test.OutMessage;

SET outRef.item2 = 'item2';
SET outRef.item3 = 'item3';
```

### Array Example

```esql
DECLARE inRef REFERENCE TO InputRoot.XMLNSC.Parent.Child.ArrayField[1];
DECLARE tempChar CHAR;

WHILE LASTMOVE(inRef) DO
   -- do something with the ref
   SET tempChar = inRef;
   MOVE inRef NEXTSIBLING NAME 'ArrayField';
END WHILE;
```

---

## Cardinality

Just like array processing, the `CARDINALITY` function is rather resource intensive and it's best to omit it where possible.

### Best Practice: Calculate Once

When using `CARDINALITY` in a loop, it's good practice to just do it once and store the result in a variable (instead of putting it in the loop definition and running it each time the loop is traversed).

```esql
DECLARE arraySize INTEGER CARDINALITY(InputRoot.XMLNSC.A.B.C[]);
WHILE (I < arraySize) DO
   -- do something
END WHILE;
```

### Avoiding Cardinality in Child Element Checks

Cardinality is also often used to determine if a field already has child elements.

**Less Efficient Approach:**
```esql
DECLARE outRef REFERENCE TO OutputRoot.XMLNSC.TARGET;

DECLARE arraySize INTEGER CARDINALITY(InputRoot.XMLNSC.A.B.C[]);
WHILE (I < arraySize) DO

   IF CARDINALITY(outRef.*[]) > 0 THEN
      CREATE NEXTSIBLING OF outRef AS outRef NAME 'ChildField';
   ELSE
      CREATE FIRSTCHILD OF outRef AS outRef NAME 'ChildField';
   END IF;
END WHILE;
```

**More Efficient Approach:**
```esql
DECLARE outRef REFERENCE TO OutputRoot.XMLNSC.TARGET.ChildField[1];

DECLARE arraySize INTEGER CARDINALITY(InputRoot.XMLNSC.A.B.C[]);
WHILE (I < arraySize) DO

   IF LASTMOVE(outRef) THEN
      CREATE NEXTSIBLING OF outRef AS outRef NAME 'ChildField';
   ELSE
      CREATE FIRSTCHILD OF outRef AS outRef NAME 'ChildField';
   END IF;
END WHILE;
```

---

## Declare Statements

Each declare statement/set statement comes with a small performance cost. Reducing the number of declare statements by declaring multiple variables in one line helps improve performance.

Alternatively, declaring a variable and setting the initial value with a single statement is more performant and helps reduce memory usage.

### Example

```esql
CREATE COMPUTE MODULE CodingGuidelines_Compute
   CREATE FUNCTION Main() RETURNS BOOLEAN
   BEGIN
      -- Less performant code
      DECLARE variable1 CHARACTER;
      DECLARE variable2 CHARACTER;
      DECLARE variable3 CHARACTER;
      
      SET variable1 = 'value';
      SET variable2 = 'value';
      SET variable3 = 'value';

      -- Improvement: Declare and initialize in one statement
      DECLARE variable4, variable5, variable6 CHARACTER 'value';

      RETURN TRUE;
   END;
END MODULE;
```

---

## PASSTHRU Statements

When using the `PASSTHRU` statement, use variables for values that change during execution. If you need to run a query multiple times with different values, don't generate multiple `PASSTHRU` statements but use the PASSTHRU variable injection.

### Example

```esql
CREATE COMPUTE MODULE CodingGuidelines_Compute
   CREATE FUNCTION Main() RETURNS BOOLEAN
   BEGIN
      -- Multiple SQL PREPARE behind the scenes (INEFFICIENT)
      PASSTHRU('UPDATE TABLE1 AS T SET Attempts = 1 WHERE T.Company = ''Alice''');
      PASSTHRU('UPDATE TABLE1 AS T SET Attempts = 2 WHERE T.User = ''Alice''');

      -- Single SQL PREPARE (EFFICIENT)
      DECLARE user CHARACTER 'Alice';
      DECLARE attempt INTEGER 1;

      WHILE attempt <= 2 DO
         PASSTHRU('UPDATE TABLE1 AS T SET Attempts = ? WHERE T.User = ?', attempt, user);
         SET attempt = attempt + 1;
      END WHILE;

      RETURN TRUE;
   END;
END MODULE;
```

### Why This Matters

The reason for this is that each `PASSTHRU` statement with fixed variables triggers a SQL PREPARE statement, which impacts performance. When using variables, the values can change without needing another SQL PREPARE in the background.

---

## String Manipulation

Any string manipulation function (`LENGTH`, `SUBSTRING`, etc.) is resource intensive. It's best to limit the use of these functions as much as possible.

### Best Practice

If you need the same result in multiple places, it's better to call the function once and store the result in a variable.

```esql
-- Instead of calling LENGTH multiple times
IF LENGTH(InputRoot.XMLNSC.Message.Field) > 10 THEN
   SET OutputRoot.Field1 = LENGTH(InputRoot.XMLNSC.Message.Field);
   SET OutputRoot.Field2 = LENGTH(InputRoot.XMLNSC.Message.Field) * 2;
END IF;

-- Call once and store the result
DECLARE fieldLength INTEGER LENGTH(InputRoot.XMLNSC.Message.Field);
IF fieldLength > 10 THEN
   SET OutputRoot.Field1 = fieldLength;
   SET OutputRoot.Field2 = fieldLength * 2;
END IF;
```

---

## BROKER SCHEMA Declarations

In multi-application ACE deployments, ESQL modules in different applications or libraries can inadvertently share namespace if `BROKER SCHEMA` is not declared correctly.

### Rule

Every ESQL module file must begin with a `BROKER SCHEMA` declaration that matches the application or library package path. Without it, ACE will assign a default schema, which can cause routing conflicts or unexpected module resolution when multiple applications are deployed on the same integration server.

### Example

```esql
-- Required at the top of every .esql file
BROKER SCHEMA com.example.myapp;

CREATE COMPUTE MODULE MyFlow_Compute
   CREATE FUNCTION Main() RETURNS BOOLEAN
   BEGIN
      ...
   END;
END MODULE;
```

**Check:** Verify that every `.esql` file has a `BROKER SCHEMA` declaration, and that the schema matches the project structure.

---

## IBM-Provided Helper Functions and Toolkit-Generated Stubs

`CopyMessageHeaders` and `CopyEntireMessage` are **not** hand-written code. The Eclipse Toolkit **pre-populates both as local procedures into every ESQL module it generates**, together with two commented-out `CALL`s in `Main`. A freshly generated Compute module looks like this:

```esql
CREATE COMPUTE MODULE MyFlow_Compute
	CREATE FUNCTION Main() RETURNS BOOLEAN
	BEGIN
		-- CALL CopyMessageHeaders();
		-- CALL CopyEntireMessage();
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

	CREATE PROCEDURE CopyEntireMessage() BEGIN
		SET OutputRoot = InputRoot;
	END;
END MODULE;
```

**Do NOT flag** these procedures as "hand-rolled", "duplicated across modules", or "shadowing IBM built-ins". Identical copies of this exact stub in every module are the Toolkit default, not a code-quality problem. This is the single most common false positive in ESQL reviews - do not raise it.

**The only checks that apply to the stubs:**

1. **Unused stub → suggest removal (🟢 Low).** If the procedures are present but never `CALL`ed anywhere in `Main` (the `CALL`s are still commented out, or there is no call at all), they are dead code. Suggest deleting the unused procedures to keep the module clean. This is a tidy-up, not a defect.
2. **Genuine hand-rolled clone → flag as duplication.** Only flag duplication when a procedure with a **different or similar name** (e.g. `CopyHeaders`, `CopyAllHeaders`, `MoveMessage`) replicates this signature - the `WHILE I < CARDINALITY(InputRoot.*[])` header-copy loop or the `SET OutputRoot = InputRoot` full copy - or a slight deviation of it. That is someone re-implementing the built-in behaviour by hand and should use the standard procedure instead.

**Separately, do flag** using `CopyEntireMessage()` (or `SET OutputRoot = InputRoot`) when the compute mode does not require a full copy (see `flow_guidelines.md` - Compute Mode decision matrix), or performing a full tree copy when only a targeted copy of specific headers is needed (see the targeted copy pattern in `flow_guidelines.md`). That is a runtime-efficiency finding about **how the copy is used**, independent of the stub procedures above.

---

## Output Tree Header Order

`OutputRoot` is serialized to the wire in **child order**, so the tree must be built in the order the receiving transport expects:

1. `Properties` first.
2. Transport / protocol headers in wire order - MQ: `MQMD`, then `MQMDE` (if present), then `MQRFH2`; HTTP: the relevant `HTTPInputHeader` / `HTTPResponseHeader` / `HTTPRequestHeader`.
3. Body parser (`XMLNSC`, `JSON`, `DFDL`, `BLOB`, etc.) last.

When the body is created before the headers, or `Properties` is not first, the headers land in the wrong physical position or are silently dropped, producing an unreadable message downstream. `CopyMessageHeaders()` and `CopyEntireMessage()` emit the correct order on their own, so code that copies headers and then writes the body is fine.

**Check:** In modules that build `OutputRoot` by hand, verify the body folder (`OutputRoot.JSON` / `OutputRoot.XMLNSC` / etc.) is not written before the headers, that `Properties` is established first, and that `MQRFH2` is created as the next sibling of `MQMD` rather than implicitly via a folder-value `SET`. Flag a body-first build order or an `MQRFH2` written ahead of `MQMD`.

---

## Message Domain Handling

Choosing the wrong message domain results in unnecessary parsing overhead, incorrect tree access, or failure to parse at all.

### Domain Selection Guidelines

| Domain | Use when |
|--------|----------|
| `XMLNSC` | XML input with namespace awareness required - preferred for most XML scenarios |
| `XML` | Legacy XML without namespace support - avoid for new development |
| `JSON` | JSON input/output |
| `BLOB` | Binary or opaque content - no parsing, maximum performance |
| `MRM` | Fixed-format or model-driven messages (SWIFT, EDIFACT, etc.) |
| `DFDL` | Complex fixed-format messages with DFDL schema |

### Common Issues

- Using `XMLNSC` when the message is binary and no parsing is needed - use `BLOB`
- Using `XML` instead of `XMLNSC` for namespace-aware XML - `XML` does not support namespaces correctly
- Relying on parser auto-detection instead of explicitly setting the domain - auto-detection adds overhead and can misidentify format

**Check:** Verify that input nodes and ResetContentDescriptor nodes explicitly set the correct domain for the data being processed.

### JSON Schema Validation

When reviewing JSON validation nodes or JSON schema files, note that ACE supports **JSON Schema draft 4 only**. Draft 6, 7, or 2019-09 keywords (`contains`, `if`, `then`, `else`, `$defs`, `propertyNames`, `$id`, `examples`) are not supported and will be silently ignored or cause runtime errors.

See also: `flow_guidelines.md` - JSON Schema Version Compatibility.

---

## NULL Handling

Incorrect NULL comparisons in ESQL are a common source of subtle bugs. ESQL follows SQL semantics: `NULL = NULL` evaluates to `UNKNOWN`, not `TRUE`.

### Rule

Always use `IS NULL` or `IS NOT NULL` for NULL comparisons. Never use `= NULL` or `<> NULL`.

### Example

```esql
-- WRONG: = NULL never evaluates to TRUE in ESQL
IF InputBody.Field = NULL THEN ...

-- CORRECT: IS NULL is the proper SQL/ESQL syntax
IF InputBody.Field IS NULL THEN ...

-- Use COALESCE to provide a default when a field may be NULL
DECLARE safeValue CHARACTER COALESCE(InputBody.Field, 'default');
```

**Check:** Scan for any `= NULL` or `<> NULL` comparisons - these are always bugs. Also check that COALESCE is used where downstream code assumes a non-null value.

---

## Summary

Key ESQL review guidelines:

1. **Map file structure first** - identify Main() vs. helper procedures before reviewing; scope every finding to the correct function
2. **Use references** for array and message tree navigation
3. **Calculate CARDINALITY once** and store in a variable
4. **Use LASTMOVE()** instead of CARDINALITY for child element checks
5. **Declare multiple variables** in a single statement
6. **Initialize variables** during declaration
7. **Use parameterized PASSTHRU** statements with variables
8. **Cache string manipulation** results in variables
9. **Declare BROKER SCHEMA** at the top of every .esql file
10. **Do not flag Toolkit-generated stubs** (`CopyMessageHeaders`, `CopyEntireMessage`) as hand-rolled or duplicated - suggest removal only if unused, flag a differently-named clone of their signature, and separately flag `CopyEntireMessage()` where the compute mode makes it unnecessary (see IBM-Provided Helper Functions and Toolkit-Generated Stubs)
11. **Choose the correct message domain** explicitly - do not rely on auto-detection
12. **JSON Schema: draft 4 only** - ACE does not support draft 6/7/2019 keywords
13. **Use IS NULL / IS NOT NULL** - never `= NULL` or `<> NULL`
14. **Build the output tree in header order** - `Properties`, then transport headers in wire order, then body last; flag body-first builds and `MQRFH2` ahead of `MQMD`
