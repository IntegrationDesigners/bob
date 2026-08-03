---
template_version: 0.1.0
last_updated: 2026-06-03
compatible_with: ACE Flow Builder v0.2.0+
status: stable
---

# ACE ESQL Style & Readability Rules

Thirteen rules captured from real flow-building sessions about how to *write* ESQL - naming, reference naming, single-use extraction, declaration placement, control flow, comments. Apply these while generating any `.esql` file in `ace-flow-builder`. They sit alongside `validated_rules.md` (which covers correctness - `MQRFH2`, `MQFMT_*`, etc.); style rules don't override correctness rules, they complement them.

Each rule has the same shape: rule statement → why it matters → ✅ Good → ❌ Bad → optional Nuance or Exception.

---

## Naming

### Rule 1 - Functional variable names

Variables are named for what they hold, not their type, position, or a generic placeholder.

**Why:** ESQL is read more than it is written, and a meaningful name is the cheapest possible comment. `customerEmail` tells the next reader what's in the variable; `tmp` makes them scroll back to the `DECLARE`.

**Forbidden defaults:** `x`, `tmp`, `temp`, `data`, `val`, `result`, `str`, `num`, `obj`.

✅ **Good**
```esql
DECLARE customerEmail CHARACTER InputBody.Customer.Email;
IF customerEmail LIKE '%@%' THEN ...
```

❌ **Bad**
```esql
DECLARE tmp CHARACTER InputBody.Customer.Email;
IF tmp LIKE '%@%' THEN ...
```

**Exception:** Short numeric loop indexes (`i`, `j`, `k`) inside tight `WHILE`/`FOR` loops, and `REFERENCE` cursors - which carry the `ref` prefix per Rule 13 (`refInput`, `refOutput`, `refBody`, …).

---

### Rule 2 - Procedure names express intent (verb-noun)

Procedures and functions are named for what they do, in `verbNoun` form.

**Why:** At the call site, the procedure name is the only documentation the reader sees. `CALL process();` tells them nothing; `CALL mapCustomerToCanonical(...)` tells them everything they need to skim past.

**Forbidden defaults:** `process`, `handle`, `doStuff`, `helper`, `helper1`, `run`, `execute`.

✅ **Good**
```esql
CALL validateRequest(refInput);
CALL mapCustomerToCanonical(refInput, refOutput);
CALL buildErrorResponse(refOutput, errCode, errText);
```

❌ **Bad**
```esql
CALL process(refInput);
CALL handle(refInput, refOutput);
CALL doStuff(refOutput);
```

---

### Rule 3 - No Hungarian / type prefixes

Don't prefix variable names with type tags (`str`, `int`, `b`, `n`, `arr`).

**Why:** The `DECLARE` already states the type. The prefix is noise that drifts out of sync when the type changes, and it makes the actual concept harder to grep.

✅ **Good**
```esql
DECLARE customerCount INTEGER 0;
DECLARE customerName CHARACTER InputBody.Name;
DECLARE isActive BOOLEAN TRUE;
```

❌ **Bad**
```esql
DECLARE intCustomerCount INTEGER 0;
DECLARE strCustomerName CHARACTER InputBody.Name;
DECLARE bIsActive BOOLEAN TRUE;
```

**Exception:** `REFERENCE` cursors carry the `ref` prefix (Rule 13: `refInput`, `refOutput`, …) - `ref` is the one sanctioned prefix, because it marks a behaviourally-distinct category (tree cursor vs value), not a redundant type tag.

---

### Rule 4 - Avoid abbreviations unless universal

Spell out the concept. Universal industry abbreviations are fine; private shorthand is not.

**Why:** The author always knows what `custEml` means; the next reader has to guess. The cost of typing four extra characters is paid once; the cost of decoding is paid every time the code is read.

**Fine to use:** `id`, `url`, `http`, `https`, `json`, `xml`, `csv`, `mq`, `db`, `api`, `uri`, `uuid`, `dn`, `ip`.

**Not fine:** `cust`, `emp`, `eml`, `addr`, `desc`, `qty`, `amt`, `prc`, `acct`.

✅ **Good**
```esql
DECLARE customerEmail CHARACTER InputBody.Customer.Email;
DECLARE orderQuantity INTEGER InputBody.Order.Quantity;
DECLARE productDescription CHARACTER InputBody.Product.Description;
```

❌ **Bad**
```esql
DECLARE custEml CHARACTER InputBody.Customer.Email;
DECLARE ordQty INTEGER InputBody.Order.Quantity;
DECLARE prdDesc CHARACTER InputBody.Product.Description;
```

**Test:** If a teammate would have to ask what the abbreviation means, spell it out.

---

## Variables

### Rule 5 - No single-use variables

Don't declare a variable that's read only once. Either inline the expression, or - if the name genuinely documents intent the expression doesn't - keep it and accept it as deliberate documentation.

**Why:** Each extra `DECLARE` adds a line of noise, a name the reader has to track, and a parse step. A single-use variable is almost always either a missed inlining or a missing rename.

✅ **Good** - inline when the call already reads cleanly
```esql
SET OutputRoot.JSON.Data.length = LENGTH(InputBody.Field);
```

❌ **Bad** - pointless intermediate
```esql
DECLARE tmp INTEGER LENGTH(InputBody.Field);
SET OutputRoot.JSON.Data.length = tmp;
```

**Nuance:** Keep the variable if the name carries meaning the expression doesn't. `customerIdLength` adds context that bare `LENGTH(InputBody.Customer.Id)` doesn't - keeping it for documentation is fine, even if used once.

---

### Rule 6 - One variable, one purpose

A variable holds one logical thing for its entire scope. Don't reuse `tmp` for an integer at line 10 and a string at line 30, and don't reuse `result` to hold three unrelated intermediate values.

**Why:** A reused variable forces the reader to mentally re-bind the name at every reassignment, and it defeats whatever the name was supposed to document.

✅ **Good**
```esql
DECLARE customerName CHARACTER InputBody.Customer.Name;
DECLARE orderCount   INTEGER   CARDINALITY(InputBody.Orders.Order[]);
```

❌ **Bad**
```esql
DECLARE tmp CHARACTER InputBody.Customer.Name;
-- ...20 lines later...
SET tmp = CAST(CARDINALITY(InputBody.Orders.Order[]) AS CHARACTER);
```

---

### Rule 7 - Declare close to first use

Declare a variable on the line before its first use, inside the smallest block containing all its uses. Don't front-load every `DECLARE` at the top of `Main()`.

**Why:** Keeps the value, its name, and its purpose in a single visual chunk. The reader doesn't have to scroll back 40 lines to remember what `customerEmail` was initialised to.

✅ **Good**
```esql
-- ... earlier logic ...
DECLARE customerEmail CHARACTER InputBody.Customer.Email;
IF customerEmail LIKE '%@%' THEN
    SET OutputRoot.JSON.Data.email = customerEmail;
END IF;
```

❌ **Bad**
```esql
DECLARE customerEmail CHARACTER InputBody.Customer.Email;
DECLARE orderCount    INTEGER   0;
DECLARE isActive      BOOLEAN   FALSE;
-- ... 40 unrelated lines ...
IF customerEmail LIKE '%@%' THEN ...  -- finally
```

**Nuance:** Yields to the standing "Declare Statements" grouping rule when several same-type variables share a scope and are used together - combine them into one `DECLARE` line first, then place that line close to the use site.

---

## Structure

### Rule 8 - No single-use procedures/functions

Don't extract a `PROCEDURE` or `FUNCTION` that's called from exactly one place. Inline it.

**Why:** ESQL has no inlining optimiser. An extracted single-use proc costs a call frame at runtime and forces the reader to jump out of `Main()` to follow the logic. The benefit a proc normally provides - reuse, named abstraction - is absent when there's exactly one caller.

✅ **Good** - short header setup inlined into `Main()`
```esql
-- inside Main()
CALL CopyMessageHeaders();
SET OutputRoot.Properties.MessageFormat = 'JSON';
```

❌ **Bad** - three-line helper called once
```esql
-- inside Main()
CALL setupHeaders();
-- ...later, at the bottom of the module...
CREATE PROCEDURE setupHeaders() BEGIN
    CALL CopyMessageHeaders();
    SET OutputRoot.Properties.MessageFormat = 'JSON';
END;
```

**Exception:** Keep the extraction when the body is large enough that inlining hurts the caller's readability - typically `> ~15 lines` or `> 2 levels of nesting`, e.g. a multi-field canonical mapping, a multi-branch validator, a complex error-response builder. The threshold is judgement, not arithmetic: if inlining would push `Main()` past the point where you can read it top-to-bottom in one pass, keep the proc.

---

### Rule 9 - Don't reinvent ESQL built-ins

Before writing a custom `FUNCTION` or `PROCEDURE`, check whether ESQL already provides what you need. If a built-in does the same job, use the built-in.

**Why:** Custom helpers cost maintenance, can drift in behaviour (NULL handling, edge cases), and force every reader to open the helper to understand what's happening. The built-in is documented, optimised by the engine, and one line at the call site. Rule 8 says "only extract when reused or for readability" - this rule adds: "and only when there is no built-in to reuse instead."

✅ **Good** - use the built-in directly
```esql
SET OutputRoot.JSON.Data.suffix = COALESCE(RIGHT(value, 3), '');
-- or, with NULL-safe input:
SET OutputRoot.JSON.Data.suffix = RIGHT(COALESCE(value, ''), 3);
```

❌ **Bad** - a custom helper reinventing `RIGHT` + `COALESCE`
```esql
CREATE FUNCTION RightString(IN value CHARACTER, IN len INTEGER) RETURNS CHARACTER
BEGIN
    DECLARE v        CHARACTER COALESCE(value, '');
    DECLARE startPos INTEGER   LENGTH(v) - len + 1;
    IF startPos < 1 THEN SET startPos = 1; END IF;
    RETURN SUBSTRING(v FROM startPos FOR len);
END;
```

**Common built-ins that get reinvented (use these, don't wrap them):**

| Need | Built-in |
|---|---|
| Default for NULL | `COALESCE(x, y)` |
| Right N characters | `RIGHT(x, n)` |
| Left N characters | `LEFT(x, n)` |
| Substring | `SUBSTRING(x FROM start FOR len)` |
| Strip whitespace | `TRIM(x)` / `TRIM(LEADING ...)` / `TRIM(TRAILING ...)` |
| Length | `LENGTH(x)` |
| Replace | `REPLACE(x, search, replace)` |
| Uppercase / lowercase | `UPPER(x)` / `LOWER(x)` |
| Position of substring | `POSITION(needle IN haystack)` |
| Cardinality of an array | `CARDINALITY(arr[])` |
| Element exists | `EXISTS(path[])` or `LASTMOVE(ref)` |
| Type cast | `CAST(x AS <type>)` (with `FORMAT '...'` for dates) |
| Format a date | `CAST(CURRENT_TIMESTAMP AS CHARACTER FORMAT 'yyyyMMdd')` |
| Generate UUID | `UUIDASCHAR` (no parens - it's a constant function) |

**Exception:** A custom helper is justified when the built-in genuinely doesn't cover the case - e.g. a domain-specific normalisation that involves several steps and is reused. Even then, name the helper for the business rule (`canonicaliseCustomerId`) not the mechanism (`StringCleaner`), and per Rule 8 it must be called more than once.

**How to apply:** When you find yourself about to write a `CREATE FUNCTION` or `CREATE PROCEDURE`, ask "is there a one-line ESQL expression that does this?" If yes, write the expression at the call site.

---

### Rule 10 - Fail fast

Handle failure cases at the top of a procedure with an early exit (`PROPAGATE TO TERMINAL 'failure'; RETURN FALSE;` or equivalent), and keep the happy path flat. Don't nest the success branch inside 3-5 levels of `IF ... END IF`.

**Why:** Nested success branches grow into pyramids: every reader has to track which `END IF` closes which condition and which level is the "real" logic. Early-exit guards keep the happy path at indent level 0.

✅ **Good** - guards at the top, success path flat
```esql
IF InputRoot.JSON IS NULL THEN
    PROPAGATE TO TERMINAL 'failure';
    RETURN FALSE;
END IF;
IF NOT EXISTS(InputBody.Customer[]) THEN
    PROPAGATE TO TERMINAL 'failure';
    RETURN FALSE;
END IF;

-- happy path, flat
SET OutputRoot.JSON.Data.customerId = InputBody.Customer.Id;
SET OutputRoot.JSON.Data.email      = InputBody.Customer.Email;
RETURN TRUE;
```

❌ **Bad** - success nested inside three guards
```esql
IF InputRoot.JSON IS NOT NULL THEN
    IF EXISTS(InputBody.Customer[]) THEN
        IF InputBody.Customer.Id IS NOT NULL THEN
            SET OutputRoot.JSON.Data.customerId = InputBody.Customer.Id;
            SET OutputRoot.JSON.Data.email      = InputBody.Customer.Email;
            RETURN TRUE;
        END IF;
    END IF;
END IF;
PROPAGATE TO TERMINAL 'failure';
RETURN FALSE;
```

---

## Comments

### Rule 11 - Comment the WHY, not the WHAT

A comment earns its place when it explains something the code can't: a hidden constraint, an MQ or parser quirk, a workaround for a known bug, a non-obvious business rule. Don't restate what the next line literally says.

**Why:** Comments that paraphrase the code add visual noise and rot the moment the code changes underneath them. Comments that explain *why* survive refactors because they're tied to the constraint, not the syntax.

✅ **Good** - explains a constraint the code can't
```esql
-- MQRFH2 must be CREATEd as NEXTSIBLING of MQMD before any usr fields
-- are set, otherwise the parser silently drops them. See validated_rules.md §2.
CREATE NEXTSIBLING OF OutputRoot.MQMD DOMAIN 'MQRFH2';
```

❌ **Bad** - restates the code
```esql
-- copy headers
CALL CopyMessageHeaders();

-- set the length
SET OutputRoot.JSON.Data.length = LENGTH(InputBody.Field);
```

---

### Rule 12 - No commented-out code

Delete dead code. Git remembers.

**Why:** Commented-out blocks rot - they reference variables that no longer exist, behaviour that's no longer correct, and approaches that were rejected. They mislead readers about what's live and add visual noise. Anything worth keeping belongs in git history, not in the current file.

✅ **Good** - clean current file, the old approach lives in git
```esql
SET OutputRoot.JSON.Data.customerId = InputBody.Customer.Id;
```

❌ **Bad** - dead block competing with the live line
```esql
-- SET OutputRoot.JSON.Data.customerId = CAST(InputBody.Customer.Id AS INTEGER);
-- SET OutputRoot.JSON.Data.customerId = COALESCE(InputBody.Customer.Id, 0);
SET OutputRoot.JSON.Data.customerId = InputBody.Customer.Id;
```

**Exception:** None. If you genuinely need to keep an alternative implementation visible, document the WHY in a comment (per Rule 10) and reference the git SHA where the old code lives - don't paste the old code itself.

---

## References

### Rule 13 - Prefix REFERENCE variables with `ref`

Every `REFERENCE` variable starts with a lowercase `ref`, followed by what it points at in PascalCase: `refInput`, `refOutput`, `refBody`, `refInsert`, `refException`.

**Why:** A `REFERENCE` is a live cursor into the message tree, not a value. The `ref` prefix makes that visible at every use site - `SET refBody.id = ...` reads clearly as "mutate the tree under the cursor". It also keeps cursor names clear of ESQL reserved words: a cursor over `ParserException.Insert` becomes `refInsert`, never `insert` - `INSERT` is a reserved keyword and the Toolkit ESQL parser rejects it as an identifier (`ibmint package` is lax and won't flag it). This convention replaces the older in/out-suffix cursor names.

✅ **Good**
```esql
DECLARE refBody REFERENCE TO InputRoot.JSON.Data;
DECLARE refOutput REFERENCE TO OutputRoot.JSON.Data;
SET refOutput.id = refBody.customerId;

DECLARE refInsert REFERENCE TO refParserError.Insert[1];
```

❌ **Bad**
```esql
DECLARE insert REFERENCE TO parserError.Insert[1];   -- reserved word -> Toolkit parser error
DECLARE bodyCursor REFERENCE TO InputRoot.JSON.Data;  -- no `ref` prefix
```

**Note:** This is the one sanctioned exception to Rule 3 (no type prefixes) - `ref` marks a genuine, behaviourally-distinct category (tree cursor vs value), not a redundant restatement of the declared type.
