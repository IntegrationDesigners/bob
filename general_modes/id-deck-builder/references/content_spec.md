# Content spec - what `build_deck.py` reads

One JSON object. Write it with the Write tool (ASCII punctuation, `C:/` paths).
A complete example that uses every type: `../assets/example_spec.json`.

```json
{
  "title": "Deck title (core properties)",
  "author": "Matthias Blomme",
  "template": "C:/path/to/ID_example_deck.pptx",
  "layouts": {"band": "Image breakdown"},
  "slides": [ ... ]
}
```

- `template` - the carcass; `--template` on the command line overrides it.
- `layouts` - optional overrides of the six keys `lead`, `band`, `panel`, `quote`,
  `team`, `closer` when the template names its layouts differently. Missing layouts fail
  at open time with the list of available names.
- Every slide takes an optional `"notes": "text"` or `"notes_index": N` (0-based index
  into the speaker-note blocks harvested from `--marp file.md`, in source order). An index
  past the end is an error, not a silent skip.

Inline markup in body strings: `` `code` `` renders in Consolas purple, `**bold**` renders
bold. Nothing else is interpreted.

## Slide types

### lead
```json
{"type": "lead", "title": "IBM Bob 2.0", "subtitle": "What's new",
 "extra": "Matthias Blomme", "title_size": 42, "sub_size": 18,
 "sticker": "C:/path/optional.png"}
```
Title slide (42/18), section divider (defaults 36/15), closing sentence (32/17).
`extra` is the small muted line at the bottom; `sticker` a picture placed bottom right.

### stats
```json
{"type": "stats", "title": "...", "subtitle": "optional",
 "cards": [["270K", "tokens of context, up from 200K"], ["3", "clear modes"]],
 "takeaway": "optional one-liner for the purple bar"}
```
Each card is `[figure, body]`. 2-4 cards.

### cards
```json
{"type": "cards", "title": "...", "subtitle": "optional",
 "cards": [["Heading", "Body"], ["Heading", "Body"], ["Heading", "Body"]],
 "takeaway": "optional"}
```
3 or 4 cards of `[heading, body]`. Bodies over ~180 characters overflow a 3-card slide;
over ~120 on a 4-card slide.

### tall_cards
```json
{"type": "tall_cards", "title": "...",
 "cards": [["01", "Agent", "Takes action and completes the task."], ["02", "Plan", "..."], ["03", "Ask", "..."]],
 "takeaway": "optional"}
```
`[number, heading, body]`; 3 items (or 5 for a recap row). No subtitle: the cards
overlap the band where a subtitle would sit.

### panel
```json
{"type": "panel", "chip": "Bob 2.0", "title": "Other changes in 2.0",
 "cards": [["01", "Nested workflows", "Workflows can now call other workflows."], ...],
 "note": "optional line under the grid"}
```
Up to 4 `[number, lead, body]` cards in a 2x2 grid. Keep bodies under ~90 characters.

### code
```json
{"type": "code", "title": "Small file, explicit contract",
 "code": ["your-project/", "  .bob/", "    skills/   # one folder per skill"],
 "bullets": ["Project skills live in `.bob/skills/`", "..."]}
```
Up to ~12 code lines (9.5 pt) and 3 bullets. A `#` starts a teal comment run; a line
starting with `#` is all comment.

### quote_panel
```json
{"type": "quote_panel", "chip": "Hooks", "title": "The 5 available hooks",
 "lead": "italic one-liner under the title",
 "items": [["SessionStart", "Inject context once, before the first turn."], ...],
 "statement": ["Five lifecycle points,", "only UserPromptSubmit and PreToolUse can block."]}
```
Up to 5 `[head, body]` items on the left; `statement` is one or two lines for the purple
panel (24 pt then 20 pt). Keep the second statement line under ~60 characters.

### circle_trio
```json
{"type": "circle_trio", "title": "The three built-in modes",
 "items": [["?", "Ask", "quote"], ["bars", "Plan", "quote"], ["gear", "Agent", "quote"]],
 "footer": "optional teal line at the bottom"}
```
Exactly 3 `[glyph, label, quote]`; glyph is `"bars"`, `"gear"` or any single character.

### closer
```json
{"type": "closer", "title": "Thank you", "name": "Matthias Blomme"}
```
The template's own closing layout with its placeholders filled.

## Anything else

Import the library from a scratchpad script and build the slide by hand:

```python
import sys; sys.path.insert(0, "<skill>/scripts")
from id_deck import Deck, PURPLE, TEAL, CARD
d = Deck("C:/path/template.pptx")
s = d.band("A slide no recipe covers")
d.rect(s, 0.47, 2.3, 4.4, 2.5, CARD); d.text(s, 0.6, 2.4, 4.1, 0.4, ["Heading"], size=13, color=PURPLE, bold=True)
d.save("C:/out/deck_generated.pptx")
```

If the same custom slide is needed twice, it is a recipe: add it to `id_deck.py` and a
type to `build_deck.py`, and put one instance in `assets/example_spec.json`.
