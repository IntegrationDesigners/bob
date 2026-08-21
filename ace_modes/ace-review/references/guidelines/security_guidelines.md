---
template_version: 1.1.0
last_updated: 2026-07-02
compatible_with: ACE Review v1.0.0+
status: stable
---
# ACE Security Guidelines

## Sensitive Data Handling

**Never log passwords, API keys, tokens, credit card numbers, or other sensitive information in plain text.**

```esql
-- BAD: logs sensitive data
SET Environment.Variables.Debug = InputRoot.XMLNSC.Request.Password;

-- GOOD: mask it
SET Environment.Variables.Debug = 'Password: ********';
```

Sensitive categories: authentication credentials, PII (SSN, passport), financial data (card numbers, bank accounts), health information, business secrets.

---

## Secure Credential Storage

**Never hardcode credentials in message flows or ESQL code.**

Recommended approaches:
1. Use the ACE vault (`ibmint set credential`) for database, HTTP, and service credentials
2. Use Policy Projects for endpoint configurations
3. Use external vault integration (HashiCorp Vault, IBM Key Protect)
4. Use environment variables / platform secrets for container deployments

```bash
# Add or update a database credential in the server's vault
# (the per-work-directory vault is created implicitly by the first set credential call)
ibmint set credential --work-directory <work_dir> --credential-type jdbc --credential-name <datasource_name> --vault-key <key>

# Add or update HTTP credentials
ibmint set credential --work-directory <work_dir> --credential-type http --credential-name <security_identity> --vault-key <key>

# List stored credentials
ibmint display credentials --work-directory <work_dir> --vault-key <key>

# Remove a credential
ibmint unset credential --work-directory <work_dir> --credential-type http --credential-name <security_identity> --vault-key <key>
```

At server start, supply the vault key with `--vault-key` or the `MQSI_VAULT_KEY` environment variable. `ibmint create vault` is only needed for an external directory vault shared across servers - the per-work-directory vault is created implicitly.

Legacy: `mqsisetdbparms` is the legacy node-managed credential path - migrate to the vault.

---

## Input Validation and Sanitization

**Never trust data from external sources. Always validate and sanitize input.**

Checklist:
- Check data types and formats
- Validate against expected ranges
- Sanitize special characters
- Verify message structure
- Check for SQL injection patterns
- Validate XML/JSON structure

```esql
DECLARE userId CHARACTER InputRoot.XMLNSC.Request.UserId;

-- ESQL has no regex MATCHES() function. Check allowed characters explicitly:
-- TRANSLATE removes every allowed character; anything left over is invalid.
IF LENGTH(TRANSLATE(userId,
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', '')) > 0 THEN
    THROW USER EXCEPTION MESSAGE 2951 VALUES('Invalid user ID format');
END IF;

-- Simple patterns can also be checked with LIKE, e.g.:
-- IF userId NOT LIKE 'USR%' THEN ... END IF;

IF LENGTH(userId) < 3 OR LENGTH(userId) > 20 THEN
    THROW USER EXCEPTION MESSAGE 2951 VALUES('User ID length out of range');
END IF;
```

---

## SQL Injection Prevention

**Always use parameterized queries with PASSTHRU statements.**

```esql
-- BAD: vulnerable to SQL injection
PASSTHRU('SELECT * FROM Users WHERE UserId = ''' || userId || '''');

-- GOOD: parameterized
PASSTHRU('SELECT * FROM Users WHERE UserId = ?', userId);
```

---

## XML External Entity (XXE) Prevention

Configure parsers to prevent XXE attacks. Disable DTD processing when not needed, use message sets with defined schemas, validate XML against known schemas, and avoid processing untrusted XML with external entities.

---

## Secure Communication

**Always use encrypted communication channels for external systems.**

- Use HTTPS for all external HTTP/REST calls
- Use TLS channels for MQ connections
- Configure channel authentication records (CHLAUTH)
- Use message encryption when required
- Implement mutual authentication

```esql
SET OutputLocalEnvironment.Destination.HTTP.SecurityProfile = 'SecureHTTPProfile';
```

---

## Error Handling and Information Disclosure

**Error messages must not reveal internal system details.**

```esql
-- BAD: exposes internals
SET OutputRoot.XMLNSC.Error.Detail = SQLSTATE || ' - ' || SQLERRORTEXT;

-- GOOD: generic response, detailed log
SET OutputRoot.XMLNSC.Error.Code = 'ERR_500';
SET OutputRoot.XMLNSC.Error.Message = 'An internal error occurred';
CALL writeToLog('ERROR', 'Database error: ' || SQLSTATE || ' - ' || SQLERRORTEXT);
```

Never expose: database error messages, stack traces, internal file paths, system configuration details, or version information.

---

## Access Control and Authorization

Verify user permissions before processing requests. Implement explicit authorization checks rather than relying on downstream systems to enforce them.

---

## Audit Logging

Log all security-relevant events:

- Authentication attempts (success and failure)
- Authorization failures
- Data access (especially sensitive data)
- Configuration changes
- Security exceptions
- Unusual patterns or anomalies

---

## Secure Configuration Checklist

- Disable unnecessary protocols and services
- Use strong encryption algorithms (TLS 1.2+)
- Implement certificate validation
- Configure appropriate timeouts
- Limit message sizes
- Enable security auditing
- Apply regular security updates and patches

---

## Container Security (ACE in Containers)

1. Use minimal base images
2. Run as non-root user
3. Scan images for vulnerabilities
4. Use secrets management (Kubernetes secrets, OpenShift)
5. Implement network policies
6. Enable pod security policies

---

## Data Encryption

Encrypt sensitive data both at rest and in transit:

- **Transport-level** - TLS/SSL for all channels
- **Message-level** - WS-Security, JWE where required
- **Field-level** - encryption of specific sensitive fields
- **Database** - TDE or column encryption for stored data

---

## Summary

1. Never log sensitive data in plain text
2. Use secure credential storage (the ACE vault via `ibmint set credential`; external vaults) - `mqsisetdbparms` is legacy
3. Always validate and sanitize input from external sources
4. Prevent SQL injection with parameterized queries
5. Disable XXE processing in XML parsers
6. Use TLS/SSL for all external communication
7. Avoid information disclosure in error messages
8. Implement proper authorization checks
9. Maintain audit logs for security events
10. Follow secure configuration practices
11. Secure container deployments properly
12. Encrypt sensitive data at rest and in transit
