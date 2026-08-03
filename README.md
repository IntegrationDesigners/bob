# Bob Modes

A curated collection of specialized Bob modes for enterprise integration and development workflows.

## Overview

This repository contains custom Bob modes designed to enhance productivity across various technology domains. Each mode collection provides expert assistance for specific development tasks, from code generation to documentation and review.

## Available Mode Collections

### 🔧 ACE Modes (`ace_modes/`)

Specialized modes for IBM App Connect Enterprise (ACE) development:
- **ace-readme** - Technical documentation generator
- **ace-flow-builder** - Message flow builder and generator
- **ace-flow-designer** - Requirements gathering and design
- **ace-review** - Code review and quality analysis (git-scoped incremental reviews, tailorable via custom rules)
- **cve-analysis** - Exploitability assessment of CVEs and IBM security bulletins for ACE and MQ (affected vs exploitable, component mapping, batch triage, persistent decision log)

[View detailed ACE modes documentation →](ace_modes/README.md)

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

### Installation

Use the provided PowerShell script to import modes into your projects:

```powershell
.\Import-BobModes.ps1 -SourcePath ".\ace_modes" -TargetProjectPath "D:\Projects\YourProject"
```

The script will:
- Detect all available Bob modes
- Create or update `.bob/custom_modes.yaml` in your project
- Merge modes intelligently, avoiding duplicates

After importing, reload your VS Code window to activate the new modes.

### Usage

1. Import the modes you need into your project
2. Open Bob's mode selector in VS Code
3. Choose the appropriate mode for your task
4. Follow the mode's guided workflow

## Repository Structure

```
bobmodes/
├── README.md                    # This file
├── Import-BobModes.ps1          # Mode import utility
├── ace_modes/                   # ACE integration modes
│   ├── README.md               # Detailed ACE modes documentation
│   ├── Import-BobModes.ps1     # ACE-specific import script
│   ├── ace-readme/             # Documentation generator mode
│   ├── ace-flow-builder/       # Flow builder mode
│   ├── ace-flow-designer/      # Flow designer mode
│   └── ace-review/             # Code review mode (review/ + custom-rules/rules.md)
└── [future mode collections]/
```

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
**Last Updated:** June 2026