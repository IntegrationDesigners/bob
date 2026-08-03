# ACE Support Case Skill - Authoritative Workflow

Read this file before starting any support case session. It defines the exact sequence, branching logic, and questions to ask at each phase.

---

## Phase 1: Triage

**Goal:** Understand the problem before touching any tooling. Be conversational - one or two questions at a time. Do not front-load everything.

### Step 1 - Open with the basics

Ask only these two things first:

```
What is happening exactly? Describe the problem as you see it.
Are there any visible error codes, BIP messages, or abend files?
```

### Step 2 - Follow up based on the answer

Ask follow-up questions one topic at a time, in this order, only for what has not been answered yet:
- **When?** - date and approximate time (needed to scope log extraction)
- **Reproducible?** - yes/no; if yes, what triggers it?
- **Where?** - integration node name, integration server name(s) affected; or is this a standalone integration server?
- **What changed?** - any deployments, config changes, patches, or OS updates before this started?

### Step 3 - Classify

Classify in two levels: the high-level category sets *how* you collect; the sub-type picks the exact commands.

**First, the high-level category:**

| Category | What it looks like | How you collect |
|---|---|---|
| Functional | Something is broken: errors, abends, crashes, wrong output, failed deploys, DB/SSL errors | Reactive - gather the artifacts the failure already left behind |
| Performance | It runs, but badly: high CPU/memory, poor throughput, latency | Proactive - start trace at debug, reproduce, capture resource use, run ACELogAnalyser |
| General / unknown | Symptoms unclear or mixed | Treat as both |

**Then, for a Functional problem, the sub-type** (Performance is its own path, no sub-type):

| Functional sub-type | Key indicators |
|---|---|
| Crash / abend | Process stops, BIP2111 (Windows), BIP2060 (Unix), abend files found |
| Message flow | Wrong output, messages stuck, flow behaving unexpectedly |
| Deployment / start-up | Node/IS fails to start, BIP8875-range errors, deploy fails |
| Database / ODBC | ODBC errors, SQL codes, database connectivity |
| SSL / TLS / GSKit | Certificate errors, SSL handshake failure, SQL10013N / BIP2322E |

**Internal C++ class names are clues, not facts.** Names in `.Abend` stack frames or loaded modules (e.g. `ImbDatabaseInputNode`, `imbdfsql.lil`) hint at the area but are **not** authoritative palette node types or database vendors. Treat them as leads to confirm - ask the user for the actual palette node type (and DB vendor) before naming either in the case description. Do not, e.g., report a "DatabaseInput node" or "Db2" purely because a frame or module said so.

---

## Phase 2: Runtime Access Check

Ask:
```
Do you have direct access to the ACE runtime environment (can you run commands on the server)?
```

**Branch A - Have access:**
1. Ask: `What is the value of MQSI_BASE_FILEPATH?` (or `echo $MQSI_BASE_FILEPATH` / `echo %MQSI_BASE_FILEPATH%`) - this is the **install** dir.
2. Ask: `What OS is the ACE runtime on? (Windows / Linux / AIX / OCP)`
3. Ask: `Is this an integration node setup, or a standalone integration server?`
4. Ask: `What is the node's work-data root - the directory given to mqsicreatebroker -w?` This is `<NODE_WORK_DIR>` and it holds `components\<NODE>\...` and `common\log\`. **Do not assume `%ProgramData%\IBM\MQSI\`** - it is configurable per site (e.g. `D:\IBM\mqsi\Nodes`). `MQSI_WORKPATH` is the registry/global config root, not necessarily the data path. If unknown, it can be read from `mqsilist`/the service definition, but just ask.
5. Create the output folder: `ACE_SupportCase_<NodeName>_<YYYYMMDD>` in the current working directory
6. Run all commands directly and place outputs in this folder

**Branch B - No access (must generate scripts for user):**
1. Ask the same questions (OS, node vs standalone, and the `<NODE_WORK_DIR>` work-data root from `mqsicreatebroker -w`)
2. Generate a shell script (`.sh` or `.bat`) with all commands pre-filled
3. Instruct the user to run it from an ACE Console / sourced profile and share the output
4. Provide the output folder structure they should create

---

## Phase 3: Baseline Collection (always)

Run regardless of problem type.

**ACE commands require the ACE environment - always remind the user:**
- **Windows:** Use the **ACE Console** (Start menu → IBM App Connect Enterprise → ACE Console). A regular Command Prompt or PowerShell will not have the ACE commands available.
- **Linux/AIX:** Source the profile first before running any ACE command:
  ```bash
  . /opt/ibm/ace-<version>/server/bin/mqsiprofile
  # example: . /opt/ibm/ace-13/server/bin/mqsiprofile
  ```

```bash
# Step 1: System info
mqsiservice -v > ACE_SupportCase_<NODE>_<YYYYMMDD>/mqsiservice_v.txt

# Step 2: ACE Data Collector
# Check if bundled (ACE >= v11.0.0.8)
ls "$MQSI_BASE_FILEPATH/server/bin/aceDataCollector.sh"   # Unix
dir "%MQSI_BASE_FILEPATH%\server\bin\aceDataCollector.bat" # Windows

# Run for integration node:
$MQSI_BASE_FILEPATH/server/bin/aceDataCollector.sh -b <NODE>
# Run for specific IS:
$MQSI_BASE_FILEPATH/server/bin/aceDataCollector.sh -b <NODE> -e <IS>
# Run for standalone IS:
$MQSI_BASE_FILEPATH/server/bin/aceDataCollector.sh -w <WORKDIR>

# Output lands in current directory as ACE_Data_Collector_<timestamp>_<type>
# Move it into the support folder:
mv ACE_Data_Collector_* ACE_SupportCase_<NODE>_<YYYYMMDD>/
```

**Step 3: Node and per-IS console logs (always - the Data Collector does not always capture these).**
Copy the on-disk logs from the node's work-data root (`<NODE_WORK_DIR>` = the `mqsicreatebroker -w` value from Phase 2):

```bash
# Node-level logs
#   Windows: <NODE_WORK_DIR>\components\<NODE>\log\
#   Linux:   <NODE_WORK_DIR>/components/<NODE>/log/

# For EACH affected integration server:
#   per-IS logs:           <NODE_WORK_DIR>\components\<NODE>\servers\<IS>\log\
#   console / stdout-stderr: any *.txt / *.log at the IS root <NODE_WORK_DIR>\components\<NODE>\servers\<IS>\

# Windows example
xcopy /E /I "<NODE_WORK_DIR>\components\<NODE>\log"                 "ACE_SupportCase_<NODE>_<YYYYMMDD>\logs\node\"
xcopy /E /I "<NODE_WORK_DIR>\components\<NODE>\servers\<IS>\log"    "ACE_SupportCase_<NODE>_<YYYYMMDD>\logs\servers\<IS>\"
copy        "<NODE_WORK_DIR>\components\<NODE>\servers\<IS>\*.txt"  "ACE_SupportCase_<NODE>_<YYYYMMDD>\logs\servers\<IS>\"
copy        "<NODE_WORK_DIR>\components\<NODE>\servers\<IS>\*.log"  "ACE_SupportCase_<NODE>_<YYYYMMDD>\logs\servers\<IS>\"

# Linux example
cp -r "<NODE_WORK_DIR>/components/<NODE>/log/."              "ACE_SupportCase_<NODE>_<YYYYMMDD>/logs/node/"
cp -r "<NODE_WORK_DIR>/components/<NODE>/servers/<IS>/log/." "ACE_SupportCase_<NODE>_<YYYYMMDD>/logs/servers/<IS>/"
cp    "<NODE_WORK_DIR>"/components/<NODE>/servers/<IS>/*.{txt,log} "ACE_SupportCase_<NODE>_<YYYYMMDD>/logs/servers/<IS>/" 2>/dev/null
```

For a **standalone** integration server, there is no `components\<NODE>\` layer - use `<WORKDIR>\log\` and the `*.txt`/`*.log` at `<WORKDIR>\`.

**If ACE < v11.0.0.8:** Direct user to https://www.ibm.com/support/pages/node/886323 to download `aceDataCollector.sh` (Unix) or `aceDataCollector.bat` (Windows) first.

**OCP containers:**
```bash
oc rsh <ace-pod-name>
. /opt/ibm/ace-<version>/server/bin/mqsiprofile
cd /home/aceuser
aceDataCollector.sh -w /home/aceuser/ace-server

# From a new terminal:
oc rsync <POD_NAME>:/home/aceuser/ACE_Data_Collector_<timestamp>_SIS ./ACE_SupportCase_<NODE>_<YYYYMMDD>/
```

---

## Phase 4: Problem-Specific Diagnostics

Execute the steps for the classified category. **Functional** problems (4b, 4d-4g) are about gathering what the failure already produced; **Performance** (4c) is about capturing a reproduction. 4a runs for everything. Sections can overlap - collect all that apply.

### 4a. All problems - check for abend files

```bash
# Windows
dir "<INSTALL_DIR>\errors\"

# Linux/UNIX
ls /var/mqsi/errors/
```

If abend files exist: include them in the bundle and flag this to IBM as high priority.

### 4b. Crash / Abend

In addition to Phase 3 and 4a:

**Event Viewer export = a time window, NOT the full log.** Full exports are huge, slow to
share, and bury the signal. Default policy: **30 min before the earliest occurrence → 30 min
after the latest occurrence.** If the occurrences fall into separate clusters far apart in
time (e.g. a crash this morning and one last week), export **one window per cluster** rather
than one giant span. `wevtutil` requires the query timestamps in **UTC** - the snippet below
converts local time for you.

```powershell
# Bound the window to the occurrence cluster (use the timestamps collected in Phase 1).
$earliest = Get-Date "<YYYY-MM-DD HH:MM:SS>"   # earliest occurrence (local time)
$latest   = Get-Date "<YYYY-MM-DD HH:MM:SS>"   # latest occurrence  (local time); = earliest if only one
$from = $earliest.AddMinutes(-30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$to   = $latest.AddMinutes(30).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$q = "*[System[TimeCreated[@SystemTime>='$from' and @SystemTime<='$to']]]"
wevtutil epl Application ACE_SupportCase_<NODE>_<YYYYMMDD>\eventlog_application.evtx /q:"$q" /ow:true
wevtutil epl System      ACE_SupportCase_<NODE>_<YYYYMMDD>\eventlog_system.evtx      /q:"$q" /ow:true
# For multiple clusters, re-run with different $earliest/$latest and a suffixed file name.

# GUI equivalent: eventvwr → Application (or System) log → Filter Current Log →
#   "Logged" = Custom range, From = earliest−30 min, To = latest+30 min → OK →
#   Save Filtered Log File As → eventlog_application.evtx
```
```bash
# Linux: grab syslog across the same earliest−30 → latest+30 window
awk -v s="<earliest occurrence minus 30 min>" -v e="<latest occurrence plus 30 min>" \
  '$0>=s && $0<=e' /var/log/syslog > ACE_SupportCase_<NODE>_<YYYYMMDD>/syslog_excerpt.txt
# (or, if exact timestamps are awkward, grep a generous window around the crash lines)
```

**Do NOT collect MQ FFST (`.fdc`) by default.** MQ is not assumed to be involved in a crash - pre-collecting MQ diagnostics is collecting for an unclassified vector. Gather MQ FFST only if MQ is actually in play (the flow uses MQ nodes / the abend implicates MQ), under the gated checklist item `MQ FFST files (.fdc …) - if MQ is involved` in `diagnostics_guide.md` §10.

### 4c. Performance

```bash
# 1. Check Nagle/tcpnodelay setting
mqsireportproperties <NODE> -e <IS> -o ComIbmSocketConnectionManager -n tcpnodelay

# 2. Collect user trace at debug level
#    Start trace, reproduce the slow behaviour, stop trace
mqsichangetrace <NODE> -u -e <IS> -l debug
# ... wait for user to reproduce ...
mqsichangetrace <NODE> -u -e <IS> -l none

# 3. Copy user trace files (from the node work-data root, NOT assumed %ProgramData%)
# Windows: <NODE_WORK_DIR>\common\log\<NODE>.<IS>.userTrace.*.txt
#          (only %ProgramData%\IBM\MQSI\common\log\ when the node was created without -w)
# Linux:   <NODE_WORK_DIR>/common/log/<NODE>.<IS>.userTrace.*.txt
#          (default /var/mqsi/common/log/ when created without -w)

# 4. Run ACELogAnalyser on trace files
java -Xmx2000m -jar <INSTALL_DIR>/server/tools/aceloganalyser.jar \
  -z traceAnalysis \
  -f <NODE>.<IS>.userTrace.0.txt,<NODE>.<IS>.userTrace.1.txt \
  -d ACE_SupportCase_<NODE>_<YYYYMMDD>/loganalyser_output/

# 5. Activity logs (from Web UI → download CSV) - include if available
```

**Check for trace wrapping:** if the first and last timestamps in the trace are closer together than the reproduction window, the trace wrapped and data was lost. Increase trace file size with `mqsichangetrace` and re-collect.

### 4d. Message Flow

```bash
# 1. User trace at normal level
mqsichangetrace <NODE> -u -e <IS> -l normal
# ... reproduce ...
mqsichangetrace <NODE> -u -e <IS> -l none

# 2. Export Windows Event Viewer (or syslog excerpt for Linux) - 30 min before / 30 min
#    after the event only, not the full log. See §4b for the wevtutil /q time-window command.

# 3. Project interchange - headless BAR packaging
mqsipackagebar -w <WORKSPACE_DIR> -a <APPLICATION_NAME> -o ACE_SupportCase_<NODE>_<YYYYMMDD>/<APP>.bar

# If multiple applications:
mqsipackagebar -w <WORKSPACE_DIR> -a <APP1> -a <APP2> -o ACE_SupportCase_<NODE>_<YYYYMMDD>/bundle.bar
```

Include any shared-classes configuration if relevant.

### 4e. Deployment / Start-up Failure

```bash
# 1. Environment verification
mqsicvp <NODE> > ACE_SupportCase_<NODE>_<YYYYMMDD>/mqsicvp_output.txt 2>&1

# 2. Check JVM properties
mqsireportproperties <NODE> -e <IS> -o ComIbmJVMManager -n jvmSystemProperty

# 3. List deployed resources
mqsilist <NODE> -e <IS>

# 4. Service trace (captures startup sequence)
#    Must start trace, then attempt to start the node/IS
mqsichangetrace <NODE> -t -b -l debug
# start the node/IS
mqsichangetrace <NODE> -t -b -l none

# 5. Event viewer / syslog (startup BIP codes appear here) - windowed export only:
#    30 min before / 30 min after the failed start. See §4b for the wevtutil /q command.

# 6. Include the BAR file that failed to deploy
```

**Check TMPDIR (Linux/Unix):** each IS needs ≥50 MB in `/tmp`. BIP4512 = TMPDIR issue.

### 4f. Database / ODBC

**Inventory the DSN first - do NOT assume a vendor.** Loaded modules or stack frames are not proof of which database is in play. Identify the vendor(s) from the DSN → driver → server mapping before running any vendor-specific tool.

```bash
# === Step 1: vendor-neutral DSN inventory (always first) ===

# ACE-side DSN credentials / list (all DSNs)
mqsireportdbparms <NODE> -n "*" > ACE_SupportCase_<NODE>_<YYYYMMDD>/mqsireportdbparms_all.txt

# OS-side DSN → driver → server mapping
# Windows (export both system + driver registries):
reg export "HKLM\SOFTWARE\ODBC\ODBC.INI"     ACE_SupportCase_<NODE>_<YYYYMMDD>\odbc_ini.reg
reg export "HKLM\SOFTWARE\ODBC\ODBCINST.INI" ACE_SupportCase_<NODE>_<YYYYMMDD>\odbcinst_ini.reg
# Linux:
cat $ODBCSYSINI/odbc.ini $ODBCSYSINI/odbcinst.ini > ACE_SupportCase_<NODE>_<YYYYMMDD>/odbc_ini.txt

# === Step 2: environment + ODBC verification ===
mqsicvp <NODE>                       # includes an ODBC connectivity check
mqsireportdbparms <NODE> -e <IS> -n <DATASOURCE_NAME>   # drill into the specific DSN

# === Step 3: ODBC trace during error reproduction ===
# Windows: ODBC Administrator → Tracing tab → Start Tracing Now
# Linux: set Trace=yes in $ODBCSYSINI/odbcinst.ini

# === Step 4: user trace (normal) during reproduction ===
mqsichangetrace <NODE> -u -e <IS> -l normal
# ... reproduce ...
mqsichangetrace <NODE> -u -e <IS> -l none
```

**Step 5 - vendor-specific, ONLY after the DSN inventory identifies the vendor:**
```bash
# Db2:    db2level ; db2 get db cfg for <DATABASE> | grep -i maxappls ; collect db2dialog.log ; Db2 XA config
# Oracle: check libclntsh / libgcc availability and GSKit ordering (see §4g)
# SQL Server: confirm the driver named in odbc_ini.reg; collect the driver version
# Informix: $INFORMIXDIR / $INFORMIXSERVER env
```

Include: ODBC trace output, the DSN inventory above, database table definitions (DDL), and any vendor log (e.g. Db2 `db2dialog.log`) only for the vendor actually identified.

### 4g. SSL / TLS / GSKit

```bash
# 1. Check library path ordering
echo $LD_LIBRARY_PATH    # Linux
echo $LIBPATH            # AIX
# MQ GSKit path must come BEFORE any Db2 or Oracle library paths
# Fix: export LD_LIBRARY_PATH=<MQ_INSTALL>/gskit8/lib64:$LD_LIBRARY_PATH

# 2. User trace (normal)
mqsichangetrace <NODE> -u -e <IS> -l normal
# ... reproduce ...
mqsichangetrace <NODE> -u -e <IS> -l none

# 3. Check policy/keystore configuration
mqsireportproperties <NODE> -e <IS> -o ComIbmMQTTSourceConnector -a
# (adapt object name to actual node type)
```

---

## Phase 5: Analysis & Case Generation

### Step 1 - Self-assess

Before generating anything, review what was collected:
- Any BIP codes pointing to a known root cause?
- Trace entries showing exactly where the failure occurs?
- Event log entries matching the problem timestamp?
- Known patterns (GSKit library ordering, TMPDIR space, semaphore permissions)?

Note your observations - they go into the case description.

**Before naming a node type or DB vendor in the case:** if your evidence is an internal C++ class name or `.lil`/module name from an abend stack (`ImbDatabaseInputNode`, `imbdfsql.lil`, etc.), that is a clue - confirm the actual **palette** node type and the actual database vendor with the user first. Don't state "DatabaseInput node" / "Db2" in the submission on the strength of a stack frame or loaded module alone.

### Step 2 - Run ACELogAnalyser (if trace files collected)

```bash
java -Xmx2000m -jar <INSTALL_DIR>/server/tools/aceloganalyser.jar \
  -z traceAnalysis \
  -f <traceFile1>,<traceFile2> \
  -d ACE_SupportCase_<NODE>_<YYYYMMDD>/loganalyser_output/
```

### Step 3 - Generate the IBM case submission

Write to `ACE_SupportCase_<NODE>_<YYYYMMDD>/ibm_case_submission.txt` AND display in chat so the user can copy-paste directly into the IBM case portal.

Use this template, filled with all collected information:

```
=== IBM SUPPORT CASE SUBMISSION ===

CASE TITLE:
[ACE <version>] <symptom in 10 words or less> on <node/IS name> - <OS>
Example: [ACE 13.0.7.0] Integration server crash on ACENODE/default - Windows Server 2022

PRODUCT: IBM App Connect Enterprise
PRODUCT AREA: ACE
PRODUCT VERSION: <exact version from mqsiservice -v, e.g. 13.0.7.0>

SEVERITY:
<Choose one and explain briefly>
  1 - Critical business impact (production or service is down)
  2 - Significant impact (any system is down)
  3 - Minor business impact
  4 - Minimal impact (how-to / minor problem)
Selected: <N> - <one-line justification>

OPERATING SYSTEM: <OS name + version, e.g. Windows Server 2022 / RHEL 9.2>

BUSINESS IMPACT:
<One to two sentences: what is blocked, degraded, or at risk as a result of this problem>

DESCRIPTION:

Problem:
<What error code, message, or behaviour is observed. Be specific - include BIP codes, SQL codes, exact error text.>

Steps to reproduce:
1. <step>
2. <step>
3. <step>
<Include: "Tried restarting: yes/no", "Collected trace: yes", "Ran aceDataCollector: yes">

Suggestions / answers sought:
<What do you want IBM to provide: workaround / root cause analysis / fix / explanation / how-to>

Expected outcome:
<What should have happened instead of what was observed>

=== DIAGNOSTICS ATTACHED ===
- mqsiservice -v output
- ACE Data Collector archive (ACE_Data_Collector_<timestamp>_<type>)
<add any of the following that apply>
- User trace (<normal|debug>)
- Service trace
- Windows Event Viewer export (±30 min around the event, not the full log)
- Abend / dump files
- BAR file / project interchange
- ODBC trace
- ACELogAnalyser report
- mqsicvp output
```

### Step 4 - Compress and hand over

```bash
# Unix
tar -czf ACE_SupportCase_<NODE>_<YYYYMMDD>.tar.gz ACE_SupportCase_<NODE>_<YYYYMMDD>/

# Windows - zip the ACE_SupportCase_<NODE>_<YYYYMMDD> folder
```

Confirm to the user: the `.txt` file goes into the IBM case description field; the archive goes as an attachment.

---

## Output Folder Structure

```
ACE_SupportCase_<NodeName>_<YYYYMMDD>/
├── ibm_case_submission.txt          ← copy-paste into IBM case portal
├── case_description.txt             ← internal notes / observations
├── mqsiservice_v.txt
├── ACE_Data_Collector_<timestamp>_<type>/   ← from aceDataCollector
├── traces/
│   ├── <NODE>.<IS>.userTrace.0.txt
│   ├── <NODE>.<IS>.userTrace.1.txt
│   └── <NODE>.<IS>.trace.0.txt             ← service trace if collected
├── logs/
│   ├── eventlog_application.evtx            ← Windows (windowed export)
│   ├── syslog_excerpt.txt                   ← Linux
│   ├── node/                                ← <NODE_WORK_DIR>\components\<NODE>\log\
│   └── servers/<IS>/                        ← per-IS log\ + console *.txt/*.log
├── errors/
│   └── <abend/dump files>
├── applications/
│   ├── <APP>.bar
│   └── mqsipackagebar_output.txt
├── mqsicvp_output.txt                        ← startup issues
├── mqsireportdbparms_output.txt             ← database issues
├── odbc_trace.log                            ← database issues
└── loganalyser_output/                       ← ACELogAnalyser results
```
