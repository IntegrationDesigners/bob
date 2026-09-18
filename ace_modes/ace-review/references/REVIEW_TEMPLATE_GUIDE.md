---
template_version: 1.1.0
last_updated: 2026-07-02
compatible_with: ACE Review v1.0.0+
status: stable
---
# ACE Review Template - Usage Guide

This guide explains how to fill in `REVIEW_TEMPLATE.md` to produce consistent, high-quality ACE reviews.

See the full guideline files in `guidelines/` for the domain knowledge to apply in each section.

---

## Template Philosophy

- **Comprehensive** - covers all aspects of an ACE application
- **Consistent** - same structure across all reviews
- **Actionable** - clear recommendations with priorities
- **Version-aware** - aligned with the detected ACE version
- **Operational** - useful for dev, ops, and architecture teams alike

---

## Filling Each Section

### Overview
- Clear, concise description of what the adapter does
- Key technologies (MQ, REST, Database, File, etc.)
- Integration pattern (polling, event-driven, request-response, etc.)

### Architecture - Purpose
- Why does this adapter exist?
- What business problem does it solve?
- What would happen if it stopped working?

### Architecture - Components
- List all message flows with a one-line description each
- Note how flows interact if there are multiple

### Architecture - Dependencies
- Shared libraries
- External systems
- Required infrastructure (databases, queues, etc.)

### Flow Analysis (one section per flow)
For each flow, provide:
1. **Purpose** - one sentence
2. **Flow Design** - Mermaid diagram showing nodes and connections, including error paths
3. **Key Components** - analysis of each significant node

For each node, document:
- Configuration properties
- Responsibilities
- Key logic (code snippet if complex)
- Error handling behaviour

Focus on business logic nodes (Compute, Database, REST). Skip trivial pass-through nodes unless they have important configuration.

### Configuration
- Table comparing all environments (TEST / PROD / etc.)
- Call out non-obvious settings and critical dependencies between properties

### Logging Strategy
- For each log point: file, line, log type, status value, fields logged, trigger condition
- Log aggregation integration (if any): enabled, prefix, retention (ELK, Splunk, cloud logging, or "none configured")

### Strengths
Be specific - reference actual code and node names. Categories to consider:
- Design patterns applied well
- Error handling robustness
- Security implementation
- Performance optimizations
- Configuration flexibility
- Operational visibility

### Areas for Improvement
Every finding needs: finding ID (TOPIC-NN), title, issue description, location (clickable file link with line number), code snippet (5-15 lines), specific recommendation, severity label.

**Finding ID format:** Use a topic code + 2-digit counter, reset per topic group:
- SEC-01, SEC-02 (Security)
- R-01, R-02 (Reliability / Error Handling)
- PERF-01 (Performance)
- FD-01, FD-02 (Flow Design)
- C-01, C-02 (Coding - ESQL/Java)
- CF-01, CF-02 (Configuration)
- O-01 (Observability / Logging)
- M-01 (Maintainability)

**Location format:** Always a clickable Markdown link with a line number:
```
**Location:** [`ProcessOrder.esql:42`](path/to/ProcessOrder.esql)
```
Never just a plain path or just a filename without a line number. The line number goes in the link TEXT only - the href target is the plain file path without `:line` (a `:line` suffix in the href breaks link resolution in most viewers).

**Code snippets:** Scope the snippet to the specific function or procedure containing the issue. Do NOT combine multiple CREATE FUNCTION / CREATE PROCEDURE blocks into one snippet - show only the relevant function. This prevents findings about one function being misread as findings about another.

Prioritisation:
- Critical - security, data loss, crash risk
- High - performance impact, reliability risk, error handling gap
- Medium - best practice violation, maintainability
- Low - nice-to-have, future-proofing

**Findings Summary table:** After all individual findings, add a `## Findings Summary` table that lists every finding in one place. One row per finding, ordered Critical → High → Medium → Low:

```markdown
| ID | Title | Severity | Location |
|----|-------|----------|----------|
| R-01 | Commented-Out RETURN TRUE | 🔴 Critical | [`file.esql:36`](path/to/file.esql) |
| SEC-01 | Raw Token Logged | 🟠 High | [`postRecord.subflow:96`](path/to/postRecord.subflow) |
```

This gives readers a quick at-a-glance overview of all findings before they dive into the detail.

### ACE Best Practices Compliance
- What is being done correctly and why it is good
- What ACE features or patterns could be adopted, with links to IBM docs

### Testing Recommendations
Cover three levels:
1. **Unit** - individual compute nodes, ESQL functions, error paths, edge cases
2. **Integration** - end-to-end with real systems, error scenarios, recovery
3. **Performance** - realistic volumes, under load, resource usage

### Operational Considerations
- **Monitoring** - metrics to track, alert thresholds, dashboards
- **Maintenance** - regular tasks, frequency, procedures
- **Troubleshooting** - common issues, diagnostic queries, log patterns

### Conclusion
- Recap key strengths
- Priority improvements grouped by High / Medium / Low
- Overall rating: Production-Ready / Needs Work / Not Ready

---

## Do's and Don'ts

### Do
- Be specific: "Add retry logic with exponential backoff in [`ProcessResponse.esql:65`](path/to/ProcessResponse.esql)" not "error handling could be better"
- Show code snippets - 5-15 lines, scoped to the relevant function/procedure, highlighting the issue
- Link to IBM documentation for every recommendation
- Acknowledge what is done well - a review that only lists problems is less useful
- Use TOPIC-NN IDs consistently: SEC-01, R-01, FD-01, C-01, CF-01, O-01, M-01, PERF-01

### Don't
- Leave placeholder text in the final output
- Use vague language like "should consider" or "might be improved"
- Overwhelm with low-priority findings - prioritise clearly
- Assume - verify before stating, check ACE version compatibility for all recommendations

---

## Section-Specific Tips

### Mermaid Diagrams
- Show the full happy path and all error paths
- Use colours consistently: input nodes blue, output green, error red, logging yellow
- Keep it readable - topology matters more than exhaustive property detail

### Code Snippets
Show the minimal context needed to understand the issue - around 8 lines is usually right. Include a comment that highlights exactly what the problem is.

**Scope to the relevant function:** Each ESQL file contains one or more CREATE FUNCTION / CREATE PROCEDURE blocks. Always show the snippet from the specific function where the issue occurs. Never mix code from multiple functions in one block - this leads to findings being misattributed to the wrong function. If a finding is about a helper procedure, the snippet should be from that procedure, not from Main().

### Recommendations
Structure every recommendation as:
- **Action**: the specific change to make
- **Benefit**: why this helps
- **Consideration**: what to watch out for during implementation
- **Reference**: IBM docs link

---

## When to Mark Sections N/A
If a section genuinely does not apply (no database = no database schema section), mark it clearly:

N/A - this adapter does not use database integration.

Do not leave sections blank or with placeholder text.

---

## Quality Checklist

Before finalising a review:

- [ ] All sections completed or marked N/A
- [ ] No placeholder text remaining
- [ ] Every finding ID uses TOPIC-NN format (SEC-01, R-01, FD-01, etc.)
- [ ] Every Location field is a clickable Markdown link with a line number
- [ ] Every file reference in the body text includes a line number and a link
- [ ] Code snippets accurate and scoped to the specific function/procedure containing the issue
- [ ] All recommendations are specific and actionable
- [ ] IBM documentation links tested and valid
- [ ] Severity labels applied consistently
- [ ] Findings grouped by topic, ordered by severity
- [ ] Findings Summary table present after the last individual finding, one row per finding
- [ ] Overall rating matches the findings
