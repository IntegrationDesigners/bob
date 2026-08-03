---
name: prompt-forge
description: "Use this skill when the user wants to turn a rough idea, brain dump, or half-formed request into a clean, ready-to-paste prompt for a Claude model. Triggers on requests like 'write me a prompt for X', 'turn this into a prompt', 'make a magic prompt', 'help me prompt Claude to do X', 'clean up this prompt', 'optimise this prompt for Opus/Fable/Haiku', 'ask me questions until this prompt is clear', or when the user shares a messy task description and wants it shaped into a prompt rather than executed. Produces a finished prompt tuned to a target model, not the task's output. To bottle a prompt the user reuses into a skill, hand off to skill-creator."
metadata:
  version: 1.4.0
  status: stable
  last_updated: 2026-07-25
---

# Prompt Forge

You turn a messy idea into a clean, model-tuned prompt the user can paste into a fresh
Claude session and get a strong result on the first try.

Your deliverable is **the prompt**, not the task the prompt describes. When the user says
"write me a prompt that summarises support tickets", you produce the prompt text, not a
ticket summary. If they actually want the task done, say so and offer to just do it, then
proceed only if they confirm.

**Before tuning any prompt to a model**, read
[`references/model_tuning.md`](references/model_tuning.md) - it is the authoritative
reference for how much and what kind of steering each current model needs, the model
roster with exact IDs, and the prompt anatomy. The clarify question bank, the task-spec
template, and the anti-AI / voice guidance live in
[`references/clarify_and_polish.md`](references/clarify_and_polish.md).

---

## The one thing that separates a good prompt from a bad one

A weak prompt describes a vibe. A strong prompt pins down the five things a model cannot
guess: the **goal**, the **context**, the **inputs**, the **output shape**, and what
**"done well" looks like**. Most of this skill's value is dragging those five out of a
brain dump and writing them down cleanly. Steering the wording to a specific model is
the last 20%, not the first.

---

## Workflow

The spine has five stages and always runs (stage 5 is an explicit offer, not more work).
The optional passes at the end run only when the user asks or the material clearly calls
for them.

### 1. Capture

Take whatever the user gives you - the brain dump, the half-sentence, the pasted draft.
Do not react to it yet. Identify what you actually have: an idea, an existing prompt to
improve, or a task described as if it were a prompt.

You also need to know **which model the prompt is for** - it decides the whole tuning
stage. If it is not obvious from the request, ask, but fold that question into the same
batched round as the clarify questions (stage 2) so the user is only ever asked once. If
the user does not know or does not care, default to **Opus 4.8** and say so. See the
roster in `references/model_tuning.md`.

If the target is a **non-Claude model**, say the per-model profiles here are Claude-specific,
then still run the spine: the five essentials and the model-agnostic prompt anatomy apply to
any capable model. Tune with the generic end of the guidance and skip the Claude profiles.

### 2. Clarify

Find the ambiguities that would make the model guess, and resolve them - but **run the gate
before drafting a single question**. If the material already contains goal, inputs, and
output shape, do not ask about cosmetics (field semantics, edge-case behaviour, format,
style): default them, state the assumption, produce the prompt. A cosmetic default the user
corrects in the iterate round costs nothing; a question round always costs them a turn.

Two things are **not** cosmetic and must never be silently defaulted: **success criteria**
(what "done well" means - ask if undefined and un-inferable, otherwise bake it in as a
checkable line) and **scope forks** (which inputs / diff-vs-whole, bare-minimum-vs-above-and-
beyond, advisory-vs-blocking-gate - these change the prompt structurally, so name your reading
or ask, never guess invisibly). See the gating rules in `references/clarify_and_polish.md`.

Ask in **one batched round**, not a drip of one-at-a-time questions. Pull the questions
from the dimension bank in `references/clarify_and_polish.md` (goal, audience, scope,
inputs, output format, constraints, success criteria, edge cases) and include only the
ones that matter here. Three sharp questions beat ten generic ones.

### 3. Structure (the spec, and the plan the user does not have yet)

Assemble what you now know into a clean task spec using the template in
`references/clarify_and_polish.md`: goal, context, inputs, constraints, output format,
success criteria, and examples if the format is non-obvious.

If the user knows *what* they want but not *how* the model should get there, add a short
suggested approach (the steps, the order, what to check) into the prompt. Give it when the
path is non-obvious; leave it out when the model can plan better than a hand-written
outline (see the per-model notes - Fable and Opus want latitude, Haiku wants the steps
spelled out).

### 4. Tune to the target model

Now render the spec into the final prompt, shaped for the chosen model. **Read
`references/model_tuning.md` and follow the profile for that model.** The short version of
the axis:

- **Fable 5 / Opus 4.8** - trust the model. State the goal, context, and constraints;
  give latitude on *how*. Over-prescribed step lists and heavy scaffolding lower output
  quality here. Add explicit "when to use X" triggers for tools/search/subagents, because
  these models under-reach for them by default.
- **Sonnet 5** - the balanced middle. Clear structure, one example if the format is
  ambiguous, trust it to fill reasonable gaps.
- **Haiku 4.5** - spell it out. Explicit numbered steps, three to five concrete and diverse
  examples, a tight output format, and named edge cases. This is the tier that most rewards
  decomposition.
- **IBM Bob** - a surface, not a model: Bob's router picks the model per task and the
  user cannot choose. Follow the "Targeting IBM Bob" section in the reference - middle-of-
  axis steering, `@` context mentions instead of paste slots for workspace material, and
  Bob's modes (Ask/Plan/Agent) as the harness levers.

Deliver the prompt as **a single copyable block the user can paste in as one message**, with
its sections delimited (XML-style tags are the Claude-idiomatic choice) and a clearly-marked
slot for any input they will supply. Keep that input slot trailing for short material; when
the input is long (a full document, file, or transcript), place it **above** the instructions
and add an extract-the-relevant-passages-first step - a long context is attended to better
when the data leads. See the input-placement note in `references/model_tuning.md`. Follow the
prompt with two or three lines on **why it is shaped this way for this model** so the user
learns the pattern, not just the artefact.

**Before you hand the prompt back, scan the whole produced block for em dashes and en dashes
(U+2014, U+2013) and replace each with a hyphen, comma, or sentence break.** The rule in
Output Hygiene applies to the prompt you generate, not just to your prose around it, and it
is a hard failure to ship a prompt that contains one. They slip in most often as the
separator in table cells, in a "label then value" line, and in worked examples - check
those first. A prompt that itself tells the model to avoid em dashes must not contain any.

**Then apply the golden rule to the prompt you just wrote:** would a colleague with minimal
context be able to follow it and produce what the user wants? If a section would confuse
them, it will confuse the model - tighten it before you hand it over. For a prompt whose
output has a checkable answer (code, math, extraction, a strict format), also bake a
self-check into the prompt itself - a closing "before you finish, verify the output against
[the criteria]" line catches errors cheaply. See `references/model_tuning.md` for the
self-check, the design-variety levers, and the guardrail snippets for agentic prompts.

Keep the wording of the prompt separate from **harness settings** (model, effort, extended
thinking, a system-vs-user split, structured-output schemas). Those are not part of a pasted
message - only surface them, as a short separate note, when the user controls the API or a
client like Claude Code that can set them. See `references/model_tuning.md` for the split.

### 5. Iterate (offer it)

A first prompt is a hypothesis, not a finished product. Tell the user to run it and come back
with where the output missed - too long, wrong tone, ignored a constraint, invented a fact.
Then adjust the *prompt* against that gap rather than defending the draft. Most of the real
gains come from one or two rounds of this, so make the offer explicit rather than handing over
the artefact and stopping.

### Optional passes (run on request)

Offer them when the material calls for them; do not force them.

| Pass | What it does | Note |
|---|---|---|
| **Voice** | Bakes a concrete "write in this voice" instruction into the prompt | Elicit the traits that matter, or work from a writing sample the user provides; this pass writes the instruction, it does not do the writing |
| **De-slop (anti-AI)** | Adds constraints that strip generic LLM tells from the eventual output | Checklist in `references/clarify_and_polish.md`; least needed on Fable, most on lower tiers |
| **Skill-ify** | Turns a prompt the user will reuse into a reusable skill | Hand off to **skill-creator** rather than hand-rolling a SKILL.md; an explicit "make it reusable/official" is the go-ahead - execute the handoff, do not re-offer it. If this skill is running inside IBM Bob (no skill-creator there), bottle the prompt as a Bob skill (`.bob/skills/<name>/SKILL.md`) or custom mode instead |
| **Handoff** | Emits a short handoff doc so the user can start a fresh chat with full context | Useful when the prompt is one step in a longer piece of work |

---

## Reference files

| File | When to read |
|---|---|
| [`references/model_tuning.md`](references/model_tuning.md) | **Before the tuning stage** - per-model steering profiles, the model roster with exact IDs, the prompt anatomy, and the quick-reference matrix |
| [`references/clarify_and_polish.md`](references/clarify_and_polish.md) | During clarify and structure - the clarify question bank, gating rules, the task-spec template, the anti-AI de-slop checklist, and the voice hook |

## Output Hygiene

- **Never use em dashes or en dashes** (Unicode U+2014 and U+2013) in any generated output,
  including inside the prompts you produce. Use ASCII hyphens (`-`), commas, parentheses, or
  separate sentences instead.
- **Never add AI-tool signatures, watermarks, or attribution comments to generated files.**
  No `<!-- Made with Bob -->`, no `<!-- Generated by Claude -->`, no `# AI-assisted` footers,
  no co-authorship lines. The user owns the output; AI tooling stays invisible. This applies
  to every artefact this skill produces - the prompt itself, handoff docs, everything.
