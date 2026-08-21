# Bob Modes

A curated collection of specialized Bob modes for enterprise integration and development workflows.

## Overview

This repository contains custom Bob modes designed to enhance productivity across various technology domains. Each mode collection provides expert assistance for specific development tasks, from code generation to documentation and review.

Most of them ship in two forms from the same folder: a **Bob mode** (`.bobmodes`, which you pick from the mode selector) and a **skill** (`SKILL.md`, which Bob selects itself when your request matches, and which Claude Code can use too). They install differently - see **[SKILLS.md](SKILLS.md)** for where Bob looks, what a multi-root VS Code workspace means for skill scope, and the naming rule that decides whether a skill loads at all.

## Available Mode Collections

### 🔧 ACE Modes (`ace_modes/`)

Specialized modes for IBM App Connect Enterprise (ACE) development:
- **ace-readme** - Technical documentation generator
- **ace-flow-builder** - Message flow builder and generator
- **ace-flow-designer** - Requirements gathering and design
- **ace-flow-harness** - End-to-end deploy-and-test execution: installs dependencies, provisions the environment, deploys with ibmint, starts the server, drives the flow, and verifies results via executable scripts
- **ace-conventions-profiler** - Extracts the house-style conventions of an existing ACE estate into a reusable profile that ace-flow-builder conforms to
- **ace-review** - Code review and quality analysis (git-scoped incremental reviews, tailorable via custom rules)
- **cve-analysis** - Exploitability assessment of CVEs and IBM security bulletins for ACE and MQ (affected vs exploitable, component mapping, batch triage, persistent decision log)
- **ace-support-case** - IBM support-case preparation: guided diagnostic collection (aceDataCollector, traces, abend files) and a ready-to-paste case submission

[View detailed ACE modes documentation →](ace_modes/README.md)

### 🧰 General Modes (`general_modes/`)

Modes for general developer and advocacy workflows, not tied to ACE:
- **ibm-champion-report** - assembles an IBM Champion act-of-advocacy submission: prefilled champ-report form URL plus a copy-paste field sheet (never auto-submits)
- **prompt-forge** - turns a rough idea or brain dump into a clean prompt tuned for a specific target model; the deliverable is the prompt, not the task's output

[View detailed general modes documentation →](general_modes/README.md)

## Getting Started

### 📚 New to Bob Modes?

If you're new to Bob modes or want to learn how to create your own, start here:

**[→ Getting Started Guide](GETTING_STARTED.md)**

This comprehensive guide covers:
- What Bob modes are and how they work
- Using existing modes effectively
- Creating your first custom mode
- Best practices and troubleshooting
- Real-world examples and templates

### Quick Start

### Installing the skills

Skills are discovered from a skills directory, and the folder name there is the skill's
identity. Install them globally - one command, and they are available in every folder, every
workspace and every window:

```powershell
.\scripts\Install-Skills.ps1 -WhatIf    # preview, changes nothing
.\scripts\Install-Skills.ps1            # junction every skill into %USERPROFILE%\.bob\skills
```

```bash
./scripts/install-skills.sh --dry-run     # macOS / Linux
./scripts/install-skills.sh
```

The script junctions (or copies) each skill into `~/.bob/skills`, refuses to install anything
if a folder name, `SKILL.md` `name:` and `.bobmodes` `slug:` disagree, leaves skills from
other sources alone, and backs up - never deletes - anything it replaces. Add
`-ProjectPath <path>` / `--project <path>` to install into a single project instead, and
`-Agent Both` / `--agent both` to cover `~/.claude/skills` as well.

**Working in a multi-root VS Code workspace?** Install globally. A project-scoped skill only
applies to tasks started in that one workspace folder, and Bob binds each task to a single
folder. [SKILLS.md](SKILLS.md) explains the whole discovery model.

### Installing the modes

Use the PowerShell script to import modes into a project:

```powershell
.\Import-BobModes.ps1 -SourcePath ".\ace_modes" -TargetProjectPath "D:\Projects\YourProject"
```

The script will:
- Detect all available Bob modes
- Create or update `.bob/custom_modes.yaml` in your project
- Merge modes intelligently, avoiding duplicates

After importing, reload your VS Code window to activate the new modes. A `.bobmodes` edit
alone changes nothing - re-run the import first.

### Usage

1. Install the skills, or import the modes you need into your project
2. Describe your task - Bob picks a matching skill on its own, or you name it
3. For a mode, open Bob's mode selector in VS Code and choose it
4. Follow the guided workflow

## Repository Structure

```
bob/
├── README.md                    # This file
├── SKILLS.md                    # Skill discovery, workspace scope, installation
├── Import-BobModes.ps1          # Mode import utility
├── scripts/
│   ├── Install-Skills.ps1      # Skill installer (Windows)
│   └── install-skills.sh       # Skill installer (macOS / Linux)
├── ace_modes/                   # ACE integration modes
│   ├── README.md               # Detailed ACE modes documentation
│   ├── Import-BobModes.ps1     # ACE-specific import script
│   ├── ace-readme/             # Documentation generator (Bob mode only, no SKILL.md)
│   ├── ace-flow-builder/       # Flow builder
│   ├── ace-flow-designer/      # Flow designer
│   ├── ace-flow-harness/       # Deploy-and-test harness (provisions, deploys, runs, verifies)
│   ├── ace-conventions-profiler/ # House-style conventions extractor (profile for flow-builder)
│   ├── ace-review/             # Code review (custom-rules/rules.md)
│   ├── cve-analysis/           # CVE / security-bulletin exploitability assessment
│   └── ace-support-case/       # IBM support-case diagnostics and submission
├── general_modes/               # Modes not tied to ACE
│   ├── README.md               # Detailed general modes documentation
│   ├── ibm-champion-report/    # IBM Champion activity report builder
│   └── prompt-forge/           # Model-tuned prompt builder
└── [future mode collections]/
```

Each mode folder holds a `.bobmodes` (the Bob mode), usually a `SKILL.md` (the skill entry
point), and a `references/` directory with the workflow and guideline files it loads on
demand. The folder name is the skill's identity: it must match the `SKILL.md` `name:` and the
`.bobmodes` `slug:`, and the installers refuse to run when it does not.

## Contributing

### Contribution Policy

**All contributions must follow the feature branch workflow:**

1. **Fork the repository** OR **create a feature branch** from `main`
2. Make your changes in the feature branch
3. Submit a merge request for review
4. Wait for approval before merging

**Direct commits to `main` are not allowed.**

### Feature Branch Workflow

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
git add .
git commit -m "Description of changes"

# Push to remote
git push origin feature/your-feature-name

# Create a merge request in GitLab
```

### Contribution Guidelines

- Follow the existing mode structure and conventions
- Include comprehensive documentation for new modes
- Test modes thoroughly before submitting
- Update relevant README files
- Use clear, descriptive commit messages

## Important Disclaimers

### ⚠️ AI-Generated Content

**Always review and validate the output from Bob modes.** These modes use AI assistance, which can:
- Make mistakes or generate incorrect code
- Misinterpret requirements
- Produce outputs that need refinement
- Miss edge cases or specific business rules

**You are responsible for:**
- Reviewing all generated code and documentation
- Testing implementations thoroughly
- Validating against your specific requirements
- Ensuring compliance with your organization's standards

### 🔒 Security Considerations

- Never commit sensitive information (credentials, API keys, etc.) to mode configurations
- Review generated code for security vulnerabilities
- Follow your organization's security policies and guidelines
- Use appropriate access controls for mode configurations

### 📋 Quality Assurance

- Generated code should be treated as a starting point, not a final product
- Always perform code reviews on AI-generated content
- Test thoroughly in non-production environments first
- Validate against your organization's coding standards

## Support and Feedback

For questions, issues, or suggestions:
- Create an issue in the GitLab repository
- Refer to individual mode documentation for specific guidance

## License

Refer to your organization's policies regarding code reuse and distribution.

---

**Version:** 1.0
**Last Updated:** August 2026