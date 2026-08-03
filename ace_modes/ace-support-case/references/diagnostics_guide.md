# ACE Support Case - Diagnostics Guide

Distilled from the IBM ACE Troubleshooting and Support documentation set. Use this as the authoritative command and path reference when collecting diagnostics for an IBM support case.

---

## 1. System Information (always first)

```bash
mqsiservice -v
```

Captures: product version, fix pack level, interim fixes, OS, Java version. Required for every IBM support case.

---

## 2. ACE Data Collector (always run - for every problem type)

The data collector is the single most complete automated diagnostic tool. Run it before anything else.

### Availability
| ACE Version | Availability |
|---|---|
| v11.0.0.8+ | Bundled - located at `$MQSI_BASE_FILEPATH/server/bin/aceDataCollector.sh` (Unix) / `aceDataCollector.bat` (Windows) |
| v12 / v13 | Always bundled |
| < v11.0.0.8 | Download from https://www.ibm.com/support/pages/node/886323 |

### Detection
```bash
# Unix
ls "$MQSI_BASE_FILEPATH/server/bin/aceDataCollector.sh"

# Windows (from ACE Console)
dir "%MQSI_BASE_FILEPATH%\server\bin\aceDataCollector.bat"
```

### Command syntax

**Unix (AIX / Linux):**
```bash
# Integration node only
./aceDataCollector.sh -b <NODE>

# Integration node + specific IS
./aceDataCollector.sh -b <NODE> -e <IS>

# Standalone integration server (by workdir)
./aceDataCollector.sh -w <WORKDIR>

# Help
./aceDataCollector.sh -h
```

**Windows (run from ACE Console):**
```bat
aceDataCollector.bat -b <NODE>
aceDataCollector.bat -b <NODE> -e <IS>
aceDataCollector.bat -w <WORKDIR>
```

**OCP (container):**
```bash
oc rsh <ace-pod-name>
. /opt/ibm/ace-<version>/server/bin/mqsiprofile
cd /home/aceuser
aceDataCollector.sh -w /home/aceuser/ace-server

# Copy output to local machine (new terminal)
oc rsync <POD_NAME>:/home/aceuser/ACE_Data_Collector_<timestamp>_SIS ./
```

### Output location and naming
- Unix: compressed archive in current working directory
- Windows: output folder in current working directory
- Naming: `ACE_Data_Collector_<YYmmDD-HHMMSS>_<IntNode|SIS|general>`

**No performance impact** - safe to run against a live node or server.

---

## 3. Trace Collection

### User Trace (application-level debugging)

Start user trace:
```bash
# Node-managed IS
mqsichangetrace <NODE> -u -e <IS> -l normal
mqsichangetrace <NODE> -u -e <IS> -l debug   # more verbose

# Standalone IS
mqsichangetrace -u -w <WORKDIR> -l normal
```

Reproduce the problem, then stop trace:
```bash
mqsichangetrace <NODE> -u -e <IS> -l none
```

**Log file locations:**

| Deployment | Path |
|---|---|
| Node-managed IS (Windows) | `<NODE_WORK_DIR>\common\log\<NODE>.<IS>.userTrace.0.txt` |
| Node-managed IS (Linux) | `<NODE_WORK_DIR>/common/log/<NODE>.<IS>.userTrace.0.txt` |
| Standalone IS | `<WORKDIR>/config/common/log/<IS>.userTrace.0.txt` |

`<NODE_WORK_DIR>` is the work-data root passed to `mqsicreatebroker -w` (ask the user - see workflow Phase 2). It defaults to `%ProgramData%\IBM\MQSI\` (Windows) or `/var/mqsi/` (Linux) **only when the node was created without `-w`** - many sites override it (e.g. `D:\IBM\mqsi\Nodes`). `MQSI_WORKPATH` is the registry/global config root, not necessarily this data path.

File rotation: 5 files (0-4), wraps back to 0. If first/last timestamps are suspiciously close but the trace ran longer, wrapping occurred - increase trace file size with `mqsichangetrace`.

### Service Trace (system-level - only on IBM direction or explicit request)

```bash
# Integration node
mqsichangetrace <NODE> -t -b -l debug

# Node-managed IS
mqsichangetrace <NODE> -t -e <IS> -l debug

# Stop service trace
mqsichangetrace <NODE> -t -b -l none
```

Independent server: set `trace: 'service'` in `server.conf.yaml` (restart required), or start with `--service-trace` flag.

**Service trace log locations:**

| OS | Path |
|---|---|
| Windows (node-managed) | `<NODE_WORK_DIR>\common\log\<NODE>.<IS>.trace.n.txt` |
| Linux (node-managed) | `<NODE_WORK_DIR>/common/log/<NODE>.<IS>.trace.n.txt` |
| Standalone IS | `<WORKDIR>/config/common/log/integration_server.<IS>.trace.n.txt` |

`<NODE_WORK_DIR>` = the `mqsicreatebroker -w` value (defaults to `%ProgramData%\IBM\MQSI\` / `/var/mqsi/` only when no `-w` was given).

**Command tracing (for command failures):**
```bash
command --trace c:\tmp\listtrace.txt

# Or via environment variables
MQSI_UTILITY_TRACE=normal        # or debug
MQSI_UTILITY_TRACESIZE=<KB>
# Reset after use - otherwise all subsequent commands are traced
```

### ODBC Trace

**Windows:**
1. Copy `uktrc95.dll` and `ukicu.dll` from `<ACE_INSTALL_DIR>\bin` to `C:\Windows\System32` (required for Oracle, PostgreSQL, Sybase only - skip for Db2)
2. Open **ODBC Data Source Administrator (64-bit)**
3. Tracing tab → Select DLL → choose `uktrc95.dll` → set Log File Path → Start Tracing Now

**Linux/UNIX:**
Edit `$ODBCSYSINI/odbcinst.ini`:
```ini
[ODBC]
Trace=yes
TraceFile=/tmp/odbc_trace.log
```
Stop: set `Trace=no` in the same file. Ensure adequate disk space.

---

## 4. Logs

### Work-data root and the common log dir (read this before quoting any log path)

ACE log/trace data does **not** necessarily live under `%ProgramData%\IBM\MQSI\`:
- `MQSI_BASE_FILEPATH` = the **install** dir.
- `MQSI_WORKPATH` = the **registry/global config root**, not necessarily the data path.
- The real data path is the node's **work-data root** `<NODE_WORK_DIR>` - whatever was given to `mqsicreatebroker -w` (configurable per site, e.g. `D:\IBM\mqsi\Nodes`). It defaults to `%ProgramData%\IBM\MQSI\` (Windows) / `/var/mqsi/` (Linux) **only when no `-w` was used**.
- Common log dir = `<NODE_WORK_DIR>\common\log\`. Node logs = `<NODE_WORK_DIR>\components\<NODE>\log\`. Per-IS logs + console (stdout/stderr) = `<NODE_WORK_DIR>\components\<NODE>\servers\<IS>\log\` and `*.txt`/`*.log` at the IS root.

Always ask the user for `<NODE_WORK_DIR>` (workflow Phase 2) rather than assuming `%ProgramData%`.

### Error logs

| OS | Path |
|---|---|
| Windows | `<INSTALL_DIR>\errors\` |
| Linux/UNIX | `/var/mqsi/errors/` |

Contains MiniDump files (Windows, BIP2111) and core dumps (Unix, BIP2060).

### Windows Event Viewer
```
eventvwr
```
**Export a time window, not the full log.** Default policy: 30 minutes before the **earliest** occurrence through 30 minutes after the **latest** occurrence. Full-log exports are huge, slow to upload, and bury the relevant entries. If occurrences form separate clusters far apart in time, export one window per cluster instead of one giant span. `wevtutil` requires the query timestamps in **UTC** (the snippet converts local time for you).

GUI: select the Application (or System) log → **Filter Current Log** → set **Logged** to a custom range (From = earliest − 30 min, To = latest + 30 min) → OK → **Save Filtered Log File As** → `.evtx`.

PowerShell (filters at export time):
```powershell
$earliest = Get-Date "<YYYY-MM-DD HH:MM:SS>"   # earliest occurrence, local
$latest   = Get-Date "<YYYY-MM-DD HH:MM:SS>"   # latest occurrence, local (= earliest if only one)
$from = $earliest.AddMinutes(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$to   = $latest.AddMinutes(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$q = "*[System[TimeCreated[@SystemTime>='$from' and @SystemTime<='$to']]]"
wevtutil epl Application eventlog_application.evtx /q:"$q" /ow:true
wevtutil epl System      eventlog_system.evtx      /q:"$q" /ow:true
```

### Linux syslog
```bash
# Entries filtered for ACE
grep -i mqsi /var/log/syslog
```

### Exception log / Activity log
Available via the ACE Web UI (Integration Node admin UI or standalone server UI).

---

## 5. ACELogAnalyser

```bash
java -Xmx2000m -jar <INSTALL_DIR>/server/tools/aceloganalyser.jar \
  -z <functionality> \
  -f <inputFile1>,<inputFile2> \
  -d <outputDirectory>
```

**GUI mode** (no arguments):
```bash
java -Xmx2000m -jar <INSTALL_DIR>/server/tools/aceloganalyser.jar
```

**Functionality modes:**

| Mode | Purpose |
|---|---|
| `traceAnalysis` | Performance analysis from trace files; generates IBM Support-ready report |
| `splitTraceThreads` | Splits trace per thread |
| `extractUserTrace` | Extracts user trace from service trace files |
| `extractSyslogAndErrorEntries` | Extracts syslog and error entries |
| `activityLogAnalysis` | Analyzes activity logs; generates FLOW_* accounting reports |
| `flowcontaining` | Extracts flow-containing information |
| `splitAccountingAndStatsCSVFiles` | Splits accounting/stats CSV per message flow |
| `parserManagerAnalysis` | Analyzes memory and PARSER logs |

---

## 6. Startup & Environment Verification

```bash
# Verify environment, ODBC, MQ, permissions
mqsicvp <NODE>

# Check component properties
mqsireportproperties <NODE> -e <IS> -o ComIbmJVMManager -a

# Check/fix JVM options
mqsireportproperties <NODE> -e <IS> -o ComIbmJVMManager -n jvmSystemProperty
mqsichangeproperties <NODE> -e <IS> -o ComIbmJVMManager -n jvmSystemProperty -v ""

# List deployed resources
mqsilist <NODE>
mqsilist <NODE> -e <IS>
```

**TMPDIR check (Linux/Unix):** each IS needs ≥50 MB in `/tmp` (or `$TMPDIR`). Low space → BIP4512 with `java.lang.NoClassDefFoundError`.

**Semaphore permissions (Unix):** all ACE user IDs must share the same primary group. BIP2228 = semaphore issue.

**Key startup BIP codes:**

| Code | Meaning |
|---|---|
| BIP2111 | Windows MiniDump generated - crash |
| BIP2060 | Unix integration server terminated unexpectedly |
| BIP2228 | Unix semaphore permissions (primary group mismatch) |
| BIP4512 | TMPDIR space or access issue |
| BIP8875 | Component verification failure - check Event Viewer / syslog |
| BIP8048 / BIP8059 | Oracle XA global coordination - start queue manager first with `-si` |
| BIP2275 | Policy connection properties invalid (only caught at deploy/start, not create) |

---

## 7. Database Diagnostics

### Db2
```bash
db2 connect to <DATABASE>
db2 list database directory
mqsireportdbparms <NODE> -e <IS> -n <datasource>

# Bind procedures (required for ODBC)
# Linux/UNIX
db2 bind ~/sqllib/bnd/@db2cli.lst grant public
# Windows
db2 bind x:\sqllib\bnd\@db2cli.lst grant public
```

**XA coordination (global transactions with MQ):**
- Configure `XAResourceManager` stanza in `qm.ini` (Linux) or IBM MQ Explorer (Windows)
- `ThreadOfControl=THREAD` required
- Db2 `maxappls` / `maxagents` must be sufficient: formula = 5 (internal) + 1 per DB access node per IS thread
- SQL1040N = maxappls exceeded
- `LD_ASSUME_KERNEL` must be unset on Linux for globally coordinated flows

**AIX TCP/IP for Db2 (SQL1224N):**
```bash
db2set DB2COMM=tcpip
db2stop && db2start
```

### GSKit library conflicts (Db2 + MQ SSL - SQL10013N / BIP2322E)
Place MQ's GSKit directory at the front of the library path:

```bash
# AIX
export LIBPATH=<MQ_INSTALL>/gskit8/lib64:$LIBPATH

# Linux
export LD_LIBRARY_PATH=<MQ_INSTALL>/gskit8/lib64:$LD_LIBRARY_PATH
```

Add to `mqsiprofile` or the IS startup script.

### Oracle
- `LD_LIBRARY_PATH`: put `/lib64` before Oracle library path to avoid `libgcc` conflicts
- Fixed-length `CHAR` vs `VARCHAR2` comparison issues require padding in ESQL

### Informix
Required environment variables: `INFORMIXDIR`, `INFORMIXSERVER`, `INFORMIXSQLHOSTS`, `TERMCAP`, `TERM`, `LIBPATH`
```bash
export SQLHOSTS=$INFORMIXDIR/etc/sqlhosts
```
Database must have transaction logging enabled (`create database with log`).

---

## 8. Performance Diagnostics

```bash
# Check tcpnodelay / Nagle algorithm setting
mqsireportproperties <NODE> -e <IS> -o ComIbmSocketConnectionManager -n tcpnodelay

# Disable Nagle algorithm for HTTP/HTTPS (small message performance)
mqsichangeproperties <NODE> -e <IS> -o ComIbmSocketConnectionManager -n tcpnodelay -v true
```

User trace at `debug` level + ACELogAnalyser `traceAnalysis` mode is the primary performance collection path.

---

## 9. Abend & Dump Files

Check proactively - abend files never occur during normal operation:

```bash
# Windows
dir "<INSTALL_DIR>\errors\"

# Linux/UNIX
ls /var/mqsi/errors/
```

- Windows: MiniDump files → BIP2111 in event log
- Unix: core dump files → BIP2060 in syslog
- Causes: out-of-memory, invalid instruction from user-defined extension, unrecoverable internal error

Contact IBM Support immediately if abend files are found.

---

## 10. IBM Support Case Submission Checklist

**Mandatory for every case:**
- [ ] `mqsiservice -v` output
- [ ] ACE Data Collector output archive
- [ ] Node + per-affected-IS logs from `<NODE_WORK_DIR>\components\<NODE>\log\` and `...\servers\<IS>\log\`, plus console/stdout `*.txt`/`*.log` at the IS root
- [ ] Problem description: what happened, expected vs actual, exact timing
- [ ] OS details: Windows version + service pack / `uname -a` (Linux)

**Include as applicable:**
- [ ] User trace files (debug level for crashes/performance, normal for functional)
- [ ] Service trace files (only if IBM requests or startup failure)
- [ ] Windows Event Viewer export (.evtx) or syslog excerpts - windowed to earliest−30 min → latest+30 min, not the full log
- [ ] Abend/dump files from `errors/` directory
- [ ] BAR file for the failing application
- [ ] Project interchange (generated via `mqsipackagebar`)
- [ ] ODBC trace output (for database issues)
- [ ] `mqsicvp` output (for startup/environment issues)
- [ ] ACELogAnalyser report (`traceAnalysis` mode)
- [ ] Any shared-classes configuration
- [ ] MQ FFST files (`.fdc` from MQ errors directory) - if MQ is involved
- [ ] Db2 `db2dialog.log` and table definitions - if database is involved
- [ ] Sample message that triggered the issue

**Compression:**
- Unix: `tar -czf support_bundle.tar.gz ACE_SupportCase_<NodeName>_<YYYYMMDD>/`
- Windows: standard zip/7zip of the output folder
