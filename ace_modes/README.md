# ACE Bob Modes

This directory contains specialized Bob modes for IBM App Connect Enterprise (ACE) development and operations. These modes provide expert assistance for ACE integration projects.

## Available Modes

### 📄 ACE README (`ace-readme`)

**Purpose:** Generates comprehensive technical README documentation for IBM ACE applications and adapters.

**When to use:**
- You need to document an existing ACE application or adapter
- You want to create technical documentation for developers, architects, or operations teams
- You need a README that can be committed alongside source code

**What it does:**
- Reads ACE source files (.msgflow, .esql, .java)
- Produces detailed technical documentation with:
  - Application overview and architecture
  - Flow-by-flow analysis with Mermaid diagrams
  - Configuration tables (TEST vs PROD)
  - MQ queue definitions
  - REST API endpoints (if applicable)
  - Operational considerations
- Uses clickable file:line references throughout
- Stays descriptive, not evaluative (pure documentation, not code review)

**Key features:**
- Automatic ACE version detection
- Mermaid flow diagrams
- Comprehensive configuration documentation
- Mixed audience writing (developers, architects, ops)

**Location:** `ace-readme/`

---

### 🏗️ ACE Flow Builder (`ace-flow-builder`)

**Purpose:** Designs and generates IBM ACE v13 message flows - complete .msgflow XML, ESQL files, and test plans.

**When to use:**
- You need to create a new ACE message flow
- You want to build a REST API from an OpenAPI/Swagger spec
- You need ESQL code for compute nodes
- You want to test an ACE flow with curl commands and test cases

**What it does:**
- Identifies IBM ACE patterns from your description
- Works in two modes:
  - **Iterative:** Quick v0.1 generation with refinement in turns (for known patterns)
  - **Thorough:** Full requirements gathering and design confirmation (for novel flows)
- Generates complete, ready-to-import ACE projects:
  - .msgflow XML in ACE Toolkit format
  - ESQL compute modules with proper BROKER SCHEMA structure
  - .project and application.descriptor files
  - Deployment properties and ibmint commands
- Produces structured test plans with curl commands
- Can validate builds (compile, deploy, run test messages)

**Key features:**
- Supports HTTP, MQ, File, Database, Kafka, and 93+ IBM ACE patterns
- REST API track for OpenAPI/Swagger-driven development
- Iterative refinement with flow_state.md tracking
- Build validation (Level 1: compile, Level 2: deploy, Level 3: run)
- Searches your filesystem for verified node attributes

**Location:** `ace-flow-builder/`

---

### 🎨 ACE Flow Designer (`ace-flow-designer`)

**Purpose:** Interactive requirements gathering and flow design for ACE message flows, producing detailed specifications before implementation.

**When to use:**
- You're starting a new ACE integration project
- You need to gather requirements from stakeholders
- You want a detailed design specification before coding
- You need to plan complex multi-flow integrations

**What it does:**
- Conducts structured interviews to gather requirements
- Produces comprehensive design specifications including:
  - Business context and integration requirements
  - Flow design with Mermaid diagrams
  - Node-by-node specifications
  - ESQL logic outlines
  - Error handling strategy
  - Testing approach
- Creates a START_PROMPT for ace-flow-builder to implement the design

**Key features:**
- Structured interview process
- Comprehensive design documentation
- Seamless handoff to ace-flow-builder
- Supports both simple and complex integrations

**Location:** `ace-flow-designer/`

---

### 🔍 ACE Review (`ace-review`)

**Purpose:** Senior-level code review for ACE message flows, ESQL, Java compute nodes, and MQ configuration.

**When to use:**
- You want to review ACE code quality
- You need to check for common mistakes and best practices
- You want security, performance, or error handling analysis
- You need a structured review report with prioritized findings

**What it does:**
- Reviews .msgflow files for flow design, node configuration, and wiring
- Reviews .esql files for coding patterns, performance, and correctness
- Reviews Java compute nodes for thread safety and performance
- Reviews deployment properties and MQ configuration
- Produces structured reports with:
  - Findings grouped by topic (Security, Reliability, Performance, etc.)
  - Severity ratings (Critical, High, Medium, Low)
  - Specific recommendations with file:line references
  - Strengths and areas for improvement
  - Overall assessment rating

**Review Levels:**
- **Level 0 (Peek):** Single focus area - quick scan, key findings only
- **Level 1 (Short):** ESQL + flow design + Java + common mistakes (default)
- **Level 2 (Intermediate):** Level 1 + error handling review
- **Level 3 (Extended):** Level 2 + security + performance/monitoring

**Key features:**
- Automatic ACE version detection
- Compute mode validation (cross-checks mode vs. ESQL behavior)
- Promoted property analysis (deployment descriptor vs. node defaults) - a stale node default that the descriptor correctly overrides is recorded as a remark, not a rated finding
- Incremental git scoping - on a repeat review, diffs against the prior review report and reviews only what changed
- Trust-boundary severity - side effects executed via subflows, shared libraries, or PROPAGATE TO LABEL are attributed to where they run and rated by blast radius, with verified-from-source separated from inferred
- Correct handling of Toolkit-generated ESQL stubs (CopyMessageHeaders / CopyEntireMessage are never mis-flagged as hand-rolled duplicates)
- Dark-mode-legible Mermaid diagrams (fill + stroke + color on every style line)
- Mixed audience reporting (developers, architects, ops)
- Constructive, actionable findings

**Custom rules:** the mode reads `custom-rules/rules.md`. Out of the box it is empty and the review runs exactly as described. Add your organisation's house standards there - accepted deviations (e.g. shared log prefixes, PROPAGATE-finalisation exceptions, MQ settings on the default queue), central framework libraries to treat as trusted, and severity overrides. A rule that allows something the review would normally flag is still surfaced as an accepted deviation (a remark), never silently dropped.

**Location:** `ace-review/`

---

### 🛡️ CVE Analysis (`cve-analysis`)

**Purpose:** Practical exploitability assessment of CVEs and IBM security bulletins for IBM App Connect Enterprise **and** IBM MQ, plus the third-party components they bundle (IBM Semeru/Java, XML stacks, Jakarta Mail, embedded Node.js, Liberty in mqweb, GSKit).

**When to use:**
- A scanner or bulletin names a CVE and you need to know whether it actually matters here
- You are triaging a monthly IBM PSIRT sweep
- You need to justify patch urgency (emergency vs the normal maintenance window) to a security team
- Someone asks "are we affected by CVE-XXXX-NNNNN?"

**What it does:**
- Separates **affected** from **exploitable**. IBM marks a product affected whenever it bundles a vulnerable component, which is an inventory statement, not a risk statement
- Places every CVE in one of three exposure classes and defends the placement:
  - **Direct runtime exposure** - reachable from an external interface (HTTP/SOAP input, MQ channel, REST API, web console)
  - **Indirect / conditional exposure** - reachable only through customer code or an enabled feature
  - **Runtime inheritance** - bundled but not reachable from untrusted input
- Researches the IBM bulletin, the upstream advisory (Apache, Eclipse, OpenSSL, GHSA, Oracle CPU), and NVD/MITRE, rather than restating the CVE description
- Maps the vulnerable component to where it actually surfaces inside ACE and MQ, with confidence flags and a "False trails" section for claims that sound right and are not
- Optionally greps the ACE projects in the workspace for real usage of the vulnerable node type, library, or listener
- Produces a deep-dive report per CVE or a triage table for a bulletin sweep, closed with a fixed-order digest (what it is, applicable, action, notes, related)

**Key features:**
- ACE and MQ assessed **separately** - they share almost no architecture, so one product's reasoning is never reused for the other
- Multi-CVE bulletins are validated per CVE, never as one bundle with five ids
- Never repeats the CVSS score as if it were the risk; CVSS scores the vulnerability in the abstract, the report scores it in context
- Conceptual and defensive only: no exploit instructions, payloads, or proof-of-concept code
- **Decision log** - every assessment is recorded with its verdict, its reasoning, and a mandatory "revisit when" trigger. A CVE that resurfaces in next quarter's scan is answered from the log rather than re-researched. Set a durable location in `custom-rules/rules.md`; the fallback inside the mode folder does not survive a re-clone

**Estate baseline (`.env`):** copy `.env.sample` to `.env` and fill in exact ACE/MQ fix-pack levels, install method (on-prem vs Certified Containers, node-managed vs standalone), co-location, and HA topology. Many bulletins resolve on form factor alone. The file is gitignored and stays on your machine; keep it current, since stale versions here mean wrong verdicts.

**Custom rules:** the mode reads `custom-rules/rules.md`, empty out of the box. Add patch-urgency thresholds and sign-off, which endpoints sit behind a WAF or gateway, which scanner produces the findings you triage, reporting requirements, and the decision-log location. Facts about the estate belong in `.env`; policy about the estate belongs here.

**Boundary:** for collecting diagnostics or opening an IBM case, use `ace-support-case` instead. If the fix level requires a version jump the estate is not on, hand off to `ace-migration`.

**Location:** `cve-analysis/`

---

### 🆘 ACE Support Case (`ace-support-case`)

**Purpose:** Walks you through collecting a complete diagnostic bundle for an IBM ACE support case (PMR / ticket), then writes a ready-to-paste IBM case submission - so IBM Support gets everything it needs the first time, with no back-and-forth.

**When to use:**
- You need to open an IBM support case / PMR / ticket for ACE
- You need to gather diagnostics for IBM
- You hit error codes such as `BIP2111` or `BIP2060`, a crash, or abend files
- You want to know what logs or information IBM needs

**What it does:**
- **Triage** - a conversational set of questions to understand the symptom, timing, scope, and recent changes, then classifies the problem (crash/abend, performance, functional, deployment, database/ODBC, SSL/TLS/GSKit, or general)
- **Runtime access check** - either runs the collection commands directly on the server, or generates a ready-to-run script for someone who has access
- **Baseline collection** - `mqsiservice -v` plus **aceDataCollector**, the single most complete automated diagnostic tool
- **Problem-specific diagnostics** - a decision tree of exactly what to gather for each problem type (event-log windows, user/service trace, ODBC trace, abend/dump files, GSKit library-ordering checks, and more)
- **Analysis and case generation** - self-assessment of the collected data and a ready-to-paste IBM case submission block (title, product, version, severity, business impact, structured description), with the bundle assembled into an `ACE_SupportCase_<NodeName>_<YYYYMMDD>/` folder, compressed and ready to attach

**Key features:**
- Distilled from IBM's ACE 13 "Troubleshooting and support" documentation; `references/manifest.csv` links the relevant IBM doc pages by URL
- The diagnostic commands must be run from an ACE Console (Windows) or after sourcing `mqsiprofile` (Linux/UNIX) - the mode generates the commands and scripts, you run them against your own environment
- Assumes ACE v11.0.0.8 or later for the bundled aceDataCollector; v12 and v13 fully supported

**Custom rules:** the mode reads `custom-rules/rules.md`, empty out of the box. Add your organisation's house trace / data-collection procedure, where your logs actually live (custom work-dirs, containers, Splunk/ELK), data-handling policy (redaction, approved upload channel), IBM entitlement (ICN, site ID, support tier, named callers), and internal governance (incident tickets, severity mapping). A custom rule that conflicts with a default step wins - the mode follows it and says so.

**Boundary:** if you want the failing code fixed rather than a case opened, use `ace-review` instead. If the assessment starts from a CVE or security bulletin, that is `cve-analysis`.

**Location:** `ace-support-case/`

---

## Mode Workflow

### Typical Development Flow

1. **Design Phase:** Use `ace-flow-designer` to gather requirements and create a detailed specification
2. **Build Phase:** Use `ace-flow-builder` to implement the design (can work directly from the designer's output)
3. **Review Phase:** Use `ace-review` to validate code quality and best practices
4. **Documentation Phase:** Use `ace-readme` to generate comprehensive technical documentation

### Quick Build Flow

For simple, well-understood patterns:
1. **Build Phase:** Use `ace-flow-builder` directly in iterative mode
2. **Review Phase:** Use `ace-review` to check the implementation
3. **Documentation Phase:** Use `ace-readme` to document the result

---

## Mode Transitions

The modes are designed to work together and will suggest transitions when appropriate:

- **ace-flow-designer** → **ace-flow-builder** (after design is complete)
- **ace-flow-builder** → **ace-review** (after implementation)
- **ace-review** → **ace-flow-builder** (to implement recommended fixes)
- **Any mode** → **ace-readme** (to generate documentation)

---

## File Structure

Each mode directory contains:
- `.bobmodes` - Mode definition file (configuration for Bob)
- `SKILL.md` - Detailed skill documentation (optional, for reference)
- `references/` - Reference files, templates, and guidelines used by the mode
- `examples/` - Example inputs and outputs (where applicable)
- `custom-rules/rules.md` - your organisation's house rules, applied on top of the built-in workflow (where applicable; empty by default)
- `.env.sample` - template for per-environment facts (where applicable). Copy to `.env` and fill in; `.env` is gitignored and must never be committed

---

## Importing Modes into Bob

There are two ways to make these ACE modes available in Bob: **Global Setup** (user-wide) and **Local Setup** (project-specific).

### Automated Import (Recommended)

Use the included PowerShell script to automatically import modes into any project:

```powershell
.\Import-BobModes.ps1 -SourcePath "D:\git\i8c_bobmodes\ace_modes" -TargetProjectPath "D:\Projects\YourProject"
```

The script will:
- Recursively scan for all `.bobmodes` files in the source directory
- Create a `.bob/custom_modes.yaml` file in your target project if it doesn't exist
- Merge modes into an existing `custom_modes.yaml` file, avoiding duplicates
- Preserve any existing custom modes in the target project

After running the script, reload your VS Code window (Ctrl+Shift+P → "Reload Window") to activate the new modes.

### Manual Setup

#### Global Setup (User-Wide)

Global setup makes modes available across all your projects. This is ideal when you work with ACE regularly across multiple projects.

**Configuration location:** Bob's global settings (typically in VS Code user settings)

**How it works:**
- Modes are defined once in your user configuration
- Available in every project you open in VS Code
- Changes to mode definitions require updating the global configuration

**When to use:**
- You work with ACE across multiple projects
- You want consistent mode availability everywhere
- You're the primary user of your development machine

**Setup steps:**
1. Open VS Code Settings (Ctrl+,)
2. Search for "Bob Custom Modes"
3. Edit the global custom modes configuration
4. Add the ACE mode definitions from the `.bobmodes` files
5. Reload VS Code window

#### Local Setup (Project-Specific)

Local setup makes modes available only within a specific project. This is the pattern used in the reference example at `D:\Projects\Lineas\.bob\custom_modes.yaml`.

**Configuration location:** `.bob/custom_modes.yaml` in your project root

**How it works:**
- Each project has its own `.bob/` directory
- The `custom_modes.yaml` file contains mode definitions specific to that project
- Modes are only available when working in that project
- The file is typically committed to version control, so team members get the same modes

**When to use:**
- You want project-specific modes
- You're working in a team and want to share mode configurations
- Different projects need different sets of modes
- You want modes versioned with your project code

**Setup steps:**
1. Create a `.bob/` directory in your project root (if it doesn't exist)
2. Create or edit `.bob/custom_modes.yaml`
3. Copy the mode definitions from the `.bobmodes` files
4. Structure the file with a `customModes:` array at the root
5. Reload VS Code window
6. Commit the `.bob/` directory to version control (optional but recommended for teams)

**Example structure:**
```
YourProject/
├── .bob/
│   └── custom_modes.yaml
├── src/
├── flows/
└── README.md
```

The `custom_modes.yaml` file follows this pattern:
```yaml
customModes:
  - slug: ace-flow-builder
    name: 🏗️ ACE Flow Builder
    description: Designs and generates IBM ACE v13 message flows
    roleDefinition: >-
      You are a senior IBM ACE integration developer...
    whenToUse: >-
      Use this mode when...
    groups:
      - read
      - - edit
        - fileRegex: (\.(msgflow|esql|...)$)
          description: ACE project files
      - command
    customInstructions: >-
      Follow this workflow...
  - slug: ace-review
    name: 🔍 ACE Review
    # ... additional mode configuration
```

### Choosing Between Global and Local

| Aspect | Global Setup | Local Setup |
|--------|-------------|-------------|
| **Scope** | All projects | Single project |
| **Configuration** | User settings | `.bob/custom_modes.yaml` |
| **Team Sharing** | No | Yes (via version control) |
| **Maintenance** | Update once for all projects | Update per project |
| **Best For** | Individual developers | Team projects |

### Verifying Installation

After importing modes (either globally or locally):

1. Reload VS Code window (Ctrl+Shift+P → "Reload Window")
2. Open Bob's mode selector
3. Look for the ACE modes with their emoji icons:
   - 📄 ACE README
   - 🏗️ ACE Flow Builder
   - 🎨 ACE Flow Designer
   - 🔍 ACE Review
   - 🛡️ ACE/MQ CVE Analysis
   - 🆘 ACE Support Case

If modes don't appear, check:
- The `.bob/custom_modes.yaml` file syntax (YAML is whitespace-sensitive)
- VS Code's Output panel for Bob-related errors
- That you've reloaded the window after making changes

---

## Getting Started

1. **Import the modes** using the automated script or manual setup (see above)
2. **Choose the right mode** based on your current task (see "When to use" sections above)
3. **Activate the mode** in Bob's mode selector
4. **Follow the mode's workflow** - each mode will guide you through its process
5. **Transition to other modes** as needed to complete your project

---

## ACE Version Support

All modes support:
- IBM ACE v11
- IBM ACE v12
- IBM ACE v13

The modes automatically detect the ACE version from project files and adjust documentation links and recommendations accordingly.

---

## Additional Resources

- **IBM ACE Documentation:** https://www.ibm.com/docs/en/app-connect
- **ACE Patterns Catalog:** Included in ace-flow-builder references
- **ESQL Style Guide:** Included in ace-flow-builder references
- **Review Guidelines:** Included in ace-review references

---

## Contributing

These modes are part of the i8c Bob Modes collection. For questions, issues, or contributions, please refer to the main repository documentation.

---

*Last Updated: August 2026*