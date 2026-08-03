# flow_designer - ideas / scratchpad

Scratchpad for the ace-flow-designer skill. Never deleted.

## Origin

The missing upstream step: ace-flow-builder assumes a precise, node-level spec already exists
(its `example/input.md` is empty; real runs were fed a hand-written `analysis_<Name>.md` titled
"<Name> - flow-builder start prompt"). flow_designer is the interactive skill that *produces* that
start prompt - aimed at a junior developer who knows the goal but not how to spec it.

Pipeline: requirement → **flow_designer (interview)** → start prompt → flow_builder → files.

## Design decisions (v0.1.0)

- Sibling of flow_builder under `ace/`, not a variant - it has its own distinct workflow.
- Reuses `../flow_builder/references/ace_patterns_catalog.md` at D1 (no-duplication rule).
- Output = `<FlowName>_start_prompt.md`; H1 mirrors the worked exemplar.
- State file `<FlowName>.design_state.md` mirrors flow_builder's `flow_state.md` so interviews resume.
- Interview phases D0-D8; topics from the user's list (goal, use case, pattern, scope, error
  handling, logging) plus interfaces, processing, non-functionals.
- The output explicitly pre-answers flow_builder's Phase B1 so the build starts without re-asking.

## Design decisions (v0.2.0 - flow-builder contract alignment)

Cross-referenced flow_designer's output against flow-builder's full input contract (extracted via
agents from flow_builder's workflow.md / restapi_build.md / validated_rules.md) and the gold-standard
`analysis_MQEventReader.md`. Closed the gaps flow-builder *blocks* on. Scope chosen with the user:
**Lean + REST branch**, **capture data shapes (not code)**, **ask if Java is needed**.

- **REST API branch (Phase DR)** - replaces D3+D4 when the pattern is REST API; mirrors flow-builder's
  two-question gate (existing-vs-scratch spec, handler error pattern) + operations table. New worked
  example `example/example_rest_start_prompt.md`.
- **Output contract / target shape** added to D3 (data shape / sample payload - still no code).
- **ESQL-vs-Java** question added to D4 (default ESQL; capture class + contract if Java confirmed).
- **HTTP error-vs-failure retry classification** added to D5 (conditional on outbound HTTP).
- **Timer / delayed-retry params** in D5 (conditional); **integration server name** elevated to D7.
- **Subflow terminal wiring** captured in D2 when a subflow is chosen (flow-builder blocker).
- **Routing-source** marked a must-answer blocker, never defaulted.
- Junior-friendliness pass: conditional questions ("ask only if…"), friendlier phrasing for the HTTP
  and Java questions, D7 split into always-ask vs ask-if-relevant.

## TODO / future

- [x] ~~Add a second worked example (REST API)~~ - `example/example_rest_start_prompt.md` added.
- [ ] Dry-run the interview live with a real junior; tune question batching (D0 feel natural?).
- [ ] Consider an "express" single-batch mode for users who say "just write the spec".
- [ ] Decide whether flow_builder's `example/input.md` should point at this skill's output format.
- [ ] Possible v0.3: subflow per-path node sequence + multi-flow directory layout (deferred - full
      topology parity was out of scope for the Lean+REST pass).
