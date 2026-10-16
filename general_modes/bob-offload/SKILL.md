---
name: bob-offload
description: "Use this skill when the user wants a coding task handed off to IBM Bob through the Bob Shell CLI (bob run, headless) so it spends Bobcoins from the IBM team budget instead of Claude usage, with Claude staying in control as orchestrator and reviewer. Triggers on 'offload this to bob', 'hand this to bob', 'let bob do this', 'run this through bob shell', 'burn some bobcoins', 'use the bob budget', or when the user wants to spare Claude usage on well-specified coding work and Bob's team budget has room. Claude writes a standalone brief, launches bob run in the background, then reviews the resulting diff itself. Do NOT use for judgment-heavy, underspecified or architecture work, and do not hand Bob a review job - Claude reviews, Bob generates."
metadata:
  version: 0.2.0
  status: draft
  last_updated: 2026-10-16
---

# Bob Offload

Delegate a well-specified coding task to IBM Bob via Bob Shell (`bob run`, headless) so the
generation cost lands on the IBM Bob team budget (Bobcoins), while you - Claude - keep the
brief, the review and the integration.

Written against bobshell 2.0.5 (npm package `bobshell`, binary `bob`, home `~/.bob`, a
Gemini-CLI fork), signed in with SSO. Every launch flag and behaviour below was measured
on 2026-10-01 in a scratch repo unless marked otherwise.

## When to offload, when not to

Offload: mechanical, well-specified, verifiable work - boilerplate, tests, pattern refactors,
scaffolding, doc drafts. Bob is also a reasonable pick for IBM-stack work (ACE, MQ, IBM i)
when the brief is precise.

Keep in Claude: anything that needs conversation context, judgment, architecture, root-cause
debugging, or secrets. Never put credentials or private personal data in a brief: it goes
to IBM's gateway.

Budget: Bobcoins are a per-TEAM server-side budget. Check the team's remaining budget in
Bob IDE before queueing a batch.

## Workflow

### 1. Write the brief - a file, with the Write tool

Bob sees none of the conversation. Author the brief with the Write tool into the session
scratchpad (never a heredoc - on Windows the shell boundary corrupts multi-line content).
Shape and tuning come from the "Targeting IBM Bob" section of the prompt-forge skill's
`references/model_tuning.md`: Bob's router picks the model,
so steer the middle of the axis - numbered requirements, every path spelled out, a
checkable "Done when" with the verification commands to run.

```
# Task        - the result wanted, in one paragraph
# Workspace   - exact files/paths in scope; what NOT to touch
# Requirements - numbered, each independently checkable
# Done when   - commands to run and what to report
```

### 2. Pick the mode by what Bob must EXECUTE, not by whether it writes

**`ask` and `plan` have NO shell.** "Read-only" does not mean "can run read-only commands":
an ask-mode brief that said "run `git log`" was refused - Bob answered "in Ask mode I cannot
run commands" and still billed 0.12 coins (2026-10-16). Any brief that names a command to
run (git, tests, build, grep via shell) needs agent mode.

| Bob must... | Mode and flags | Where `-w` points |
|---|---|---|
| read files and answer, no commands | `--mode ask` | live checkout is fine |
| summarise command output (git log, test results) | `--mode ask`, Claude runs the commands and pastes the output into the brief | live checkout is fine |
| run commands, change nothing | `--mode agent --disable-tool-groups edit,mcp,browser --disable-subagents` | a git worktree |
| write code | `--mode agent` | a git worktree |

- Pasting the output is the cheapest route: the same git summary cost 0.04 coins with the
  output in the brief, against 0.12 for the refused ask-mode run.
- `--disable-tool-groups edit,mcp,browser --disable-subagents` (verified 2026-10-16): Bob ran
  `execute_command` and reported no file-writing tool; the probe file it was told to write
  was not created. 0.08 coins. It still has the shell, and the shell can write
  (`git checkout`, a redirect), so this is not a sandbox - keep it in a worktree.
- `--disable-subagents` matters: in ask mode Bob handed the job to a subagent that had only
  file-reading tools.

### 3. Launch in the background

```
bob run --trust -w <repo> --format json --mode <mode> \
  --max-cost <bobcoins> --max-turns <n> --disable-mcp \
  < <scratchpad>/bob-brief-<slug>.md > <scratchpad>/bob-out-<slug>.json \
  2> <scratchpad>/bob-err-<slug>.log
```

Run it with the Bash tool, `run_in_background: true`, and:

- The prompt goes on stdin when no positional prompt is given (verified). A one-liner may
  go as the positional argument instead.
- `-w <repo>` is the workspace. `--trust` marks it trusted; an untrusted folder runs in
  safe mode (no project settings, no auto-approval, no MCP - per the Bob Shell docs).
- Headless `agent` mode auto-approves file writes AND shell commands (verified: it ran
  `git status` unprompted). Point `-w` at a git worktree for anything non-trivial
  (`git worktree add`), never the user's live checkout.
- `--mode` comes from the table in step 2; custom mode slugs also work (none are
  defined in `~/.bob/settings/custom_modes.yaml` as of 2026-10-01).
- Run it from Git Bash. PowerShell 5.1 `Out-File`/`>` writes a BOM (or UTF-16) that breaks
  a strict JSONL reader on line 1.
- `--format stream-json` shows every tool call and result, which is useful when a run
  misbehaves. Its final `result` record carries `stats` but NO `last_message`; the answer
  is spread over the `message` records.
- `--disable-mcp` unless the task needs an MCP server - faster start, smaller surface.
- `--max-cost` is in Bobcoins; set it. Probe tasks cost 0.04-0.21 each.
- Never pipe the launch through `tail`/`grep` - it masks the real exit status.

### 4. Review - the reason Claude stays in the loop

The output file holds JSON lines. The final record is
`{"type":"result","status":...,"stats":{"task_id","duration_ms","session_costs","max_cost","tool_calls"},"last_message":...}`.

1. Scan for any `"type":"error"` record FIRST. `status: success` and exit code 0 do not mean
   the run met its limits (see scars).
2. `last_message` is a claim, not evidence. `git -C <repo> status` and `git diff`: judge the
   diff against the brief as if a stranger wrote it.
3. Run the done-criterion yourself (tests, build, one real input).
4. Small gaps: fix directly. Real gaps: resume the same task so Bob keeps its context:
   `bob run --trust -w <repo> --format json -r <task_id> "<correction>"` (verified;
   `session_costs` is cumulative across the resumed task).

### 5. Report

Terse: what was delegated, the Bobcoin cost (`session_costs`), review verdict, what you
fixed yourself, where the branch is.

## Known scars

- `--max-cost` is checked after a request, not before: with a cap of 0.01 the run spent
  0.042, emitted `{"type":"error","message":"The task reached the cost limit ..."}` and
  STILL ended with `status: success` and exit code 0. Set the cap with one request of
  headroom in mind and always grep the output for `"type":"error"`.
- Node prints an `ExperimentalWarning: SQLite` line on stderr every run - noise; keep
  stderr out of the JSON file, but in its own file, never `2>/dev/null`: a refused API key
  exited 1 with empty stdout, and with stderr discarded the reason was lost (2026-10-16).
- Bob tasks land in `~/.bob/db/bob.db` (`tasks` table, id = the `task_id` above), not
  `~/.claude`. Bob IDE shows them too.
- `bob` and Bob IDE share the team budget: a big overnight batch can exhaust it for the
  user's interactive Bob work the next morning.
- Reading is what costs: an ask-mode review read 12 client files in 31 tool calls and spent
  its whole 4-coin cap in 88 s with zero findings emitted (2026-10-04). Size
  review briefs at ~3 files per coin and make them write findings per file as they go.
