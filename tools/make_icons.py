#!/usr/bin/env python3
"""Draws the app icons into ios/LaBatalla/Assets.xcassets.

The mark: the flag's triangle pointing forward with the lone star cut out of it, and two stripes
trailing. Blue and white only. Four icon sets, each with a light, dark and tinted 1024 PNG:
  AppIcon        white mark on royal blue (the primary icon)
  AppIcon-Tech   white mark on tech blue
  AppIcon-Paper  blue mark on white
  AppIcon-Star   the lone star alone, on royal blue

Run from the repo root:  python3 tools/make_icons.py
Needs Pillow (pip install pillow). Everything is drawn 4x and scaled down, so edges are smooth.
"""
import json
import math
import os

from PIL import Image, ImageDraw

SIZE = 1024
SS = 4  # supersampling
S = SIZE * SS

ROYAL = (30, 91, 230)
ROYAL_DEEP = (20, 66, 180)
TECH = (10, 132, 255)
TECH_DEEP = (0, 96, 220)
NAVY = (11, 27, 77)       # dark-mode background
WHITE = (255, 255, 255)
PAPER = (255, 255, 255)
TINT_GREY = (236, 238, 243)

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ios", "LaBatalla", "Assets.xcassets")


def star_points(cx, cy, outer, inner=None, points=5):
    inner = inner or outer * 0.382
    pts = []
    for i in range(points * 2):
        a = -math.pi / 2 + i * math.pi / points
        r = outer if i % 2 == 0 else inner
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def gradient(top, bottom):
    """A vertical gradient background, slightly lighter at the top."""
    img = Image.new("RGBA", (S, S), top + (255,))
    px = img.load()
    for y in range(S):
        t = y / (S - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(S):
            px[x, y] = c + (255,)
    return img


def flat(color, alpha=255):
    return Image.new("RGBA", (S, S), color + (alpha,))


def rounded_bar(draw, x0, y0, x1, y1, fill):
    r = (y1 - y0) / 2
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=fill)


def draw_mark(img, color, hole=None):
    """The triangle with the star cut out and two stripes. `hole` is the color inside the star
    (the background); None cuts it to transparent."""
    u = S / 1024
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # Triangle: left edge from (200,230) to (200,794), tip at (596,512). Pointing forward.
    tri = [(200 * u, 230 * u), (200 * u, 794 * u), (596 * u, 512 * u)]
    d.polygon(tri, fill=color + (255,))
    # Two stripes trailing from the tip's side, like the flag's.
    rounded_bar(d, 640 * u, 338 * u, 824 * u, 418 * u, color + (255,))
    rounded_bar(d, 640 * u, 606 * u, 824 * u, 686 * u, color + (255,))
    # The star, cut out of the triangle.
    star = star_points(318 * u, 512 * u, 104 * u)
    if hole is None:
        cut = Image.new("L", (S, S), 255)
        ImageDraw.Draw(cut).polygon(star, fill=0)
        a = layer.getchannel("A")
        from PIL import ImageChops
        layer.putalpha(ImageChops.multiply(a, cut))
    else:
        d.polygon(star, fill=hole + (255,))
    img.alpha_composite(layer)
    return img


def draw_lone_star(img, color):
    u = S / 1024
    d = ImageDraw.Draw(img)
    d.polygon(star_points(512 * u, 470 * u, 300 * u), fill=color + (255,))
    rounded_bar(d, 332 * u, 796 * u, 692 * u, 852 * u, color + (255,))
    return img


def finish(img):
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def write_set(name, light, dark, tinted):
    folder = os.path.join(ROOT, f"{name}.appiconset")
    os.makedirs(folder, exist_ok=True)
    finish(light).convert("RGB").save(os.path.join(folder, "icon-1024.png"), optimize=True)
    finish(dark).convert("RGB").save(os.path.join(folder, "icon-1024-dark.png"), optimize=True)
    finish(tinted).save(os.path.join(folder, "icon-1024-tinted.png"), optimize=True)
    contents = {
        "images": [
            {"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "icon-1024-dark.png",
             "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "filename": "icon-1024-tinted.png",
             "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
        f.write("\n")
    print("wrote", folder)


def main():
    os.makedirs(ROOT, exist_ok=True)
    with open(os.path.join(ROOT, "Contents.json"), "w") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")

    transparent = (0, 0, 0, 0)

    # Royal: the primary icon.
    write_set("AppIcon",
              draw_mark(gradient(ROYAL, ROYAL_DEEP), WHITE, hole=None),
              draw_mark(flat(NAVY), WHITE, hole=None),
              draw_mark(Image.new("RGBA", (S, S), transparent), TINT_GREY, hole=None))
    # Tech blue.
    write_set("AppIcon-Tech",
              draw_mark(gradient(TECH, TECH_DEEP), WHITE, hole=None),
              draw_mark(flat(NAVY), WHITE, hole=None),
              draw_mark(Image.new("RGBA", (S, S), transparent), TINT_GREY, hole=None))
    # Paper: blue mark on white.
    write_set("AppIcon-Paper",
              draw_mark(flat(PAPER), ROYAL, hole=None),
              draw_mark(flat(NAVY), WHITE, hole=None),
              draw_mark(Image.new("RGBA", (S, S), transparent), TINT_GREY, hole=None))
    # Star: the lone star.
    write_set("AppIcon-Star",
              draw_lone_star(gradient(ROYAL, ROYAL_DEEP), WHITE),
              draw_lone_star(flat(NAVY), WHITE),
              draw_lone_star(Image.new("RGBA", (S, S), transparent), TINT_GREY))


if __name__ == "__main__":
    main()
