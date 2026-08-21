# Skills in Bob

How Bob finds the skills in this repository, what changes when you work in a VS Code
*workspace* instead of a single project folder, and how to install them.

Verified against **IBM Bob 2.0.3** (`bob-code` extension, Bob-IDE): the paths and rules below
were read out of the extension's own skill loader and confirmed in Bob's runtime log, not
inferred from Claude Code's behaviour.

---

## Modes and skills come from the same folder

Every folder under `ace_modes/` and `general_modes/` ships up to two entry points for the
same workflow. They are different mechanisms and they install differently.

| | Bob mode | Skill |
|---|---|---|
| File | `.bobmodes` | `SKILL.md` |
| Installed as | an entry in `custom_modes.yaml` | a folder containing `SKILL.md` |
| Chosen by | you, from the mode selector | Bob, when the description matches your request - or you, by name |
| Installed with | `Import-BobModes.ps1` | `scripts/Install-Skills.ps1` |
| Picked up | after a window reload | immediately (the directories are watched) |
| Also works in | Bob | Bob **and** Claude Code |

`ace-readme` currently ships as a Bob mode only - it has no `SKILL.md`, so the skill
installers list it and skip it.

---

## Where Bob looks for skills

In this order. The first definition of a name wins, so a workspace skill shadows a global one
of the same name, and `~/.bob` shadows `~/.claude`.

| Scope | Path | Notes |
|---|---|---|
| Workspace | `<workspace folder>/.bob/skills/<name>/SKILL.md` | also `.bob/<group>/skills/<name>/SKILL.md` |
| Workspace | `<workspace folder>/.agents/skills/<name>/SKILL.md` | |
| Workspace | `<workspace folder>/.claude/skills/<name>/SKILL.md` | shared with Claude Code |
| Global | `~/.bob/skills/<name>/SKILL.md` | `%USERPROFILE%` on Windows |
| Global | `~/.agents/skills/<name>/SKILL.md` | |
| Global | `~/.claude/skills/<name>/SKILL.md` | shared with Claude Code |

Two consequences worth knowing:

- **If you already use Claude Code, Bob can see those skills already.** `~/.claude/skills` is
  on Bob's global list. Installing again into `~/.bob/skills` is only needed if you want the
  skills to outlive Claude Code, or want them to win a name collision.
- **Globally, one grouping level is allowed:** `~/.bob/skills/<group>/<name>/SKILL.md` is
  found (the group folder is just a container - the skill's name is still `<name>`). Inside a
  project, it is not: `.bob/skills/<name>/` must be exactly one level deep.

Bob's own built-in skills sit at the bottom of the pile - a skill of the same name from any
of the directories above overrides them.

---

## What "workspace" means here - the multi-root answer

A VS Code *workspace* (`.code-workspace`) can hold several root folders. Bob does not read the
`.code-workspace` file at all. It works with the **workspace folders** VS Code reports, and a
Bob task is bound to exactly one of them:

- With one folder open, that folder is the task's root.
- With several, **New Task** asks *"Select a workspace to start a new Task"* first. Whatever
  you pick is the task's root for its whole life.

Skills are filtered by that root: only skill files **under the task's folder** count as
workspace skills. So in a workspace with `libs/` and `services/`, a skill installed into
`libs/.bob/skills/` is invisible to a task you started in `services/`. The Settings > Skills
list shows workspace skills per folder, which is why a skill can be listed there and still not
be available in the task you are running.

Two more workspace-scope conditions:

- **The workspace must be trusted.** In an untrusted window Bob drops every workspace-scoped
  skill and keeps only the global and built-in ones.
- **A blanket `.bob/` line in the project's `.gitignore` can hide them.** Bob builds the
  exclude list for its own file search from `.gitignore` and `.bobignore`, so the initial scan
  can skip the very directory the skills live in. Ignore the noisy subfolders instead
  (`.bob/tasks/`, `.bob/.bob-errors/`) and keep `.bob/skills/` visible. The install scripts
  warn when they spot this.

**So: if you work in a multi-root workspace, install globally.** `~/.bob/skills` is the same
for every folder, every workspace and every window - nothing to pick, nothing to duplicate.
Use a project install only when you want a skill to travel with one repository.

---

## The name is the folder name

Bob takes a skill's identity from **the folder it sits in**, not from the `name:` in the
frontmatter. The rules it enforces:

- kebab-case: `^[a-z0-9]+(-[a-z0-9]+)*$` - lower-case letters, digits and single hyphens
- at most 64 characters
- not `builtin`, `global` or `workspace`

A folder that breaks those rules is dropped **in silence**: no error, no entry in the skill
list. A folder named `flow_builder` never loads, however correct its `SKILL.md` is. And a
folder whose name merely *differs* from the frontmatter loads under the folder name, so you
end up typing one name while every document describes another.

That is why this repository keeps folder name, `SKILL.md` `name:` and `.bobmodes` `slug:`
identical, and why the installers refuse to install anything at all when they diverge.

---

## Installing

### Windows (PowerShell)

```powershell
.\scripts\Install-Skills.ps1 -WhatIf              # preview, changes nothing
.\scripts\Install-Skills.ps1                      # junction all skills into ~\.bob\skills
.\scripts\Install-Skills.ps1 -Agent Both -Prune   # also ~\.claude\skills, drop renamed leftovers
.\scripts\Install-Skills.ps1 -Name ace-review     # just one skill
.\scripts\Install-Skills.ps1 -ProjectPath D:\Projects\MyApp -Name ace-review
                                                  # copy one skill into that project
```

### macOS / Linux (bash)

```bash
./scripts/install-skills.sh --dry-run
./scripts/install-skills.sh
./scripts/install-skills.sh --agent both --prune
./scripts/install-skills.sh --project ~/dev/myapp --name ace-review
```

### By hand

```bash
cp -r ./ace_modes/ace-review ~/.bob/skills/ace-review
```

The destination folder name is the skill's identity - it must match the `name:` in its
`SKILL.md`.

### Junction/symlink or copy

| | Link (junction on Windows) | Copy |
|---|---|---|
| Default for | a global install | a project install |
| Edits in this repository | live immediately | need a re-run of the installer |
| Survives moving/deleting this clone | no | yes |
| Can be committed to a project | no | yes |

A copy into a project deliberately leaves `.env` files, `log/` directories and
`customer_profile.md` behind - those hold real customer or personal detail.

### What the installers do and do not touch

- They validate first and install nothing if any skill's name has drifted.
- Entries they did not create - a real directory from a marketplace, a link pointing outside
  this repository - are left alone and reported, never overwritten.
- Anything they do replace is moved to `skills-backup/` beside the skills directory, never
  deleted.
- `-Prune` / `--prune` removes links into this repository whose skill no longer exists (the
  leftovers of a rename). Copies are never pruned: a copy is indistinguishable from a skill
  someone installed by hand.

---

## After installing

Bob watches the skill directories and picks changes up without a restart, including a new
skill folder appearing. If a skill does not show up under **Settings > Skills**, reload the
window (`Ctrl+Shift+P` -> *Developer: Reload Window*).

Claude Code enumerates skills once at session start - start a new session there.

| Symptom | Likely cause |
|---|---|
| Skill missing everywhere | folder name is not kebab-case, or has no `SKILL.md` |
| Skill missing in one root of a multi-root workspace | project-scoped install in a different root - install globally |
| Skill listed in Settings but never used in a task | task started in another workspace folder |
| Only global skills present | workspace not trusted |
| Project skills not found on a fresh window | `.gitignore` excludes `.bob/` wholesale |
| Wrong version of a skill runs | a workspace skill, or `~/.bob/skills`, shadows the copy you edited |

---

## Modes, for completeness

Modes follow the same scoping story but a different file:

| Scope | Path |
|---|---|
| Workspace | `<workspace folder>/.bob/custom_modes.yaml` (also `.bob/<group>/custom_modes.yaml`) |
| Global | `~/.bob/settings/custom_modes.yaml` |

`Import-BobModes.ps1` writes the workspace file:

```powershell
.\Import-BobModes.ps1 -SourcePath ".\ace_modes" -TargetProjectPath "D:\Projects\YourProject"
```

Editing a `.bobmodes` here changes nothing by itself - re-run the import, then reload the
window. For a multi-root workspace, either import into each root you work in, or paste the
mode definitions into the global `custom_modes.yaml` once.
