# Integration Designers house style - the numbers

Extracted from the example decks (`IBM_Bob_for_Developers_v2.pptx`, `IBM_Bob_Overview.pptx`,
`IBM_Bob_Top5_vs_ClaudeCode.pptx`) with `scripts/introspect_deck.py` on 2026-09-09, and
encoded as constants in `scripts/id_deck.py`. Template lineage: "Integration Designers -
PowerPoint Template 2022.potx" (Template_Blomme).

## Canvas

10.0 x 5.63 in (16:9 at the small size). Content column x = 0.47 in, width 9.06 in.
Point sizes are therefore small: a 22 pt title fills the band, 13 pt card headings,
10 pt body, 9.5 pt code.

## Colours

| Name | Hex | Where |
|---|---|---|
| PURPLE | `281A77` | bands, panels, takeaway bar, headings on white, code panel |
| TEAL | `00D7B0` | chips, big numbers, dots, takeaway text, accent bars |
| TEAL_TITLE | `01D9AA` | titles on purple lead slides and the quote-panel statement |
| DARK | `1A2332` | body text on white |
| GRAY | `4B5563` | secondary body text (tall and panel cards, italic leads) |
| CARD | `F4F7FA` | light card fill (with a coloured 0.08 in top bar) |
| CARD2 | `F2F2F4` | rounded tall/panel card fill (with soft purple shadow, alpha 20%) |
| MUTED_ON_PURPLE | `8E87B5` | author line on the title slide |

Theme colour scheme (dk1 `281A77`, dk2 `00D7B0`, accent1 `1E73BE`, accent2 `8E87B5`) is
consistent with the above; the slides set explicit RGB anyway.

## Fonts

Slides use **IBM Plex Sans** for everything except code, which uses **Consolas**. The
theme declares Montserrat (major) and Georgia (minor); the existing decks override them at
run level, so do the same. Neither Plex nor Montserrat is installed on this box: the decks
already rely on substitution, and specifying Plex is still right for machines that have it.

## Layouts (default template, 18 in the master)

| Key in `LAYOUTS` | Name | Used by | Furniture to know about |
|---|---|---|---|
| lead | `Intro / tussentitel slide` | `lead()` | purple background, teal rule, logo bottom right |
| band | `Image breakdown` | `band()` and everything built on it | purple top band ends at y = 1.99; lower half has teal dashes + label placeholders, covered by a white rect |
| panel | `1_Overview 2` | `panel()` | left purple panel with logo (x < 4.0); a teal rule at y ~5.2 that the note covers |
| quote | `1_Quote no picture` | `quote_panel()` | teal square + quote mark on the left half (covered), purple panel from x = 6.04 |
| team | `1_Meet the team` | `circle_trio()` | purple full-bleed |
| closer | `Thank you` | `closer()` | two text placeholders (title, name) - the only recipe that keeps placeholders |

Other layouts present but unused by the recipes: `1_Title slide_Purple`, `Title slide met
foto`, `Title slide met te uploaden foto`, `1_Intro / tussentitel slide_2`, `Overview -
aanpasbare cirkel`, `Overview met logo`, `Overview 2`, `Quote`, `Bulletpoints`,
`1_Image breakdown`, `Quote with image slot`, `Bullet_n3en2_highlights`.

## Recipe geometry (inches)

- **band title**: (0.47, 0.42) w 9.06 h 0.5, 22 pt white bold; optional subtitle at y 1.02, 10.5 pt.
- **takeaway bar**: purple rect (0.1, 5.19) 9.8 x 0.38; teal 10 pt text, middle-anchored.
- **cards** (3 or 4 across, gap 0.25): y 2.3, h 2.55; top bar 0.08; heading 13 pt purple at
  y+0.24 (head box 0.3, or 0.55 when 4 cards); body 10 pt dark, line spacing 1.1.
- **stats**: cards y 2.35 h 2.2; figure 30 pt teal at y+0.27; body 11 pt at y+1.0.
- **tall cards**: y 1.45, h 3.35 (3 across, gap 0.25) or h 3.5 (5 across, gap 0.22, 20 pt
  number); radius 0.09; number 22 pt teal, heading 12.5 pt purple at y+0.72, body 9.5 pt
  gray at y+1.4.
- **panel**: chip at (4.2, 0.42), width 0.34 + 0.085 per character; title (4.2, 0.95) 20 pt;
  cards 2.7 x 1.65 in a 2x2 grid from (4.2, 1.70) stepping 2.85 / 1.80; teal circle
  d 0.5 with the number in 12 pt white; note at (4.2, 5.18) 9.5 pt purple over a white
  cover (4.1, 5.15, 5.9 x 0.45).
- **code**: panel (0.47, 2.25) 4.45 x 2.75, radius 0.045, margins 0.22/0.12; 9.5 pt
  Consolas, comments teal; bullets from (5.55, 2.4) stepping 0.85 with a 0.12 teal dot.
- **quote panel**: white cover (0, 0, 6.04 x 5.63); chip (0.45, 0.42); title (0.45, 1.0)
  22 pt; italic lead (0.45, 1.58) 10.5 pt gray; teal rule (0.47, 2.18) 0.49 x 0.05; items
  from y 2.5 stepping 0.57 (head 11.5 pt purple bold, body 10.5 pt dark); statement at
  (6.5, 0.85) 24 pt and (6.5, 2.25) 20 pt, TEAL_TITLE bold.
- **circle trio**: title centred (2.0, 0.42) 22 pt white; circles d 1.3 at x 1.33 / 4.35 /
  7.38, y 1.51; labels 14 pt teal at y 3.25, quotes 9.5 pt white at y 4.25 (columns x 0.77
  / 3.80 / 6.82, w 2.4); footer 10 pt teal at y 5.25.
- **lead**: title (0.93, 0.95) 8.4 x 1.0, bottom-anchored, 36 pt (title slide 42, closing
  sentence 32); subtitle (0.93, 2.45) 15 pt white (18 / 17); extra (0.93, 4.95) 11 pt
  muted; optional sticker picture at (7.55, 3.35) h 1.9.
