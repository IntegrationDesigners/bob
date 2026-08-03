# Custom support case rules

<!--
This file is empty by default - the ACE Support Case skill runs exactly as shipped.

Add your organisation's own rules below these comments. When this file contains
anything outside this comment block, the skill reads it and applies it on top of
its built-in workflow. If a custom rule conflicts with a default step, the custom
rule wins - the skill follows it and tells you it is doing so.

Good things to put here (the kind of thing the generic workflow cannot know):

- House trace / data-collection procedure - your own scripts, flags, and steps,
  and where they differ from the default aceDataCollector / trace instructions.
- Where your logs actually live - custom work-dir, container/volume paths, or a
  log aggregator (Splunk / ELK) instead of the local error log.
- Data handling - what to redact before anything goes to IBM, and the approved
  upload channel (portal attachment vs ECuRep, encryption, no production data).
- Entitlement - IBM Customer Number (ICN), site ID, support tier, named callers.
- Internal governance - required incident/change ticket, internal-to-IBM
  severity mapping, where the diagnostic bundle must be stored.
-->
