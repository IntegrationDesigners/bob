# ACE Flow Harness - The Enforced Template

This is the canonical template the `ace-flow-harness` skill enforces and explains.
It is distilled from working harnesses (the PGP SupportPac standalone / Docker /
node-managed setups). The point of a *template* is that the load-bearing parts are
fixed and explained, while the project-specific parts are parameters.

---

## 1. Directory Layout (the shared contract)

```
testing/
├── README.md                        # index: which topology, what gets tested
│
├── test-resources/                  # SHARED across every topology - single source of truth
│   └── Sources/
│       ├── <PolicyProject>/         # policy project(s) - DEPLOYED FIRST
│       │   ├── policy.descriptor
│       │   └── *.policyxml
│       ├── <Application>/           # application project(s)
│       │   ├── application.descriptor
│       │   └── <flow files: .msgflow / .esql / .subflow>
│       ├── Deploymentdescriptors/
│       │   └── containerOverrides.properties   # promoted-property overrides
│       └── <test-data>/             # keys, sample inputs, fixtures
│
├── <topology>/                      # one of: standalone-server | docker | node-managed
│   ├── <deploy_and_test script>     # the EXECUTABLE harness for this topology
│   ├── README.md                    # prerequisites + lifecycle + config + troubleshooting
│   └── (docker only) docker-compose.yml, scripts/run-tests.sh
│
└── installation-scripts/ (repo root)  # optional: install-<pac>.bat for install-wide deps
```

**Why `test-resources/` is shared:** every topology deploys the *same* Sources, so
they live once and each topology script points at them. Divergence here is the #1
cause of "passes in Docker, fails standalone."

---

## 2. Dependency Installation (where each JAR goes)

| Artifact | Destination | Scope | Why |
|----------|-------------|-------|-----|
| `<Pac>Impl.jar` (runtime plugin) | `<ACE_HOME>/server/jplugin/` | install-wide | loaded by the integration server runtime |
| `<Pac>.jar` (toolkit plugin) | `<ACE_HOME>/tools/plugins/` | install-wide | loaded by the ACE Toolkit (design-time) |
| 3rd-party libraries | **shared-classes (topology-specific)** | varies | available to flows at runtime |

### shared-classes location is topology-specific

This is the subtle one. Same jars, different home:

| Topology | shared-classes path | Rationale |
|----------|--------------------|-----------|
| **Standalone** | `<SERVER_WORK_DIR>/shared-classes/` | per-server, isolated, no admin needed |
| **Docker** | `<work-dir>/shared-classes/` (in the container) | ephemeral container, per-server |
| **Node-managed / install-wide** | `%MQSI_REGISTRY%\shared-classes\` | shared by all servers under the node |

> Put 3rd-party libs in the wrong shared-classes dir and the flow deploys fine but
> throws `ClassNotFoundException`/`NoClassDefFoundError` at **runtime**.

### Ship the *whole* dependency set

A dependency is often several jars. Example - BouncyCastle for PGP needs all three:
`bcprov` (provider) + `bcpg` (OpenPGP) + `bcutil` (relocated/back-compat classes).
Drop one and it fails at runtime, not at deploy. The manifest must list the full set.

---

## 3. The Ordered Lifecycle (do not reorder load-bearing steps)

```
0. Source the ACE env        call mqsiprofile (.cmd/.sh) - puts ibmint/IntegrationServer
                             /mqsi* on PATH. NOTHING below works without this.
1. Install dependencies      impl->jplugin, tool->tools/plugins, 3rd-party->shared-classes
2. Provision test env        work dir + {keys,input,output}; copy test data/keys; config
3. Place shared-classes      copy the FULL dependency set into the topology-correct dir
4. Deploy  (policies FIRST)  ibmint deploy ... --project <PolicyProject>
           (then app)        ibmint deploy ... --project <Application> --overrides-file <...>
   ── server must NOT be running yet for work-dir deploys ──
5. Start server              clean config/.lock; IntegrationServer --work-dir .. --name ..
                             WAIT for BIP1991I in events log (poll, not a fixed sleep)
6. Verify listener           HTTP_PORT shows LISTENING before driving traffic
7. Drive the flow            curl POST endpoint / file drop / MQ put; capture output+status
8. Verify results            status 200 + non-empty; round-trip byte compare; BIP*E: scan
9. Report + teardown         summarize; point at logs; leave running or stop cleanly
```

### Step-by-step rationale

**0. Source the ACE environment.** `ibmint`, `IntegrationServer`, and every `mqsi*`
command are NOT on PATH in a fresh shell. They become available only after sourcing
the ACE profile:
- Windows: `call "<ACE_HOME>\server\bin\mqsiprofile.cmd"`
- Linux/Docker: `source "<ACE_DIR>/server/bin/mqsiprofile"`

The canonical standalone pattern is a thin **wrapper script** that sources the
profile and then calls the real harness, so the harness body can assume the env is
ready (this is exactly what `run-test-with-ace-env.bat` does):
```bat
@echo off
call "C:\Program Files\IBM\ACE\13.0.7.0\server\bin\mqsiprofile.cmd"
if errorlevel 1 ( echo [ERROR] Failed to source ACE environment & exit /b 1 )
call "%~dp0deploy_and_test.bat"
exit /b %ERRORLEVEL%
```
> Symptom when skipped: `'ibmint' is not recognized` / `command not found`. This is
> the single most common reason a harness "doesn't work" on a clean machine, in CI,
> or when an agent runs it from a non-ACE shell - the agent must source the profile
> first too.

**1. Install dependencies.** Impl and tool jars are install-wide (under `ACE_HOME`),
so this step usually calls the repo's `install-<pac>.bat` (idempotent, `/force`).
3rd-party libs are handled in step 3 because their home depends on topology.

**2. Provision test env.** Create the server work dir and the data dirs
(`keys/`, `input/`, `output/` - or your flow's equivalents). Copy keys/fixtures.
Write any `server.conf.yaml` / overrides. Make this **idempotent**: clean an old
work dir first so reruns are deterministic.

**3. Place shared-classes.** Create `<shared-classes>` and copy the full 3rd-party
set. This is separate from step 1 precisely because the destination differs by topology.

**4. Deploy - policies first, then app.** Use `ibmint deploy` into the work dir:
```
ibmint deploy --input-path "<Sources>" --output-work-directory "<work_dir>" --project <PolicyProject>
ibmint deploy --input-path "<Sources>" --output-work-directory "<work_dir>" --project <Application> \
              --overrides-file "Deploymentdescriptors/containerOverrides.properties"
```
- **Policies first:** the app's policy references resolve only if the policy project
  is already present.
- **Before server start:** a work-dir deploy stages files under `<work_dir>/run/`; a
  *running* server won't pick them up. Deploy, then start.
- **Overrides apply to the app:** promoted properties (file paths, ports, key
  locations, passphrase keys) come from the overrides file so the same BAR/Sources
  work across environments.

**5. Start server + wait for BIP1991I.** Remove any stale `config/.lock` from a
crashed run. Start, then **poll the events log** until
`BIP1991I: Integration server has finished initialization` appears. A fixed `sleep`
is flaky - slow machines under-wait, fast machines over-wait.

**6. Verify listener.** Before sending traffic, confirm the HTTP port is bound:
- Windows: `netstat -ano | findstr ":<HTTP_PORT>" | findstr "LISTENING"`
- *nix: `grep "BIP1991I"` already implies startup; also check the port if needed.
If it isn't listening, the flow didn't deploy or the port collides - fail with the
log tail, don't blast curl into the void.

**7. Drive the flow.** Exercise the real interface:
- HTTP: `curl -X POST http://localhost:<HTTP_PORT>/<path> -o <out> -w "%{http_code}" -s`
- File: drop a fixture into the input dir, wait up to 2× the polling interval.
- MQ: `amqsput`/`rfhutil` to the input queue, `amqsget` the output.

**8. Verify results.** Assert:
- HTTP status `200` (or expected), output file exists and is non-empty.
- Round-trip flows: compare original vs final **byte-for-byte** (`fc /B` on Windows;
  `cmp`/`diff` on *nix). Text compare can hide trailing-newline/encoding diffs.
- Scan logs for errors: `findstr /C:"BIP" ... | findstr "E:"` /
  `grep -i "BIP.*E:" <logs>`.

**9. Report + teardown.** Print original/result, a clear PASS/FAIL, and the log path.
Either leave the server up for inspection (handy locally) or stop it cleanly:
- Windows: `taskkill /F /FI "WINDOWTITLE eq <SERVER_NAME>*"`
- Docker: `docker stop <container>`

---

## 4. The Harness Manifest (parameters)

Gather these once; infer from the repo where possible, ask only for the rest.

| Parameter | Example | Notes |
|-----------|---------|-------|
| `ACE_VERSION` / `ACE_HOME` | `13.0.7.0` / `C:\Program Files\IBM\ACE\13.0.7.0` | autodetect newest if unset |
| `TOPOLOGY` | `standalone` \| `docker` \| `node-managed` | drives shared-classes dir |
| `SERVER_NAME` / `SERVER_WORK_DIR` | `TEST_SERVER_PGP` / `C:\temp\pgp\TEST_SERVER_PGP` | |
| `HTTP_PORT` / `ADMIN_PORT` | `7800` / `7600` | verify listener on HTTP_PORT |
| `DEPENDENCIES` | `PGPSupportPacImpl.jar`→jplugin; `PGPSupportPac.jar`→tools/plugins; `bcprov`+`bcpg`+`bcutil`→shared-classes | FULL set |
| `POLICY_PROJECTS` (ordered) | `PGP_Policies` | deployed first |
| `APPLICATIONS` (ordered) | `TestPGP_App` | with overrides |
| `OVERRIDES_FILE` | `Deploymentdescriptors/containerOverrides.properties` | |
| `TEST_DATA` | keys → `keys/`; sample → `input/plain.txt` | |
| `DRIVER` | `POST /pgp/encrypt`, then `POST /pgp/decrypt` | interface(s) to exercise |
| `VERIFY` | round-trip `fc /B`; status 200; `BIP*E:` scan | success criteria |

---

## 5. Topology Cheat-Sheet

| Concern | Standalone | Docker | Node-managed |
|---------|-----------|--------|--------------|
| shared-classes | `<work_dir>/shared-classes` | `<work_dir>/shared-classes` (container) | `%MQSI_REGISTRY%\shared-classes` |
| Start command | `IntegrationServer --work-dir .. --name ..` | same, inside container | server under a node |
| Script | `deploy_and_test.bat` | `run-tests.sh` + compose | `setup-and-test-node.bat` |
| Best for | local Windows + Toolkit debug | CI, isolation, no local ACE | multi-server, prod-like |
| Teardown | `taskkill /F /FI "WINDOWTITLE eq <name>*"` | `docker stop` | stop server + delete node |

---

## 6. Load-Bearing Gotchas (the checklist)

- [ ] **Source the ACE env first** - `mqsiprofile` (.cmd/.sh) before any `ibmint`/
      `IntegrationServer`/`mqsi*`. Use the wrapper-script pattern for standalone.
- [ ] **Deploy before start** - work-dir deploys aren't hot-loaded by a running server.
- [ ] **Policies before app** - policy references resolve only if policies are deployed.
- [ ] **shared-classes in the topology-correct dir** - wrong dir → runtime ClassNotFound.
- [ ] **Full dependency set shipped** - e.g. BouncyCastle = bcprov + bcpg + bcutil.
- [ ] **Wait on `BIP1991I`**, never a fixed timer.
- [ ] **Clean stale `config/.lock`** before restart.
- [ ] **Binary compare** round-trips (`fc /B`) - not text compare.
- [ ] **Secrets out of committed scripts** - passphrases via policy/override/env.
- [ ] **Idempotent reruns** - clean the work dir / input/output so a 2nd run is clean.
- [ ] **Fail fast, non-zero exit** - so the script drops straight into CI.

---

## 7. Script Skeleton (topology-agnostic shape)

```
0a. Source ACE env   (wrapper: call mqsiprofile.cmd, then call deploy_and_test)
0b. Config block     (ACE_HOME, SERVER_NAME, work dir, ports, Sources path)
1. Install deps      (call install-<pac> script; /force /skipbackup)
2. Setup test dirs   (mkdir keys/input/output; copy test data)
3. Clean + recreate  (rm old work dir; mkdir work dir + shared-classes)
4. Copy 3rd-party    (cp full dependency set -> shared-classes)
5. Deploy            (ibmint deploy policies; ibmint deploy app --overrides-file)
6. Start server      (clean .lock; start; poll events log for BIP1991I)
7. Verify listener   (netstat / port check on HTTP_PORT)
8. Drive + verify    (curl encrypt; curl decrypt; fc /B compare; BIP*E: scan)
9. Report + hints    (PASS/FAIL; log path; how to stop the server)

Every step: [STEP] log on entry, [OK]/[ERROR] on exit, exit /b 1 on failure.
```

See `examples/pgp_supportpac_harness_example.md` for a fully worked instantiation.
