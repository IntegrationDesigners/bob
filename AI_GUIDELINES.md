# AI Guidelines for the IBM Tooling

How Integration Designers uses AI inside the IBM tooling: IBM Bob (Bob IDE and Bob Shell),
the modes and skills in this repository, IBM's Flow Pilot skills for ACE and API Connect,
and the MCP features of App Connect Enterprise 13.

The rules come first and are short on purpose: they protect our customers, our colleagues
and ID. The three how-to sections after them show how to set up `.bobignore`, what Bob's
commands can touch, and a hook that blocks secrets. How to install and use the tools is in
[GETTING_STARTED.md](GETTING_STARTED.md) and [SKILLS.md](SKILLS.md).

**Status:** draft for review. **Owner:** Matthias Blomme, Product Lead AI.

---

## Scope

- IBM Bob IDE and Bob Shell, with or without the modes and skills from this repository.
- IBM App Connect Flow Pilot and IBM API Connect Flow Pilot.
- ACE 13 MCP: REST APIs exposed as MCP tools (13.0.7 and later) and the MCP Admin Server.
- Any MCP server you connect to Bob.

AI tools a customer provides or mandates follow the customer's own rules, not this page.

---

## 1. The customer decides first

- Use Bob on customer code, configuration or data only when the customer allows
  AI-assisted development. If the contract or the customer's policy does not say, ask.
- Where the customer's policy is stricter than this page, theirs applies.
- Know where your prompts go. Before your first customer task, read the "Data privacy &
  training" and "Data storage & retention" sections of the Bob FAQ. Check data residency
  when the customer cares where data is processed.

## 2. Keep secrets and customer data out of the context

- Never paste credentials, keystores, stash files or production payloads into a prompt.
- Put a `.bobignore` in the root of every customer workspace. Write it so that it covers
  every subfolder (see [A](#a-a-bobignore-that-reaches-every-folder)).
- Know its limits. In Bob IDE, `.bobignore` blocks reads and writes on matching files. In
  Bob Shell it controls read access only, so write tools can still write to ignored paths.
  In both, it is not a system-level sandbox, and the commands Bob runs mostly ignore it
  (see [B](#b-what-bobs-tools-touch-and-what-its-commands-touch)).
- Install the secrets hook (see [C](#c-a-hook-that-blocks-secrets)). It stops a prompt or a
  tool call that carries a private key, a hard-coded password or a password on an
  `mqsisetdbparms` or `mqsicredentials` command line.
- Never give Bob a customer's vault key. `ace-flow-harness` passes the vault key on the
  `IntegrationServer` command line, so run it only against a local test work directory
  with a throwaway vault.
- Work with test data or anonymised samples. Strip customer names, hosts and queue manager
  names from anything that leaves the customer: a blog, a community post, this repository.

## 3. Read freely, write and run deliberately

- Auto-approving read actions is fine. Keep approval on for file writes and command
  execution, and certainly on a machine that can reach customer environments.
- Trust specific commands through an allowlist, and put the dangerous ones on a denylist.
  A denied command stays denied, even with auto-approve on. Do not auto-approve all
  command execution.
- Bob IDE: use the Permissions button next to the mode selector. Bob Shell: use
  `/permissions` during a session. Both write to the `approval` key in
  `~/.bob/settings/settings.json`: `allowed_permissions` for the groups, and
  `allowedExecutors` (with `approvedCommands` and `deniedCommands`) for `execute_command`.
- Headless `bob run` in `agent` mode approves file writes and shell commands without
  asking. Point it (`-w`) at a separate git worktree, never at your live checkout or a
  customer workspace. See [general_modes/bob-offload](general_modes/bob-offload/SKILL.md).

## 4. A human owns every change

- AI output is a draft. You review it, you test it and you sign it off, to the same
  standard as code you typed yourself.
- Every change goes through a merge request with a human reviewer. Customer repositories
  follow the customer's own flow.
- The modes help the reviewer; they do not replace one. Use `ace-review` for a structured
  review, and `ace-flow-harness` to deploy and run the flow before you call it done.
- Never let Bob deploy to, or change, a production environment.

## 5. Build to the customer's house style

- Run `ace-conventions-profiler` on the customer's existing estate first, so that
  `ace-flow-builder` produces flows that look like theirs and not like ours.
- If the requirement is still vague, start with `ace-flow-designer`. It turns the
  requirement into a spec before anything is generated.

## 6. MCP: least privilege

- Connect only MCP servers from trusted sources. For confidential projects, prefer local
  servers. Keep a list of the MCP servers you use on customer work.
- A local MCP server runs with the same permissions as Bob: it can reach your file system,
  your environment variables and anything else you can.
- The ACE MCP Admin Server is disabled by default. Enable it only on your own development
  or test integration server, and set `readOnly: true` unless the task needs write tools.
- A REST API exposed as an MCP tool can be called by any AI agent that reaches it. Give it
  the same authentication and authorisation as any other client, and get the customer's
  sign-off.
- Never connect an AI agent to a production admin endpoint.
- Leave the `mcp` permission group out of auto-approve on customer work.

## 7. Flow Pilot: IBM's own skills for ACE and API Connect

**App Connect Flow Pilot** is IBM's public agent skill `ace-flowpilot`
([ot4i/ace-flowpilot](https://github.com/ot4i/ace-flowpilot), MIT licence). It teaches
Bob, or GitHub Copilot, to write correct Toolkit artefacts: message flows, subflows, ESQL,
JavaCompute nodes, connector flows, policy projects and project scaffolding. The ACE Toolkit
13.0.9.0 and later downloads the latest release into `<workspace>/.bob/skills/ace-flowpilot`
(and `.github/skills/` for Copilot) when it opens a workspace while online, and updates it on
restart. You manage this under Window > Preferences > Integration Development > AI
preferences. On older Toolkits, install a release yourself.

- Use it together with our skills, not instead of them. Flow Pilot makes the artefacts
  correct. Our skills add the design interview, the customer's conventions, the review and
  the deploy-and-test run. When both could match a request, name the skill you want.
- Do not edit the copy in `.bob/skills/ace-flowpilot`. By default the Toolkit deletes that
  folder before every update. Your own skills go in a sibling folder.
- At a customer, the Toolkit fetches the skill from github.com on startup. If the customer
  does not allow that, switch off the download on startup and install a release you have
  reviewed.
- Fixes go upstream as a pull request to ot4i/ace-flowpilot. ID already has pull requests
  merged there.

**API Connect Flow Pilot** is IBM's agent kit for API Connect 12.1.1 and API Studio: skills
that author, lint, build, publish and test APIs, plus MCP servers that act on a live API
Connect instance. Kit 12.1.1.2.3 holds 11 skills and 6 MCP servers. Its `/setup-agent-kit`
skill configures the MCP servers for Bob, Claude Code or GitHub Copilot.

- The kit is licensed under the IBM ILAN. Install it from IBM's download on your own
  machine. Never copy its skills, examples or rulesets into this repository or a customer
  repository.
- The setup writes your instance credentials in plain text into `<workspace>/.bob/mcp.json`.
  Add that file to `.gitignore`. Also add it to `.bobignore`, so that Bob's file tools cannot
  read it into a prompt, and check that the MCP servers still start afterwards.
- The MCP servers publish to a real API Connect instance. Point them at a sandbox catalog
  or a test provider organisation, never at production, and keep approval on for MCP calls.

## 8. Bobcoins are a shared budget

- Bobcoins are a per-team budget, and Bob IDE and Bob Shell draw on the same one. A large
  batch run can empty it for the whole team.
- Set `--max-cost` on every headless `bob run` job. See
  [general_modes/bob-offload](general_modes/bob-offload/SKILL.md).

## 9. Diagnostics for IBM support

- `ace-support-case` collects traces and data collector output. These bundles can contain
  payloads, hostnames and user IDs. Review them before you attach them to an IBM case.

## 10. Share what works

- A prompt, mode or skill that saves you time belongs in this repository: open a feature
  branch and a merge request (see [README.md](README.md), Contributing).
- Bring questions and ideas to the Product Lead AI. Fasttrack sessions cover the modes; ask
  for one for your team.
- Learning path: [GETTING_STARTED.md](GETTING_STARTED.md), then the IBM Bob Developer
  Associate certification.

---

## A. A `.bobignore` that reaches every folder

`.bobignore` uses the same syntax as `.gitignore`. It sits in the root of the workspace, and
its rules cover only files inside that workspace. In a multi-root VS Code workspace, a Bob
task is bound to one folder, so every workspace folder needs its own `.bobignore`.

Whether a pattern reaches every subfolder depends on where its slashes are:

| Pattern | Matches |
|---|---|
| `*.jks` | No slash: a file of that name in **every** folder |
| `secrets/` | Only a trailing slash: a folder of that name in **every** folder, with all its contents |
| `/secrets/` | A leading slash: only the folder in the workspace root |
| `config/credentials.json` | A slash in the middle: anchored to the root, so **only** `<root>/config/credentials.json` |
| `**/config/credentials.json` | `**/` in front: that path below **any** folder |
| `samples/**` | `/**` at the end: everything inside the root's `samples` folder |
| `**/prod-samples/**` | Both: everything inside any `prod-samples` folder, at any depth |
| `src/**/*.esql` | `/**/` in the middle: zero or more folders in between |

The trap is the middle slash. `config/credentials.json` looks as if it reaches every
folder, but it does not. Put `**/` in front of any path that holds a slash.

Negation (`!pattern`) re-includes a file, but not one inside a folder that is already
excluded: `secrets/` followed by `!secrets/readme.md` still hides the readme. If you need
an exception, exclude the folder's files instead of the folder: `**/secrets/*` followed by
`!**/secrets/readme.md`.

These rules are git's. Bob documents its `.bobignore` syntax as identical to `.gitignore`.

A starting point for an ACE or MQ workspace:

```
# Keys, keystores and stash files, in every folder
*.key
*.pem
*.jks
*.p12
*.kdb
*.sth
.env

# Secret folders, in every folder
secrets/
credentials/

# Paths with a slash need **/ to reach every folder
**/.bob/mcp.json

# Real customer payload samples
**/prod-samples/**
```

## B. What Bob's tools touch, and what its commands touch

Bob changes files in two ways, and they are not controlled by the same settings.

**Bob's file tools** (`read_file`, `write_file`, `apply_diff`, `insert_content`,
`search_and_replace`, `list_files`) check `.bobignore` before every operation (in Bob Shell,
for reads only). A separate setting decides whether they may work outside the workspace
root; in Bob IDE it is called "Allow outside workspace tool requests".

**The commands Bob runs** (`execute_command`) are different. Bob checks only a short,
predefined list of file-reading commands, such as `cat` and `grep`, against `.bobignore`.
Any other command, whether a script, `ibmint`, `mqsi*`, `git`, Maven, `npx` or a `>`
redirect, runs with your user rights. It can read, write and delete anywhere the operating
system lets you, inside or outside the workspace. Neither `.bobignore` nor the workspace
setting restricts it.

In ACE work that means:

- `ibmint deploy` and the `mqsi*` commands write to the integration server's work directory,
  which usually sits outside the workspace. `mqsisetdbparms` and `mqsicredentials` write
  credentials into that work directory or into a vault.
- A build or a package install writes to caches in your home directory.
- A local MCP server and a hook both run with your full user permissions. Neither is
  sandboxed.
- The ACE Toolkit itself rewrites `.bob/skills/ace-flowpilot` on startup (see rule 7).

So the controls for commands are approval (rule 3), a denylist for what must never run, the
secrets hook in [C](#c-a-hook-that-blocks-secrets), and a workspace in which everything a
command can reach is something you mean it to reach. For a sensitive project, that is a
dedicated workspace on a machine without production access.

## C. A hook that blocks secrets

Bob runs lifecycle hooks: shell commands at fixed points in a session. Two of them can
block:

- `UserPromptSubmit` runs before your prompt is sent, and receives it as `prompt`.
- `PreToolUse` runs before a tool is approved and executed, and receives `tool_name` and
  `tool_input`.

Bob passes the event as JSON on stdin. Exit code 2 blocks the call, and stderr says why.

Hooks live under the `hooks` key of a settings file. Global hooks, in
`~/.bob/settings/settings.json`, run in every workspace. Workspace hooks, in
`.bob/settings.json`, are added on top for one project. Put the secrets hook in the global
file so that it always runs. A global hook needs an absolute script path; it runs with the
task's workspace as working directory (via `cmd /c` on Windows). An administrator can also
enforce hooks for the whole organisation through the `EnforcedHooks` group policy. Users
cannot override those.

Save this as `~/.bob/hooks/block-secrets.mjs`. It needs Node.js. Bob Shell runs on Node,
so any machine with Bob Shell has it; a machine with only Bob IDE may need Node installed.

```js
// block-secrets.mjs - Bob hook: stops a prompt or tool call that carries a secret.
// Bob passes the event as JSON on stdin; exit code 2 blocks it, stderr says why.
import { readFileSync } from "node:fs";

const event = JSON.parse(readFileSync(0, "utf8"));
const strings = (v) =>
  typeof v === "string" ? [v]
  : v && typeof v === "object" ? Object.values(v).flatMap(strings)
  : [];
const texts = event.hook_event_name === "UserPromptSubmit"
  ? [event.prompt ?? ""]
  : strings(event.tool_input);
const command = event.tool_name === "execute_command"
  ? String(event.tool_input?.command ?? "")
  : "";

const inText = [
  [/-----BEGIN [A-Z ]*PRIVATE KEY-----/, "a private key"],
  [/(password|passwd|pwd|secret|api[_-]?key|token)["']?\s*[:=]\s*["'][^"'\s]{4,}["']/i,
   "a hard-coded secret"],
];
const inCommand = [
  [/mqsisetdbparms\b.*\s-p\s+\S+/, "a password on the mqsisetdbparms command line"],
  [/--(password|client-secret|api-key|passphrase|bearer-token|access-token|refresh-token|secret-access-key)[=\s]+\S+/,
   "a secret on the command line"],
];

const hit = inText.find(([re]) => texts.some((t) => re.test(t)))
  ?? inCommand.find(([re]) => re.test(command));
if (hit) {
  console.error(`Blocked by block-secrets: ${hit[1]}. Keep secrets out of Bob; set them yourself.`);
  process.exit(2);
}
```

Then register it in `~/.bob/settings/settings.json`, with your own home directory in the
path. `PreToolUse` has no `matcher`, so it checks every tool call, including MCP calls, which
is where data leaves your machine.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [ { "type": "command", "command": "node C:/Users/<you>/.bob/hooks/block-secrets.mjs" } ] }
    ],
    "PreToolUse": [
      { "hooks": [ { "type": "command", "command": "node C:/Users/<you>/.bob/hooks/block-secrets.mjs" } ] }
    ]
  }
}
```

What it catches:

- a private key in a prompt, a file write, a diff or an MCP call;
- a quoted password, secret, API key or token literal, such as `"password": "..."` or
  `SET pwd = '...';`;
- a password on an `mqsisetdbparms` command line (`-p`), and a `--password`,
  `--client-secret` or `--api-key` (and similar) on any command line, which covers
  `mqsicredentials`.

What it does not catch:

- a secret that Bob reads from a file: that is what `.bobignore` is for;
- anything a command does after it starts (see [B](#b-what-bobs-tools-touch-and-what-its-commands-touch));
- vault keys on the command line, which it lets through on purpose so that
  `ace-flow-harness` can start a local test server.

To check that it works, send Bob a prompt containing `-----BEGIN RSA PRIVATE KEY-----`.
Bob should refuse to send it and show the hook's message.

It matches patterns, so it is a safety net, not a guarantee. Add a secret scanner as a git
pre-commit hook in every repository (gitleaks, for example) for whatever still gets through.

---

## Before you start on a customer project

- [ ] The customer allows AI-assisted development.
- [ ] A `.bobignore` is in the root of every workspace folder, with `**/` where a path has a slash.
- [ ] The secrets hook is in your global Bob settings.
- [ ] Auto-approve covers reads only, plus an allowlist of specific commands and a denylist.
- [ ] Your MCP servers are listed and trusted, and the ACE MCP Admin Server is off or read-only.
- [ ] Any Flow Pilot download from github.com is allowed, or switched off.
- [ ] A conventions profile exists for the customer's estate.
- [ ] The review and test path is agreed.

## Open for review

- Rule 1: do we require the customer's consent in writing, or is a confirmation by mail
  enough?
- Do we tell the customer when a deliverable was produced with AI assistance, and how?
- Should ID enforce the secrets hook for everyone through the `EnforcedHooks` group policy?

## Sources

- Bob documentation (bob.ibm.com/docs), IDE and Shell: Security guidelines, Ignoring files
  (`.bobignore`), Auto-approve, Approval settings, Lifecycle hooks, Group policies, MCP in
  Bob, FAQ. The hook input fields and the workspace settings path were checked against Bob
  Shell 2.0.6.
- ACE 13.0 documentation: "Developing MCP tools", "Configuring admin MCP tools",
  "Configuring AI skills preferences" and the `mqsicredentials` command.
- API Connect 12.1.1 documentation: "IBM API Connect Flow Pilot for API development".
- [ot4i/ace-flowpilot](https://github.com/ot4i/ace-flowpilot) (latest release v0.0.8,
  2026-09-25).
- Git documentation: [gitignore pattern format](https://git-scm.com/docs/gitignore).
- [general_modes/bob-offload](general_modes/bob-offload/SKILL.md) for the Bobcoins budget and
  headless runs.

---

**Version:** 0.2 (draft)
**Last Updated:** November 2026
