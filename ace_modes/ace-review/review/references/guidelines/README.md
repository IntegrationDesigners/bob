---
template_version: 1.1.0
last_updated: 2026-07-02
compatible_with: ACE Review v1.0.0+
status: stable
---
# ACE Review Guidelines - Reference Index

This directory contains domain knowledge files used during ACE code reviews.

## Files

| File | Scope | Review Levels |
|---|---|---|
| [`esql_guidelines.md`](esql_guidelines.md) | ESQL coding - references, cardinality, PASSTHRU, declarations, string manipulation | L0 (if chosen), L1, L2, L3 |
| [`flow_guidelines.md`](flow_guidelines.md) | Flow design - node count, compute modes, parsing, async vs sync | L0 (if chosen), L1, L2, L3 |
| [`java_guidelines.md`](java_guidelines.md) | Java compute nodes - thread safety, references, StringBuilder, BLOB handling | L0 (if chosen), L1, L2, L3 |
| [`ten_ace_message_flow_mistakes.md`](ten_ace_message_flow_mistakes.md) | Top 10 common pitfalls from IBM Expert Labs | L1, L2, L3 |
| [`config_guidelines.md`](config_guidelines.md) | Configuration - deployment properties, MQ definitions, policy files, promoted properties, JSON schema versions | L1+ whenever config files are provided |
| [`error_handling_guidelines.md`](error_handling_guidelines.md) | Error handling - try-catch, retry, compensation, logging, HTTP/DB errors | L2, L3 |
| [`security_guidelines.md`](security_guidelines.md) | Security - credentials, input validation, SQL injection, XXE, TLS, audit logging | L3 |
| [`performance_monitoring_guidelines.md`](performance_monitoring_guidelines.md) | Performance - KPIs, caching, async, memory, thread pools, anti-patterns | L3 |

## Output structure files (in `references/`)

| File | Purpose |
|---|---|
| [`../REVIEW_TEMPLATE.md`](../REVIEW_TEMPLATE.md) | The review output document structure |
| [`../REVIEW_TEMPLATE_GUIDE.md`](../REVIEW_TEMPLATE_GUIDE.md) | How to fill each section of the template |
| [`../workflow.md`](../workflow.md) | Full workflow detail and analysis checklists |
