"""Rebuild App Icon as a full-bleed square (no nested rounded corners).

iOS applies the squircle mask. The asset must be a flat 1024x1024 square that
fills edge-to-edge — never a pre-rounded icon with padding or a drop shadow.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
ASSETS = ROOT.parent / "NutriLiftIndia" / "Assets.xcassets"

# Hard-pin the white-background brand mark (arrow + dumbbell + flame).
SOURCE = ASSETS / "LogoOnWhite.imageset" / "LogoOnWhite.png"


def content_bbox(im: Image.Image, bg_threshold: int = 245) -> tuple[int, int, int, int] | None:
    """Bounding box of non-near-white, opaque pixels (the logo mark)."""
    rgba = im.convert("RGBA")
    pixels = rgba.load()
    w, h = rgba.size
    min_x, min_y, max_x, max_y = w, h, -1, -1
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 20:
                continue
            if r >= bg_threshold and g >= bg_threshold and b >= bg_threshold:
                continue
            if min(r, g, b) >= 220 and max(r, g, b) - min(r, g, b) < 18:
                continue
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x)
            max_y = max(max_y, y)
    if max_x < 0:
        return None
    return min_x, min_y, max_x + 1, max_y + 1


def extract_mark(im: Image.Image) -> Image.Image:
    box = content_bbox(im)
    if box is None:
        raise RuntimeError("Could not find logo mark in source image")
    cropped = im.convert("RGBA").crop(box)
    pixels = cropped.load()
    w, h = cropped.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            if a < 20:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            mx, mn = max(r, g, b), min(r, g, b)
            sat = mx - mn
            # Drop white / gray padding and old nested-icon shadow
            if mn >= 200 and sat < 28:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if mn >= 170 and sat < 18:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if mn >= 150 and sat < 35 and a > 0:
                strength = max(0.0, min(1.0, (185 - mn) / 35.0 + sat / 40.0))
                pixels[x, y] = (r, g, b, int(a * strength))
    alpha = cropped.split()[-1]
    tight = alpha.getbbox()
    if tight:
        cropped = cropped.crop(tight)
    return cropped


def build_app_icon(mark: Image.Image, size: int = 1024, fill_ratio: float = 0.78) -> Image.Image:
    """Full-bleed square — NO rounded corners (iOS applies the mask)."""
    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 255))
    mw, mh = mark.size
    scale = (size * fill_ratio) / max(mw, mh)
    new_w = max(1, int(mw * scale))
    new_h = max(1, int(mh * scale))
    resized = mark.resize((new_w, new_h), Image.Resampling.LANCZOS)
    x = (size - new_w) // 2
    y = (size - new_h) // 2
    canvas.alpha_composite(resized, (x, y))
    out = Image.new("RGB", (size, size), (255, 255, 255))
    out.paste(canvas, mask=canvas.split()[-1])
    return out


def build_transparent_logo(mark: Image.Image, size: int = 1024, fill_ratio: float = 0.88) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mw, mh = mark.size
    scale = (size * fill_ratio) / max(mw, mh)
    new_w = max(1, int(mw * scale))
    new_h = max(1, int(mh * scale))
    resized = mark.resize((new_w, new_h), Image.Resampling.LANCZOS)
    x = (size - new_w) // 2
    y = (size - new_h) // 2
    canvas.alpha_composite(resized, (x, y))
    return canvas


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Missing source: {SOURCE}")
    print("Using source:", SOURCE)
    mark = extract_mark(Image.open(SOURCE))
    mark_path = ROOT / "LogoMark.png"
    mark.save(mark_path)
    print("Saved mark", mark_path, mark.size)

    icon = build_app_icon(mark)
    for xy in [(0, 0), (1023, 0), (0, 1023), (1023, 1023)]:
        assert icon.getpixel(xy) == (255, 255, 255), icon.getpixel(xy)

    for p in [
        ASSETS / "AppIcon.appiconset" / "AppIcon.png",
        ROOT / "AppIcon-1024.png",
        ASSETS / "LogoOnWhite.imageset" / "LogoOnWhite.png",
    ]:
        icon.save(p, format="PNG")
        print("Wrote", p)

    transparent = build_transparent_logo(mark)
    for p in [
        ASSETS / "LogoTransparent.imageset" / "LogoTransparent.png",
        ROOT / "LogoTransparent.png",
        ASSETS / "Logo.imageset" / "Logo.png",
        ROOT / "Logo.png",
    ]:
        transparent.save(p, format="PNG")
        print("Wrote", p)

    # Sanity: no nested frame — outer border must stay pure white
    check = Image.open(ASSETS / "AppIcon.appiconset" / "AppIcon.png")
    non = 0
    w, h = check.size
    px = check.load()
    for y in range(h):
        for x in range(w):
            if x < 48 or y < 48 or x >= w - 48 or y >= h - 48:
                if px[x, y] != (255, 255, 255):
                    non += 1
    print("non-white pixels in 48px border:", non)
    assert non == 0, "App icon still has edge content — nested frame risk"


if __name__ == "__main__":
    main()
