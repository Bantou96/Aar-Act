#!/usr/bin/env python3
"""Render `aartool --help` as a terminal graphic, for release posts and README art.

The text is piped from the real command and never retyped, so the picture cannot
claim a version, a command or a count that the tool does not produce. That is
the whole point: an announcement image is the one artefact nobody re-checks
after a release, and a stale one is a public untruth.

Drawn with PIL rather than SVG on purpose. Every SVG renderer tried here
substitutes a non-monospace font for the box-drawing glyphs in the banner, and
the letterforms stop tiling: per-character grid placement and forced glyph
widths both still broke. PIL with DejaVu Sans Mono tiles correctly.

Usage:
  python3 scripts/make-help-image.py [--out FILE] [--scale N]

Needs Pillow and DejaVu Sans Mono:
  pip install Pillow
  apt install fonts-dejavu-core     # or dnf install dejavu-sans-mono-fonts
"""
import argparse
import os
import subprocess
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Pillow is required: pip install Pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_DIRS = [
    "/usr/share/fonts/truetype/dejavu",          # Debian, Ubuntu
    "/usr/share/fonts/dejavu-sans-mono-fonts",   # Fedora, RHEL
    "/usr/share/fonts/dejavu",
]
BG, FG, ACC, DIM, HD, BAR = "#0d1117", "#c9d1d9", "#00e5b0", "#7d8590", "#f0f6fc", "#161b22"
BANNER_ROWS = 6


def find_font(name):
    for d in FONT_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return p
    sys.exit(f"{name} not found. Install DejaVu Sans Mono, or the banner will not tile.")


def help_lines():
    """The real output, truncated at Global options. Truncating is honest;
    inventing a line would not be."""
    exe = os.path.join(ROOT, "scripts", "aartool")
    out = subprocess.run([exe, "--help"], cwd=ROOT, capture_output=True, text=True,
                         env={**os.environ, "LC_ALL": "C.UTF-8"})
    if out.returncode != 0:
        sys.exit(f"aartool --help failed:\n{out.stderr}")
    lines = [l.rstrip() for l in out.stdout.split("\n")]
    try:
        lines = lines[:next(i for i, l in enumerate(lines) if l.startswith("Global options:"))]
    except StopIteration:
        sys.exit("could not find the Global options block; has --help changed shape?")
    while lines and not lines[-1]:
        lines.pop()
    return lines


def render(lines, scale):
    fs, lh, pad = 22 * scale, 32 * scale, 45 * scale
    reg = ImageFont.truetype(find_font("DejaVuSansMono.ttf"), fs)
    bold = ImageFont.truetype(find_font("DejaVuSansMono-Bold.ttf"), fs)
    small = ImageFont.truetype(find_font("DejaVuSansMono.ttf"), 17 * scale)
    adv = reg.getlength("M")

    top, w = 95 * scale, 1100 * scale
    h = top + len(lines) * lh + 125 * scale

    img = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(img)

    d.rectangle([0, 0, w, 52 * scale], fill=BAR)
    for i, c in enumerate(("#ff5f57", "#febc2e", "#28c840")):
        x = (28 + i * 26) * scale
        d.ellipse([x, 18 * scale, x + 16 * scale, 34 * scale], fill=c)
    title = "aartool --help"
    d.text(((w - small.getlength(title)) / 2, 18 * scale), title, font=small, fill=DIM)

    for n, line in enumerate(lines):
        y = top + n * lh
        if n < BANNER_ROWS:
            d.text((pad, y), line, font=reg, fill=ACC)
        elif line.strip().startswith("v") and "|" in line:
            d.text((pad, y), line, font=bold, fill=HD)
        elif line.endswith(":") and not line.startswith(" "):
            d.text((pad, y), line, font=bold, fill=HD)
        elif line.startswith("  ") and len(line) > 14 and line[2] != " ":
            d.text((pad, y), line[:14], font=bold, fill=ACC)
            d.text((pad + 14 * adv, y), line[14:], font=reg, fill=FG)
        else:
            d.text((pad, y), line, font=reg, fill=FG)

    fy = top + len(lines) * lh + 30 * scale
    d.line([pad, fy - 20 * scale, w - pad, fy - 20 * scale], fill="#30363d", width=scale)
    d.text((pad, fy), "$ sudo apt install aartool", font=bold, fill=ACC)
    d.text((pad, fy + 31 * scale), "$ sudo dnf install aartool", font=bold, fill=ACC)
    tail = "pkgs.cyberaar.io  ·  GPL-3.0"
    d.text((w - pad - small.getlength(tail), fy + 34 * scale), tail, font=small, fill=DIM)
    return img


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="aartool-help.png", help="output PNG (default: %(default)s)")
    ap.add_argument("--scale", type=int, default=2,
                    help="pixel density, 2 gives a crisp image on retina (default: %(default)s)")
    a = ap.parse_args()

    lines = help_lines()
    img = render(lines, a.scale)
    img.save(a.out)
    version = next((l.strip() for l in lines if l.strip().startswith("v")), "unknown version")
    print(f"{a.out}  {img.width}x{img.height}  ({version})")


if __name__ == "__main__":
    main()
