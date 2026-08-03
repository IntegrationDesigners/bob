# Getting Started with Bob Modes

A practical guide to understanding, using, and creating custom Bob modes for your development workflows.

## Table of Contents

1. [What are Bob Modes?](#what-are-bob-modes)
2. [Quick Start](#quick-start)
3. [Using Existing Modes](#using-existing-modes)
4. [Creating Your First Custom Mode](#creating-your-first-custom-mode)
5. [Best Practices](#best-practices)
6. [Troubleshooting](#troubleshooting)
7. [Next Steps](#next-steps)

---

## What are Bob Modes?

Bob modes are specialized AI assistant configurations that provide expert guidance for specific development tasks. Each mode:

- **Focuses on a specific domain** (e.g., ACE integration, code review, documentation)
- **Follows structured workflows** to ensure consistent, high-quality outputs
- **Includes domain expertise** encoded as instructions and reference materials
- **Automates repetitive tasks** while maintaining quality standards

Think of modes as expert colleagues who specialize in different areas - you switch to the right expert for each task.

---

## Quick Start

### Prerequisites

- VS Code with Bob extension installed
- Access to this repository or a copy of the modes you want to use

### Installation

1. **Import modes into your project:**

   ```powershell
   # Windows PowerShell
   .\ace_modes\Import-BobModes.ps1 -SourcePath ".\ace_modes" -TargetProjectPath "D:\Projects\YourProject"
   ```

   The script will:
   - Detect all available Bob modes
   - Create or update `.bob/custom_modes.yaml` in your project
   - Merge modes intelligently, avoiding duplicates

2. **Reload VS Code:**
   - Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (Mac)
   - Type "Reload Window" and press Enter

3. **Verify installation:**
   - Open Bob's mode selector
   - You should see your imported modes listed

---

## Using Existing Modes

### Available Mode Collections

This repository includes several mode collections:

#### ACE Modes (`ace_modes/`)

Specialized modes for IBM App Connect Enterprise development:

- **🏗️ ACE Flow Builder** - Designs and generates message flows, ESQL, and test plans
- **🧭 ACE Flow Designer** - Interviews you about requirements and produces structured specs
- **📄 ACE README** - Generates comprehensive technical documentation
- **🔍 ACE Review** - Performs code quality analysis and reviews

### How to Use a Mode

1. **Select the appropriate mode:**
   - Click the mode selector in Bob's interface
   - Choose the mode that matches your task

2. **Provide context:**
   - Share relevant files or describe your task
   - The mode will guide you through its workflow

3. **Follow the workflow:**
   - Each mode has structured phases
   - Answer questions when prompted
   - Review outputs before proceeding

### Example: Using ACE Flow Builder

```
You: "Build an ACE v13 HTTP flow named OrderProcessor in D:\Projects\MyApp.
Input: POST to /orders, JSON with orderId and items.
Processing: validate against schema, enrich with customer data, calculate totals.
Output: 202 Accepted with confirmation JSON."

Bob (in ace-flow-builder mode): 
[Follows structured workflow to generate .msgflow, .esql, and test files]
```

---

## Creating Your First Custom Mode

### When to Create a Custom Mode

Create a custom mode when you have:

- **Repetitive workflows** - Same analysis/review process multiple times
- **Domain expertise** - Specialized knowledge to encode
- **Structured outputs** - Consistent report formats needed
- **Multi-step processes** - Complex workflows to automate
- **Quality standards** - Specific criteria to enforce

### The 5-Phase Creation Process

#### Phase 1: Define Your Domain

Answer these questions:

1. **What problem does this solve?**
   - Be specific: "Analyze X for Y to produce Z"

2. **What are the inputs?**
   - Required vs optional
   - Expected formats

3. **What are the outputs?**
   - Deliverables and their structure
   - Format requirements

4. **What's the workflow?**
   - Sequential steps
   - Decision points
   - Loops or iterations

**Exercise:** Write a one-paragraph summary:

> "This mode analyzes [domain] by examining [inputs] to identify [issues]. It produces [deliverables] that help [users] make [decisions]. The key value is [automation/consistency/expertise]."

#### Phase 2: Structure Your Workflow

Break your workflow into 3-6 major phases:

```
PHASE 1: Setup & Validation
├── Gather inputs
├── Validate data
└── Set expectations

PHASE 2: Analysis
├── Parse data
├── Run checks
└── Identify issues

PHASE 3: Synthesis
├── Categorize findings
├── Prioritize issues
└── Generate insights

PHASE 4: Reporting
├── Create documents
├── Format outputs
└── Add references

PHASE 5: Quality Check
├── Verify completeness
├── Check consistency
└── Validate accuracy
```

#### Phase 3: Write the Configuration

Create a `.bobmodes` file:

```yaml
customModes:
  - slug: your-mode-name          # lowercase-with-hyphens
    name: 🎯 Display Name         # emoji + readable name
    description: One-line summary # What it does in <100 chars
    
    roleDefinition: >-
      You are an expert in [domain].
      Your expertise includes: [list 3-5 key areas]
      You excel at: [list 3-5 key skills]
    
    whenToUse: >-
      Use this mode when:
      - [Scenario 1]
      - [Scenario 2]
      - [Scenario 3]
    
    groups:
      - read                      # Can read all files
      - - edit                    # Can edit specific files
        - fileRegex: \.(md|txt)$  # Regex for allowed files
          description: What files
      - command                   # Can execute commands
    
    customInstructions: >-
      [Your workflow instructions here]
```

#### Phase 4: Create Templates

Templates ensure consistent outputs:

```markdown
# Document Title

## Metadata
[Project info, dates, versions]

## Executive Summary
[High-level overview]

## Detailed Findings
[Individual findings]

## Recommendations
[Action items]

## References
[Links and docs]
```

#### Phase 5: Document Usage

Essential documentation sections:

1. **Overview** - What the mode does (2-3 sentences)
2. **When to Use** - Specific scenarios
3. **Required Inputs** - What data is needed
4. **Expected Outputs** - What you'll get
5. **Prompt Templates** - Ready-to-use examples (5-10)
6. **Best Practices** - How to prompt effectively
7. **Common Scenarios** - Real-world examples
8. **Troubleshooting** - Common issues

### Example: Simple Code Review Mode

```yaml
customModes:
  - slug: python-review
    name: 🐍 Python Review
    description: Reviews Python code for quality, security, and best practices
    
    roleDefinition: >-
      You are a senior Python developer with expertise in code quality,
      security, and best practices. You review Python code systematically
      and provide actionable feedback.
    
    whenToUse: >-
      Use this mode when:
      - You want to review Python code for quality issues
      - You need security vulnerability checks
      - You want best practices validation
    
    groups:
      - read
      - - edit
        - fileRegex: \.(md|txt)$
          description: Review reports only
    
    customInstructions: >-
      ## PHASE 1: ANALYZE CODE
      
      Read all Python files and identify:
      - Code quality issues
      - Security vulnerabilities
      - Performance concerns
      - Best practice violations
      
      ## PHASE 2: CATEGORIZE FINDINGS
      
      Group findings by:
      - 🔴 CRITICAL: Security issues, data loss risks
      - 🟠 HIGH: Performance problems, maintainability issues
      - 🟡 MODERATE: Code style, minor improvements
      - 🟢 LOW: Suggestions, optimizations
      
      ## PHASE 3: GENERATE REPORT
      
      Create a markdown report with:
      - Executive summary
      - Findings by category
      - Code examples with line numbers
      - Recommended fixes
      - Priority order
```

---

## Best Practices

### Core Principles

1. **Be Explicit, Not Implicit**
   - Clear instructions over vague guidance
   - Specific examples over general descriptions
   - Defined outputs over assumed formats

2. **Optimize for Predictability**
   - Users should know what to provide
   - Users should know what they'll get
   - Consistent structure across runs

3. **Automate What Can Be Automated**
   - File existence checks
   - Pattern matching
   - Data extraction
   - Format validation

4. **Make Outputs Actionable**
   - Every finding should answer: What, Why, Where, How, When
   - Include file/line references
   - Provide concrete examples
   - Prioritize actions

5. **Enable Iteration**
   - Version your outputs
   - Document confidence levels
   - Allow feedback loops
   - Support refinement

6. **No Reference Duplication**
   - One source of truth per reference
   - Variant modes point to parent references
   - Shared content lives in parent mode

### Writing Effective Instructions

Use this pattern for each phase:

```yaml
## PHASE [N]: [PHASE NAME]

### [N.1] [Step Name]
- ALWAYS [mandatory action]
- IF [condition] THEN [action]
- Check for [specific thing]
- Document [what to record]

### [N.2] [Step Name]
For [scenario]:
- [Action 1]
- [Action 2]
- [Action 3]

IMPORTANT: [Critical note or warning]
```

### The 3 Levels of Instruction Clarity

❌ **Level 1: Vague** (Don't do this)
```yaml
- Analyze the data
- Find problems
- Make report
```

⚠️ **Level 2: Basic** (Minimum acceptable)
```yaml
- Analyze input files for errors
- Categorize errors by severity
- Generate markdown report with findings
```

✅ **Level 3: Explicit** (Best practice)
```yaml
- Analyze [specific files] for [specific patterns]:
  * Pattern 1: [what to look for]
  * Pattern 2: [what to look for]
- Categorize findings using severity scale:
  * 🔴 CRITICAL: [definition]
  * 🟠 HIGH: [definition]
  * 🟡 MODERATE: [definition]
  * 🟢 LOW: [definition]
- Generate report using template: templates/[template-name].md
  * Include: [section 1], [section 2], [section 3]
  * Format: [specific format requirements]
```

---

## Troubleshooting

### Common Issues

**Issue: Mode not appearing in selector**
- Solution: Reload VS Code window after importing modes
- Check `.bob/custom_modes.yaml` exists in your project

**Issue: YAML syntax errors**
- Solution: Validate your `.bobmodes` file with the CI pipeline
- Use a YAML validator online
- Check indentation (use spaces, not tabs)

**Issue: Mode produces unexpected outputs**
- Solution: Review your `customInstructions` for clarity
- Add more explicit examples
- Test with simple cases first

**Issue: Mode asks too many questions**
- Solution: Provide defaults in your instructions
- Batch related questions together
- Consider an "iterative" vs "thorough" mode split

### Getting Help

- Review the comprehensive guide: `D:\GIT\bob_modes\How_to_Create_Custom_Bob_Modes.md`
- Check existing modes for examples
- Create an issue in the GitLab repository
- Contact the repository maintainers

---

## Next Steps

### For Users

1. **Explore existing modes** - Try the ACE modes with sample projects
2. **Customize prompts** - Learn what works best for your workflow
3. **Provide feedback** - Help improve modes by reporting issues

### For Mode Creators

1. **Read the full guide** - `D:\GIT\bob_modes\How_to_Create_Custom_Bob_Modes.md`
2. **Study existing modes** - Learn from working examples
3. **Start simple** - Create a basic mode, then iterate
4. **Test thoroughly** - Use real data and edge cases
5. **Document well** - Help others use your mode effectively

### Resources

- **Full Creation Guide**: `D:\GIT\bob_modes\How_to_Create_Custom_Bob_Modes.md`
- **ACE Modes Documentation**: `ace_modes/README.md`
- **Example Modes**: Browse `ace_modes/` directory
- **CI/CD Pipeline**: `.gitlab-ci.yml` for validation

---

## Summary

Bob modes are powerful tools for automating domain-specific workflows. Whether you're using existing modes or creating new ones:

- **Start with clear goals** - Know what problem you're solving
- **Follow structured workflows** - Consistency leads to quality
- **Iterate and improve** - Modes get better with use and feedback
- **Share and collaborate** - Help others benefit from your expertise

**Ready to get started?** Pick a mode from the repository and try it with your next task!

---

**Version:** 1.0
**Last Updated:** June 2026