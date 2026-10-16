---
name: ace-flow-harness
description: "Use this skill when the user wants to actually STAND UP an IBM ACE test environment and RUN an end-to-end deploy-and-test cycle - not just design test cases. It installs dependency JARs (SupportPac / 3rd-party libraries), provisions the test environment, deploys policy projects and applications in order with ibmint, starts an integration server (waits for BIP1991I), drives the flow over HTTP/file/MQ, and verifies results. Triggers on 'set up a test harness for my flow/SupportPac', 'automate deploy and test', 'install dependencies and run the flow', 'create a deploy_and_test script', 'stand up an integration server and test it', 'add shared-classes and deploy the policy + app'. Produces executable scripts (.bat/.sh) plus a harness README following a canonical template. Use ace-flow-test FIRST to design the test cases (plan only, no execution); use this skill to provision and execute. Use ace-flow-builder to build the flow itself."
metadata:
  variant_version: 1.1.1
  parent_mode: ace-flow-builder
  sibling_modes: [ace-flow-test, ace-flow-builder]
  last_updated: 2026-08-28
  status: stable
---

# ACE Flow Harness Mode

**Slug:** `ace-flow-harness`
**Name:** 🏗️🔧🧪 ACE Flow Harness
**Parent Mode:** ace-flow-builder
**Type:** Specialized Variant (Test Execution & Provisioning)

## Purpose

Generate and explain an **executable** end-to-end test harness for an IBM ACE
artifact (an application, a SupportPac, a policy-backed flow). Where `ace-flow-test`
*designs* the test cases and writes a plan document, this skill *provisions the
environment and runs the cycle*: install dependencies → set up test env →
place shared-classes → deploy policy projects + applications → start integration
server → verify HTTP listener → drive the flow → verify results.

It works from a **canonical template that it enforces and explains** - a fixed
directory layout and an ordered lifecycle - and parameterizes the project-specific
bits (artifact names, ports, endpoints, dependencies, test data) so the same
harness pattern applies to any ACE app/SupportPac, not just one.

**Execution + provisioning** - this skill produces and (when asked) runs real
scripts. It is NOT a document-only generator.

## When to Use

- ✅ Stand up a repeatable deploy-and-test environment for a flow/app/SupportPac
- ✅ Install dependency JARs (SupportPac impl/tool jars, 3rd-party libs) correctly
- ✅ Get shared-classes placement right per topology
- ✅ Deploy policy projects + applications in the correct order with `ibmint`
- ✅ Automate server start, listener verification, and result checking
- ✅ Author `deploy_and_test.bat` / `run-tests.sh` style scripts
- ✅ Reproduce a CI-friendly test cycle (Docker / standalone / node-managed)

## When NOT to Use

- ❌ Designing test scenarios / curl catalogs / validation checklists → use **ace-flow-test**
- ❌ Building or modifying the flow / ESQL itself → use **ace-flow-builder**
- ❌ ESQL or Java unit tests → out of scope for the whole family
- ❌ Reviewing flow quality → use **ace-review** / **ace-review-flow**

## The Enforced Template

This skill expects (and will create) a canonical layout. It will flag deviations
and explain why each part exists. Full detail in
`references/harness_template.md`.

```
testing/
├── test-resources/                 # SHARED across every topology
│   └── Sources/
│       ├── <PolicyProject>/        # policy project(s) - deployed FIRST
│       ├── <Application>/          # application project(s)
│       ├── Deploymentdescriptors/  # *.properties overrides (containerOverrides)
│       └── <test-data>/            # keys, sample inputs, fixtures
├── <topology>/                     # standalone-server | docker | node-managed
│   ├── <deploy_and_test script>    # the executable harness
│   └── README.md
└── README.md
```

Dependency JAR placement (the part people get wrong):

| Artifact | Goes to | Scope |
|----------|---------|-------|
| `*Impl.jar` (runtime plugin) | `<ACE_HOME>/server/jplugin/` | install-wide |
| `*.jar` (toolkit plugin) | `<ACE_HOME>/tools/plugins/` | install-wide |
| 3rd-party libs (e.g. BouncyCastle trio) | **per topology** - see below | varies |

Shared-classes location **differs by topology** - a top source of "works on my
box" failures:
- **Standalone / Docker:** `<SERVER_WORK_DIR>/shared-classes/`
- **Node-managed / install-wide:** `%MQSI_REGISTRY%\shared-classes\`

## The Enforced Lifecycle (ordered)

The skill runs these in order and refuses to reorder the load-bearing steps.
Each step is explained in `references/harness_template.md`.

0a. **Read the repo's own harness docs - ALL of them - before running anything.**
   If a `testing/` tree exists, enumerate and read `testing/README.md` **and every
   per-topology README** (`standalone-server/`, `docker/`, `node-managed/`), not just
   the index plus the first topology you happen to run. Each topology README carries
   constraints the index and the scripts do not encode - which shared-classes level
   the jars go to, the port map, the documented cleanup verbs, the known issues.
   Reading one topology's doc does not transfer to the others. This is a gate, not
   a suggestion: skipping it is the most common way this skill gets it wrong.
0b. **Source the ACE environment** - `ibmint`/`IntegrationServer`/`mqsi*` are not on
   PATH until you source the ACE profile (`mqsiprofile.cmd` on Windows,
   `mqsiprofile` on Linux). The standalone pattern is a wrapper script
   (`run-test-with-ace-env.bat`) that sources the profile, then calls the harness.
   An agent running the harness from a non-ACE shell must source it first too.
1. **Install dependencies** - impl jar → `server/jplugin`, tool jar → `tools/plugins`,
   3rd-party libs → shared-classes (location per topology).
2. **Provision test env** - create work dir + `{keys,input,output}` (or equivalent),
   copy test data / keys, set config in `<work_dir>/overrides/server.conf.yaml` only
   (Overrides-only rule - never write the base `server.conf.yaml`; ACE layers it over
   built-in defaults, so a rewritten base file starts fine and silently drops every
   generated setting).
3. **Place shared-classes** - copy the full dependency set (e.g. `bcprov` + `bcpg`
   + `bcutil`) into the topology-correct shared-classes dir.
4. **Deploy - policy project(s) FIRST, then application(s)** - `ibmint deploy
   --input-path <Sources> --output-work-directory <work_dir> --project <name>`,
   applying the overrides file to the app. **Must happen BEFORE server start** for
   work-dir-based deploys.
5. **Start integration server** - `IntegrationServer --work-dir <work_dir>
   --name <server>`; **wait for `BIP1991I`** in the events log (do not use a fixed
   sleep). Clean stale `config/.lock` first.
6. **Verify listener** - confirm the HTTP port is `LISTENING` before driving traffic.
7. **Drive the flow** - HTTP (`curl -X POST .../endpoint`), file drop, or MQ put,
   capturing output and HTTP status.
8. **Verify results** - assert status `200` + non-empty output; for round-trip flows
   compare original vs result (`fc /B` on Windows, byte compare on *nix); scan logs
   for `BIP*E:` errors.
9. **Report + teardown** - summarize, point at logs, leave the server running for
   inspection or stop it by matching its `--work-dir` in the process command line
   (never by window title or process name: other servers on the box are not yours) /
   `docker stop`.

## Load-Bearing Gotchas (always check / explain)

Each one has bitten a real run. The full checklist, with the why behind every item, is
section 6 of `references/harness_template.md`, and section 6a holds the traps that only
bite under CI or an agent. **Before hand-over, walk 6 and 6a item by item and say which
hold** - this file keeps only the ones that cost the most when missed:

- **Source the ACE env first** (`mqsiprofile` via the wrapper pattern) - `'ibmint' is
  not recognized` is the #1 "fails on a clean machine / in CI" cause.
- **Deploy before start, policies before the app** - work-dir deploys are not hot-loaded.
- **Wait on `BIP1991I`**, never a fixed timer - and never `timeout /t` in a `.bat`
  (a no-op once output is redirected; use `ping 127.0.0.1 -n <secs+1> >nul`).
- **`call` every `mqsi*.cmd` tool** - without it control never returns and the run
  reads as a passing step that stopped early.
- **The harness runs, it is not handed over unrun.** This skill executes: write the
  script, then run it and report each scenario's result. A harness handed back as "run
  this yourself" is an unfinished step. Before the first run, parse-check the script in
  its own shell (PowerShell: `[System.Management.Automation.Language.Parser]::ParseFile`;
  bash: `bash -n`). Shell syntax does not travel: bash here-strings (`<<<`, `<<EOF`) do
  not exist in PowerShell - pipe MQSC in instead (`$mqsc | docker exec -i QM1 runmqsc QM1`).
  A generated PowerShell harness with `<<<` did not even parse (2026-10-13).
- **Queue checks measure each scenario's own effect.** Assert the change in depth around
  a scenario, or drain the queue right before it, never an absolute depth: a poison
  message from an earlier run reaches the error queue only after its redeliveries, so it
  can land after the next run's "clear queues" and fail an unrelated scenario (three
  reruns failed T1 on a leftover T5 message, 2026-10-13).
- **Drive a worker flow through its real producer.** A message hand-put on the queue
  (`amqsput`, no MQRFH2) arrives in a different shape than one the intake flow wrote, and
  a hand probe passed while every real job failed (2026-10-12). Normal scenarios go in at
  the front door; direct puts only for poison and malformed-shape cases.
- **External directory vault: `--ext-vault-key`, not `--vault-key`.** When the server's
  overrides name `Credentials: ExternalDirectoryVault`, start it with
  `IntegrationServer --work-dir <wd> --ext-vault-key <key>`; `--vault-key` is the work
  directory's own vault and fails with BIP9964E even with the right key (2026-10-13).
- **A blocker read from configuration is a hypothesis.** Before stopping as blocked
  (a missing credential, channel authentication, a queue that "must" exist), make the
  cheapest real attempt - deploy and start with what exists, or blank the setting that
  cannot resolve - and stop only on the BIP or MQRC that attempt produced, quoted.
  Concretely: BIP2688E on an MQ `securityIdentity` is answered by blanking the identity and
  redeploying, not by asking for a password - a local developer queue manager usually
  takes the connection without one, and a channel's CHCKCLNT read from MQSC predicts
  nothing until a connection is tried (a chain stalled on this twice, 2026-10-12).
- **A container dying between `BIP1990I` and `BIP1991I`** is usually a version-gated
  startup block (ACE 13.0.8 call-home), not a harness bug - read the BIP id first.

## Parameters (the "harness manifest")

The repo's own docs are the source of truth - see lifecycle step **0a**, which is a
hard gate. Reuse the values in those docs verbatim, along with the wrapper + harness
scripts, the `install-<pac>` script, and `Deploymentdescriptors/*.properties`. The
template fills gaps and explains *why*; it never overrides a working documented setup.

Gather these before generating; ask only for what you cannot infer from the repo:

| Parameter | Example | Notes |
|-----------|---------|-------|
| `ACE_VERSION` / `ACE_HOME` | `13.0.8.1` / `C:\Program Files\IBM\ACE\13.0.8.1` | make it overridable (`if not defined ACE_VERSION set ...`), do not hardcode |
| `TOPOLOGY` | `standalone` \| `docker` \| `node-managed` | drives shared-classes location |
| `SERVER_NAME` / `SERVER_WORK_DIR` | `TEST_SERVER_PGP` / `C:\temp\pgp\TEST_SERVER_PGP` | |
| `HTTP_PORT` / `ADMIN_PORT` | `7800` / `7600` | verify listener on HTTP_PORT |
| `DEPENDENCIES` | impl/tool jars + 3rd-party libs (+ targets) | full set, not partial |
| `POLICY_PROJECTS` (ordered) | `PGP_Policies` | deployed first |
| `APPLICATIONS` (ordered) | `TestPGP_App` | with overrides file |
| `OVERRIDES_FILE` | `Deploymentdescriptors/containerOverrides.properties` | |
| `TEST_DATA` | keys → `keys/`, sample → `input/plain.txt` | |
| `DRIVER` | `POST /pgp/encrypt`, `POST /pgp/decrypt` | interface to exercise |
| `VERIFY` | round-trip `fc /B`, status 200, log scan | success criteria |

## Output

- Executable harness script(s): `deploy_and_test.bat` (Windows standalone),
  `run-tests.sh` (Docker/Linux), or node-managed setup script - matching the topology.
- A topology `README.md` documenting prerequisites, the lifecycle, config table,
  and troubleshooting.
- Optional: `docker-compose.yml` / overrides for the Docker topology.

Scripts must fail fast with clear `[STEP]` / `[OK]` / `[ERROR]` logging and a
non-zero exit on failure, so they drop into CI unchanged.

## File Restrictions

- **Read:** All files
- **Edit/Create:** scripts (`.bat`, `.sh`, `.cmd`, `.ps1`), `.yml`/`.yaml`,
  `.properties`, `.md`, `.txt`
- **Command:** Allowed (this skill executes - install, deploy, start, curl, verify)

## Mode Transitions

- **ace-flow-test** - design the test scenarios / plan first (it does not execute);
  feed its scenarios into this harness's `DRIVER` / `VERIFY`.
- **ace-flow-builder** - build or fix the flow/ESQL when a test reveals a defect.
- **ace-review-config** - review the generated server/policy config.
- **code** - ad-hoc edits to test data or one-off command execution.

## Example Usage

```
User: "Install the deps, deploy the policy project and app, start a server and
       run the encrypt/decrypt round-trip."
Skill: Confirms the harness manifest (ports, work dir, deps), generates/uses a
       deploy_and_test script following the enforced lifecycle, runs it, and
       reports the round-trip result + any BIP errors.
```

## Reference Files

- `references/harness_template.md` - the enforced template, full lifecycle with
  rationale, topology matrix, and the complete gotcha list.
- `references/examples/pgp_supportpac_harness_example.md` - worked reference
  implementation (PGP SupportPac: BouncyCastle deps, PGP policies, encrypt/decrypt
  round-trip) across standalone + Docker topologies.
- `references/language_semantics_probe.md` - when the question is how the parsers treat a
  syntax construct (one app per variant, per-parser verdicts from BIP logs, must-fail canary).

Companion (different responsibility):
- the **ace-flow-test** skill - its worked HTTP/PGP example is the *test plan*
  counterpart for the same flow (scenarios/checklists, no execution).

## Output Hygiene

- **Never use em dashes or en dashes** (Unicode U+2014 and U+2013) in any generated output. Use ASCII hyphens (`-`), commas, parentheses, or separate sentences instead.
- **Never add AI-tool signatures, watermarks, or attribution comments to generated
  files.** No `<!-- Made with Bob -->`, no `<!-- Generated by Claude -->`, no
  `# AI-assisted` footers, no co-authorship lines inside the body of any deliverable.
  Applies to every file this skill produces - `.bat`, `.sh`, `.yml`, `.properties`,
  README, everything. The user owns the output; AI tooling stays invisible.
