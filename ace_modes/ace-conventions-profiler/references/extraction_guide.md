# Extraction Guide - Detection Recipes

Concrete recipes for the profiler, grounded in real ACE v13 file shapes. Section B was calibrated against a real estate (2026-06); remaining `[CALIBRATE]` markers, if any, flag recipes still unverified against production files - lower confidence on findings that depend on one until confirmed.

---

## A. Project classification (Phase 1.1)

Read `.project` `<natures>`. Exact strings:

| Project kind | Natures present |
|---|---|
| Application | `com.ibm.etools.msgbroker.tooling.applicationNature` + `...messageBrokerProjectNature` |
| Shared library | `com.ibm.etools.msgbroker.tooling.libraryNature` + `...sharedLibraryNature` + `...messageBrokerProjectNature` |
| Static library | `com.ibm.etools.msgbroker.tooling.libraryNature` + `...staticLibraryNature` + `...messageBrokerProjectNature` |
| REST API application | `com.ibm.etools.mft.restapi.ui.Nature` + `...applicationNature` + `...messageBrokerProjectNature` |

`library.descriptor` confirms a library and its kind via its `type=` attribute, e.g.
`type="com.ibm.etools.msgbroker.tooling.sharedLibraryNature"`. Namespace `http://com.ibm.etools.mft.descriptor.lib`.

A large estate can hold hundreds of apps and 100+ libraries. The library index (Section B) is **whole-estate** (cheap: just read descriptors). The per-axis extraction (Section E) is from a **sample** of apps. Keep that distinction in the profile provenance.

---

## B. Library reference counting (Phase 1.2)

An application declares the libraries it references in **two** places. Read both, union per app, then count distinct apps per library.

1. **App `.project` `<projects>` section** - Eclipse project references:
   ```xml
   <projects>
     <project>SomeSharedLib</project>
   </projects>
   ```
   This is **frequently populated** and on real estates commonly mirrors `<references>` exactly. (The v0.1 assumption that it is "usually empty" was wrong - empty is the isolated-test-app case, not the norm.)

2. **`application.descriptor` `<references>`** - namespace `http://com.ibm.etools.mft.descriptor.app`, root `ns2:appDescriptor`. CONFIRMED shape: each entry is wrapped in `<sharedLibraryReference>`, not a bare `<libraryName>`:
   ```xml
   <references>
     <sharedLibraryReference><libraryName>SomeSharedLib</libraryName></sharedLibraryReference>
     <sharedLibraryReference><libraryName>AnotherLib</libraryName></sharedLibraryReference>
   </references>
   ```
   Count by matching `<libraryName>([^<]+)</libraryName>` inside `<references>`.

3. **REST API apps use `restapi.descriptor`, not `application.descriptor`** - namespace `http://com.ibm.etools.mft.descriptor.restapi`, root `ns2:restapiDescriptor`. Its `<references>` block uses the **same** `<sharedLibraryReference><libraryName>` shape, so reference counting must glob BOTH `application.descriptor` and `restapi.descriptor`. The REST descriptor additionally declares:
   - `<ns2:operations>` mapping operation name -> implementing subflow, and
   - `<ns2:errorHandlers>` with `type="CATCH|FAILURE|TIMEOUT"` -> handler subflow. **REST error handlers are declared here, not wired in the `.msgflow`** - read this file for the error-handling axis on REST apps (see E3).

**Classification:** distinct-app-count high -> framework; count == 1 -> app-specific. Record the number. (A mid-range count is a domain library shared within one business area - label it as such rather than forcing framework/app-specific.)

**Fallback when both are empty but usage exists:** if Phase 2 shows a subflow/ESQL module physically located in library L being invoked by N apps, treat L as shared on usage evidence and set confidence `medium` (not `high`), noting the reference sections were empty.

---

## C. Reusable-unit index (Phase 1.3)

| Unit | Where | What to capture |
|---|---|---|
| Subflow | `*.subflow` | file name (= node type when referenced), source/sink terminals, internal nodes |
| ESQL module | `*.esql` | `BROKER SCHEMA <x>`, each `CREATE COMPUTE/PROCEDURE/FUNCTION MODULE <name>`, each `CREATE PROCEDURE`/`CREATE FUNCTION` |
| Java | `*.java` in the sibling `<App>Java` project | public classes + methods called from JavaCompute nodes |
| Map | `*.map` | `mappingDeclaration name`, input/output message assemblies |
| Message model | `*.mxsd` / `*.xsd` / `*.json` | root element/type names, location (which project/folder) |

Tag every unit with its owning project and the framework/app-specific verdict from B.

A library subflow is referenced from a flow as `<Lib>_<Sub>.subflow:FCMComposite_1` with a matching `xmlns:<Lib>_<Sub>.subflow="<Lib>/<Sub>.subflow"` on the package - that wiring is the cross-reference link in Section D.

---

## D. Node usage in flows (Phase 2)

In a `.msgflow` / `.subflow` (`ecore:EPackage`):
- **Built-in nodes** appear as `<nodes xmi:type="ComIbm<Type>.msgnode:FCMComposite_1" ...>`. Capture the `ComIbm<Type>`, the `translation` label string, and key attributes (e.g. `computeExpression`, `queueName`, `URLSpecifier`, `messageDomainProperty`, `messageSet`).
- **Subflow nodes** (reuse signal) appear as `<nodes xmi:type="<subflowName>.subflow:FCMComposite_1" ...>` with a matching `xmlns:<subflowName>.subflow="..."` on the package. A subflow from a framework library used across apps is a framework usage.
- **ESQL linkage**: `computeExpression="esql://routine/<schema>#<module>.Main"` ties a Compute node to its module. The middle segment is the **BROKER SCHEMA** when one is declared (`esql://routine/com.acme.orders#Setup.Main`); a flat app with no schema uses the empty segment (`esql://routine/#Setup.Main`); a library routine uses the library name (`esql://routine/<Lib>#<Module>.Main`). Use this to map node -> ESQL module and to detect whether the app declares a schema.
- **Connections**: `<connections ... sourceTerminalName=... targetTerminalName=...>`. Use to detect whether `Catch`/`Failure`/`Timeout` terminals are wired and to what, and to detect `PROPAGATE TO LABEL`-style fan-out to named Label nodes.

---

## E. Per-axis recipes (Phase 3)

1. **Frameworks** - framework subflows/modules from C invoked across apps (D). Capture the call convention: which terminal, what is set on `Environment`/`LocalEnvironment` before the call, naming of the invoking node. ESQL library calls appear in two valid styles, detect both: fully-qualified `CALL <Lib>.<Proc>(...)` / `<Lib>.<Func>(...)`, OR a `PATH <Lib>;` declaration at the top of the module followed by unqualified calls.
2. **Logging** - recurring log nodes (Trace `ComIbmTrace`, a logging subflow, a JavaCompute logger) and the ESQL pattern that feeds them (e.g. set `Environment.Variables.Log.*` then `PROPAGATE TO LABEL '<LOG>'`). Capture node type, where in the flow it sits (entry / per-step / error path), what fields it writes (correlation id, status, payload, fixed fields), the field-name casing (watch for historical variants of the same field), and the label naming.
3. **Error handling** - recurring handler subflows (names like `*CatchHandler`, `*FailureHandler`, `*TimeoutHandler`). For REST apps these are declared in `restapi.descriptor` `<ns2:errorHandlers>` (B item 3), NOT wired in the `.msgflow` - read the descriptor. For MQ apps look for retry/drop/backout subflows on named Label nodes. Capture the error-response structure and cross-check `error_handling_guidelines.md`.
4. **Integration patterns** - input/output node pairing per flow: WSInput+WSReply (request-reply), MQInput with no reply (fire-and-forget), TimeoutControl+TimeoutNotification (delayed retry), aggregation nodes (scatter-gather), FileInput->queue (file-pickup), DB work-queue (insert rows + forward to in-progress queue). Count occurrences.
5. **Naming** - tokenize project/repo names, `BROKER SCHEMA` packages, flow names, ESQL module names (`<FlowName>[_<Purpose>]` is common), node labels, queue names, UDP names, and any log-prefix value. Look for a dominant scheme; flag competing schemes as variants. Cross-check `esql_style.md`.
6. **Configuration / externalization** - UDPs (flow `eStructuralFeatures`, promoted from library subflows via `attributeLinks`, read in ESQL via `DECLARE <x> EXTERNAL <type>`), per-environment `deploymentDescriptors/<App>_<ENV>.properties`, `.policyxml`, configurable services, vault references. Capture what is externalized vs hardcoded - and note when UDP `defaultValueLiteral` holds committed environment-specific values (test UNC paths, tenant GUIDs) that are meant to be overridden at deploy, so flow-builder does not treat them as canonical.
7. **Project / package structure** - folder layout (whether `.esql` sits under folders mirroring the `BROKER SCHEMA` path, where schemas live), app/lib naming, REST `gen/` + `deploymentDescriptors/` folders.
8. **Message modeling / formats** - which domain each node uses (`messageDomainProperty` / `ResetContentDescriptor`), DFDL vs XMLNSC vs JSON vs BLOB, where models live. Shared schemas are often referenced with `{LibraryName}schema.json` syntax (in `messageSet`/schema attributes); app-local schemas live in the app. Note the JSON-schema draft-4 ACE constraint.
9. **Security / credentials** - policy projects (`MQEndpoint` etc. in `.policyxml`), security/TLS profiles (often pinned via UDP), how credentials are referenced (by named identity resolved from a host vault / Windows Credential Manager / `mqsisetdbparms`) and kept out of source. Record a `mqsisetdbparms` finding as `descriptive (legacy)` - when the profile becomes prescriptive guidance, the modern path is the ibmint vault (`ibmint set credential`). Cross-check `security_guidelines.md` for SQL/parameterization patterns.
10. **Transaction / recovery** - backout queue config, retry/circuit-breaker shapes (timer pairs, retry/drop subflows with retry-count UDPs), self-requeue variants, MQ transactionality.
11. **Monitoring / audit** - the primary audit trail (e.g. a central log store correlated by an activity/correlation id generated once per message), Trace-node diagnostics, and any legacy monitoring style (e.g. CBE / Common Base Event) that should be recognised but not replicated.

For every finding: support count (occurrences / total examined), confidence, prescriptive/descriptive (with the qualifier vocabulary in `profile_template.md`), and the correctness cross-check (Section F).

---

## F. Correctness cross-check (Phase 3)

Before canonicalising any finding, check it against these (read, never duplicate):
- `../../ace-flow-builder/references/validated_rules.md`
- `../../ace-flow-builder/references/esql_style.md`
- `../../ace-flow-builder/references/refactoring_patterns.md`
- `../../ace-review/references/guidelines/{esql,flow,error_handling,security,performance_monitoring}_guidelines.md`
- `../../ace-review/references/guidelines/ten_ace_message_flow_mistakes.md`

If a consistent pattern matches a known anti-pattern or violates a validated rule, mark it `CONFLICT - <rule> - replicate anyway or fix?` and carry it to Phase 4 unresolved. The user's curation decision becomes the entry's `resolution` (replicate / encourage / fix / dropped - see `profile_template.md`).

---

## G. Customer-vs-IBM artifact test (Phase 1.4 missing-library gate)

A referenced-but-missing project is a **customer artifact you must ask for** when it would be a normal ACE project (has/should have a `library.descriptor`, a customer-style name, lives under the workspace). It is an **external dependency to note and skip** when it is:
- an IBM-supplied component (names under `com.ibm.*`, IBM connector/adapter packs), or
- a third-party jar / shared component referenced from a JavaCompute classpath rather than an ACE library project.

The user may also **waive** a missing customer library (e.g. a trailing reference into a repo no longer used). When waived, record it under the profile's "Open questions / Resolved" with the waiver reason and do not block the run. When in doubt, ask rather than assume - but never block the whole run on an obviously IBM-supplied dependency.
