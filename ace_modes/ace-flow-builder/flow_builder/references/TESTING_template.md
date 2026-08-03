---
template_version: 0.1.0
last_updated: 2026-04-30
compatible_with: ACE Flow Builder v0.3.0+
status: beta
---

<!--
TESTING.md template - Phase B5 fills this in and writes to <project>/TESTING.md.

Sections in order:
1. What's under test
2. Components
3. Build + deploy
4. Test scenarios (S1 smoke, S2 full pipeline, S3 exception paths)
5. What to watch for
6. Cleanup
7. Things this test cannot prove

Replace [PLACEHOLDERS] with concrete values from the validation run. Remove
any sub-section that genuinely doesn't apply (e.g. an HTTP-only flow with
no MQ component drops the MQ rows in Components and the runmqsc step in
Build + deploy).

Overwrite this file on every Level-2 / Level-3 re-run. Historical record
lives in <FlowName>.flow_state.md "Validation Results" section.
-->

# Local end-to-end test - [FlowName]

How [FlowName] is exercised against the local validation harness without touching real production endpoints.

## What's under test

[One-paragraph description of the flow path being validated. Name the input source, the transformation steps, and the output destination(s). Mention the redirect target (mock URL, local QM, etc.) so a reader understands what's being substituted for prod.]

Example shape: *"The full [InputSource] → MQ → [InternalRouting] → [DownstreamCall] pipeline, with the outbound [API/system] calls all redirected to a local mock running on `http://localhost:7801`."*

## Components

| Component | Detail |
|---|---|
| **[QmgrName]** | IBM MQ in Docker (`[path-to-compose.yaml]`), exposing 1414. Connects via the `[ChannelName]` channel; credentials live in the compose env. |
| **PolicyProject** at `[workspace-path]\PolicyProject` | Supplies the `[PolicyName]` MQEndpoint policy that the IS uses to reach [QmgrName] in CLIENT mode. |
| **Mock** (under `[Mock-folder]/`) | Answers [list of endpoints]. Hardcoded fixtures so a fresh mock immediately drives both adapter branches: [list ID → response → branch]. |
| **`<FlowName>_LOCAL.properties`** | Overrides [list of UDPs / hostnames] on the flow(s) so calls hit `http://localhost:7801` instead of the real downstream. |
| Vault | Stores any required credentials (initialized via `ibmint create vault --work-dir <work-dir> --vault-key <key>`). Vault key passed at server start via `--vault-key` or `MQSI_VAULT_KEY`. |

Remove rows that don't apply. Add rows for any extra components (subflows, shared libs that are particularly relevant, secondary mocks, etc.).

## Build + deploy

```bash
# 1. Boot the local qmgr (skip if already running)
cd [path-to-compose-dir] && docker compose up -d

# 2. Apply queue + subscription definitions
docker cp [project]\mqsc\MQDefs.mqsc [QmgrContainer]:/tmp/
docker exec [QmgrContainer] bash -c "runmqsc [QmgrName] < /tmp/MQDefs.mqsc"

# 3. Stage projects under one folder so `ibmint package --input-path` finds them
#    Use Windows directory junctions to avoid copying.
mklink /J stage\[Application]   [workspace]\[Application]
mklink /J stage\[SharedLib1]    [workspace]\[SharedLib1]
mklink /J stage\PolicyProject   [workspace]\PolicyProject

# 4. Package
ibmint package --input-path stage \
    --output-bar-file [Bundle].bar \
    --do-not-compile-java

# 5. Apply LOCAL overrides
ibmint apply overrides [project]\deploymentDescriptors\[FlowName]_LOCAL.properties \
    --input-bar-file [Bundle].bar \
    --output-bar-file [Bundle]_LOCAL.bar

# 6. Stage work_dir with the BAR + a server.conf.yaml that enables HTTPConnector
#    on the chosen port and points the IS at the PolicyProject for default MQ
xcopy /Y [Bundle]_LOCAL.bar work_dir\run\
# (server.conf.yaml is generated separately - see Section 4 of validation_runbook.md)

# 7. Start the standalone Integration Server
IntegrationServer --work-dir work_dir --name [TestServerName] --console-log
```

If the flow doesn't use MQ, drop steps 1, 2 (and the Docker compose dependency).
If the flow doesn't have shared libs / PolicyProject, drop step 3 and stage the single project directly.
If the flow has no external URLs to redirect, drop step 5.

## Test scenarios

### S1 - Mock smoke test (no MQ required)

Bypass the adapter and hit the mock directly with curl to confirm fixtures behave as expected:

```bash
# [Endpoint 1 description]
curl -s [method] [mock-url]/[path]

# [Endpoint 2 description]
curl -s -o /dev/null -w "%{http_code}\n" [method] [mock-url]/[path-with-fixture-id]  # → [expected-status]
```

Adapt to the actual flow's downstream calls. Drop S1 if the flow has no HTTP downstream (timer-only / pure-MQ flows).

### S2 - Full pipeline: [Input] → [Path] → [Output]

Drop a sample [input format] message onto `[InputQueueOrEndpoint]`:

```bash
# [Description of the test message - which fixture branch it drives]
docker exec -i [QmgrContainer] /opt/mqm/samp/bin/amqsput [InputQueue] [QmgrName] \
    < [project]\testData\[sample-file].json
```

Or use the [Load flow / file drop / curl POST] entry point: [describe the alternate entry].

**What to watch for in the SIS console:**

- `BIP9332I: Application '[FlowName]' has been reloaded successfully` at startup
- `BIP2269I` confirming application is deployed
- For each test message:
  - [ComputeNodeA] writes a log entry with `status="[expected-status-A]"` then `status="[expected-status-B]"` (or `[alternate]`)
  - [ComputeNodeB] writes `status="[expected-status-C]"`
  - The mock's HTTP listener receives the call (visible in mock stdout)
  - HTTP [expected-status-code] returns; [HandlerNode] routes to the success log

### S3 - Exception paths

- Drop a message with `[bad-input-1]` → expect `[ComputeNode]` logs `WARN status="[expected-warning]"` and propagates to DROP
- Drop a message with `[bad-input-2]` → expect `[ComputeNode]` logs `WARN status="[expected-warning]"` and propagates to DROP

Two scenarios is usually enough. Adapt cases per flow design.

## Cleanup

```bash
# Stop the IntegrationServer (Ctrl-C in its console)

# (Optional, only if you own the compose file) tear down the qmgr
docker compose -f [path-to-compose.yaml] down
```

## Things this test cannot prove

- Real [downstream-system] auth flow (production OAuth tenant + client_credentials)
- Real [downstream-system]'s verbose `_errors[]` body shapes on 4xx
- Production proxy + TLS configuration
- Behaviour under network partition / retry policies (the mock always answers)
- [Add per-flow limitations]

These remain as integration-test scope, not unit-validation scope.
