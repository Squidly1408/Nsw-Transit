"""Draws the NSW Transit logo and writes the PNGs used by flutter_launcher_icons.

Run from the project root:  python tool/make_logo.py
Then:                       dart run flutter_launcher_icons
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "logo"
SIZE = 1024
SS = 4  # supersampling factor for smooth edges

NAVY_TOP = (16, 42, 92)
NAVY_BOTTOM = (6, 20, 52)
WHITE = (255, 255, 255)
ORANGE = (247, 144, 30)
TEAL = (0, 180, 200)


def gradient(size):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(round(a + (b - a) * t) for a, b in zip(NAVY_TOP, NAVY_BOTTOM))
        d.line([(0, y), (size, y)], fill=c)
    return img


def bezier(p0, p1, p2, p3, n=200):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        x = u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def draw_mark(d, s, scale=1.0):
    """Draws the route mark centred in an s x s canvas. scale shrinks it toward the centre."""
    c = s / 2

    def P(x, y):  # coordinates given on a 0..1 grid
        return (c + (x - 0.5) * s * scale, c + (y - 0.5) * s * scale)

    w = s * scale
    line_w = int(w * 0.075)

    # Route: from origin (bottom left) curving up to the destination pin (top right)
    start = P(0.27, 0.76)
    end = P(0.66, 0.53)
    path = bezier(start, P(0.64, 0.80), P(0.28, 0.50), end, n=1500)
    r = line_w / 2  # stamp circles along the curve: wide PIL lines leave gaps on bends
    for x, y in path:
        d.ellipse([x - r, y - r, x + r, y + r], fill=WHITE)

    # Origin: teal dot with white ring
    ox, oy = start
    r1, r2 = w * 0.085, w * 0.045
    d.ellipse([ox - r1, oy - r1, ox + r1, oy + r1], fill=WHITE)
    d.ellipse([ox - r2, oy - r2, ox + r2, oy + r2], fill=TEAL)

    # Destination pin (orange teardrop) sitting on the end of the route
    px, py = P(0.66, 0.30)
    pr = w * 0.13
    tip = (px, py + pr * 2.05)
    d.polygon([(px - pr * 0.86, py + pr * 0.5), (px + pr * 0.86, py + pr * 0.5), tip], fill=ORANGE)
    d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=ORANGE)
    hr = pr * 0.42
    d.ellipse([px - hr, py - hr, px + hr, py + hr], fill=WHITE)


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    big = SIZE * SS

    # Full icon (iOS + legacy Android): opaque square, the OS applies its own mask
    icon = gradient(big)
    draw_mark(ImageDraw.Draw(icon), big)
    icon = icon.resize((SIZE, SIZE), Image.LANCZOS)
    icon.save(OUT / "app_icon.png")

    # Adaptive foreground (Android 8+): transparent, mark kept inside the 66% safe zone
    fg = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw_mark(ImageDraw.Draw(fg), big, scale=0.62)
    fg.resize((SIZE, SIZE), Image.LANCZOS).save(OUT / "app_icon_foreground.png")

    # In-app logo: rounded tile with transparent corners
    tile = gradient(big).convert("RGBA")
    draw_mark(ImageDraw.Draw(tile), big)
    tile.putalpha(rounded_mask(big, int(big * 0.22)))
    tile.resize((512, 512), Image.LANCZOS).save(OUT / "logo.png")

    print(f"Wrote logo PNGs to {OUT}")


if __name__ == "__main__":
    main()
