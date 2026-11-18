#!/usr/bin/env python3
"""Build the nameplate DoT dots' art in a class-resource style (Grimoire 0.4.4).

Three 32 px textures, drawn by Dots.lua at the dots' size:

- DotEmpty.tga: a gold ring around a dark socket, for a DoT that is missing.
- DotOrb.tga: a lit sphere in grey, tinted with the DoT's color while it is up.
- DotRing.tga: the gold ring alone, drawn over the orb.

The ring is that of the shield display: a dark outline, gold lit from above,
a thin shadow inside. Output: uncompressed 32-bit TGA, top-left origin. Needs
numpy. Deterministic.
"""

import argparse
from pathlib import Path

import numpy as np

SIZE = 32
SUPERSAMPLE = 8
TEXTURES = Path(__file__).resolve().parent.parent / "Textures"

# Radii in texture pixels, from the center.
OUTLINE_OUTER = 15.2
GOLD_OUTER = 14.0
GOLD_INNER = 11.2
SHADOW_INNER = 10.2

OUTLINE = np.array([24, 16, 6], float)
GOLD_DARK = np.array([138, 98, 34], float)
GOLD_LIGHT = np.array([246, 214, 122], float)
SHADOW = np.array([16, 11, 5], float)
SOCKET = np.array([20, 17, 14], float)


def grid():
    count = SIZE * SUPERSAMPLE
    axis = (np.arange(count) + 0.5) / SUPERSAMPLE - SIZE / 2.0
    x, y = np.meshgrid(axis, axis)
    return x, y, np.hypot(x, y)


def down(image):
    """Averages the samples of each pixel, colors weighted by their alpha."""
    weighted = image.copy()
    weighted[..., :3] *= weighted[..., 3:4]
    small = weighted.reshape(SIZE, SUPERSAMPLE, SIZE, SUPERSAMPLE, 4).mean(axis=(1, 3))
    alpha = small[..., 3:4]
    small[..., :3] = np.where(alpha > 0, small[..., :3] / np.maximum(alpha, 1e-6), 0)
    return small


def layer(image, mask, color, alpha=1.0):
    """Paints color over image where mask, premultiplied on straight alpha."""
    covered = mask * alpha
    image[..., :3] = image[..., :3] * (1 - covered[..., None]) + color * covered[..., None]
    image[..., 3] = image[..., 3] + (1 - image[..., 3]) * covered
    return image


def ring(image, x, y, r):
    """The frame: outline, gold lit from above, shadow inside."""
    layer(image, ((r <= OUTLINE_OUTER) & (r > GOLD_OUTER)).astype(float), OUTLINE, 0.95)
    # Lit from the top left: light there, dark at the bottom right.
    lit = np.clip(0.5 - (x * 0.45 + y * 0.9) / (2 * GOLD_OUTER) * 1.25, 0, 1)
    gold = GOLD_DARK + (GOLD_LIGHT - GOLD_DARK) * lit[..., None]
    band = ((r <= GOLD_OUTER) & (r > GOLD_INNER)).astype(float)
    image[..., :3] = image[..., :3] * (1 - band[..., None]) + gold * band[..., None]
    image[..., 3] = image[..., 3] + (1 - image[..., 3]) * band
    layer(image, ((r <= GOLD_INNER) & (r > SHADOW_INNER)).astype(float), SHADOW, 0.85)
    return image


def build_ring():
    x, y, r = grid()
    return down(ring(np.zeros(r.shape + (4,)), x, y, r))


def build_empty():
    x, y, r = grid()
    image = np.zeros(r.shape + (4,))
    # A dark socket, a little lighter toward the bottom, as an empty pip.
    depth = np.clip(0.5 + y / (2 * GOLD_INNER), 0, 1)
    socket = SOCKET * (0.7 + 0.6 * depth[..., None])
    inside = (r <= GOLD_INNER).astype(float)
    image[..., :3] = socket * inside[..., None]
    image[..., 3] = inside * 0.85
    return down(ring(image, x, y, r))


def build_orb():
    x, y, r = grid()
    image = np.zeros(r.shape + (4,))
    radius = GOLD_INNER + 0.4
    inside = (r <= radius).astype(float)
    # A sphere lit from the top left: bright body, darker rim, a soft highlight.
    edge = np.clip(r / radius, 0, 1)
    body = 0.92 - 0.42 * edge ** 2.2
    light = np.exp(-(((x + radius * 0.32) ** 2 + (y + radius * 0.38) ** 2) / (2 * (radius * 0.36) ** 2)))
    shade = np.clip(body + 0.35 * light - 0.10 * np.clip((x + y) / (2 * radius), 0, 1), 0, 1)
    image[..., :3] = (shade * 255)[..., None] * inside[..., None]
    image[..., 3] = inside
    return down(image)


def tga(image):
    height, width = image.shape[:2]
    header = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, width & 255, width >> 8, height & 255, height >> 8, 32, 0x28])
    rgba = np.clip(np.round(image * np.array([1, 1, 1, 255.0])), 0, 255).astype(np.uint8)
    return header + rgba[..., [2, 1, 0, 3]].tobytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=TEXTURES)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, image in (("DotRing", build_ring()), ("DotEmpty", build_empty()), ("DotOrb", build_orb())):
        (args.out / (name + ".tga")).write_bytes(tga(image))
        print(name)


if __name__ == "__main__":
    main()
