# Media

How to regenerate the terminal graphic used in release posts and announcements.

```bash
python3 scripts/make-help-image.py --out aartool-help.png
```

Needs Pillow and DejaVu Sans Mono:

```bash
pip install Pillow
sudo apt install fonts-dejavu-core      # or: sudo dnf install dejavu-sans-mono-fonts
```

`--scale 2` is the default and gives a crisp 2200px image; `--scale 1` halves it.

## Why it pipes from the tool

The text comes from a real `aartool --help` run and is never retyped. An
announcement image is the one artefact nobody re-checks after a release: it is
posted once, then lives on other people's timelines. A version number typed by
hand into a picture is wrong at the next release and nothing anywhere will fail.

The same reasoning produced the guard on the aartool figures on cyberaar.io.
That page had claimed 51 Ansible roles against a real 52, and 96 CIS controls
against a real 109, for an unknown period.

**Regenerate after every release**, before posting anything. The image carries
the version and the command list, and both move.

## Why PIL and not SVG

An SVG would be the obvious choice for something this geometric, and it does
not work here. Every SVG renderer tried substitutes a non-monospace font for the
box-drawing glyphs in the banner, so the characters stop tiling and the
letterforms turn to mush. Per-character grid placement and `textLength` with
`lengthAdjust="spacingAndGlyphs"` were both tried; both still broke, because
positioning cannot fix a glyph that is drawn wider than its cell.

PIL renders the glyphs with the font's own metrics, so the banner tiles the way
it does in a terminal.

If you change this, check the banner at full size before believing it. The
failure is obvious in the art and invisible in the code.
