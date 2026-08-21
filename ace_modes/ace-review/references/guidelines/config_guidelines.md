---
template_version: 1.1.0
last_updated: 2026-07-02
compatible_with: ACE Review v1.0.0+
status: stable
---
# ACE Configuration Guidelines

Reference for `ace-review-config` and `ace-review` modes. Covers deployment properties, MQ definitions, policy files, and promoted properties.

---

## 1. Deployment Properties (.properties / .yaml)

### 1.1 Critical Rules

| Rule | Severity | Explanation |
|------|----------|-------------|
| No hardcoded passwords | CRITICAL | Any `password=`, `pwd=`, `secret=` must use overrides |
| No hardcoded IP addresses | HIGH | Use hostnames or promoted properties |
| No hardcoded queue manager names | HIGH | Must be environment-specific via overrides |
| TEST config must not deploy to PROD | CRITICAL | Validate env-specific values differ |
| All promoted properties must have values in every env | HIGH | Missing value = deployment failure |

### 1.2 Promoted Property Naming Convention

```properties
# Good - clear component and purpose
MyApp#HTTPConnector/httpConnectorPortNumber=7800
MyApp#MQOutput/queueManagerName=QM1
MyApp#DatabasePolicy/policyName=MyDatabasePolicy

# Bad - ambiguous
port=7800
queue=MYQUEUE
```

Format: `[ApplicationName]#[NodeLabel]/[PropertyName]=[Value]`

### 1.3 Environment-Specific Override File Structure

```
overrides/
├── dev.properties
├── test.properties
├── uat.properties
└── prod.properties
```

Apply with: `ibmint apply overrides overrides/prod.properties --bar-file App.bar`

### 1.4 Common Properties Anti-Patterns

```properties
# BAD - hardcoded credentials
database.password=MySecretPassword123
mq.password=mqpassword

# BAD - hardcoded environment-specific URL
backend.url=http://192.168.1.100:8080/api

# BAD - TEST queue in PROD properties
output.queue=TEST.ORDER.QUEUE

# GOOD - use promoted property placeholders
# (the value is set per-environment at deploy time via ibmint apply overrides)
MyApp#BackendHTTP/requestURI=https://api.prod.company.com/orders
```

---

## 2. MQ Configuration Best Practices

### 2.1 Queue Definition Checklist

Every application queue must define:

| Property | Required | Recommendation |
|----------|----------|----------------|
| `MAXDEPTH` | Yes | Set explicitly - default 5000 may be too low or too high |
| `DEFPSIST` | Yes | `YES` for business-critical messages, `NO` for transient |
| `BOQNAME` | Yes | Every input queue needs a backout queue |
| `BOTHRESH` | Yes | Recommend 3-5 (retry limit before backout) |
| `MAXMSGL` | Review | Default 4MB - set explicitly for your payload size |
| `DESCR` | Recommended | Document purpose for ops team |

### 2.2 Backout Queue Pattern

```mqsc
* Application input queue
DEFINE QLOCAL('APP.ORDER.INPUT') +
  DESCR('Order processing input') +
  DEFPSIST(YES) +
  MAXDEPTH(10000) +
  MAXMSGL(1048576) +
  BOQNAME('APP.ORDER.BACKOUT') +
  BOTHRESH(3)

* Backout queue - must exist before first message
DEFINE QLOCAL('APP.ORDER.BACKOUT') +
  DESCR('Backout queue for APP.ORDER.INPUT') +
  DEFPSIST(YES) +
  MAXDEPTH(50000)

* Dead letter queue (system level - one per QM)
ALTER QMGR DEADQ('SYSTEM.DEAD.LETTER.QUEUE')
```

**Common finding:** `BOQNAME` defined but queue doesn't exist - messages in backout go to the DLQ anyway but without context.

### 2.3 Channel Security

```mqsc
* Block anonymous connections
SET CHLAUTH('*') TYPE(BLOCKUSER) USERLIST('nobody') DESCR('Deny all by default')

* Allow specific user - map to a least-privileged application user
SET CHLAUTH('APP.SVRCONN') TYPE(USERMAP) +
  CLNTUSER('aceuser') USERSRC(MAP) MCAUSER('appuser')

* Require TLS on server-connection channels
* ANY_TLS12_OR_HIGHER lets the queue manager negotiate a modern (ECDHE) suite
ALTER CHANNEL('APP.SVRCONN') CHLTYPE(SVRCONN) +
  SSLCIPH('ANY_TLS12_OR_HIGHER') +
  SSLCAUTH(REQUIRED)
```

**Never map a channel to `mqm`** (or any other MQ administrative user) - that grants full queue manager administration to every client on the channel. Always map to a least-privileged application user.

**Findings to flag:** Server-connection channels with `SSLCIPH(' ')` (blank = no TLS); channels mapped to `MCAUSER('mqm')` or another admin user; deprecated `TLS_RSA_*` cipher specs (no forward secrecy) - recommend `ANY_TLS12_OR_HIGHER` or an explicit ECDHE suite.

### 2.4 Queue Naming Conventions to Validate

Good pattern: `[DOMAIN].[APPLICATION].[PURPOSE]` e.g. `ORDER.PROCESSOR.INPUT`
Red flags:
- Queues named `TEST.*` referenced in production properties
- Generic names like `INPUT`, `OUTPUT`, `QUEUE1`
- No dead-letter queue defined on the queue manager

---

## 3. Policy Files (.policyxml)

### 3.1 Policy Types and Key Fields

**Endpoint policy** (HTTP/MQ/database connections):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<policies>
  <policy policyType="HTTPSProxy" policyName="BackendHTTPS" policyTemplate="HTTPSProxy">
    <proxyType>https</proxyType>
    <proxyHost>proxy.company.com</proxyHost>
    <proxyPort>8080</proxyPort>
  </policy>
</policies>
```

**MQ connection policy:**
```xml
<policy policyType="MQEndpoint" policyName="ProdQueueManager">
  <queueManagerName>PROD.QM1</queueManagerName>
  <connectionName>mqhost.company.com(1414)</connectionName>
  <channelName>APP.SVRCONN</channelName>
  <useSSL>true</useSSL>
  <!-- Prefer ANY_TLS12_OR_HIGHER (negotiates a modern ECDHE suite) over fixed TLS_RSA_* specs -->
  <SSLCipherSpec>ANY_TLS12_OR_HIGHER</SSLCipherSpec>
</policy>
```

### 3.2 Policy Review Checklist

- [ ] `policyName` matches what's referenced in application properties
- [ ] No hardcoded passwords in policy XML (use credential policies instead)
- [ ] MQ endpoint policies use TLS in non-dev environments
- [ ] HTTP endpoint policies have correct timeouts set
- [ ] Credential policies use vault references, not plaintext

### 3.3 Credential Policy Anti-Pattern

```xml
<!-- BAD - plaintext password in policy file -->
<policy policyType="Credential" policyName="DBCredential">
  <usernameProperty>dbuser</usernameProperty>
  <passwordProperty>MyPlainTextPassword</passwordProperty>  <!-- CRITICAL finding -->
</policy>

<!-- GOOD - reference to a vault or environment variable -->
<policy policyType="Credential" policyName="DBCredential">
  <usernameProperty>{env:DB_USER}</usernameProperty>
  <passwordProperty>{env:DB_PASSWORD}</passwordProperty>
</policy>
```

---

## 4. Application Descriptor Review

### 4.1 `application.descriptor` Structure

```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns2:appDescriptor xmlns="http://com.ibm.etools.mft.descriptor.base"
                   xmlns:ns2="http://com.ibm.etools.mft.descriptor.app">
  <references/>
</ns2:appDescriptor>
```

**When `<references>` is not empty:** contains shared library dependencies. Validate:
- Each referenced library exists in the BAR or as a separate deployed library
- No circular dependencies
- Library version matches what's deployed to the server

### 4.2 JSON Schema Version Check (ACE-specific)

ACE v13 supports **JSON Schema draft 4 only**. Draft 6/7 keywords cause silent validation failures.

**Draft 6/7 keywords that must NOT appear in `.json` schema files used by ACE:**

| Keyword | Draft | ACE behaviour |
|---------|-------|---------------|
| `contains` | Draft 6 | Ignored silently |
| `propertyNames` | Draft 6 | Ignored silently |
| `const` | Draft 6 | Ignored silently |
| `if` / `then` / `else` | Draft 7 | Ignored silently |
| `$defs` | 2019-09 | Ignored silently |
| `$id` | Draft 6 | Ignored silently |
| `examples` | Draft 6 | Ignored silently |
| `readOnly` / `writeOnly` | Draft 7 | Ignored silently |

---

## 5. Configuration Finding IDs and Severity

Configuration findings use the `CF-NN` prefix. `NN` is a **sequential counter** starting at 01 within the Configuration topic group (family convention: the counter resets per topic group and does not encode a category). Order findings by severity within the group.

Typical configuration finding categories:

| Category | Example |
|----------|---------|
| Hardcoded credentials | Password in properties file |
| Hardcoded endpoints | IP address in properties |
| Missing backout queue | BOQNAME blank or queue absent |
| No DLQ on queue manager | DEADQ not set |
| TLS not configured | SSLCIPH blank on SVRCONN |
| JSON Schema version | draft-07 keyword in ACE schema |
| Missing promoted property | Property referenced but not in override file |
| TEST config in PROD | Queue/URL contains TEST |
| Policy credential plaintext | Password in policyxml |
| Missing BOTHRESH | Backout threshold not set |
