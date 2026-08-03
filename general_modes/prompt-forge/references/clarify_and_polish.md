# Clarify and polish reference

Everything the spine needs during the clarify and structure stages: the clarify question
bank, the gating rules that stop clarification becoming an interrogation, the task-spec
template, and the optional voice and anti-AI passes.

---

## Clarify question bank, by dimension

Pull from these. Include only the questions whose answer would actually change the prompt.
Rephrase them to the user's material - do not read the bank aloud.

| Dimension | The questions to consider |
|---|---|
| **Goal** | What is the single outcome? What does the user do with the result? What would make this a failure? |
| **Audience** | Who reads the output - the user, an end user, a machine? What do they already know? |
| **Scope** | What is in, and what is out? Which inputs exactly - all of X, or only what changed (the diff)? How big is one run (one item, a batch, an ongoing job)? Bare-minimum output, or go above and beyond? Advisory report, or a blocking gate? |
| **Inputs** | What material does the model get? What form is it in? Is it pasted, referenced, or fetched? Can it be missing or malformed? |
| **Output format** | Prose, list, table, JSON, code, a file? How long? Any fixed template or schema? |
| **Constraints** | Hard rules, tone, things to avoid, length caps, forbidden actions? |
| **Success criteria** | How does the model know it did well? Is there a checkable property ("valid JSON", "under 200 words", "cites a source per claim")? |
| **Edge cases** | Empty input, ambiguous input, conflicting instructions, out-of-scope requests - what should happen? |

Aim for **three sharp questions**, not ten generic ones. Format and edge cases are usually
defaultable; **success criteria and scope forks are the ones that must be surfaced** (asked
or named as an explicit assumption), never silently guessed - see the gating rules below.

### Gating rules (when NOT to ask, and what you must never bury)

**Run the gate before opening the question bank, not after.** The bank is a menu of what
*could* be unclear; the gate decides whether you are allowed to ask at all. It has two
failure modes, not one: **over-asking** (interrogating when you could default) and
**silently defaulting a fork that changes what the prompt does**. The gate stops both.

- **Hard gate on cosmetics:** if the material contains goal, inputs, and output shape, do
  not ask about field semantics, edge-case behaviour, format, severity labels, or style -
  those are defaultable. Pick the sensible default, state it as a named assumption, produce
  the prompt. The user corrects a wrong cosmetic default in the iterate round for free; a
  question round always costs a turn.
- **Two things are NOT cosmetic - surface them, never default them invisibly:**
  - **Success criteria.** "What good looks like" is what the whole prompt is judged
    against, not a format detail. If it is genuinely undefined and you cannot infer it with
    confidence, that is a real fork worth one question. If you can infer it, bake it into
    the prompt as an explicit, checkable success line ("valid JSON", "under 200 words",
    "cites a source per claim") - not a silent guess.
  - **Scope forks.** These change the prompt structurally, so a wrong silent guess wastes a
    whole run: *which inputs* (the whole tree vs the PR diff; the service vs the changed
    files), *ambition level* (bare-minimum vs go-above-and-beyond - one modifier swings the
    output enormously and the model cannot guess it), and *gate vs advisory* (a blocking
    verdict vs a findings report). When the request hints at one - "before we merge a PR"
    points at the diff, "audit" hints gate - name your reading as a stated assumption, or
    ask if you cannot infer it. Never let it default invisibly.
- The user said "just make something reasonable" or is clearly in a hurry: default and
  state, but still name any scope or success assumption you made.

Never ask a question whose answer you could infer with reasonable confidence - but for
scope and success, "inferred" means *stated*, not silent. Over-asking offloads your own
thinking; silently defaulting a structural fork ships the wrong prompt. Avoid both.

---

## Task-spec template

Assemble the answers into this before writing the final prompt. It is scaffolding for you,
not necessarily the literal shape of the prompt (the model profile decides how much of it
survives into the prompt text).

```
GOAL:        <the one outcome>
CONTEXT:     <background the model needs and would otherwise invent>
TASK:        <the request, stated once>
INPUTS:      <what it works on / where the material appears>
CONSTRAINTS: <hard rules; do X not Y; length; tone; forbidden actions>
OUTPUT:      <exact shape of the answer>
SUCCESS:     <how "done well" is checked>
EXAMPLES:    <none, or 3-5 diverse ones covering edge cases, if format/judgement is non-obvious>
APPROACH:    <optional suggested steps, if the path is non-obvious and the model wants them>
```

Then hand the spec to [`model_tuning.md`](model_tuning.md) to render it into the final,
model-shaped prompt.

---

## Optional pass: voice

When the user wants the eventual output to sound like them (or like a specific target
voice), bake a voice instruction into the prompt. This skill only *writes the instruction*;
it does not do the writing itself.

- **Keep the instruction concrete.** A vague "write in my voice" does nothing for the target
  model. Name the traits that actually matter: "direct, leads with the answer, short
  paragraphs, no corporate filler, sentence-case headings, straight quotes, dry humour",
  and so on.
- **Get the traits from the user, or from a sample.** If the user has not described their
  voice, either ask for three or four defining traits, or ask them to paste a short piece
  they have written and derive the traits from it. If they want a named public style, name
  the qualities of that style rather than just the label.
- **Consider embedding a short exemplar.** For voice, one or two lines of the target voice
  in the prompt often carries more than a list of adjectives, especially on Fable and Opus.
- Voice notes land especially well on Fable and Opus, which follow communication-style
  guidance closely; lower tiers need the traits made more explicit.

---

## Optional pass: de-slop (anti-AI)

Adds constraints that strip the generic-LLM tells from the eventual output. Include the
items that fit the task; do not paste the whole list into every prompt.

**Frame it as what to do, not only what to avoid.** A positive instruction the model can act
on ("compose in flowing prose") steers more reliably than the matching prohibition ("don't
use bullet lists"): a bare "avoid:" list tells the model what to suppress without telling it
what to produce instead, so it self-monitors rather than writing well. Lead with the positive
form wherever one exists; keep the negative only for tells that have no natural positive.

Reframe the common tells as positive instructions:

- **Open on the substance** - the first sentence answers the question or starts the task (no
  "Certainly!", "Great question", "In this response I will").
- **Stop when the content stops** - no closing paragraph that restates what was just said.
- **State claims plainly** - where confidence is genuinely low, say so once and specifically,
  instead of a hedge stack ("it's worth noting", "generally speaking", "in many cases").
- **Vary rhythm to the content** - do not pad everything into groups of three or forced
  parallel structure.
- **Let the structure carry the order** - drop the "Firstly... Secondly... In conclusion"
  signposting.
- **Keep an even, factual register** - no manufactured enthusiasm, no exclamation marks.
- **Use plain, specific words** - "use" not "leverage", "lets you" not "seamless" or
  "robust"; concrete nouns over consultant-speak.

A few tells only have a "do not" form - keep those negative and explicit: **no emoji unless
asked**, and **no em dashes or en dashes** (this skill's own hygiene rule; instruct the target
model to use hyphens, commas, or separate sentences).

Calibrate by tier: Fable needs the least of this (its default prose is cleanest), lower tiers
need more of it made explicit. Place the positive style directions up front with the rest of
the constraints, and keep the short "no emoji / no em dashes" reminders near the end so they
are the last thing the model reads before answering.

---

## Optional pass: handoff

When the prompt is one step in a longer piece of work, emit a short handoff doc so the user
can open a fresh session with full context and not re-explain. Keep it to:

- **Goal** - what the larger piece of work is.
- **Where we are** - what this prompt does and what has been decided.
- **The prompt** - the finished artefact.
- **Open questions / next steps** - anything deferred.

---

## Optional pass: skill-ify

When the user will reuse a prompt regularly, it should become a skill rather than a prompt
they paste each time. Do not hand-roll a `SKILL.md` here. Hand off to the **skill-creator**
skill, passing the finished prompt and the task spec as the starting material.

Match the handoff to how the reuse surfaced: if the user **explicitly asked** to make the
prompt reusable or official, that request already is the go-ahead - execute the handoff in
the same turn, do not answer with "say the word". Reserve the offer for reuse *you* inferred
("you'll clearly run this weekly - want it as a skill?").
