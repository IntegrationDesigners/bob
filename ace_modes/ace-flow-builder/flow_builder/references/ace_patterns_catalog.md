---
template_version: 0.1.0
last_updated: 2026-03-16
compatible_with: ACE Flow Builder v0.1.0+
status: beta
---
# ACE Patterns Catalog

Source: https://ot4i.github.io/ace-patterns/en/repo_metadata.json
IBM official pattern library for ACE **v13** (all patterns in this catalog target ACE v13 unless explicitly marked legacy).

**Version note:** Only use patterns from `https://github.com/ot4i/ace-patterns/releases/download/v1.0.0/` - these are the v13 patterns. Older individual-repo patterns (v11/v12 era) are listed at the bottom under Legacy and should NOT be used.

**Download URL format for v13 patterns:**
`https://github.com/ot4i/ace-patterns/releases/download/v1.0.0/[PatternName].patternzip`

**Template coverage:** All 93 patterns (92 protocol/format + RAG) are ✅ extracted to `references/examples/[PatternName]/`. Each directory contains real IBM ACE v13 `.msgflow`, `.esql`, and supporting files.

Use this catalog when a user asks to build a flow - match their description to the closest pattern(s) and name it explicitly.

---

## Starter Patterns

Simple, self-contained flows with no external dependencies. Use these as the starting point when a user is new to ACE or wants the simplest possible working example.

| Pattern | Description | Example |
|---------|-------------|---------|
| HTTP Request-Reply | Receive HTTP request, compute ESQL response, reply directly | `SimpleHTTPResponse` |

### HTTP Request-Reply (REST Endpoint)

The simplest complete ACE flow. Accepts an HTTP request, runs ESQL to build a response, and replies - all within the same flow. No MQ, no external calls, no file I/O.

- **Nodes:** `ComIbmWSInput` → `ComIbmCompute` → `ComIbmWSReply`
- **Message domain:** JSON (set on input node: `messageDomainProperty="JSON"`)
- **Use when:** building a REST API endpoint that computes a response from ESQL logic
- **Key ESQL pattern:**
  ```esql
  SET OutputRoot.Properties = InputRoot.Properties;
  SET OutputRoot.HTTPResponseHeader."Content-Type" = 'application/json';
  CREATE FIELD OutputRoot.JSON.Data;
  DECLARE refOutput REFERENCE TO OutputRoot.JSON.Data;
  SET refOutput.status = 'success';
  SET refOutput.timestamp = CURRENT_TIMESTAMP;
  ```
- **Example files:** `references/examples/SimpleHTTPResponse/`
- **Deployment (standalone server):**
  ```bat
  ibmint package --input-path . --output-bar-file [FlowName].bar --project [FlowName]
  IntegrationServer --work-dir work_dir --name [ServerName] --admin-rest-api 7600 --http-port-number 7800 --console-log
  ```
- **Test endpoint:** `http://localhost:7800/[url-path]`

---

## Protocol Transformation Patterns
**Category:** `com.ibm.dev.pattern.protocoltransformation`
**Doc:** https://ot4i.github.io/ace-patterns/en/categories/ProtocolTransformation.html

These are the most common flow types - bridging one transport protocol to another.

| From \ To | Database | Email | File | HTTP | IBM MQ | JMS | Kafka | MQTT | TCP/IP |
|-----------|----------|-------|------|------|--------|-----|-------|------|--------|
| **Database** | - | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Email** | ✅ | - | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **File** | ✅ | ✅ | - | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **HTTP** | ✅ | ✅ | ✅ | - | ✅ | ✅ | ✅ | ✅ | ✅ |
| **IBM MQ** | ✅ | ✅ | ✅ | ✅ | - | ✅ | ✅ | ✅ | ✅ |
| **JMS** | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ | ✅ | ✅ |
| **Kafka** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ | ✅ |
| **MQTT** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - | ✅ |
| **TCP/IP** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | - |

72 combinations total. All use the same basic structure: Input node → Compute/Mapping node → Output node. The main variation is the node types used.

**Common patterns users will ask for:**
- HTTP to IBM MQ (HTTP inbound → put to queue) - `references/examples/HTTPtoIBMMQ/`
- IBM MQ to HTTP (read from queue → call REST API) - `references/examples/IBMMQtoHTTP/`
- File to IBM MQ (pick up file → put to queue) - `references/examples/FiletoIBMMQ/`
- IBM MQ to File (read from queue → write file) - `references/examples/IBMMQtoFile/`
- Kafka to IBM MQ / IBM MQ to Kafka - `references/examples/KafkatoIBMMQ/`, `references/examples/IBMMQtoKafka/`

**Node types by protocol:**
- Database input: `ComIbmDatabaseInput.msgnode` (ESQL for query)
- Email input: `ComIbmEmailInput.msgnode`
- File input/output: `ComIbmFileInput.msgnode`, `ComIbmFileOutput.msgnode`
- HTTP input/reply: `ComIbmWSInput.msgnode`, `ComIbmWSReply.msgnode`
- HTTP outbound: `ComIbmWSRequest.msgnode`
- IBM MQ input/output: `ComIbmMQInput.msgnode`, `ComIbmMQOutput.msgnode`
- JMS input/output: `ComIbmJMSInput.msgnode`, `ComIbmJMSOutput.msgnode`
- Kafka input/output: `ComIbmKafkaConsumer.msgnode`, `ComIbmKafkaProducer.msgnode`
- MQTT input/output: `ComIbmMQTTInput.msgnode`, `ComIbmMQTTOutput.msgnode`
- TCP/IP input/output: `ComIbmTCPIPServerInput.msgnode`, `ComIbmTCPIPClientOutput.msgnode`

---

## Format Transformation Patterns
**Category:** `com.ibm.dev.pattern.formattransformation`
**Doc:** https://ot4i.github.io/ace-patterns/en/categories/FormatTransformation.html

Converting message format within a flow. These are usually combined with a protocol pattern.

| Pattern | Status | Example Directory |
|---------|--------|-------------------|
| BLOB to JSON | ✅ | `references/examples/BLOBtoJSON/` |
| BLOB to XML | ✅ | `references/examples/BLOBtoXML/` |
| BLOB to Fixed Length | ✅ | `references/examples/BLOBtoFixedLength/` |
| BLOB to Delimited | ✅ | `references/examples/BLOBtoDelimited/` |
| JSON to BLOB | ✅ | `references/examples/JSONtoBLOB/` |
| JSON to XML | ✅ | `references/examples/JSONtoXML/` |
| JSON to Fixed Length | ✅ | `references/examples/JSONtoFixedLength/` |
| JSON to Delimited | ✅ | `references/examples/JSONtoDelimited/` |
| XML to BLOB | ✅ | `references/examples/XMLtoBLOB/` |
| XML to JSON | ✅ | `references/examples/XMLtoJSON/` |
| XML to Fixed Length | ✅ | `references/examples/XMLtoFixedLength/` |
| XML to Delimited | ✅ | `references/examples/XMLtoDelimited/` |
| Fixed Length to BLOB | ✅ | `references/examples/FixedLengthtoBLOB/` |
| Fixed Length to JSON | ✅ | `references/examples/FixedLengthtoJSON/` |
| Fixed Length to XML | ✅ | `references/examples/FixedLengthtoXML/` |
| Fixed Length to Delimited | ✅ | `references/examples/FixedLengthtoDelimited/` |
| Delimited to BLOB | ✅ | `references/examples/DelimitedtoBLOB/` |
| Delimited to JSON | ✅ | `references/examples/DelimitedtoJSON/` |
| Delimited to XML | ✅ | `references/examples/DelimitedtoXML/` |
| Delimited to Fixed Length | ✅ | `references/examples/DelimitedtoFixedLength/` |

20 patterns. Key node types: `ComIbmCompute.msgnode` (ESQL), graphical Mapping node (`ComIbmMSLMapping.msgnode`).

Most format transformation patterns include both an ESQL compute and a Mapping node alternative. Check the `_Compute.esql` and `_Mapping.map` files.

---

## Scatter-Gather Patterns
**Category:** `com.ibm.dev.pattern.scattergather`
**Doc:** https://ot4i.github.io/ace-patterns/en/categories/ScatterGather.html

Split a message, process parts independently, reassemble. Not in v1.0.0 release - use IBM documentation.

| Pattern | Description | Status |
|---------|-------------|--------|
| Persistent Aggregation | Aggregates multiple messages with persistence (survives restart) | 🔲 not in release |
| Non-Persistent Aggregation | Aggregates multiple messages in memory | 🔲 not in release |
| Collector | Collects a set of related messages into one | 🔲 not in release |
| Splitter | Splits one message into multiple | 🔲 not in release |

Key node types: `ComIbmAggregateControl.msgnode`, `ComIbmAggregateReply.msgnode`, `ComIbmIterate.msgnode`, `ComIbmCollector.msgnode`.

---

## Messaging Patterns
**Category:** `com.ibm.dev.pattern.messaging`
**Doc:** https://ot4i.github.io/ace-patterns/en/categories/Messaging.html

Patterns for asynchronous message exchange over MQ. Not in v1.0.0 release - use IBM documentation.

| Pattern | Description | Status |
|---------|-------------|--------|
| Messaging Fire-and-Forget | Put to a queue, no reply expected | 🔲 not in release |
| Messaging Request-Reply | Put to a queue, wait for reply on a reply queue | 🔲 not in release |
| Messaging Publication | Publish to a topic (MQ pub/sub) | 🔲 not in release |
| Coordinated Request-Reply | Correlate replies across multiple requests | 🔲 not in release |

---

## Enterprise Integration Patterns
**Category:** `com.ibm.dev.pattern.enterpriseintegration`
**Doc:** https://ot4i.github.io/ace-patterns/en/categories/EnterpriseIntegration.html

Advanced integration patterns. More complex, multi-flow solutions. Not in v1.0.0 release - use IBM documentation.

| Pattern | Description | Status |
|---------|-------------|--------|
| Saga | Distributed transaction with compensating actions | 🔲 not in release |
| Circuit Breaker | Fail fast when downstream is unavailable | 🔲 not in release |
| Delayed Retry / Scheduled Redelivery | Retry a failed call after a delay (typically with exponential backoff). Implemented with `ComIbmTimeoutControl` + `ComIbmTimeoutNotification` (Controlled mode). See `msgflow_format.md` "Timer Nodes" and `validated_rules.md` §7. | 🔲 not in release - use timer-pair pattern |
| Record and Replay | Capture and replay messages for testing/recovery | 🔲 not in release |
| Claim Check | Store large payload, pass a reference (token) | 🔲 not in release |
| Filtering | Route messages based on content/criteria | 🔲 not in release |
| Dynamic Routing | Route based on runtime-determined destination | 🔲 not in release |
| Scheduling | Timer-triggered message flow (Automatic mode timer) | 🔲 not in release |
| Sequence-Resequence | Reorder messages by sequence number | 🔲 not in release |
| Canonical Data Model | Transform all formats to/from a common canonical model | 🔲 not in release |

---

## AI / RAG Pattern
**Extra pattern** - not in the 5 main categories but available in v1.0.0 release.

| Pattern | Status | Example Directory |
|---------|--------|-------------------|
| RAG (Retrieval-Augmented Generation) | ✅ | `references/examples/RAG/` |

Includes: `Indexing.msgflow`, chunking ESQL, Pinecone/IBM watsonx.ai policy files, OpenAPI subflow.

---

## Legacy / Older Patterns (IIB-era)

These appear in the catalog but target older product versions. **Do NOT use for ACE v13.**

- **File Processing** - HTTP one-way, MQ one-way
- **Record Distribution** - HTTP one-way, MQ one-way
- **Message-based Integration** - MQ one-way (XML), MQ request-response variants
- **Service Enablement** - MQ one-way with acknowledgement, MQ request-response
- **Service Facade** - Static Endpoint, MQ variants
- **Service Virtualization** - Static Endpoint

---

## Summary

| Category | Count | Templates Available |
|----------|-------|---------------------|
| Starter Patterns | 1 | ✅ SimpleHTTPResponse |
| Protocol Transformation | 72 | ✅ All 72 extracted |
| Format Transformation | 20 | ✅ All 20 extracted |
| Scatter-Gather | 4 | 🔲 Not in v1.0.0 release |
| Messaging | 4 | 🔲 Not in v1.0.0 release |
| Enterprise Integration | 10 | 🔲 Not in v1.0.0 release |
| AI / RAG | 1 | ✅ Extracted |
| Legacy (IIB-era) | 11 | ⚠️ Older versions - do not use |
| **Total v13** | **110** | **94 extracted** |

---

## How to Use This in the Skill

When a user describes what they want to build, map it to a pattern:

| User says... | Pattern | Example to use |
|---|---|---|
| "Simple HTTP endpoint / hello world / REST API" | HTTP Request-Reply | `references/examples/SimpleHTTPResponse/` |
| "I need to read from MQ and call an API" | IBM MQ to HTTP | `references/examples/IBMMQtoHTTP/` |
| "Convert XML to JSON" | XML to JSON | `references/examples/XMLtoJSON/` |
| "Pick up a file and put it on a queue" | File to IBM MQ | `references/examples/FiletoIBMMQ/` |
| "Read from queue and write to file" | IBM MQ to File | `references/examples/IBMMQtoFile/` |
| "HTTP POST to put on a queue" | HTTP to IBM MQ | `references/examples/HTTPtoIBMMQ/` |
| "Convert JSON to XML" | JSON to XML | `references/examples/JSONtoXML/` |
| "Read from Kafka, put to MQ" | Kafka to IBM MQ | `references/examples/KafkatoIBMMQ/` |
| "Read from MQ, write to Kafka" | IBM MQ to Kafka | `references/examples/IBMMQtoKafka/` |
| "Read from database, send to queue" | Database to IBM MQ | `references/examples/DatabasetoIBMMQ/` |
| "Fan out to multiple systems" | Splitter + Aggregation | Use Scatter-Gather pattern docs (no template) |
| "Put to a queue and forget about it" | Messaging Fire-and-Forget | Use Messaging pattern docs (no template) |
| "Route based on message content" | Filtering or Dynamic Routing | Use Enterprise Integration docs (no template) |
| "Timer-triggered batch job" / "run every N seconds" / "heartbeat" | Scheduling (Automatic mode) | `ComIbmTimeoutNotification` with `timeoutInterval="N"`. See `msgflow_format.md` "Timer Nodes". |
| "Retry if downstream is down" / "delayed retry" / "exponential backoff" / "scheduled redelivery" / "schedule a retry" / "retry after N seconds" | Circuit Breaker / Delayed Retry | `ComIbmTimeoutControl` + `ComIbmTimeoutNotification` (Controlled mode) pair. See `msgflow_format.md` "Timer Nodes" and `validated_rules.md` §7. Search the user's existing flows first for a working example - there is no shipped IBM v13 template. |

Name the pattern explicitly when you recognize it - it helps the user understand what they're building and gives them vocabulary for future discussions.

## What Each Example Directory Contains

Each `references/examples/[PatternName]/` directory contains real IBM ACE v13 files extracted from the official pattern zip (September 2024):

| File | Description |
|------|-------------|
| `[PatternName].msgflow` | Complete message flow XML - import directly into ACE Toolkit |
| `[PatternName]_Compute.esql` | ESQL transformation module (format transformation patterns) |
| `[PatternName]_HandleException.esql` | Standard error handler ESQL module |
| `[PatternName]_Mapping.map` | Graphical mapping file (where applicable) |
| `[PatternName]_Database.esql` | Database ESQL module (Database source/target patterns) |
| `[PatternName]_inputMessage.xml` | Sample input message (format transformation patterns) |
| `application.descriptor` | ACE application descriptor |
| `.project` | Eclipse project file |
| `*.xsd`, `*.json` | Schema files for format transformation patterns |
| `jms.defs` | JMS definitions file (JMS patterns) |
