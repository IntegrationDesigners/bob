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
0a. Read the repo's docs     testing/README.md AND every per-topology README - a gate,
                             not a suggestion. Reuse their values verbatim.
0b. Source the ACE env       call mqsiprofile (.cmd/.sh) - puts ibmint/IntegrationServer
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

**0a. Read the repo's own harness docs - all of them.** Before executing anything,
enumerate and read `testing/README.md` **and every per-topology README**
(`standalone-server/`, `docker/`, `node-managed/`). Each one carries constraints the
index README and the scripts do not encode: which shared-classes *level* the jars go
to, the port map, the documented cleanup verbs, the known issues for that topology.
Reading the index plus the first topology you run does **not** transfer to the others.

> Symptom when skipped: you drive topology 2 and 3 straight from their scripts, miss a
> documented constraint, and the user has to stop you mid-run to ask whether you read
> their README. Cheap to do, expensive to skip.

**0b. Source the ACE environment.** `ibmint`, `IntegrationServer`, and every `mqsi*`
command are NOT on PATH in a fresh shell. They become available only after sourcing
the ACE profile:
- Windows: `call "<ACE_HOME>\server\bin\mqsiprofile.cmd"`
- Linux/Docker: `source "<ACE_DIR>/server/bin/mqsiprofile"`

The canonical standalone pattern is a thin **wrapper script** that sources the
profile and then calls the real harness, so the harness body can assume the env is
ready (this is exactly what `run-test-with-ace-env.bat` does):
```bat
@echo off
if not defined ACE_VERSION set ACE_VERSION=13.0.8.1
call "C:\Program Files\IBM\ACE\%ACE_VERSION%\server\bin\mqsiprofile.cmd"
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
Write server config to `<work_dir>/overrides/server.conf.yaml` only - never the base
`server.conf.yaml` (Overrides-only rule, section 6). Make this **idempotent**: clean an
old work dir first so reruns are deterministic.

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
- Windows: stop the process whose command line holds this run's `--work-dir`
  (PowerShell: `Get-CimInstance Win32_Process -Filter "Name='IntegrationServer.exe'" |
  Where-Object CommandLine -match [regex]::Escape('<work_dir>')`, then `Stop-Process` on
  those ids). Never by window title (a detached server has none, see 6a) or by image name.
- Docker: `docker stop <container>`

---

## 4. The Harness Manifest (parameters)

Gather these once; infer from the repo where possible, ask only for the rest.

| Parameter | Example | Notes |
|-----------|---------|-------|
| `ACE_VERSION` / `ACE_HOME` | `13.0.8.1` / `C:\Program Files\IBM\ACE\13.0.8.1` | make it overridable (`if not defined ACE_VERSION set ...`), do not hardcode |
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
| Teardown | stop the PID whose command line holds the work dir | `docker stop` | stop server + delete node |

---

## 6. Load-Bearing Gotchas (the checklist)

- [ ] **Read every topology README first** - the index plus one topology is not enough.
- [ ] **Source the ACE env first** - `mqsiprofile` (.cmd/.sh) before any `ibmint`/
      `IntegrationServer`/`mqsi*`. Use the wrapper-script pattern for standalone.
- [ ] **Deploy before start** - work-dir deploys aren't hot-loaded by a running server.
- [ ] **Policies before app** - policy references resolve only if policies are deployed.
- [ ] **shared-classes in the topology-correct dir** - wrong dir → runtime ClassNotFound.
- [ ] **Overrides-only rule** - config changes go to `overrides/server.conf.yaml`
      (standalone: `<work_dir>/overrides/`; node-managed: `<node>/servers/<server>/overrides/`;
      node: `<node>/overrides/node.conf.yaml`), never the base file. ACE layers the base
      file over built-in defaults, so a script that rewrites it "works" while dropping
      every generated setting.
- [ ] **Full dependency set shipped** - e.g. BouncyCastle = bcprov + bcpg + bcutil.
- [ ] **Wait on `BIP1991I`**, never a fixed timer.
- [ ] **Log hygiene** - `grep` the events/console log for the BIP marker and quote the
      matched line; tail 20-40 lines only when the marker is missing. Never paste a whole
      log into the reply, the README or `TESTING.md`.
- [ ] **Clean stale `config/.lock`** before restart.
- [ ] **Binary compare** round-trips (`fc /B`) - not text compare.
- [ ] **Secrets out of committed scripts** - passphrases via policy/override/env.
- [ ] **Idempotent reruns** - clean the work dir / input/output so a 2nd run is clean.
- [ ] **Fail fast, non-zero exit** - so the script drops straight into CI.
- [ ] **No `timeout /t` in `.bat`** - use `ping 127.0.0.1 -n <secs+1> >nul`.
- [ ] **`.gitattributes` pins `*.sh` to `eol=lf`** when scripts are bind-mounted.
- [ ] **Version-gated startup blocks checked** - e.g. call-home on ACE 13.0.8 images.
- [ ] **Agent-written `.bat` converted to CRLF** before its first run (see 6a).
- [ ] **`call` every `mqsi*.cmd` vendor tool** - without it control never returns.
- [ ] **Stop the server by command-line match**, not window title (see 6a).
- [ ] **A left-running server's output redirected to a file** (see 6a).

---

## 6a. Non-Interactive and Cross-Platform Traps

These bite only when the harness is run by CI or an agent - never when a human runs it
interactively - so they survive a lot of "it works for me" testing.

### `timeout /t` is a no-op under redirected stdin

Windows `timeout` requires an interactive console. Redirect the script's output
(`deploy_and_test.bat > run.log 2>&1`, any CI job, any agent-driven run) and every
call prints `ERROR: Input redirection is not supported, exiting the process
immediately` and returns at once. The waits vanish, the run usually still passes, and
the race they guarded resurfaces on a slower machine.

```bat
REM WRONG - silently skipped when stdout is redirected
timeout /t 10 /nobreak >nul

REM RIGHT - works redirected or not (n = seconds + 1)
ping 127.0.0.1 -n 11 >nul
```

### CRLF breaks bind-mounted shell scripts

A `.sh` mounted from a Windows working tree into a Linux container is line-ending
sensitive. With `core.autocrlf=true`, git stores LF but *checks out* CRLF; compose
mounts the working-tree copy, and bash fails immediately:

```
/tmp/run-tests.sh: line 3: $'\r': command not found
/tmp/run-tests.sh: line 17: syntax error near unexpected token `$'{\r''
```

The commit is clean, so the repo looks correct and this reproduces for every Windows
clone. Ship a `.gitattributes`:

```gitattributes
*.sh  text eol=lf      # executed inside Linux containers
*.bat text eol=crlf
*.cmd text eol=crlf
```

First diagnostic when a container exits within a second: `file <script>` - check for
`with CRLF line terminators` before you start reading the script's logic.

### Version-gated startup blocks

When a server dies between `BIP1990I` (starting initialization) and `BIP1991I`
(finished initialization), read the BIP code before suspecting the harness, then grep
the catalog - it names the fix:

```bash
grep -A4 '<id>' <ACE_DIR>/server/messages/BIPmsgs.properties
```

**Known: ACE 13.0.8 container images.** They ship call-home (anonymous usage
statistics) enabled with an unreplaced placeholder in
`$MQSI_WORKPATH/registry.13.0.conf.yaml`:

```yaml
---
CallHome:
  companyName: 'REPLACE_ME_COMPANY_NAME'
  enabled: true
```

The server refuses to start with `BIP2203E` + `BIP15366W: ... requires a company name
supplied to start`. The company name exists only for that anonymous feedback, so a
test harness that sends none should turn call-home off rather than invent a name:

```bash
printf 'CallHome:\n  enabled: false\n' > "${MQSI_WORKPATH:-/var/mqsi}/registry.13.0.conf.yaml"
```

This matches what a configured Windows install carries in
`C:\ProgramData\IBM\MQSI\registry.13.0.conf.yaml`, which is why standalone and
node-managed topologies never hit it. Note that
`ibmint modify installation --disable-usage-statistics` returns 0 but does **not**
clear the gate on its own (verified on 13.0.8.1-r1). Images 13.0.6/13.0.7 have no
such check, so the step is harmless on older tags.

### An agent-written `.bat` is LF until proven otherwise

It never passes through git, so `.gitattributes` does not save it. Convert to CRLF
before the first run: `cmd` label search (`call`/`goto`) on an LF-only batch file
misjumps into the middle of a later line, nondeterministically, and the failure MOVES as
the file grows (three clean runs, then added lines shifted the offsets and one test was
silently skipped). Verify with a per-file count of CRLF versus lone-LF endings, never a
boolean `grep` for `\r` - that reported CRLF present on a pure-LF file.

### Process control: `call`, stop by command line, redirect output

- `mqsicreateworkdir` and the other `mqsi*` tools are `.cmd` files: invoked without
  `call`, control never returns to the harness. The run prints its success line and then
  truncates - it reads as a passing step that stopped early. A `%ERRORLEVEL%` read inside
  a `for` body expands once at parse time; use `!ERRORLEVEL!` or assert on the BIP message.
- `taskkill /FI "WINDOWTITLE eq ..."` cannot reach a detached `IntegrationServer.exe`.
  Match on the work directory instead:
  `Get-CimInstance Win32_Process | ? CommandLine -match <work_dir>`.
- A server left running inherits the harness console's stdout handle, so any
  output-capturing caller blocks forever on a pipe the server will never close. Redirect
  its output to a file.

---

## 7. Script Skeleton (topology-agnostic shape)

```
0. Source ACE env    (wrapper: call mqsiprofile.cmd, then call deploy_and_test)
   Config block      (ACE_HOME, SERVER_NAME, work dir, ports, Sources path)
   (the 0a discovery gate is an agent action, not a step in the generated script)
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
