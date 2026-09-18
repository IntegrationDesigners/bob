# Custom review rules

<!--
This file is empty by default - the ACE Review skill runs exactly as shipped.

Add your organisation's own rules below these comments. When this file contains
anything outside this comment block, the skill reads it and applies it on top of
its built-in review. If a custom rule conflicts with a default check, the custom
rule wins - the skill follows it and tells you it is doing so.

IMPORTANT: a custom rule never silently deletes a finding. When a rule allows or
downgrades something the skill would normally flag, the skill still records it in
the "Remarks / Notes - Accepted deviations (per customer rules)" section of the
report, naming the rule that permits it. The deviation stays visible; it just is
not raised as a rated finding.

Good things to put here (house standards the generic review cannot know):

- Accepted deviations - patterns the skill would normally flag but that are
  house standard here, for example:
  - non-consistent PROPAGATE finalisation (FINALIZE/DELETE clauses) where the
    framework in use makes it safe.
  - equal or similar log prefixes across different pillars, or shared prefixes
    between prd and non-prd environments.
  - a Log node logging the full message body to the activity log (accepted
    because that log is kept in memory only).
  - MQ settings such as the backout threshold set on the default queue rather
    than on the specific queue definitions in the mqsc files.

- Central framework libraries to treat as trusted / skip - shared libraries whose
  internals should NOT be reviewed on every application review (logging framework,
  common error-handling subflows, house adapter library). List them by name so the
  skill records the dependency and stops at the boundary instead of re-auditing
  them each run. (Message-schema / model libraries the flows bind to are still
  resolved for field/schema context - see workflow.md Step 1b.)

- House severity mapping - if your organisation rates certain finding types
  differently from the default severity scale.

- Naming / logging / error-handling conventions specific to your estate that the
  review should hold code to (or explicitly not hold code to).
-->
