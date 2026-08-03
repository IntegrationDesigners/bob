---
name: ace-flow-harness
description: "Use this skill when the user wants to actually STAND UP an IBM ACE test environment and RUN an end-to-end deploy-and-test cycle - not just design test cases. It installs dependency JARs (SupportPac / 3rd-party libraries), provisions the test environment, deploys policy projects and applications in order with ibmint, starts an integration server (waits for BIP1991I), drives the flow over HTTP/file/MQ, and verifies results. Triggers on 'set up a test harness for my flow/SupportPac', 'automate deploy and test', 'install dependencies and run the flow', 'create a deploy_and_test script', 'stand up an integration server and test it', 'add shared-classes and deploy the policy + app'. Produces executable scripts (.bat/.sh) plus a harness README following a canonical template. Use ace-flow-test FIRST to design the test cases (plan only, no execution); use this skill to provision and execute. Use ace-flow-builder to build the flow itself."
metadata:
  variant_version: 1.0.1
  parent_mode: ace-flow-builder
  sibling_modes: [ace-flow-test, ace-flow-builder]
  last_updated: 2026-07-02
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

0. **Source the ACE environment** - `ibmint`/`IntegrationServer`/`mqsi*` are not on
   PATH until you source the ACE profile (`mqsiprofile.cmd` on Windows,
   `mqsiprofile` on Linux). The standalone pattern is a wrapper script
   (`run-test-with-ace-env.bat`) that sources the profile, then calls the harness.
   An agent running the harness from a non-ACE shell must source it first too.
1. **Install dependencies** - impl jar → `server/jplugin`, tool jar → `tools/plugins`,
   3rd-party libs → shared-classes (location per topology).
2. **Provision test env** - create work dir + `{keys,input,output}` (or equivalent),
   copy test data / keys, set config (`server.conf.yaml`, overrides).
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
   inspection or stop it (`taskkill /F /FI "WINDOWTITLE eq <server>*"` / `docker stop`).

## Load-Bearing Gotchas (always check / explain)

These are baked into the template because each one has bitten a real run:

- **Source the ACE env first.** `ibmint`/`IntegrationServer`/`mqsi*` aren't on PATH
  until `mqsiprofile` is sourced. Skipping it gives `'ibmint' is not recognized` -
  the #1 "it doesn't work on a clean machine / in CI" cause. Use the wrapper-script
  pattern (`run-test-with-ace-env.bat` → `deploy_and_test.bat`).
- **Deploy before start.** Work-dir deploys (`ibmint deploy --output-work-directory`)
  must complete before `IntegrationServer` starts, or the app/policies aren't picked up.
- **Policies before app.** The app's policy references resolve only if the policy
  project is already deployed.
- **shared-classes location is topology-specific** (see table above).
- **Ship the *whole* dependency set.** E.g. BouncyCastle needs `bcprov` + `bcpg`
  **and** `bcutil` (bcutil provides relocated/back-compat classes); missing one
  fails at runtime, not deploy.
- **Wait on `BIP1991I`, not on a timer.** Poll the events log; a fixed sleep is flaky.
- **Clean stale `config/.lock`** from a previous crashed run before restart.
- **Binary compare for round-trips.** Use `fc /B` (Windows) - a text compare can
  mask trailing-newline / encoding differences.
- **Passphrase / secret handling** for crypto flows - keep out of committed scripts;
  inject via policy/override or env.

## Parameters (the "harness manifest")

If the repo already has a `testing/` tree, **its own docs are the source of truth** -
read `testing/README.md` (and topology READMEs), the wrapper + harness scripts, the
`install-<pac>` script, and `Deploymentdescriptors/*.properties` first, and reuse
those values verbatim. The template fills gaps and explains *why*; it does not
override a working documented setup.

Gather these before generating; ask only for what you cannot infer from the repo:

| Parameter | Example | Notes |
|-----------|---------|-------|
| `ACE_VERSION` / `ACE_HOME` | `13.0.7.0` / `C:\Program Files\IBM\ACE\13.0.7.0` | autodetect newest if unset |
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

Companion (different responsibility):
- `ace-flow-test/references/examples/http_pgp_flow_test_example.md` - the *test
  plan* counterpart for the same PGP flow (scenarios/checklists, no execution).

## Version History

- **1.0.0** (2026-06-15) - Initial release. Template + lifecycle distilled from the
  PGP SupportPac standalone/Docker/node-managed harnesses.

## Output Hygiene

- **Never use em dashes or en dashes** (Unicode U+2014 and U+2013) in any generated output. Use ASCII hyphens (`-`), commas, parentheses, or separate sentences instead.
- **Never add AI-tool signatures, watermarks, or attribution comments to generated
  files.** No `<!-- Made with Bob -->`, no `<!-- Generated by Claude -->`, no
  `# AI-assisted` footers, no co-authorship lines inside the body of any deliverable.
  Applies to every file this skill produces - `.bat`, `.sh`, `.yml`, `.properties`,
  README, everything. The user owns the output; AI tooling stays invisible.
