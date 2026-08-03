# Worked Example: PGP SupportPac Harness

**Artifact:** PGP SupportPac for IBM ACE (custom nodes + `pgpKeytool`)
**Flow under test:** `TestPGP_App` - HTTP-triggered PGP encrypt / decrypt
**Policies:** `PGP_Policies` (sender + receiver configuration services)
**Topologies shown:** standalone (Windows) and Docker (Linux)

This is the reference instantiation of the enforced template in
`../harness_template.md`. It is the *executable* counterpart to the test-PLAN
example in `ace-flow-test/references/examples/http_pgp_flow_test_example.md`.

---

## Manifest

| Parameter | Value |
|-----------|-------|
| `ACE_VERSION` / `ACE_HOME` | `13.0.7.0` / `C:\Program Files\IBM\ACE\13.0.7.0` |
| `TOPOLOGY` | standalone (also: docker) |
| `SERVER_NAME` / `SERVER_WORK_DIR` | `TEST_SERVER_PGP` / `C:\temp\pgp\TEST_SERVER_PGP` |
| `HTTP_PORT` / `ADMIN_PORT` | `7800` / `7600` |
| `DEPENDENCIES` | `PGPSupportPacImpl.jar`→`server/jplugin`; `PGPSupportPac.jar`→`tools/plugins`; `bcprov-jdk18on-1.81.jar` + `bcpg-jdk18on-1.81.jar` + `bcutil-jdk18on-1.81.jar`→shared-classes |
| `POLICY_PROJECTS` | `PGP_Policies` (deployed first) |
| `APPLICATIONS` | `TestPGP_App` (with overrides) |
| `OVERRIDES_FILE` | `Deploymentdescriptors/containerOverrides.properties` |
| `TEST_DATA` | PGP keys → `C:\temp\pgp\keys\`; `input/plain.txt` |
| `DRIVER` | `POST /pgp/encrypt` then `POST /pgp/decrypt` |
| `VERIFY` | round-trip `fc /B`; HTTP 200; `BIP*E:` log scan |
| Secret | key passphrase `passw0rd` - supplied via policy, not the script |

> Note on the BouncyCastle trio: `bcprov` (provider) + `bcpg` (OpenPGP) **+ `bcutil`**.
> `bcutil` carries relocated/back-compat classes - omit it and encrypt/decrypt fails
> at runtime even though deploy succeeds.

---

## Directory layout (as built)

```
testing/
├── test-resources/
│   └── Sources/
│       ├── PGP_Policies/                     # PGP-SDR-CFG-SERVICE, PGP-RCV-CFG-SERVICE
│       ├── TestPGP_App/                      # pgp/encrypt.msgflow, decrypt.msgflow, *_Compute.esql
│       ├── Deploymentdescriptors/containerOverrides.properties
│       └── pgp-keys/                         # sender/receiver public+private (.asc/.pgp)
├── standalone-server/deploy_and_test.bat
├── docker/scripts/run-tests.sh + docker-compose.yml
└── node-managed-server/scripts/setup-and-test-node.bat
installation-scripts/install-pgp-supportpac.bat   # install-wide deps (jplugin/tools)
```

---

## Standalone lifecycle (Windows)

### Entry point - source ACE, then run (`run-test-with-ace-env.bat`)

The harness is *invoked* through a thin wrapper that sources the ACE environment
first; `deploy_and_test.bat` then assumes `ibmint`/`IntegrationServer` are on PATH:
```bat
@echo off
echo Sourcing ACE environment...
call "C:\Program Files\IBM\ACE\13.0.7.0\server\bin\mqsiprofile.cmd"
if errorlevel 1 ( echo [ERROR] Failed to source ACE environment & exit /b 1 )
echo Running deploy_and_test.bat...
call "%~dp0deploy_and_test.bat"
exit /b %ERRORLEVEL%
```
> Run `run-test-with-ace-env.bat`, NOT `deploy_and_test.bat` directly - unless you
> are already in an ACE Command Console (which has sourced the profile for you).
> An agent driving this from a fresh shell must `call mqsiprofile.cmd` first.

### Harness body (`deploy_and_test.bat`)

Config block:
```bat
set ACE_VERSION=13.0.7.0
set ACE_HOME=C:\Program Files\IBM\ACE\%ACE_VERSION%
set SERVER_NAME=TEST_SERVER_PGP
set SERVER_WORK_DIR=C:\temp\pgp\%SERVER_NAME%
set TEST_DIR=C:\temp\pgp
set ADMIN_PORT=7600
set HTTP_PORT=7800
set SOURCES_DIR=%~dp0..\..\testing\test-resources\Sources
```

**1. Install dependencies** (install-wide jars; idempotent force install):
```bat
call "%~dp0..\..\installation-scripts\install-pgp-supportpac.bat" /force /skipbackup
```
This copies `PGPSupportPacImpl.jar`→`server\jplugin`, `PGPSupportPac.jar`→
`tools\plugins`, and the BC trio→`%MQSI_REGISTRY%\shared-classes` (install-wide path).

**2. Provision test env:**
```bat
for %%D in (keys input output) do if not exist "%TEST_DIR%\%%D" mkdir "%TEST_DIR%\%%D"
xcopy /Y /Q "%SOURCES_DIR%\pgp-keys\*.*" "%TEST_DIR%\keys\" >nul
```

**3. Clean + place shared-classes (standalone → server work dir):**
```bat
if exist "%SERVER_WORK_DIR%" rmdir /S /Q "%SERVER_WORK_DIR%"
mkdir "%SERVER_WORK_DIR%\shared-classes"
copy /Y "%~dp0..\..\MQSI_REGISTRY\shared-classes\bcprov-jdk18on-1.81.jar" "%SERVER_WORK_DIR%\shared-classes\" >nul
copy /Y "%~dp0..\..\MQSI_REGISTRY\shared-classes\bcpg-jdk18on-1.81.jar"   "%SERVER_WORK_DIR%\shared-classes\" >nul
copy /Y "%~dp0..\..\MQSI_REGISTRY\shared-classes\bcutil-jdk18on-1.81.jar" "%SERVER_WORK_DIR%\shared-classes\" >nul
```
> Standalone uses the **server work dir** shared-classes, even though the install
> step also populated the install-wide one. The per-server copy keeps the test
> isolated and reproducible.

**4. Deploy - policies first, then app, before start:**
```bat
ibmint deploy --input-path "%SOURCES_DIR%" --output-work-directory "%SERVER_WORK_DIR%" --project PGP_Policies
ibmint deploy --input-path "%SOURCES_DIR%" --output-work-directory "%SERVER_WORK_DIR%" --project TestPGP_App ^
              --overrides-file Deploymentdescriptors\containerOverrides.properties
```

**5. Start server + wait for BIP1991I:**
```bat
del /Q "%SERVER_WORK_DIR%\config\.lock" 2>nul
start "TEST_SERVER_PGP" IntegrationServer --work-dir "%SERVER_WORK_DIR%"
:wait_for_server
findstr /C:"BIP1991I" "%SERVER_WORK_DIR%\log\integration_server.%SERVER_NAME%.events.txt" >nul 2>&1
if errorlevel 1 ( ping 127.0.0.1 -n 6 >nul & goto :wait_for_server )
```

**6. Verify listener:**
```bat
netstat -ano | findstr ":%HTTP_PORT%" | findstr "LISTENING" >nul || echo [WARN] HTTP listener not up on %HTTP_PORT%
```

**7. Drive the flow:**
```bat
echo This is a test file for PGP encryption > "%TEST_DIR%\input\plain.txt"
curl -X POST http://localhost:%HTTP_PORT%/pgp/encrypt -o "%TEST_DIR%\output\encrypted.txt"
curl -X POST http://localhost:%HTTP_PORT%/pgp/decrypt -o "%TEST_DIR%\input\plain-decrypted.txt"
```

**8. Verify round-trip (binary):**
```bat
fc /B "%TEST_DIR%\input\plain.txt" "%TEST_DIR%\input\plain-decrypted.txt" >nul
if errorlevel 1 ( echo [FAIL] original != decrypted & goto :error_exit ) else ( echo [PASS] round-trip OK )
```

**9. Teardown hint:**
```
taskkill /F /FI "WINDOWTITLE eq TEST_SERVER_PGP*"
```

---

## Docker lifecycle (Linux `run-tests.sh`) - what differs

Same lifecycle, container-flavored:

- **shared-classes** goes to `/home/aceuser/ace-server/shared-classes/` (the
  container's server work dir) - the BC trio is copied there, not to MQSI_REGISTRY.
- **Wait condition** greps the captured startup log:
  `grep -q "BIP1991I: Integration server has finished initialization" <log>`.
- **Deploy** is identical (`ibmint deploy` policies then app with overrides).
- **Endpoints** are the same (`POST /pgp/encrypt`, `/pgp/decrypt` on 7800).
- **Round-trip compare** uses a shell string/`cmp` compare instead of `fc /B`.
- Container stays alive (`tail -f /dev/null`) for `docker exec` inspection.

---

## Failure modes this harness catches

| Symptom | Root cause the template guards against |
|---------|----------------------------------------|
| `NoClassDefFoundError` at encrypt time | BC `bcutil` missing, or shared-classes in wrong dir |
| Policy not found on app deploy | app deployed before `PGP_Policies` |
| App/policies not active after start | deploy ran while server was already running |
| Flaky "connection refused" on curl | drove traffic before `BIP1991I` / listener up |
| "round-trip passes but bytes differ" | text compare instead of `fc /B` |
| 2nd run behaves differently | stale work dir / `.lock` not cleaned |

---

## Known doc nit (from the source repo)

The standalone README once listed the **decrypt** endpoint as port `7801`; the
actual flow serves both encrypt and decrypt on `7800`. When generating a harness,
trust the deployed flow's HTTP node, not prose - and verify the listener (step 6)
before driving it.
