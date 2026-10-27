"""Постеры «Люмена» в том же плоском стиле, что и игра. Без текста: так их можно ставить на все языки."""

from PIL import Image, ImageDraw, ImageFilter, ImageFont

TITLE = "Люмен"
FONT = "/System/Library/Fonts/Supplemental/Iowan Old Style.ttc"

S = 4


def new(w, h):
    return Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))


def finish(im, w, h):
    return im.resize((w, h), Image.Resampling.LANCZOS)


def ellipse(d, box, fill):
    d.ellipse([v * S for v in box], fill=fill)


def circle(d, c, r, fill):
    ellipse(d, (c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill)


def poly(d, pts, fill):
    d.polygon([(x * S, y * S) for x, y in pts], fill=fill)


def line(d, a, b, fill, width):
    d.line([(a[0] * S, a[1] * S), (b[0] * S, b[1] * S)], fill=fill, width=max(1, int(width * S)))


def bands(d, w, h):
    colors = ["#8fd4ef", "#f7d7a1", "#f3b36a", "#7dba78", "#3e8f62"]
    stripe = h / len(colors)
    for i, color in enumerate(colors):
        d.rectangle([0, int(stripe * i * S), w * S, int((stripe * (i + 1) + 1) * S)], fill=color)


def glow(base, c, r, color, alpha=90):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(layer)
    circle(dd, c, r, (*color, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(radius=18 * S))
    return Image.alpha_composite(base, layer)


def lamp(d, x, y, scale=1.0, lit=True):
    line(d, (x, 0), (x, y), "#c9862f", 3 * scale)
    cup = [
        (x - 16 * scale, y),
        (x + 16 * scale, y),
        (x + 22 * scale, y + 28 * scale),
        (x - 22 * scale, y + 28 * scale),
    ]
    poly(d, cup, "#f0c15a" if lit else "#b9a07a")
    circle(d, (x, y + 36 * scale), 14 * scale, "#ffe3a3" if lit else "#d9c7a4")
    circle(d, (x - 5 * scale, y + 30 * scale), 4 * scale, (255, 255, 255, 180))


def bush(d, x, y, r, color):
    circle(d, (x - r * 0.35, y + r * 0.1), r * 0.72, color)
    circle(d, (x + r * 0.28, y), r * 0.8, color)
    circle(d, (x, y + r * 0.22), r * 0.66, color)


def luma(d, x, y, scale=1.0):
    s = scale
    circle(d, (x - 34 * s, y + 8 * s), 16 * s, "#2f8f55")
    circle(d, (x + 34 * s, y + 10 * s), 14 * s, "#3eaf68")
    poly(d, [
        (x - 28 * s, y - 8 * s),
        (x + 28 * s, y - 8 * s),
        (x + 40 * s, y + 48 * s),
        (x - 40 * s, y + 48 * s),
    ], "#f6d7b0")
    circle(d, (x, y - 6 * s), 38 * s, "#ffe7c8")
    circle(d, (x, y - 8 * s), 34 * s, "#fff6ea")
    circle(d, (x - 12 * s, y - 10 * s), 8 * s, "#243028")
    circle(d, (x + 12 * s, y - 10 * s), 8 * s, "#243028")
    circle(d, (x - 10 * s, y - 12 * s), 2.4 * s, "#ffffff")
    circle(d, (x + 14 * s, y - 12 * s), 2.4 * s, "#ffffff")
    line(d, (x - 10 * s, y - 36 * s), (x - 22 * s, y - 58 * s), "#3eaf68", 3 * s)
    line(d, (x + 10 * s, y - 36 * s), (x + 22 * s, y - 58 * s), "#3eaf68", 3 * s)
    circle(d, (x - 22 * s, y - 58 * s), 6 * s, "#ffe08a")
    circle(d, (x + 22 * s, y - 58 * s), 6 * s, "#ffe08a")
    lamp_at = (x + 48 * s, y + 18 * s)
    line(d, (x + 24 * s, y + 10 * s), lamp_at, "#c9862f", 4 * s)
    circle(d, lamp_at, 16 * s, "#ffe7a3")
    circle(d, lamp_at, 8 * s, "#fff8df")


def fern(d, x, y, s=1.0):
    line(d, (x, y + 22 * s), (x, y - 24 * s), "#1d6b38", 3 * s)
    for i, (yy, w) in enumerate(((14, 14), (4, 18), (-6, 16), (-16, 10))):
        tint = "#2f9d52" if i % 2 == 0 else "#8ed97a"
        poly(d, [(x, y + yy * s), (x - w * s, y + (yy - 8) * s), (x, y + (yy - 3) * s)], tint)
        poly(d, [(x, y + yy * s), (x + w * s, y + (yy - 8) * s), (x, y + (yy - 3) * s)], tint)
    poly(d, [(x, y - 28 * s), (x + 6 * s, y - 18 * s), (x, y - 21 * s), (x - 6 * s, y - 18 * s)], "#e7ffd8")


def beetle(d, x, y, s=1.0):
    for side in (-1, 1):
        for i in range(3):
            yy = y - 4 * s + i * 7 * s
            line(d, (x, yy), (x + side * 18 * s, yy + 3 * s), "#8a5608", 2 * s)
    ellipse(d, (x - 13 * s, y - 2 * s, x + 13 * s, y + 22 * s), "#e8a317")
    line(d, (x, y), (x, y + 18 * s), "#8a5608", 1.4 * s)
    circle(d, (x - 4 * s, y + 6 * s), 2 * s, "#fff1c4")
    circle(d, (x + 4 * s, y + 10 * s), 2 * s, "#fff1c4")
    circle(d, (x, y - 12 * s), 7 * s, "#e8a317")
    circle(d, (x - 2 * s, y - 13 * s), 1.3 * s, "#2a2114")
    circle(d, (x + 2 * s, y - 13 * s), 1.3 * s, "#2a2114")


def moss(d, x, y, s=1.0):
    for dx, dy, r in ((-12, 6, 10), (0, 2, 12), (12, 7, 9), (-6, -4, 7), (7, -5, 7)):
        circle(d, (x + dx * s, y + dy * s), r * s, "#1aa6a0")
    circle(d, (x - 2 * s, y - 2 * s), 3 * s, "#b7fff4")


def pearl(d, x, y, s=1.0):
    poly(d, [(x, y + 8 * s), (x + 12 * s, y + 4 * s), (x + 8 * s, y + 14 * s), (x - 8 * s, y + 14 * s), (x - 12 * s, y + 4 * s)], "#7dcea0")
    circle(d, (x, y - 4 * s), 12 * s, "#f7c3d4")
    circle(d, (x, y - 4 * s), 8 * s, "#fff0f5")
    circle(d, (x - 4 * s, y - 8 * s), 3 * s, (255, 255, 255, 230))


def vine(d, x, y, s=1.0):
    line(d, (x - 14 * s, y + 14 * s), (x - 4 * s, y), "#a33a28", 3 * s)
    line(d, (x - 4 * s, y), (x + 8 * s, y + 2 * s), "#a33a28", 3 * s)
    line(d, (x + 8 * s, y + 2 * s), (x + 16 * s, y - 16 * s), "#a33a28", 3 * s)
    poly(d, [(x - 12 * s, y + 8 * s), (x - 22 * s, y - 2 * s), (x - 8 * s, y + 2 * s)], "#ef5d42")
    poly(d, [(x + 12 * s, y - 8 * s), (x + 22 * s, y - 18 * s), (x + 8 * s, y - 14 * s)], "#ef5d42")


def frost(d, x, y, s=1.0):
    import math
    pts = []
    for i in range(6):
        a = -math.pi / 2 + math.tau * i / 6
        pts.append((x + math.cos(a) * 14 * s, y + math.sin(a) * 14 * s))
    poly(d, pts, "#f4fbff")
    circle(d, (x - 3 * s, y - 4 * s), 2 * s, "#ffffff")


def moth(d, x, y, s=1.0):
    poly(d, [(x, y), (x - 18 * s, y - 10 * s), (x - 12 * s, y + 6 * s)], "#f6d7b0")
    poly(d, [(x, y), (x + 18 * s, y - 10 * s), (x + 12 * s, y + 6 * s)], "#f6d7b0")
    ellipse(d, (x - 3 * s, y - 6 * s, x + 3 * s, y + 10 * s), "#6b3a22")
    circle(d, (x, y - 8 * s), 3.2 * s, "#2a2114")


def pieces_row(d, x, y, s=1.0, gap=58):
    drawers = [fern, beetle, moss, pearl, vine, frost]
    for i, fn in enumerate(drawers):
        fn(d, x + i * gap * s, y, s)


def garden_frame(w, h):
    im = new(w, h)
    d = ImageDraw.Draw(im)
    bands(d, w, h)
    return im, d


def draw_title(im, x, y, size):
    font = ImageFont.truetype(FONT, int(size * S), index=0)
    layer = ImageDraw.Draw(im)
    layer.text((x * S, y * S), TITLE, font=font, fill="#1d4a32", anchor="mm")


def floor(d, w, y):
    d.rectangle([0, int(y * S), w * S, 4000], fill="#d9a15c")
    d.rectangle([0, int(y * S), w * S, int((y + 8) * S)], fill="#f0c98a")


def icon():
    w = h = 512
    im, d = garden_frame(w, h)
    im = glow(im, (250, 230), 170, (255, 226, 150), 70)
    d = ImageDraw.Draw(im)
    lamp(d, 118, 8, 0.85)
    lamp(d, 394, 4, 0.95)
    draw_title(im, 256, 108, 62)
    d = ImageDraw.Draw(im)
    bush(d, 8, 370, 72, "#1f7a45")
    bush(d, 508, 360, 80, "#2f8f55")
    circle(d, (48, 360), 14, "#e25b78")
    circle(d, (470, 356), 12, "#f2d36b")
    luma(d, 228, 268, 1.7)
    fern(d, 150, 448, 1.45)
    beetle(d, 256, 450, 1.4)
    pearl(d, 362, 442, 1.45)
    return finish(im, w, h)


def maskable():
    w = h = 512
    im, d = garden_frame(w, h)
    im = glow(im, (256, 250), 140, (255, 226, 150), 70)
    d = ImageDraw.Draw(im)
    lamp(d, 168, 70, 0.7)
    lamp(d, 348, 64, 0.78)
    draw_title(im, 256, 168, 46)
    d = ImageDraw.Draw(im)
    luma(d, 236, 292, 1.35)
    fern(d, 175, 408, 1.0)
    beetle(d, 256, 410, 0.95)
    pearl(d, 338, 404, 1.0)
    return finish(im, w, h)


def cover():
    w, h = 800, 470
    im, d = garden_frame(w, h)
    im = glow(im, (310, 210), 200, (255, 220, 140), 80)
    d = ImageDraw.Draw(im)
    lamp(d, 90, 4, 1.0)
    lamp(d, 360, 0, 1.25)
    lamp(d, 700, 8, 0.9)
    bush(d, -20, 360, 100, "#14633a")
    bush(d, 820, 350, 110, "#2f8f55")
    circle(d, (55, 355), 16, "#e25b78")
    circle(d, (745, 360), 14, "#f2d36b")
    moth(d, 690, 300, 1.15)
    luma(d, 230, 230, 1.9)
    draw_title(im, 560, 175, 84)
    d = ImageDraw.Draw(im)
    fern(d, 500, 360, 1.55)
    beetle(d, 610, 368, 1.5)
    pearl(d, 720, 354, 1.55)
    return finish(im, w, h)


def banner():
    w, h = 1560, 520
    im, d = garden_frame(w, h)
    im = glow(im, (780, 240), 280, (255, 220, 140), 90)
    d = ImageDraw.Draw(im)
    for x, sc in ((140, 0.95), (400, 1.15), (780, 1.35), (1160, 1.1), (1440, 0.9)):
        lamp(d, x, 4, sc)
    bush(d, -10, 400, 130, "#14633a")
    bush(d, 1570, 390, 140, "#1f7a45")
    draw_title(im, 780, 150, 78)
    d = ImageDraw.Draw(im)
    luma(d, 720, 300, 1.75)
    moth(d, 1040, 175, 1.35)
    moth(d, 1180, 210, 1.15)
    moth(d, 430, 150, 1.1)
    fern(d, 250, 400, 1.7)
    beetle(d, 380, 408, 1.6)
    moss(d, 500, 410, 1.55)
    pearl(d, 1040, 400, 1.65)
    vine(d, 1180, 400, 1.6)
    frost(d, 1320, 390, 1.7)
    return finish(im, w, h)


if __name__ == "__main__":
    out = "/Users/makey/Desktop/Проекты/telegram-ai-miniapp/lumen-godot/promo"
    for name, image in (
        ("icon-512.png", icon()),
        ("icon-maskable-512.png", maskable()),
        ("cover-800x470.png", cover()),
        ("banner-1560x520.png", banner()),
    ):
        image.convert("RGB").save(f"{out}/{name}", "PNG")
    print("ok")
