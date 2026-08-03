# ACE Conventions Profiler - Authoritative Workflow

This is the authoritative source for the profiler. Read it first, in full, before profiling anything. The SKILL.md summarises; this file governs.

The profiler is a **rule-based extractor**, not a model that learns. It runs fixed detection recipes (in `extraction_guide.md`) against an existing ACE estate, scores each finding by how consistently it appears, lets the user curate, and emits a structured **customer conventions profile** (shape defined in `profile_template.md`) that `ace-flow-builder` later consumes.

It works best across **several applications**. A single application gives weak signal (one occurrence of a pattern is not a convention). Say so up front if the user points it at one app.

---

## Confidentiality (read before writing anything)

The emitted profile necessarily contains **real library, application, node, schema, and queue names** from the customer estate. It therefore **cannot be anonymised** and stays useful only with those names intact. Two consequences, both mandatory:

1. Every generated profile (and the `analyzing.md` working file) carries a confidentiality banner at the top:
   `CONFIDENTIAL - customer-specific. Do not commit to the skill repository or any shared/public location.`
2. Print the same warning in chat when you emit the profile. Keep the profile in the customer workspace only. If any *example* profile is ever added inside this skill repo, it must use invented (anonymised) names.

---

## Phase 0 - Scope and locate

1. Ask which applications and libraries to profile, and the workspace root(s) that contain them.
2. If the user names only one application, warn that the output will be thin and ask whether more apps are available. Proceed if they confirm one is all they have.
3. Confirm the **customer label** to stamp on the profile (a short name, real or internal, the user chooses).
4. State that you will (a) index libraries, (b) cross-reference usage, (c) extract patterns with support counts, (d) present them for curation, (e) emit the profile. Then start.

Narrate each phase in one short line as you enter it (same pace discipline as the other ACE skills).

---

## Phase 1 - Library index (fan-out)

Goal: a classified inventory of every project and every reusable unit, so later phases can tell framework code from app-local code.

### 1.1 Discover projects
Glob every `.project`, `library.descriptor`, `application.descriptor`, and `restapi.descriptor` under the workspace root(s). For each project read `.project` `<natures>` and classify (see `extraction_guide.md` for exact nature strings):
- **Application** - `applicationNature`
- **Shared library** - `libraryNature` + `sharedLibraryNature`
- **Static library** - `libraryNature` + `staticLibraryNature`
- **REST API application** - `restapi.ui.Nature` + `applicationNature`

### 1.2 Classify libraries: framework vs app-specific
For each library, count how many **distinct applications** reference it. References live in two places and you must read both (see `extraction_guide.md` Section B):
- the application `.project` `<projects>` section (Eclipse project references), and
- `application.descriptor` `<references>` (and, for REST apps, `restapi.descriptor` `<references>`), where each entry is `<sharedLibraryReference><libraryName>X</libraryName></sharedLibraryReference>`.

Heuristic: referenced by **many** apps -> generic framework library; **one** -> app-specific; a **mid-range** count is usually a domain library scoped to one business area (label it that way). Record the count, not just the verdict.

This index is **whole-estate** and cheap (descriptor reads only), so classify every library even though you will only profile a sample of apps in later phases.

> Fallback: if both reference locations are empty but usage exists, fall back to **usage-based** evidence from Phase 2 (a subflow/ESQL module from library L invoked by N apps is de facto shared) and lower confidence accordingly.

### 1.3 Index reusable units
Build an index of every reusable unit, tagged with its owning project and the framework/app-specific verdict:
- subflows (`.subflow`)
- ESQL modules and their `CREATE PROCEDURE` / `CREATE FUNCTION` (with `BROKER SCHEMA`)
- Java compute classes and public methods
- maps (`.map`)
- message models (`.mxsd` / `.xsd` / `.json` schemas)

### 1.4 Missing-library gate
If an application references a library that is **not found on disk**:
- If it is a **customer artifact** (a project that would carry `library.descriptor`, not an IBM/third-party supplied component): stop and ask the user to supply it. The profile is unreliable without it.
- If it is **IBM-supplied or third-party** (apply the customer-vs-IBM test in `extraction_guide.md`): note it as an external dependency and continue. Do not nag for it.
- The user may also **waive** a missing customer library (e.g. a trailing reference into a retired repo). When waived, record it in the profile's Open questions / Resolved with the reason, and continue.

### 1.5 Select the app sample for the per-axis pass
The library index is whole-estate, but per-axis extraction runs on a sample. Choose it deliberately:
- Rank candidate apps by **most recent commit** (`git log` per repo) to favour current house style, not abandoned legacy. Note that commit-date ranking can differ from file-mtime ranking; prefer commit date.
- **Diversify across domains.** An active migration or one busy team can dominate a recency ranking and bias the sample toward one shape. Spread the sample across distinct business areas / system families so the profile reflects breadth, not one project. If you cannot, say so in the provenance.
- Keep the first pass small (single digits) and extend in later passes; the profile provenance lets a re-run diff cleanly.

---

## Phase 2 - Cross-reference build

Goal: know **where** indexed units (especially framework nodes/subflows) are used, so patterns become visible.

1. For the flows in scope across the apps in scope, record each place an indexed unit is invoked (which flow, which node, which terminal context).
2. Persist this to `analyzing.md` in the customer workspace as you go (durable backup; survives a re-run).
3. Represent the bulk as **structured inventory tables** (unit -> where used -> count). Use **mermaid only for the exemplar** of each canonical pattern (the one representative error-handling subflow, the one logging wrapper), never a diagram per flow.

`analyzing.md` is the working artifact. The profile (Phase 5) is the deliverable.

---

## Phase 3 - Pattern extraction

For each axis below, apply the recipes in `extraction_guide.md`, and for every finding record:
- **support: X of N** (how many flows/apps exhibit it out of those examined)
- **confidence** (high / medium / low) - lower it when support is thin, evidence is indirect, or a recipe was unverified on this estate
- **descriptive vs prescriptive** - is this something to replicate (prescriptive) or just something they happen to do, possibly tech debt (descriptive)?
- **correctness cross-check** - run the finding against the sources listed below. If it is consistent but conflicts with a correctness rule or a known anti-pattern, flag it `CONFLICT - replicate anyway or fix?` rather than silently canonicalising it.

### Axes
1. **Frameworks** - shared nodes/subflows/functions and how they are invoked (call convention, wiring).
2. **Logging** - which nodes, at which locations, what values/payload, naming of log points.
3. **Error handling** - handler subflows, terminal wiring (Catch/Failure/Timeout), error response shape, naming.
4. **Integration patterns** - request-reply / fire-and-forget / retry / async / canonical model.
5. **Naming standards** - projects, BROKER SCHEMA packages, flows, nodes, ESQL variables/procedures.
6. **Configuration / externalization** - UDPs, policies, configurable services, vault usage, `.properties` override conventions.
7. **Project and package structure** - app/lib naming, folder layout, where schemas live.
8. **Message modeling / formats** - DFDL / XMLNSC / JSON / BLOB; schema location conventions.
9. **Security and credentials** - policy projects, security profiles, vault patterns.
10. **Transaction / recovery** - backout queues, retry / circuit-breaker, MQ transactionality.
11. **Monitoring / audit** - monitoring events, activity log, trace conventions.

### Correctness cross-check sources (read, do not duplicate)
- `../../ace-flow-builder/references/validated_rules.md` - correctness rules. Always wins on conflict.
- `../../ace-flow-builder/references/esql_style.md` - naming / readability conventions.
- `../../ace-flow-builder/references/refactoring_patterns.md` - anti-patterns and their fixes.
- `../../ace-review/references/guidelines/esql_guidelines.md`
- `../../ace-review/references/guidelines/flow_guidelines.md`
- `../../ace-review/references/guidelines/error_handling_guidelines.md`
- `../../ace-review/references/guidelines/security_guidelines.md`
- `../../ace-review/references/guidelines/performance_monitoring_guidelines.md`
- `../../ace-review/references/guidelines/ten_ace_message_flow_mistakes.md`

---

## Phase 4 - Review and curate

Present the findings as an **accept / reject / modify** list (mirrors the flagged-violation pattern in `ace-flow-refactor`). For each finding show: the convention statement, support count, confidence, descriptive/prescriptive flag, the exemplar reference, and any correctness conflict.

- The user accepts, rejects, or edits each finding.
- A `CONFLICT`-flagged finding must be resolved explicitly before it can be accepted. The resolution is one of `replicate` (do it the customer's way), `encourage` (recommend but do not mandate), `fix` (deviate from the estate toward the correctness rule), or `dropped`. Record the chosen word on the entry (see `profile_template.md`).
- Only **accepted** findings proceed to the profile. Rejected ones are dropped; modified ones carry the user's wording.

Do not write the profile until the user has been through the list.

---

## Phase 5 - Emit profile

The deliverable is a single file, **`customer_profile.md`**, that the customer installs into their own copy of `ace-flow-builder` at `references/customer_profile.md`. flow-builder is generic; the profile is how a customer plugs their house style in. It is gitignored in the shared repo and lives only on the customer's deployment - never commit it.

1. Write the curated profile as **`customer_profile.md`** using the section schema in `profile_template.md` exactly (the schema is the contract `ace-flow-builder` reads).
2. Fill the header block: customer label, generation date, **source apps/libs (provenance)**, profiler version, and the confidentiality banner. State coverage honestly: library classification is whole-estate (N libraries by reference count), per-axis conventions are from the M sampled apps, and call out any sampling bias (e.g. the sample leaned toward one domain). A partial first pass is expected; the provenance is what lets a later pass extend it.
3. **Install it:** copy `customer_profile.md` into the customer's `ace-flow-builder` skill copy as `references/customer_profile.md` (do this directly if you can resolve that skill path; otherwise write it to the workspace and tell the user exactly where to drop it). Optionally record the install path in a memory entry for convenience.
4. Print the confidentiality warning in chat.
5. Because the header records provenance and a version/timestamp, a later re-run after new apps are added diffs cleanly against the prior profile.

---

## Mode transitions
- **ace-flow-builder** - consumes the emitted profile to build new flows in the customer's house style.
- **ace-review** - for quality findings on specific apps (the profiler describes conventions; it does not grade them).
- **ace-flow-refactor** - to bring an existing flow in line with the agreed conventions.

---

## Output hygiene

- Never use em dashes or en dashes (Unicode U+2014 and U+2013) in any generated output. Use ASCII hyphens, commas, parentheses, or separate sentences instead.
- Never add AI-tool signatures, watermarks, or attribution comments to generated files. No "Made with Bob" footer, no "Generated by Claude", no "Created with X" stamps, no co-authorship lines in the body of any deliverable. The user owns the output; AI tooling stays invisible. Applies to every file produced by this skill: the profile, `analyzing.md`, and any notes.
