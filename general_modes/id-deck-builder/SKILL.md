---
name: id-deck-builder
description: "Use this skill whenever the user wants a slide deck in the Integration Designers (ID) house style as a .pptx - from a marp/markdown deck, an outline, a blog post, a set of talking points, or 'the same content as deck X but for Y'. Triggers include 'ID-style deck', 'ID template', 'Integration Designers slides', 'turn this marp into pptx', 'rebuild this deck on our template', 'make me slides for the Bob session', 'pptx in the company style', 'convert my markdown slides to PowerPoint', and any request for a branded PowerPoint that should look like the existing IBM Bob / ACE decks. Builds slides from scratch on the template carcass with python-pptx (applying the template to an export does not work), carries speaker notes over, and renders every slide through PowerPoint COM for a visual check before hand-off. Not for generic pptx editing without the ID style - use the pptx skill for that."
metadata:
  version: 0.1.0
  status: beta
  last_updated: 2026-09-12
---

# ID Deck Builder

Turns deck content into an Integration Designers (ID) house-style `.pptx`, the way the
2026-09-09 Bob 2.0 deck was made: introspect an example deck for the dialect, strip a
template deck down to its carcass (theme, masters, 18 layouts, logo media), rebuild
every slide from a JSON content spec with the recipe library, carry the speaker notes
over, and LOOK at the rendered slides before handing anything over.

Why from scratch: "apply template" on a marp/HTML export produces off-brand slides, and
python-pptx cannot restyle placeholders it did not create. Rebuilding on the carcass gives
exact colours, fonts and geometry, and python-pptx drops the template's orphaned media on
save (a 16 MB template gives a 10 MB output with no extra stripping).

## What you need before starting

- **Content**: a marp/markdown deck, an outline, or prose. Marp sources with
  `<!--\nSpeaker notes:\n\n...\n-->` blocks get their notes carried over by index.
- **Template deck**: any existing ID deck, for example `IBM_Bob_for_Developers_v2.pptx`
  (siblings `IBM_Bob_Overview.pptx`, `IBM_Bob_Top5_vs_ClaudeCode.pptx` are the other
  examples). Ask for the path once and keep it for the session; the `template` field of
  the content spec carries it.
- **Author line** and the **output path**. Never write over a deck a human has
  hand-finished (icons, tweaks): output to `<name>_generated.pptx` unless told otherwise;
  the 2026-09-09 build script had to be re-pointed after it nearly clobbered the master.
- python-pptx 1.0.2 + lxml are installed on the default python; PowerPoint is installed
  (needed for the render step). Paths in `C:/` form: python-pptx cannot open `/c/...`.

## Workflow

### 1. Introspect before you build (new template or new recipe only)

```
python <skill>/scripts/introspect_deck.py "C:/path/template.pptx"            # layouts, theme, per-slide summary
python <skill>/scripts/introspect_deck.py "C:/path/example.pptx" --slide 6   # every shape of one slide
```

The house numbers in `references/house_style.md` were extracted this way from the
example decks. For the default template you can skip this step: the layout map in
`scripts/id_deck.py` (`LAYOUTS`) already matches it. For any other template, confirm the
six layout names it needs exist (the script lists them) and pass overrides in the spec's
`"layouts"` block. When the user points at a slide in an example deck and says "like
that", introspect that slide and copy its geometry into a recipe rather than guessing.

### 2. Map the content to slide recipes

Read `references/content_spec.md` for the field-level contract. The recipes, and when
each earns its place:

| Recipe | Use for | Looks like |
|---|---|---|
| `lead` | title slide, section dividers, the closing sentence | purple, teal title, white subtitle |
| `stats` | 2-4 big numbers with one line each | light cards with a big teal figure |
| `cards` | 3-4 parallel points | light cards, purple top bar; 4 cards get a taller heading |
| `tall_cards` | 3 or 5 numbered items that deserve weight | rounded cards overlapping the band, soft shadow |
| `panel` | a grab-bag of up to 4 changes/tips | left purple logo panel, teal chip, numbered circle cards |
| `code` | a file tree, YAML/JSON snippet + 2-3 bullets | purple code panel (comments teal), teal-dot bullets |
| `quote_panel` | a list of 5 named items + a punchline | white list left, big teal statement on purple right |
| `circle_trio` | three roles/modes with a quote each | purple full-bleed, white circles with flat teal glyphs |
| `closer` | the template's own Thank-you slide | placeholders kept and filled |

Variety is part of the style. The first Bob 2.0 build was rejected for "too many
same-looking 3-box slides"; the second pass turned two of them into tall cards, two into
panel slides and one into a quote panel. Rule of thumb: never three `cards` slides in a
row, and give the deck's two or three most important slides a heavier recipe.

Marp constructs map like this: `---` section title -> `lead`; a three-column bullet list
-> `cards` or `stats`; `p.small` footnotes -> the `takeaway` bar; fenced code -> `code`;
per-slide headers/footers are dropped (the ID template has no running headers; author on
the title and closer only). Code uses Consolas, not IBM Plex Mono: no mono Plex on this
box, and a substituted monospace breaks alignment.

### 3. Write the spec, build, count

Write the spec as JSON with the Write tool (ASCII, `C:/` paths); a starting point that
covers every recipe is `assets/example_spec.json`. Then:

```
python <skill>/scripts/build_deck.py --spec C:/work/deck.json --out C:/work/deck_generated.pptx [--marp C:/work/source.md]
```

It prints `saved ...: N slides, M with speaker notes, K KB`. Reconcile N against the
spec and M against the notes you intended to carry (the Bob build asserted 20 note
blocks up front; a silent shortfall means a regex missed a block). A `notes_index`
beyond the harvested count fails loudly on purpose.

For a slide no recipe covers, write a small scratchpad module that imports
`scripts/id_deck.py` (`Deck`, `rect`, `text`, `oval`, `card`, `takeaway`, `chip`) and
build that slide by hand; do not bend a recipe out of shape.

### 4. Render and look

```
powershell -NoProfile -ExecutionPolicy Bypass -File <skill>/scripts/render_qa.ps1 -Path C:/work/deck_generated.pptx
```

PowerPoint COM exports `Slide1.PNG .. SlideN.PNG` (about 10 s for 20 slides). Read at
least one PNG per recipe used plus every slide with a long body: the things python-pptx
cannot tell you are text overflow, a card body spilling past its bottom, the band
layout's lower-half furniture showing through, and a statement wrapping onto a fourth
line. Fix the spec (shorter body, one fewer card, smaller `title_size`) and rebuild;
never hand-edit the pptx, the next rebuild would lose it. Close the deck in PowerPoint
before rendering - Office locks it exclusively.

### 5. Hand off

Report: output path, slide count, notes count, which slides used which recipe, and what
is left for a human - icons and images (DALL-E icons went in by hand on the Bob deck),
picture compression before distribution (uncompressed PNGs took that deck to 40 MB), and
the one-line reminder that the `_generated` file is regenerable while the master is not.

## Gotchas (each one cost a rebuild)

- Layout names are Dutch/English mixed and template-specific (`Intro / tussentitel
  slide`, `Image breakdown`, `1_Overview 2`, `1_Quote no picture`, `1_Meet the team`,
  `Thank you`). Introspect, do not assume.
- The `Image breakdown` layout carries teal dashes and label placeholders in its lower
  half; `band()` covers them with a white rectangle. If a recipe on another layout shows
  stray furniture, cover it the same way rather than deleting layout shapes.
- Neither IBM Plex Sans nor Montserrat is installed on this box; the existing ID decks
  already rely on substitution, so specifying `IBM Plex Sans` is correct and renders
  properly wherever the font exists. The theme fonts (Montserrat/Georgia) are not what
  the slides use.
- Canvas is 10 x 5.63 in, so point sizes are small (22 pt band title, 13 pt card
  heading, 10 pt body). Copying sizes from a 13.33 in deck makes everything overflow.
- The example decks' "cards" are white-on-white shapes; the visible card style (light
  `F4F7FA` + coloured top bar) comes from slide 6 of the developers deck.
- Deleting slides via `sldIdLst.remove` + `drop_rel` is what makes the old media
  orphaned and dropped; deleting only the shapes keeps the 16 MB.

## Files

- `scripts/id_deck.py` - the recipe library and house constants (import it).
- `scripts/build_deck.py` - JSON spec -> pptx.
- `scripts/introspect_deck.py` - extract layouts, theme and shape geometry from any deck.
- `scripts/render_qa.ps1` - PowerPoint COM export to PNG.
- `references/house_style.md` - colours, fonts, canvas, layouts, recipe geometry.
- `references/content_spec.md` - every slide type and field.
- `assets/example_spec.json` - 12-slide spec exercising every recipe (Bob 2.0 content).
