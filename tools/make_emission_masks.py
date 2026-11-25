#!/usr/bin/env python3
"""Generate night-time window emission masks from Kenney colormaps.

Pale-blue texels (window glass) become warm light; everything else black.
Usage: python3 -I tools/make_emission_masks.py   (run from the project root)
"""
import colorsys
from PIL import Image

KITS = ["city", "suburban"]
WARM = (255, 196, 120)


def is_glass(r, g, b):
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    return 0.53 <= h <= 0.70 and l >= 0.55 and s >= 0.25


for kit in KITS:
    src = Image.open(f"game/art/kenney/{kit}/Textures/colormap.png").convert("RGB")
    out = Image.new("RGB", src.size, (0, 0, 0))
    px, po = src.load(), out.load()
    lit = 0
    for y in range(src.size[1]):
        for x in range(src.size[0]):
            r, g, b = px[x, y]
            if is_glass(r, g, b):
                k = (r + g + b) / (3 * 255)
                po[x, y] = tuple(int(c * k) for c in WARM)
                lit += 1
    out.save(f"game/art/kenney/{kit}/Textures/emission_windows.png")
    print(kit, f"{100 * lit / (src.size[0] * src.size[1]):.1f}% texels lit")
