"""Writes the asset catalog: a 1024px app icon (a red wax seal pressed with the crown, on atlas
paper, the mark of the current stop on the journey maps) and the Paper colour."""
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent / "app/Queens/Assets.xcassets"
S = 1024
X = 4  # drawn at 4x, then downsampled
SS = S * X

# Theme.Atlas and Theme.wax.
ATLAS_PAPER = (245, 236, 215)
ATLAS_SHADE = (217, 193, 147)
WAX = (156, 47, 60)
WAX_DEEP = (110, 31, 42)
WAX_LIT = (184, 66, 78)
SEAL_RING = (196, 138, 30)
SEAL_MARK = (251, 243, 230)


def paper(seed):
    """Atlas paper with soft blotches toward the edges, like the map sheet's vignette."""
    img = Image.new("RGB", (SS, SS), ATLAS_PAPER)
    rnd = random.Random(seed)
    blot = Image.new("L", (SS, SS), 0)
    d = ImageDraw.Draw(blot)
    for _ in range(14):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0.42, 0.62) * SS
        x, y = SS / 2 + math.cos(a) * r, SS / 2 + math.sin(a) * r
        k = rnd.uniform(0.18, 0.32) * SS
        d.ellipse([x - k, y - k, x + k, y + k], fill=rnd.randint(40, 90))
    blot = blot.filter(ImageFilter.GaussianBlur(SS * 0.06))
    return Image.composite(Image.new("RGB", (SS, SS), ATLAS_SHADE), img, blot)


def blob(cx, cy, r, seed, amp=0.035, n=180):
    """A circle with a wavering edge, as wax spreads."""
    rnd = random.Random(seed)
    ph = [rnd.uniform(0, 2 * math.pi) for _ in range(4)]
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        k = 1 + amp * (0.6 * math.sin(3 * t + ph[0]) + 0.3 * math.sin(5 * t + ph[1])
                       + 0.25 * math.sin(8 * t + ph[2]) + 0.15 * math.sin(13 * t + ph[3]))
        pts.append((cx + r * k * math.cos(t), cy + r * k * math.sin(t)))
    return pts


def crown(d, cx, cy, w, fill, hole=None):
    """The app's crown on its 24-unit grid, centred and `w` wide."""
    s = w / 18
    ox, oy = cx - 12 * s, cy - 13.5 * s
    pt = lambda x, y: (ox + x * s, oy + y * s)
    d.polygon([pt(3, 18), pt(4.5, 7.5), pt(9, 12), pt(12, 5), pt(15, 12), pt(19.5, 7.5), pt(21, 18)], fill=fill)
    d.rounded_rectangle([pt(3, 19.4), pt(21, 22)], radius=int(1.2 * s), fill=fill)
    for x, y in [(4.5, 7.5), (12, 5), (19.5, 7.5)]:
        (jx, jy), r = pt(x, y), 1.9 * s
        d.ellipse([jx - r, jy - r, jx + r, jy + r], fill=fill)
        if hole:
            d.ellipse([jx - r * 0.42, jy - r * 0.42, jx + r * 0.42, jy + r * 0.42], fill=hole)


def icon():
    img = paper(3)
    c, r = SS / 2, SS * 0.36
    shadow = Image.new("L", (SS, SS), 0)
    ImageDraw.Draw(shadow).polygon(blob(c + SS * 0.012, c + SS * 0.022, r * 1.02, 11), fill=110)
    img = Image.composite(Image.new("RGB", (SS, SS), (120, 80, 50)), img, shadow.filter(ImageFilter.GaussianBlur(SS * 0.02)))
    # Wax lit from the top left.
    light = Image.radial_gradient("L").resize((int(r * 3.8), int(r * 3.8)))
    falloff = Image.new("L", (SS, SS), 255)
    falloff.paste(light, (int(c - r * 0.35 - r * 1.9), int(c - r * 0.4 - r * 1.9)))
    wax = Image.composite(Image.new("RGB", (SS, SS), WAX_DEEP), Image.new("RGB", (SS, SS), WAX_LIT), falloff)
    mask = Image.new("L", (SS, SS), 0)
    ImageDraw.Draw(mask).polygon(blob(c, c, r, 11), fill=255)
    img = Image.composite(wax, img, mask)
    d = ImageDraw.Draw(img)
    # The pressed rim: a groove, then the gold ring of the map's seals.
    g = r * 0.80
    d.ellipse([c - g, c - g, c + g, c + g], outline=WAX_DEEP, width=int(SS * 0.018))
    g = r * 0.74
    d.ellipse([c - g, c - g, c + g, c + g], outline=SEAL_RING, width=int(SS * 0.014))
    # The crown with a shadow under it, so it reads as pressed into the wax.
    crown(d, c + SS * 0.006, c + SS * 0.01, SS * 0.40, WAX_DEEP)
    crown(d, c, c, SS * 0.40, SEAL_MARK, hole=WAX)
    return img.resize((S, S), Image.LANCZOS)


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
