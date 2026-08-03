# General Bob Modes

This directory contains Bob modes that are not tied to IBM App Connect Enterprise. They cover general developer and advocacy workflows and live in their own collection so the `ace_modes/` collection stays purely ACE.

## Available Modes

### 🏅 IBM Champion Report (`ibm-champion-report`)

**Purpose:** Assembles an IBM Champion (or Rising Champion) **act of advocacy** submission for the IBM Champion Program Activity Report form (the Airtable form behind `ibm.biz/champ-report`). It produces a proven prefilled-form URL plus a copy-paste field sheet - it never ticks the consent checkbox and never submits; you do the final review and click.

**When to use:**
- You want to report or register an IBM Champion activity / act of advocacy
- You want to "fill in the champ-report form" or mention `ibm.biz/champ-report`
- You want to log a blog, talk, video, idea, or code contribution for a Champion badge

**What it does:**
- **Load identity** - reads your stable identity (Champion Program ID, name, emails) from a private, gitignored `.env` (copy `.env.sample` once)
- **Gather the activity** - one act at a time: what you did, the Act-of-Advocacy type, the product(s), a link (effectively mandatory), the date, and whether IBM may amplify it
- **Write the description** - drafts each "Description of this Activity" for a reviewer who has not seen the work, factual and within the 250-word limit, and reports the word count
- **Confirm the dropdowns** - the Act-of-Advocacy (40) and Product(s) (516) option lists are verified verbatim from the live form; the mode picks the exact entry and confirms it with you
- **Produce the output** - a prefilled URL that lands 8 fields via verified field-ID / name params, plus a copy-paste sheet for the fields that cannot be prefilled (Description, Link, Amplify, How-many-more, PRIVACY)

**Key features:**
- The authoritative field spec (field-ID prefill map, date format, word limits, full verified option lists) lives in `references/form_fields.md`
- If a browser MCP is available it can fill the form in place and verify - but it never submits

**One-time setup (`.env`):** copy `.env.sample` to `.env` in the mode folder and fill in your real values once (`CHAMPION_PROGRAM_ID`, `FIRST_NAME`, `LAST_NAME`, `PRIMARY_EMAIL`, `ALTERNATE_EMAIL`). `.env` is gitignored and stays private; only `.env.sample` (placeholders) is committed.

**Location:** `ibm-champion-report/`

---

### ⚒️ Prompt Forge (`prompt-forge`)

**Purpose:** Turns a rough idea or brain dump into a clean, model-tuned prompt you can paste into a fresh Claude session. Its deliverable is **the prompt, not the task's output** - if you want the work done, just ask for the work.

**When to use:**
- You want a prompt written ("write me a prompt for X", "turn this into a prompt")
- You want an existing prompt cleaned up or tuned for a specific model
- You want to be questioned until the prompt is clear
- You have a messy task description that should be shaped rather than executed

**What it does:**
- Runs a five-stage spine - capture, clarify, structure, tune, iterate - that pins down the five things a model cannot guess: goal, context, inputs, output shape, and success criteria
- Clarification is gated and batched: one short round of questions that would actually change the prompt, not an interrogation
- Tunes the same task spec differently per target model, because **capability and steering trade off**: a capable model wants the outcome specified and latitude on the how, while a smaller one wants the steps, the format, and the examples spelled out
- Optional passes when the material calls for them: a voice pass, an anti-AI de-slop pass, a next-chat handoff document, and bottling a reused prompt into a skill

**Key features:**
- Per-model steering profiles and prompt anatomy in `references/model_tuning.md`
- Clarify question bank, task-spec template, and voice/de-slop passes in `references/clarify_and_polish.md`
- Asks which model the prompt is for; if you do not know, it picks a sensible default and tells you what it assumed

**Location:** `prompt-forge/`

---

## File Structure

Each mode directory contains:
- `.bobmodes` - Mode definition file (configuration for Bob)
- `SKILL.md` - Detailed skill documentation (optional, for reference)
- `references/` - Reference files, templates, and guidelines used by the mode
- `.env.sample` - template for private per-user facts (where applicable). Copy to `.env` and fill in; `.env` is gitignored and must never be committed

---

## Importing Modes into Bob

Use the PowerShell script at the repository root; it scans recursively for `.bobmodes` files:

```powershell
.\Import-BobModes.ps1 -SourcePath ".\general_modes" -TargetProjectPath "D:\Projects\YourProject"
```

After running the script, reload your VS Code window (Ctrl+Shift+P → "Reload Window") to activate the new modes. For global vs local setup details, see [ace_modes/README.md](../ace_modes/README.md#importing-modes-into-bob) - the process is identical.

---

*Last Updated: August 2026*
