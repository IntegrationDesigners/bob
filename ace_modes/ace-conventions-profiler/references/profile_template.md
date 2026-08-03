# Profile Template - `customer_profile.md`

This is the **contract**. The profiler emits exactly these sections as `customer_profile.md`, which the customer installs into their `ace-flow-builder` copy at `references/customer_profile.md`; `ace-flow-builder` reads exactly these sections. The axis headings here must match the Phase 3 axes in `workflow.md` and the sections flow-builder's profile-detection step reads. Do not rename sections without changing both ends.

Copy the structure below into the emitted file, filling every field. Drop an axis section only if there was genuinely no evidence for it, and when you do, list it under "Axes with no evidence" so a reader knows it was looked for and not found (absence of a section must never read as "covered, nothing to say").

Each convention entry uses this block:

```
### <convention statement, one line, imperative>
- Support: <X of N flows> / <Y of M apps>
- Confidence: high | medium | low
- Type: <one of the Type values below>
- Exemplar: <relative path to the clearest example>[ + mermaid if a shape needs showing]
- Conflict: none | CONFLICT - <which correctness rule/anti-pattern> - resolution: <resolution value below>
- Notes: <optional - edge cases, variants, the user's curation note>
```

**Type vocabulary** (pick the most specific):
- `prescriptive` - replicate by default when building.
- `prescriptive (encouraged, not mandatory)` - apply as the default for new flows, but absence is acceptable and must NOT be flagged as a defect (e.g. a convention that only the newer apps follow).
- `prescriptive (with caveat)` - apply the default, but honour the stated caveat/exception (e.g. parameterize SQL, except a documented ODBC case).
- `descriptive` - observed, not endorsed; context only. Do not replicate unless the user asks.
- `descriptive (legacy)` - an old style to recognise in existing flows but never replicate in new work.

**Resolution vocabulary** (only on `CONFLICT` entries, set during curation):
- `replicate` - build the customer's way despite the correctness rule.
- `encourage` - recommend the convention but do not mandate it.
- `fix` - deviate from the estate toward the correctness rule.
- `dropped` - finding rejected in curation; it should not appear in the profile.

---

```markdown
CONFIDENTIAL - customer-specific. Do not commit to the skill repository or any shared/public location.

# ACE Conventions Profile - <Customer Label>

| | |
|---|---|
| Customer | <label> |
| Generated | <YYYY-MM-DD> |
| Profiler version | <x.y.z> |
| Source applications | <app1, app2, ...> |
| Source libraries | <lib1 (framework), lib2 (app-specific), ...> |
| Flows examined | <N> |

> This profile was extracted from the estate above. It states how this customer
> builds ACE, for `ace-flow-builder` to conform to. Conventions never override a
> correctness rule in `validated_rules.md`; conflicts are noted per-entry.

---

## 1. Frameworks
<convention entries - shared libraries, subflows, helper functions, and the call/wiring convention for invoking them>

## 2. Logging
<convention entries - log nodes, locations, values/payload, naming of log points>

## 3. Error handling
<convention entries - handler subflows, Catch/Failure/Timeout wiring, error response shape, naming>

## 4. Integration patterns
<convention entries - request-reply / fire-and-forget / retry / async / canonical model>

## 5. Naming standards
<convention entries - projects, BROKER SCHEMA packages, flows, nodes, ESQL variables/procedures; give the actual pattern, e.g. com.<customer>.<domain>.<function>>

## 6. Configuration and externalization
<convention entries - UDPs, policies, configurable services, vault, .properties override conventions>

## 7. Project and package structure
<convention entries - app/lib naming, folder layout, schema location>

## 8. Message modeling and formats
<convention entries - DFDL / XMLNSC / JSON / BLOB, schema location>

## 9. Security and credentials
<convention entries - policy projects, security profiles, vault patterns>

## 10. Transaction and recovery
<convention entries - backout queues, retry / circuit-breaker, MQ transactionality>

## 11. Monitoring and audit
<convention entries - monitoring events, activity log, trace conventions>

---

## Axes with no evidence
<list any axis above for which no pattern was found, so absence is explicit and not mistaken for an oversight>

## Open questions for the customer
<anything the profiler could not resolve - a CONFLICT the user deferred, an ambiguous naming variant, a missing library that was waived>
```

---

## How `ace-flow-builder` reads this

- Treat every **prescriptive** entry as a default to apply when building, at the precedence stated in flow-builder's workflow: `validated_rules.md` > this profile > generic references.
- `prescriptive (encouraged, not mandatory)` - apply as the default, but do not treat its absence as an error and do not retrofit it onto unrelated work.
- `prescriptive (with caveat)` - apply the default and honour the caveat exactly as written.
- Treat **descriptive** (and `descriptive (legacy)`) entries as context, not instructions; do not replicate them unless the user asks. A `descriptive (legacy)` entry names a style to recognise but never generate.
- A `CONFLICT` entry's `resolution` tells you what to build: `replicate` = the customer's way, `encourage` = recommend but do not force, `fix` = the corrected way, `dropped` = ignore (should not be present).
- If an entry conflicts with `validated_rules.md` and has no recorded resolution, surface it to the user rather than guessing - correctness wins by default.
