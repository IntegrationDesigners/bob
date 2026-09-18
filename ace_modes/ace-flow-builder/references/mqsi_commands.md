---
template_version: 0.2.0
last_updated: 2026-07-02
compatible_with: ACE Flow Builder v0.5.0+
status: beta
---
# ACE mqsi / ibmint Command Reference (verified)

Verified command syntax for driving **node-managed** ACE integration nodes/servers on Windows. Every command here was run successfully in a real ACE 12.0.12.x / 13.0.7.x session; the "wrong form" notes are mistakes that actually cost round-trips - avoid them.

Read this in **Phase B0.5** (deploy planning) and **Phase B5** (validate) instead of rediscovering syntax by trial-and-error. Always **narrate** which command you're about to run and why (see SKILL.md "Pace & Transparency").

> Scope note: this covers node-managed runtimes driven from the OS shell. Independent/standalone servers (work-dir + vault) are covered by `validation_runbook.md`. Which mechanism a given user wants is a project decision - check memory (e.g. a `feedback-credentials-*` entry) before assuming.

---

## 1. Environment - source the per-version profile

`mqsi*` / `ibmint` need the install's environment. Source `mqsiprofile.cmd` in the **same** shell, then run the command. From the Bash/PowerShell tools, wrap in `cmd /c`:

```bat
cmd /c "\"C:\Program Files\IBM\ACE\13.0.7.0\server\bin\mqsiprofile.cmd\" >nul && mqsilist"
```

- Pick the profile matching the target version: `...\ACE\12.0.12.17\...` vs `...\ACE\13.0.7.0\...`.
- `>nul` suppresses the profile banner so command output is clean.
- Each `cmd /c` is its own environment - chain everything you need inside one invocation with `&&`.

---

## 2. Discovery - nodes, servers, ports

```bat
REM List all integration nodes on this install (+ running state + admin URI)
mqsilist

REM List integration servers under a node
mqsilist <node>            REM e.g. mqsilist TEST_V13   ->  server 'IS1' running

REM HTTP listener port a server uses (where HTTP-input flows are reachable)
mqsireportproperties <node> -e <server> -o HTTPConnector -n ListenerPort
```

- `mqsilist` prints the admin URI, e.g. `TEST_V13 ... 'https://<host>:4418' is running` (v13 = https), `TEST_V12 ... 'http://<host>:4416'` (v12 = http).
- Default integration-server HTTP listener is **7800**. If two servers must run HTTP-input flows at once, give them distinct ports (see §5).

**Gotchas (these error out):**
- `mqsireportproperties ... -r -n <prop>` → `BIP8865E: Bad flag combination` (recursive `-r` and single-property `-n` are mutually exclusive). Use `-n <prop>` for one value, or `-r` for all.
- In `mqsireportproperties`, `-p` is `--output-file`, **not** a property flag.

---

## 3. Credentials - vault first; `mqsisetdbparms` is LEGACY

**The ACE 13 credential mechanism is the vault.** Lead with it in every credential conversation:

- **Independent/standalone servers (work-dir):** per-work-directory vault via `ibmint set credential` (singular). The vault is created **implicitly** on the first `set credential --work-directory` call - `ibmint create vault` is only for *external directory* vaults shared across servers.

  ```bat
  REM Add/update a credential (singular 'credential')
  ibmint set credential --work-directory <dir> --credential-type <type> --credential-name <name> --vault-key <key>

  REM List (plural 'credentials' here only)
  ibmint display credentials --work-directory <dir> --vault-key <key>

  REM Remove
  ibmint unset credential --work-directory <dir> --credential-type <type> --credential-name <name> --vault-key <key>
  ```

  Pass the vault key at server start via `--vault-key` or `MQSI_VAULT_KEY`. Full runbook: `validation_runbook.md` §7.
- **Node-managed runtimes:** the modern node-managed alternative is the **integration NODE vault** (`mqsivault` to manage the vault, `mqsicredentials` to manage credentials in it).

### Legacy path: `mqsisetdbparms` (node-managed, pre-vault)

Use this **only when the user's estate is node-managed and already uses `mqsisetdbparms`** - do not introduce it into new setups. The syntax below is verified and kept because such estates exist:

```bat
mqsisetdbparms <node> -n <resource> -u <userId> --password <password>
```

- v12 accepts the short `-p <password>`; the v13 help lists only `--password` (use `--password` to be safe on both).
- **Resource name determines the type** - pick the right prefix for what's consuming the credential:

| Consumer | `-n <resource>` form |
|---|---|
| REST Request node **Security identity** property | `rest::<id>` |
| Security **Profile** STATIC-ID propagation (`transportPropagationConfig`) | **plain `<id>`** (no prefix) |
| MQ nodes / secured qmgr | `mq::<id>` |
| JDBC security identity | `jdbc::<id>` |
| HTTP proxy creds | `httpproxy::<proxy>` or `httpproxy::HTTPPROXY` |
| Generic DSN (Compute/Mapping/Database) | plain `<dsn>` |

  (Full list: run `mqsisetdbparms` with no args for the usage text.)

- **CAVEAT - restart to activate.** mqsisetdbparms says: *"operational changes do not take effect until the integration server(s) using the resource are restarted."* Redeploying the **app** is **not** enough - the credential is loaded at **server-process** start. After setting/changing a credential, restart the server (§5) before testing. (Observed: a flow sent no `Authorization` header right after a credential change, then sent it correctly once the server had been restarted - symptom looks identical to "basic auth not working".)

Verify what's registered (password masked):
```bat
mqsireportdbparms <node> -n <resource>
```

---

## 4. Package + deploy

```bat
REM Package one or more projects found under a directory into a BAR
ibmint package --input-path <dir> --output-bar-file <Name>.bar

REM Deploy a BAR to a node-managed integration server
mqsideploy --integration-node <node> --integration-server <server> --bar-file <Name>.bar --timeout-seconds 120
```

- **`--input-path <dir>` scans the dir for projects.** To bundle exactly the projects you want (app + policy project, etc.) without dragging in a whole repo, stage them under one folder with Windows junctions:
  ```bat
  mkdir stage
  mklink /J stage\<App>            <path-to-app-project>
  mklink /J stage\<PolicyProject>  <path-to-policy-project>
  ibmint package --input-path stage --output-bar-file <Name>.bar
  ```
  (`mklink /J` needs no admin; junctions reference, they don't copy.)
- A `SecurityProfiles` policy project (e.g. `SecurityRegistry`) can be bundled in the **same** BAR as the app - it deploys fine alongside. (The "policy must be a folder under `run/`, not in the BAR" rule in `validation_runbook.md` §3 applies only to **MQ** policies needed at server *startup*.)

**Gotchas:**
- `mqsideploy -n <node>` is **WRONG** - `-n` (`--integration-node-file`) expects a `.broker` connection file, so it tries to open a file named like your node and fails with `BIP8177E`. The node name is **positional** or `--integration-node <node>`.
- A clean deploy prints `BIP1092I: The deployment request was processed successfully.` (and `BIP9332I` per app/policy created/changed).
- `ibmint` exists on both v12 and v13.

---

## 5. Restart + properties

```bat
REM Restart the integration-server process (reloads flows AND legacy mqsisetdbparms creds)
mqsireload <node> -e <server>

REM Change the HTTP listener port (then restart for it to bind)
mqsichangeproperties <node> -e <server> -o HTTPConnector -n ListenerPort -v <port>
```

- Use `mqsireload` after a legacy `mqsisetdbparms` change (§3) - an app redeploy alone won't pick up new credentials.
- `mqsichangeproperties` returns `BIP8492W` reminding you apps need a restart/redeploy for the change to go active.

---

## 6. v12 vs v13 differences seen

| | v12 (12.0.12.x) | v13 (13.0.7.x) |
|---|---|---|
| Admin URI scheme | `http://` | `https://` |
| `mqsisetdbparms` password flag | `-p` or `--password` | `--password` (help omits `-p`) |
| `ibmint` / `mqsi*` available | yes | yes |
| Credential mechanism | mqsisetdbparms (node) | **vault** - `ibmint set credential` (independent server) or node vault `mqsivault`/`mqsicredentials` (node-managed); `mqsisetdbparms` legacy only |
| SecurityProfiles policyxml format | identical between versions | identical between versions |
