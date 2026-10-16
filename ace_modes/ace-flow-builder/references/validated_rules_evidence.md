---
template_version: 0.4.0
last_updated: 2026-09-11
status: stable
---

# ACE Flow-Building Rules - Evidence Layer

One entry per rule in `validated_rules.md`, same number and title: why it is a rule, the
run or expert review it came from, and the stamp. Read by the expert-review loop, the
T6.5 stamp walk and anyone auditing a rule. The generation subagent does not read this
file; the rules layer carries each rule's scope and tags.

**Read the stamp before you rely on a rule.** Every rule ends with a `**Stamp.**`
paragraph. Its leading token is the rule's **scope**; the rest is **evidence**:

- `v13` (or `v12+`) - the rule holds across that major version and its fix packs.
  This is the default: ESQL and tree idioms, node types, command shapes.
- `13.0.N+ (<feature>, mod pack 13.0.N)` - the rule depends on a feature or
  behaviour that arrived in that modification pack, per the manual's "New function
  added in IBM App Connect Enterprise 13.0 modification packs" page. Below that fix
  pack the mechanism does not exist and the rule does not apply as written.
- After the scope: the mechanism that validated the rule (a runtime run, an expert
  ruling, a Toolkit import, a jar or manual inspection) **on the exact install that
  produced the evidence** ("runtime run on 13.0.8.1"). That version is provenance,
  not scope - a rule proved on 13.0.8.1 with scope `v13` is expected to hold on
  13.0.2 too, and the stamp says so.

How to read it against the install in front of you (`workflow.md` B0.5a records
the installed version in the brief):

- Install on a different major version than the scope: the rule is a hypothesis
  there, not a fact. Re-verify the mechanism against the running install first.
- Install below a named mod pack: the mechanism is absent; use the path the older
  version offers and record which one you took.
- A newer version offering a different mechanism is not a contradiction of an
  older rule - it is a path the older rule never covered. Record both, scoped by
  version, instead of overwriting one with the other (rule 12 is the shape).
- When the install rejects a stamped mechanism, that rejection is a finding: write
  it into `flow_state.md` with the version observed and file it as a rule
  amendment. Never work around it silently.
- `unstamped` means no evidence beyond the rule text was found in the trail: treat
  it as a design idiom to follow unless the install disagrees, and as a candidate
  for the next measurement run.

---

## 1. Route/Filter on upstream state - ask first

**Original rule text (moved out of the rules layer 2026-09-11):**


If the routing value is available in more than one place on the message
tree (an `MQRFH2` folder, an HTTP header, `Environment.Variables.*`,
`LocalEnvironment`, etc.), **do not silently pick one**. Ask the user
which source the Route or Filter node should read from.

Both choices can be valid depending on:
- What the compute nodes between the source and the Route do to the
  message tree
- Whether the value must survive a transport hop (HTTP call, MQ put) that
  strips some headers

**Question to surface, in Phase B2 (design) or during refactor analysis:**

> "The routing value is present on `MQRFH2.usr.<X>` from the input
> message. Should the Route node filter directly on
> `$Root/MQRFH2/usr/<X>`, or should a pre-Route compute copy it into
> `Environment.Variables.*` and have the Route filter on
> `$Environment/Variables/<X>`?"

Record the decision in the design summary before generating the flow.

**Stamp.** v13 (scope asserted by the file header, not measured) - unstamped: no evidence located beyond the rule text; hypothesis until re-verified against the running install (B0.5a).

---

## 2. Create MQRFH2 explicitly, in the correct tree position

**Stamp.** v13 - runtime run on v13, patch level not recorded (RetryHTTPDispatcher build session: BuildRetryPayload and HandleException carry this exact idiom and the app was Toolkit-imported and deployed on the box; archived session-issues file, commit 31eadec) (2026-04-29); the rule was captured 2026-04-21 (commit 682eb44) from a session the trail does not identify, and the failure mode it guards against (implicit creation misplacing the parser or leaving MQMD.Format wrong) is not reproduced.

---

## 3. MQRFH2 header fields use the `(MQRFH2.Field)` typed prefix

**Stamp.** v13 - runtime run on v13, patch level not recorded (RetryHTTPDispatcher build session: the typed-prefix writes deployed on the box in BuildRetryPayload and HandleException; commit 31eadec) (2026-04-29); captured 2026-04-21 (commit 682eb44) from an unidentified session, and the wrong-slot effect of the untyped form is not reproduced.

---

## 4. MQ format values use `MQFMT_*` constants, never string literals

**Stamp.** v13 - runtime run on v13, patch level not recorded (RetryHTTPDispatcher build session: MQFMT_RF_HEADER_2 and MQFMT_STRING deployed on the box; commit 31eadec) (2026-04-29); captured 2026-04-21 (commit 682eb44) from an unidentified session; only those two constants were exercised, the other three in the table are not touched by any run in the trail, and no miscounted literal was reproduced.

---

## 5. Review and improve draft ESQL before adopting it

**Original rule text (moved out of the rules layer 2026-09-11):**


Unvalidated ESQL from external sources - spec drafts, AI-generated
snippets, legacy flow ports - routinely contains compile-time bugs:
signature mismatches, undefined references, parser-domain confusion.

Walk the code against a real sample message before declaring done. Fix
bugs in the port - don't ship them. This applies to both Build (when the
user hands you an existing snippet to build around) and Refactor (when
cleaning up legacy ESQL).

Checklist before calling draft ESQL complete:
- [ ] `BROKER SCHEMA` declared
- [ ] All referenced fields exist on the claimed input domain
- [ ] Compute mode propagates what the ESQL writes - `OutputLocalEnvironment` /
      `OutputExceptionList` writes need a matching mode (see rule 16)
- [ ] Correlation names from the closed set in rule 16 - `Environment`, never
      `InputEnvironment` / `OutputEnvironment`
- [ ] Whole-message copy is `SET OutputRoot = InputRoot;` alone (rule 17)
- [ ] No typed-prefix / folder-value confusion on `MQRFH2`
- [ ] No string-literal MQ format values (see rule 4)

**Stamp.** v13 (scope asserted by the file header, not measured) - unstamped: no evidence located beyond the rule text; hypothesis until re-verified against the running install (B0.5a).

---

## 6. Destination-list MQ Output nodes need explicit `DestinationData`

**Stamp.** v13 (scope asserted by the file header, not measured) - unstamped: no evidence located beyond the rule text; hypothesis until re-verified against the running install (B0.5a).

---

## 7. Timeout-pair identifier rule

**Stamp.** v13 - runtime run on v13, patch level not recorded (RetryHTTPDispatcher build session: TimeoutControl and TimeoutNotification paired on uniqueIdentifier A1B2C3D4, Toolkit-imported and deployed on the box; archived session-issues file issue 7, commit 31eadec) + expert ruling (fixed identifier over wildcard, same session) + manual page (IIB v9 timeout node doc for the 1-12 character limit, as cited in the session notes) (2026-04-29); the two failure modes (identifier mismatch, missing AllowOverwrite) are described from the session, not from a captured runtime trace, and the v13 manual does not restate the length limit.

---

## 8. HTTPRequest terminal semantics - `out` vs `error` vs `failure`

**Stamp.** v13 - runtime run on v13, patch level not recorded (RetryHTTPDispatcher build session: the three-terminal wiring Toolkit-imported and deployed on the box; archived session-issues file issue 15, commit 31eadec) + estate flow inspection (RetrieveFXData.msgflow, ForwardHTTPURL.msgflow in the user's repos) (2026-04-29); the terminal table was established from existing flows and the build, no captured runtime trace shows a 4xx leaving the error terminal, the "some database nodes" extension is asserted, and the HTTPRequest node's own Retry properties tab (new in mod pack 13.0.3 per the manual's new-function page) is a built-in alternative to the hand-wired retry this rule assumes and is not covered here.

---

## 9. Unify error/failure classification

**Stamp.** v13 - expert ruling (the pattern was Matthias's suggestion in the RetryHTTPDispatcher build session; archived session-issues file issue 16, commit 31eadec) + runtime run on v13, patch level not recorded (the rebuilt ClassifyResponse deployed on the box, same session) (2026-04-29); the InputExceptionList discriminator follows from rule 8's terminal semantics, no captured error/failure pair shows it.

---

## 10. v13 HTTP input/reply node type is `ComIbmWSInput` / `ComIbmWSReply`

**Stamp.** v13 - runtime run on v13, patch level not recorded (validation session against a Standalone Integration Server with Docker MQ, BIP2241E observed on ComIbmHTTPInput; commit 5b6219b; 13.0.7 inferred from rule 12's run later the same month) (2026-05-03); re-exercised positively by runtime runs on 13.0.8.1 (ComIbmWSInput mock flows end to end, digest 2026-08-17-ace13-oauth2-rest-request-049388f3, session 2026-08-27; pair 2 Level 3 HTTP flows, 2026-08-28), the original run has no digest.

---

## 11. `ComIbmWSInput` exposes the HTTP method and path via headers, not LocalEnvironment

**Stamp.** v13 - runtime run on v13, patch level not recorded (same SIS + Docker MQ validation session as rule 10: LocalEnvironment.HTTP.Input fields empty on ComIbmWSInput, routing fell through to the empty-string branch; commit 5b6219b; 13.0.7 inferred as for rule 10) (2026-05-03); no later run in the trail reads X-Original-HTTP-Command or X-Original-HTTP-URL, so the header shape is unverified on 13.0.8.x.

---

## 12. REST Request node Basic auth - Security identity is pre-emptive, Security Profile is reactive

**Stamp.** v12+ - runtime run on 12.0.12 and 13.0.7 (RestBasicAuthRepro three-case mock harness, raw mock log as evidence; digest 2026-05-28-ace-rest-basic-auth-repro-8e2e4198) (2026-05-28); the 13.0.8.x oauth2-via-policy note is its own runtime run on 13.0.8.1 (OAuthClientApp rig, digest 2026-08-17-ace13-oauth2-rest-request-049388f3, session 2026-08-27) and the mechanism scoping is commit b6fe1bf (2026-09-08); the manual's new-function page does not list the rest-credential oauth2 auth types under any mod pack (nearest items: REST Request policy security schemes in the 13.0.6 Policy Editor, bearer-token rest credentials in 13.0.4) but does list the ibmint vault and credential commands shown here as new in 13.0.1, so the behaviour is v12+ while the command block needs 13.0.1+; the RESTRequest policy path for Basic auth was out of scope, preemptiveAuthType was exercised with the value Basic only, and the 2026-05-28 run used mqsisetdbparms, not the vault.

---

## 13. Build the output tree in the correct header order

**Stamp.** v13 - manual page (offline ACE 13 docs, cited by commit 04c8ae4 for the sibling ace-review header-order checks landed in the same commit; no run or page is named for this rule itself), with the prescribed order exercised by a runtime run on 13.0.8.1 (Level 3 pair-2 classic run: Properties, MQMD, BLOB built in that order, byte-exact put, 2026-08-28) (2026-06-25); the failure mode (body first, or Properties not first) is not reproduced.

---

## 14. Schema-scope `DECLARE ... NAMESPACE` is global - declare it once, or make it local

**Stamp.** v13 - runtime run on v13, patch level not recorded (empirical repro that deployed via ibmint and failed Toolkit import, BIP4128E and the BIP4127E cascade observed at load; commit f0684e8, re-verified against the runtime on 2026-07-16 by commit 28b950c; 13.0.7.0 inferred as the only v13 install on the box before 13.0.8.1 arrived on 2026-08-11) (2026-07-15); no session digest exists for the repro, so the flow is not locatable, and no Level-3 run since has declared a schema-scope namespace.

---

## 15. MQ-input flows must preserve the payload on the error path

**Why this is a rule and not a suggestion.** Independent `ace-review-quick` scans of two
separately generated builds found these same two defects as the top findings in *both* -
inherited from the shared `IBMMQtoDatabase` pattern template, which does neither. A
template's blind spot propagates into every flow generated from it, so the validated
rules have to mandate what the templates omit, not merely describe what they contain.
When using any MQ pattern template, check these two points explicitly rather than
trusting the template.

**Stamp.** v13 - review probe (ace-review-quick on both pair-1 outputs, PROTOCOL.md "Quality probe", 2026-08-25) + expert ruling (pair 1 review M3, 2026-08-25) with the facts from runtime runs on 13.0.8.1 (Level 3 pair 1 outputs; Level 3 pair 2, both runs: catch AND failure wired to HandleException, regression check, 2026-08-28) (2026-08-25); the payload loss was found by review, not reproduced with a poisoned message on an MQ input, and the reach table (2026-08-30, T0 session) is a design decision with the File-input row still pending.

---

## 16. `Environment` has no Input/Output variants - and `computeMode` gates propagation, it copies nothing

**Stamp.** v13 - manual page ("Compute node", IBM ACE v13 manual via doc-kb) + Toolkit flow inspection (TestApp/TestFlow.msgflow, RetryHTTPDispatcher) + runtime run on 13.0.8.1 (OAuth2 rig: an OutputLocalEnvironment write was discarded until the mode included destination, digest 2026-08-17-ace13-oauth2-rest-request-049388f3, session 2026-08-27) (2026-08-27; digest 2026-08-27-bob-modes, commit 60316b0); the literal set is doc-verified, the InputEnvironment/OutputEnvironment nonexistence rests on the manual plus Matthias's report of Bob-generated ESQL failing (no compile error captured), and WebScrapeProxy.msgflow carries computeMode="localEnvironmentAndMessage" deploy-untested - do not widen the literal list without a test.

---

## 17. Whole-message copy is `SET OutputRoot = InputRoot;` - nothing else

Measured on 2026-08-28 (comparison pair 2): an HTTP-to-MQ flow generated with the
plain copy put the HTTP request line and headers into the queue message; the Level 3
byte-compare caught it. The B3.7 checklist verifies the drop on every cross-transport
flow.

Expert review pair 2 (2026-09-11, M5): the single assignment is also the more
performant path - one tree copy instead of the field-by-field rebuild (Properties, five
MQMD fields, BLOB) the classic run produced. The copy-then-drop idiom above is the
shape; the piecewise rebuild is not an alternative.

**Stamp.** v13 - runtime run on 13.0.8.1 (Level 3 pair 2 Run C: the plain copy leaked the HTTP request line into the queue payload, caught by the byte-compare and fixed with the drop, 2026-08-28; RCD harness: the whole-tree copy is satisfied from the bit stream and the response came back byte-identical, 2026-08-21) + expert ruling (pair 2 review M5, 2026-09-11) (2026-08-28); the wrong-idiom claim (CopyMessageHeaders plus wildcard SET is a partial copy) comes from Matthias's report of Bob-generated ESQL (digest 2026-08-27-bob-modes), not from a measured partial copy, and the M5 performance rationale is a statement, not a measurement.

---

## 18. Validation placement: Validate node vs ResetContentDescriptor

**Stamp.** v13 - runtime run on 13.0.8.1 (RCDInvalidCharRepro standalone-server harness, 20 requests over four revisions; digest 2026-08-21-bob-modes, QA note 2026-08-19-rcd-validation-vs-invalid-xml-characters) (2026-08-21; rule committed 4fa9a46, 2026-08-27); lazy On Demand validation was proven via ESQL field reads only - a Mapping node or Validate=inherit serializer consuming the unparsed remainder was not measured.

---

## 19. `node.conf.yaml` and `server.conf.yaml` are never edited - every change goes in `overrides/*.yaml`

**Why this is a rule.** A validation run replaced a generated 997-line
`server.conf.yaml` with a 5-line file holding only `remoteDefaultQueueManager`,
because the runbook told it to "generate this file in work_dir/server.conf.yaml". It
ran - ACE layers the file over built-in defaults - which is exactly why nobody noticed
until the expert review. Checkable: after any deploy step the base file must be
byte-identical to the freshly generated one; a modified base `*.conf.yaml` is a Phase
B5 failure and an `ace-review-config` finding.

**Stamp.** v13 - expert ruling (pair 1 review M6: the classic run had replaced the 997-line base server.conf.yaml with a 5-line file, 2026-08-25) with the facts from runtime runs on 13.0.8.1 (pair 1 classic run wrote the base file; Level 3 pair 2, both runs: overrides/server.conf.yaml carried the keys and the base file stayed at 997 lines untouched, 2026-08-28) (2026-08-25); the node-managed locations (<node>/servers/<server>/overrides, <node>/overrides/node.conf.yaml) are from the manual, only the standalone work-dir layout was exercised, and the manual's own new-function page still uses the plain "set the property in server.conf.yaml or node.conf.yaml" wording (13.0.1 sslMode item) that this house rule redirects to overrides.

---

## 20. Database access in ESQL: handle the error where it happens and capture the diagnostics

**Why this is a rule.** Two independently generated MQ-to-database flows both let
INSERT failures escape to the MQInput catch terminal, where the payload was consumed
and lost; the better of the two captured SQLCODE/SQLSTATE/row count into variables and
traced them (Matthias, expert review 2026-08-25, findings M1/M2). Rule 15 keeps the
message; this rule keeps the diagnosis.

**Stamp.** v13 - expert ruling (pair 1 review M1/M2, 2026-08-25) with the diagnostics capture from a runtime run on 13.0.8.1 (Level 3 pair 1 kb run: SQLCODE/SQLSTATE captured into variables and traced through the S3 table-break fault injection, 2026-08-25) + manual page ("DECLARE HANDLER statement", "SQLSTATE function") + Toolkit template inspection (the DatabaseInput templates use the same 'D%' class) (2026-08-25); the DECLARE CONTINUE HANDLER block as written has not been deployed by any Level-3 run - both pair-1 flows lacked it (M2) and pairs 2 and 3 touch no database.

---

## 21. Trace nodes: no hardcoded paths, no payloads in the system log

**Why this is a rule.** The pattern templates modelled `filePath="C:\temp\..."` as the
norm and both generated flows inherited it (one as the ONLY error sink); the other
flow's success path traced `${Root}` to `localError` (expert review 2026-08-25).

**Stamp.** v13 - review probe (ace-review-quick on both pair-1 outputs: hardcoded C:\temp trace as the sole error sink, success-path ${Root} to localError, 2026-08-25) + expert review (2026-08-25, per the rule text; not an M-item in PROTOCOL.md, the findings sit in the quality-probe block) with the facts from runtime runs on 13.0.8.1 (Level 3 pair 1 outputs; Level 3 pair 2, both runs: no file trace, regression check, 2026-08-28) (2026-08-25); a hygiene rule - the harm (PII in the system log, path breaking off Windows) is asserted, not measured, and the C:\temp trace did work on the Windows box in the 2026-08-24 classic run.

---

## 22. MQ client connections: the shape is a house convention, the facts are not

**Why this is a rule.** Originally Matthias's stated preference (2026-08-25, comparison
expert review M4-M6): the policy approach over node-level configuration - applied
through `overrides/server.conf.yaml`, after a run had written it into the base file.
Moved to `customer_profile.md` as a convention (2026-09-01). Expert review pair 2
(2026-09-11, M2): the policy shape is a build preference and belongs to the customer
rules only - the skill's policy-first generic default was removed; the product facts
stay, and a profile still cannot override them.

**Stamp.** v13 - runtime run on 13.0.8.1 (Level 3 pair 1: the destinationQueueManagerName crash and the vault-backed securityIdentity, 2026-08-24/25, digest 2026-08-24-classic; pair 2 Run D: policy staged under run/ and applied via overrides, 2026-08-28) + runtime run on v13, patch level not recorded (BIP1388E policy-in-BAR, 2026-05-03 SIS validation session, commit 5b6219b) + Toolkit import (pair 1 review M4: the Toolkit silently migrated the stale policyxml shape, 2026-08-25) + expert ruling (pair 1 M5/M6, 2026-08-25; pair 2 M2, 2026-09-11) (2026-08-25, amended 2026-09-01 and 2026-09-11); the convention half is a ruling, not a measurement, the brief-decides default without a profile has not been run through a pair, and the destinationQueueManagerName requirement is quoted for 13.0.8.1 only because that is the one install it was measured on (the manual's new-function page does not list it under any mod pack).

---

## 23. MQ output nodes: `messageContext="default"` unless the identity has the authority

**Why this is a rule.** Comparison pair 2 (2026-08-28): the generated HTTP-to-MQ flow
kept the default and lost several debugging turns to 2035 before the run found and fixed
it in the flow. Checkable in B3.7 (every MQOutput/MQReply carries an explicit
`messageContext`), and the 2035 signature is documented in `msgflow_format.md` for the
validation subagent.

**Stamp.** v13 - runtime run on 13.0.8.1 (Level 3 pair 2 Run C: MQOPEN failed with MQRC 2035 / BIP2666 / AMQ8077W "unauthorized: passall" under the default passAll for user app, fixed to messageContext="default" and re-run live, digest 2026-08-28-kb; Run D carried messageContext="default" and passed) (2026-08-28; rule committed 33283fd, 2026-08-30); measured for passAll against the MQ dev image's least-privilege app user only - setAll, passIdentity and setIdentity needing the same authority is from the manual, and the 16 template nodes were changed by a re-scan, not run.

---

## 24. The tracking id is minted by the first flow, never read from the payload

**Why this is a rule.** Comparison pair 3 (2026-08-30): the brief said "reply 202 with
the event id from the payload". Two arms rejected any request without a payload `id`
(routed to the Compute `failure` terminal), the third published and returned a null id.
Expert review 2026-09-11 (M1): the event id is internal, the first flow generates it -
none of the three readings was right, and the brief wording that produced them is retired.
Checkable in B3.7: an id the flow returns or logs is assigned from `UUIDASCHAR` in the
first Compute and appears in the error path and the reply.

**Stamp.** v13 - expert ruling (pair 3 review M1, PROTOCOL.md) on the pair-3 outputs, which were built against the 13.0.8.1 Toolkit workspace and never deployed (the pair-3 arms were build-only) (2026-09-11); no runtime run yet - UUIDASCHAR and the Environment carry are not listed under any mod pack on the manual's new-function page, and the next Level-3 run that returns or logs an id re-verifies this rule.

---

## 25. Kafka nodes: the connector-family types are the default

**Why this is a rule.** Comparison pair 3 (2026-08-30): the local arm generated
`ComIbmKafkaMsgProducer` because this skill's own `msgflow_format.md` node table listed
it; the other two arms followed the IBM templates. Expert review 2026-09-11 (M2):
connector type. Evidence: all 8 `*toKafka` and all 8 `Kafkato*` IBM pattern templates in
`references/examples/` use the connector-family types; in the 13.0.8.1 Toolkit both
definitions ship in `com.ibm.etools.mft.ibmnodes.definitions_13.0.8.1.jar`, but the
palette and validator registrations in `com.ibm.etools.mft.ibmnodes_13.0.8.1.jar`
name only the connector-family types. Checkable in B3.7.

**Stamp.** v13 for the connector-family default; the transactional exception is 13.0.5+ (Transactional messaging with Kafka, mod pack 13.0.5 per the manual's new-function page) - Toolkit jar inspection on 13.0.8.1 (com.ibm.etools.mft.ibmnodes.definitions_13.0.8.1.jar holds both definitions, com.ibm.etools.mft.ibmnodes_13.0.8.1.jar registers only the connector family) plus the shipped templates (16 of 16 IBM Kafka templates) + expert ruling (pair 3 review M2) (2026-09-11); no runtime run; the property diff is verified for the producer pair only, the consumer pair is taken from the templates and the manual's transactional-consumer description, and the new-function page names every Kafka mod-pack enhancement (SASL/OAUTHBEARER 13.0.7, transactional 13.0.5, Avro 13.0.2) by the classic node names KafkaProducer/KafkaConsumer/KafkaRead without ever mentioning the connector family, so which node type carries each enhancement is unverified.

---

## 26. `OutputRoot.MQMD` is not hand-built - the MQOutput node creates it

**Why this is a rule.** Comparison pair 2 (2026-08-28): the classic run's `PrepareOrder`
set five MQMD fields for a plain fire-and-forget put. Expert review 2026-09-11 (M4): not
necessary unless the flow does something special such as adding an MQRFH2 header. The
kb run of the same pair put the same bytes on the queue with no MQMD code at all (rule
17's copy-then-drop). Checkable in B3.7.

**Stamp.** v13 - expert ruling (pair 2 review M4) on the pair-2 outputs plus the manual's MQOutput page (13.0.x export: the node creates the default MQMD, Persistence mode row), with the "node creates the default MQMD" behaviour exercised by a runtime run on 13.0.8.1 (pair-2 kb run at Level 3, byte-exact put with no MQMD code, 2026-08-28) (2026-09-11); the classic run's five-field MQMD block was judged unnecessary, not measured as harmful, and MQOutput MQMD handling is not listed under any mod pack on the manual's new-function page.

---
