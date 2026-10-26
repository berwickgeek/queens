"""Writes the asset catalog: a 1024px app icon (watercolour kingdoms and an ink crown) and the Paper colour."""
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent / "app/Queens/Assets.xcassets"
INK = (42, 52, 70)
PAPER = (251, 252, 253)
PIGMENTS = [0xA8CBE0, 0xF2C58A, 0xB9D9A3, 0xE9A9A1, 0xCBB8DE]
REGIONS = ["aabbb", "aabcc", "dddcc", "deeec", "deeee"]
S = 1024
N = 5


def rgb(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


def icon():
    img = Image.new("RGB", (S, S), PAPER)
    cell = S / N
    wash = Image.new("RGB", (S, S), PAPER)
    d = ImageDraw.Draw(wash)
    for r in range(N):
        for c in range(N):
            g = ord(REGIONS[r][c]) - 97
            d.rectangle([c * cell, r * cell, (c + 1) * cell + 1, (r + 1) * cell + 1], fill=rgb(PIGMENTS[g]))
    # Granulation: speckle then soften.
    rnd = random.Random(7)
    px = wash.load()
    for _ in range(60000):
        x, y = rnd.randrange(S), rnd.randrange(S)
        k = rnd.uniform(0.9, 1.06)
        p = px[x, y]
        px[x, y] = tuple(min(255, int(v * k)) for v in p)
    wash = wash.filter(ImageFilter.GaussianBlur(2.2))
    img.paste(wash)

    d = ImageDraw.Draw(img)
    for k in range(1, N):
        o = k * cell
        d.line([(o, 0), (o, S)], fill=(190, 196, 206), width=3)
        d.line([(0, o), (S, o)], fill=(190, 196, 206), width=3)
    for r in range(N):
        for c in range(N):
            g = REGIONS[r][c]
            if c + 1 < N and REGIONS[r][c + 1] != g:
                d.line([((c + 1) * cell, r * cell), ((c + 1) * cell, (r + 1) * cell)], fill=INK, width=14)
            if r + 1 < N and REGIONS[r + 1][c] != g:
                d.line([(c * cell, (r + 1) * cell), ((c + 1) * cell, (r + 1) * cell)], fill=INK, width=14)

    # Crown in the centre cell, enlarged across it.
    s = cell * 1.5 / 24
    ox, oy = S / 2 - 12 * s, S / 2 - 13 * s
    pt = lambda x, y: (ox + x * s, oy + y * s)
    halo = [pt(1, 1.5), pt(23, 24.5)]
    d.rounded_rectangle(halo, radius=int(4 * s), fill=PAPER, outline=INK, width=10)
    d.polygon([pt(3, 18), pt(4.5, 7.5), pt(9, 12), pt(12, 5), pt(15, 12), pt(19.5, 7.5), pt(21, 18)], fill=INK)
    d.rounded_rectangle([pt(3, 19.2), pt(21, 21.8)], radius=int(1.2 * s), fill=INK)
    for x, y in [(4.5, 7.5), (12, 5), (19.5, 7.5)]:
        d.ellipse([pt(x - 1.9, y - 1.9), pt(x + 1.9, y + 1.9)], fill=INK)
        d.ellipse([pt(x - 0.8, y - 0.8), pt(x + 0.8, y + 0.8)], fill=PAPER)
    return img


def main():
    icon_dir = ROOT / "AppIcon.appiconset"
    icon_dir.mkdir(parents=True, exist_ok=True)
    icon().save(icon_dir / "icon-1024.png")
    (icon_dir / "Contents.json").write_text(json.dumps({
        "images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2))
    paper_dir = ROOT / "Paper.colorset"
    paper_dir.mkdir(parents=True, exist_ok=True)
    (paper_dir / "Contents.json").write_text(json.dumps({
        "colors": [{"idiom": "universal", "color": {"color-space": "srgb", "components": {
            "red": "0.984", "green": "0.988", "blue": "0.992", "alpha": "1.000"}}}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2))
    (ROOT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))


if __name__ == "__main__":
    main()
