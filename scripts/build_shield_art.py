#!/usr/bin/env python3
"""Build the shield display's art in a class-resource style (Grimoire 0.3.2, rows 0.3.3).

For each crescent (the outer one for the absorb, the inner one for shields
that drain with time, the innermost for bubbles) and each side of the
character (Right, Left, Top, Bottom) two textures:

- ShieldRing<Crescent><Side>.tga: the fill. White with a soft highlight band
  across its thickness, so the display's tint gives a lit, rounded look. The
  display fills it with a StatusBar (from the foot) and draws the same texture
  in black underneath as the empty track.
- ShieldRing<Crescent>Rim<Side>.tga: the frame drawn over it. A dark outline,
  a gold edge lit from above and a thin shadow inside. Not tinted. (Ticks that
  split it into segments are possible, SEGMENTS below; off since 0.3.3.)

And for the rows style, the same look as straight bars: ShieldBar<Thin><H|V>
and ShieldBarRim<Thin><H|V>, H for a row (fills from the left), V for a
column (fills from the bottom), Thin for the timed shields' bars.

The geometry is that of Dyre's Shields Up (scripts/build_arc.py there): each
crescent is part of a ring centered left of the square, stretched to span the
texture from top to bottom, and drawn by the display at its own height (the
spans in Shield.lua). Left is Right mirrored; Bottom is Right turned a quarter
clockwise and Top is Left turned the same way, so on both the foot is at the
left end and the bar fills left to right.

Output: uncompressed 32-bit TGA, top-left origin. Needs numpy. Deterministic.
"""

import argparse
from pathlib import Path

import numpy as np

UNIT = 128.0
CENTER_X = 8.0
SUPERSAMPLE = 4
TEXTURES = Path(__file__).resolve().parent.parent / "Textures"

# name: outer radius, inner radius, height (all in UNIT pixels), texture size,
# segments, and rim widths (outline, gold, shadow).
CRESCENTS = {
    "": (112.0, 96.0, 118.0, 256, 0, (0.9, 1.6, 0.6)),
    "Inner": (91.0, 83.0, 94.0, 128, 0, (0.7, 1.0, 0.4)),
    "Innermost": (78.0, 71.0, 70.0, 128, 0, (0.7, 1.0, 0.4)),
}

# Bars for the rows style: display size (length, thickness) in pixels at
# 100%, texture size (length, thickness), rim widths, corner radius. Shield.lua's
# ROW sizes must match.
BARS = {
    "": ((160.0, 14.0), (256, 32), (0.9, 1.6, 0.6), 2.5),
    "Thin": ((160.0, 7.0), (256, 16), (0.7, 1.0, 0.4), 1.5),
}

OUTLINE = np.array([24, 16, 6], float)
GOLD_DARK = np.array([138, 98, 34], float)
GOLD_LIGHT = np.array([246, 214, 122], float)
SHADOW = np.array([16, 11, 5], float)
TICK = np.array([10, 8, 4], float)


def samples(size, tall):
    """Shape coordinates (x, rise) for every subsample, shaped (size, size, SS*SS)."""
    offsets = (np.arange(SUPERSAMPLE) + 0.5) / SUPERSAMPLE
    u = (np.arange(size)[None, :, None, None] + offsets[None, None, None, :])
    v = (np.arange(size)[:, None, None, None] + offsets[None, None, :, None])
    u = np.broadcast_to(u, (size, size, SUPERSAMPLE, SUPERSAMPLE)).reshape(size, size, -1)
    v = np.broadcast_to(v, (size, size, SUPERSAMPLE, SUPERSAMPLE)).reshape(size, size, -1)
    x = u * UNIT / size
    rise = (size - v) / size * tall
    return x, rise


def build(outer, inner, tall, size, segments, rim):
    x, rise = samples(size, tall)
    dx, dy = x - CENTER_X, rise - tall / 2
    dist = np.hypot(dx, dy)
    angle = np.arctan2(dy, dx)
    inside = (dist >= inner) & (dist <= outer) & (x >= CENTER_X) & (rise >= 0) & (rise <= tall)

    # Fill: brightest a little outside the middle of the band.
    t = np.clip((dist - inner) / (outer - inner), 0, 1)
    shade = 0.62 + 0.38 * np.exp(-((t - 0.6) / 0.25) ** 2)
    fill_alpha = inside.astype(float)
    fill_rgb = np.repeat((shade * 255)[..., None], 3, axis=-1)

    # Rim: distance to the nearest edge (inner, outer, the flat ends).
    edge = np.minimum.reduce([dist - inner, outer - dist, rise, tall - rise])
    outline, gold, shadow = rim
    rgb = np.zeros(x.shape + (3,))
    alpha = np.zeros(x.shape)
    lit = np.clip(rise / tall, 0, 1)[..., None]
    gold_rgb = GOLD_DARK + (GOLD_LIGHT - GOLD_DARK) * lit
    zones = [
        (edge < outline, OUTLINE, 0.92),
        ((edge >= outline) & (edge < outline + gold), None, 1.0),
        ((edge >= outline + gold) & (edge < outline + gold + shadow), SHADOW, 0.45),
    ]
    for mask, color, opacity in zones:
        mask = mask & inside
        rgb[mask] = gold_rgb[mask] if color is None else color
        alpha[mask] = opacity
    # Ticks between segments, evenly along the crescent's height, as radial lines.
    top = np.arctan2(tall / 2, np.sqrt(max(outer ** 2 - (tall / 2) ** 2, 1)))
    interior = inside & (edge >= outline + gold)
    for k in range(1, segments):
        mark = -top + 2 * top * k / segments
        near = np.abs(angle - mark) * dist < 0.55
        mask = interior & near
        rgb[mask] = TICK
        alpha[mask] = 0.6

    def average(color, coverage):
        weight = coverage.sum(axis=-1)
        mean = (color * coverage[..., None]).sum(axis=-2) / np.maximum(weight, 1e-9)[..., None]
        return np.dstack([mean, weight / coverage.shape[-1]])

    return average(fill_rgb, fill_alpha), average(rgb, alpha)


def build_bar(display, texture, rim, radius):
    """A bar lying flat, its length across the texture: fill and rim."""
    length, thick = display
    width, height = texture
    offsets = (np.arange(SUPERSAMPLE) + 0.5) / SUPERSAMPLE
    u = np.arange(width)[None, :, None, None] + offsets[None, None, None, :]
    v = np.arange(height)[:, None, None, None] + offsets[None, None, :, None]
    u = np.broadcast_to(u, (height, width, SUPERSAMPLE, SUPERSAMPLE)).reshape(height, width, -1)
    v = np.broadcast_to(v, (height, width, SUPERSAMPLE, SUPERSAMPLE)).reshape(height, width, -1)
    # Display pixels: x along the bar, y up from its bottom edge.
    x = u * length / width
    y = (height - v) * thick / height
    # Distance inside a rounded rectangle (positive inside).
    qx = np.abs(x - length / 2) - (length / 2 - radius)
    qy = np.abs(y - thick / 2) - (thick / 2 - radius)
    outside = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - radius
    edge = -outside
    inside = edge >= 0
    t = np.clip(y / thick, 0, 1)
    shade = 0.62 + 0.38 * np.exp(-((t - 0.6) / 0.25) ** 2)
    fill_alpha = inside.astype(float)
    fill_rgb = np.repeat((shade * 255)[..., None], 3, axis=-1)
    outline, gold, shadow = rim
    rgb = np.zeros(x.shape + (3,))
    alpha = np.zeros(x.shape)
    gold_rgb = GOLD_DARK + (GOLD_LIGHT - GOLD_DARK) * t[..., None]
    for mask, color, opacity in [
        (edge < outline, OUTLINE, 0.92),
        ((edge >= outline) & (edge < outline + gold), None, 1.0),
        ((edge >= outline + gold) & (edge < outline + gold + shadow), SHADOW, 0.45),
    ]:
        mask = mask & inside
        rgb[mask] = gold_rgb[mask] if color is None else color
        alpha[mask] = opacity

    def average(color, coverage):
        weight = coverage.sum(axis=-1)
        mean = (color * coverage[..., None]).sum(axis=-2) / np.maximum(weight, 1e-9)[..., None]
        return np.dstack([mean, weight / coverage.shape[-1]])

    return average(fill_rgb, fill_alpha), average(rgb, alpha)


def sides(image):
    right = image
    left = right[:, ::-1]
    return {"Right": right, "Left": left, "Bottom": np.rot90(right, k=-1), "Top": np.rot90(left, k=-1)}


def tga(image):
    height, width = image.shape[:2]
    header = bytes((0, 0, 2)) + bytes(9) + width.to_bytes(2, "little") + height.to_bytes(2, "little") \
        + bytes((32, 0x28))
    rgba = np.clip(np.round(image * np.array([1, 1, 1, 255])), 0, 255).astype(np.uint8)
    bgra = rgba[..., [2, 1, 0, 3]]
    return header + np.ascontiguousarray(bgra).tobytes()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=TEXTURES)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name, (outer, inner, tall, size, segments, rim) in CRESCENTS.items():
        fill, frame = build(outer, inner, tall, size, segments, rim)
        for side, image in sides(fill).items():
            (args.output_dir / f"ShieldRing{name}{side}.tga").write_bytes(tga(image))
        for side, image in sides(frame).items():
            (args.output_dir / f"ShieldRing{name}Rim{side}.tga").write_bytes(tga(image))
    for name, (display, texture, rim, radius) in BARS.items():
        fill, frame = build_bar(display, texture, rim, radius)
        # A column: the row turned a quarter counterclockwise, so its left
        # end (where a row starts filling) is at the bottom.
        for part, image in (("", fill), ("Rim", frame)):
            (args.output_dir / f"ShieldBar{part}{name}H.tga").write_bytes(tga(image))
            (args.output_dir / f"ShieldBar{part}{name}V.tga").write_bytes(tga(np.ascontiguousarray(np.rot90(image, k=1))))


if __name__ == "__main__":
    main()
