"""Build an ID-style .pptx from a JSON content spec.

    python build_deck.py --spec deck.json --out C:/out/deck.pptx
                         [--template C:/path/ID_template_deck.pptx]
                         [--marp source.md]      # speaker notes by index, see below

Spec shape (see ../references/content_spec.md for every slide type and field):

    {
      "title": "IBM Bob 2.0 - What's new", "author": "Matthias Blomme",
      "template": "C:/.../IBM_Bob_for_Developers_v2.pptx",   # or --template
      "layouts": {"band": "Image breakdown"},                 # optional overrides
      "slides": [
        {"type": "lead", "title": "IBM Bob 2.0", "subtitle": "What's new",
         "extra": "Matthias Blomme", "notes": "..."},
        {"type": "cards", "title": "...", "cards": [["Heading", "Body"], ...],
         "takeaway": "...", "notes_index": 3}
      ]
    }

Notes: a slide carries either "notes" (text) or "notes_index" (0-based index into
the speaker-note blocks harvested from --marp). Paths in C:/ form.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from id_deck import Deck, marp_notes  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def tup(rows, n):
    out = []
    for r in rows:
        if len(r) != n:
            raise ValueError(f"expected {n} fields per item, got {r!r}")
        out.append(tuple(r))
    return out


def build(spec, template, out, marp=None):
    d = Deck(template, layouts=spec.get("layouts"))
    notes = marp_notes(marp) if marp else []
    for i, s in enumerate(spec["slides"], 1):
        t = s["type"]
        if t == "lead":
            slide = d.lead(s["title"], s.get("subtitle", ""), extra=s.get("extra"),
                           title_size=s.get("title_size", 36), sub_size=s.get("sub_size", 15),
                           sticker=s.get("sticker"))
        elif t == "stats":
            slide = d.stats(s["title"], tup(s["cards"], 2), takeaway=s.get("takeaway"), subtitle=s.get("subtitle"))
        elif t == "cards":
            slide = d.cards(s["title"], tup(s["cards"], 2), takeaway=s.get("takeaway"), subtitle=s.get("subtitle"))
        elif t == "tall_cards":
            slide = d.tall_cards(s["title"], tup(s["cards"], 3), takeaway=s.get("takeaway"))
        elif t == "panel":
            slide = d.panel(s["chip"], s["title"], tup(s["cards"], 3), note=s.get("note"))
        elif t == "code":
            slide = d.code(s["title"], s["code"], s.get("bullets", []))
        elif t == "quote_panel":
            slide = d.quote_panel(s["chip"], s["title"], s["lead"], tup(s["items"], 2), s["statement"])
        elif t == "circle_trio":
            slide = d.circle_trio(s["title"], tup(s["items"], 3), footer=s.get("footer"))
        elif t == "closer":
            slide = d.closer(s.get("title", "Thank you"), name=s.get("name"))
        else:
            raise ValueError(f"slide {i}: unknown type {t!r}")
        if "notes" in s:
            d.notes(slide, s["notes"])
        elif "notes_index" in s:
            idx = s["notes_index"]
            if idx >= len(notes):
                raise IndexError(f"slide {i}: notes_index {idx} but only {len(notes)} note blocks in {marp}")
            d.notes(slide, notes[idx])
    return d.save(out, title=spec.get("title"), author=spec.get("author"))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--template", default=None, help="overrides spec.template")
    ap.add_argument("--marp", default=None, help="marp source for speaker notes (notes_index)")
    a = ap.parse_args()
    spec = json.load(open(a.spec, encoding="utf-8"))
    template = a.template or spec.get("template")
    if not template:
        sys.exit("no template: pass --template or set spec.template")
    build(spec, template, a.out, a.marp)
