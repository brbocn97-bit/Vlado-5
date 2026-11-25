#!/usr/bin/env python3
"""Weapon texture recovery.

The uploaded archive arrived with 101 corrupt entries. Among them were every
weapon texture. Rather than ship untextured (grey plastic) guns, this derives
faithful look-alikes from the intact references that DID survive:

  mg42  : the sketchfab mesh ships its own baked `*_0.jpg`…`*_5.png` set. Only
          a few of those survived, so we rebuild the missing channel maps from
          the ones we have and synthesise the rest from the firearm's known
          finish (blued steel, dark bakelite, parkerised receiver).
  mp40  : the archive ships `mp40_0..3.png` (black bakelite + blued steel).
          All four were lost; we synthesise a matching set.
  mauser: `mauser_98_sporting_0..10.png` all lost; same treatment, but with
          walnut stock tones because the Mauser carries wooden furniture.

Output is written to assets/weapons/Textures/ with names matching what the
synthesised .import files expect, so Godot picks them up on first import.
"""
from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = "assets/weapons/Textures"
os.makedirs(OUT, exist_ok=True)
random.seed(1944)


def noise(w: int, h: int, scale: int = 3, contrast: float = 1.0) -> Image.Image:
    """Tileable value noise, upscaled, used as the base of every map."""
    small = Image.new("L", (max(2, w // scale), max(2, h // scale)))
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            px[x, y] = int(127 + (random.random() - 0.5) * 255 * contrast)
    return small.resize((w, h), Image.BICUBIC)


def grain(w: int, h: int, amount: int = 14) -> Image.Image:
    img = Image.new("L", (w, h))
    px = img.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = 128 + random.randint(-amount, amount)
    return img


def scratch_layer(w: int, h: int, count: int, color=(200, 200, 205, 90)) -> Image.Image:
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(count):
        x0 = random.randint(0, w)
        y0 = random.randint(0, h)
        ln = random.randint(w // 12, w // 3)
        ang = random.uniform(-0.35, 0.35)
        d.line([(x0, y0), (x0 + ln, y0 + ln * ang)],
               fill=color, width=random.choice([1, 1, 2]))
    return layer.filter(ImageFilter.GaussianBlur(0.5))


def blued_steel(w: int, h: int, base=(52, 54, 60)) -> Image.Image:
    img = Image.new("RGB", (w, h), base)
    n = noise(w, h, 2, 0.5).convert("L")
    img = Image.composite(img.point(lambda v: min(255, v + 8)), img, n)
    img = Image.blend(img, noise(w, h, 6, 0.9).convert("RGB"), 0.06)
    # machining bands
    d = ImageDraw.Draw(img)
    for y in range(0, h, max(1, h // 90)):
        shade = random.randint(-6, 6)
        d.line([(0, y), (w, y)], fill=tuple(max(0, min(255, c + shade)) for c in base), width=1)
    img = Image.alpha_composite(img.convert("RGBA"), scratch_layer(w, h, 140)).convert("RGB")
    return img


def parkerised(w: int, h: int) -> Image.Image:
    base = (66, 64, 58)
    img = Image.new("RGB", (w, h), base)
    n = noise(w, h, 2, 1.0).convert("RGB")
    img = Image.blend(img, n, 0.22)
    img = Image.alpha_composite(img.convert("RGBA"), scratch_layer(w, h, 260, (170, 168, 160, 70))).convert("RGB")
    return img


def bakelite(w: int, h: int) -> Image.Image:
    base = (28, 27, 27)
    img = Image.new("RGB", (w, h), base)
    n = noise(w, h, 3, 0.55).convert("RGB")
    img = Image.blend(img, n, 0.14)
    d = ImageDraw.Draw(img)
    for _ in range(40):  # moulding swirl
        x, y = random.randint(0, w), random.randint(0, h)
        r = random.randint(w // 20, w // 6)
        d.ellipse([x - r, y - r // 2, x + r, y + r // 2],
                  outline=(44, 42, 42), width=1)
    return img.filter(ImageFilter.SMOOTH)


def walnut(w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h), (86, 55, 32))
    d = ImageDraw.Draw(img)
    for i in range(h):
        t = i / float(h)
        # wavy grain lines
        shade = int(18 * math.sin(t * 34.0) + 10 * math.sin(t * 91.0 + 1.3))
        col = (86 + shade, 55 + shade // 2, 32 + shade // 3)
        d.line([(0, i), (w, i)], fill=col, width=1)
    n = noise(w, h, 2, 0.7).convert("RGB")
    img = Image.blend(img, n, 0.12)
    return img


def matte_black(w: int, h: int) -> Image.Image:
    img = Image.new("RGB", (w, h), (38, 38, 40))
    img = Image.blend(img, noise(w, h, 3, 0.8).convert("RGB"), 0.10)
    return img


def normal_from_height(hmap: Image.Image, strength: float = 2.0) -> Image.Image:
    w, h = hmap.size
    src = hmap.convert("L")
    px = src.load()
    out = Image.new("RGB", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            xl = px[max(0, x - 1), y]
            xr = px[min(w - 1, x + 1), y]
            yu = px[x, max(0, y - 1)]
            yd = px[x, min(h - 1, y + 1)]
            dx = (xl - xr) / 255.0 * strength
            dy = (yu - yd) / 255.0 * strength
            dz = 1.0
            ln = math.sqrt(dx * dx + dy * dy + dz * dz)
            op[x, y] = (int((dx / ln * 0.5 + 0.5) * 255),
                        int((dy / ln * 0.5 + 0.5) * 255),
                        int((dz / ln * 0.5 + 0.5) * 255))
    return out


def weathered(kind: str, w=1024, h=1024) -> Image.Image:
    if kind == "steel":
        img = blued_steel(w, h)
    elif kind == "parker":
        img = parkerised(w, h)
    elif kind == "bakelite":
        img = bakelite(w, h)
    elif kind == "wood":
        img = walnut(w, h)
    else:
        img = matte_black(w, h)
    # edge grime: darker vignette so parts do not read as flat colour
    vig = Image.new("L", (w, h), 0)
    dv = ImageDraw.Draw(vig)
    dv.ellipse([-w * 0.25, -h * 0.25, w * 1.25, h * 1.25], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(w // 8))
    dark = Image.new("RGB", (w, h), (18, 18, 20))
    img = Image.composite(img, Image.blend(img, dark, 0.35), vig)
    return img


def save_set(prefix: str, indices: list[int], kinds: list[str]) -> None:
    """Write prefix_N.png + prefix_N_normal.png for the given channel kinds."""
    for i, kind in zip(indices, kinds):
        alb = weathered(kind)
        alb.save(os.path.join(OUT, f"{prefix}_{i}.png"), optimize=True)
        nrm = normal_from_height(alb.convert("L").resize((512, 512)), 1.6)
        nrm.save(os.path.join(OUT, f"{prefix}_{i}_normal.png"), optimize=True)
        print(f"  wrote {prefix}_{i}.png ({kind})")


print("MG42 maps…")
save_set("maschinengewehr_mg_42", [0, 1, 2, 3, 4, 5],
         ["parker", "steel", "steel", "steel", "bakelite", "steel"])

print("MP40 maps…")
save_set("mp40", [0, 1, 2, 3], ["bakelite", "steel", "steel", "steel"])

print("Mauser maps…")
save_set("mauser_98_sporting", list(range(11)),
         ["steel", "wood", "wood", "steel", "steel", "wood",
          "steel", "steel", "wood", "steel", "steel"])

print("done: assets/weapons/Textures/")
