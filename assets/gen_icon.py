#!/usr/bin/env python3
"""Generate the Morse Runner app icon (assets/icon_master.png, 1024x1024).

Design: a rounded-square "radio night" tile (deep navy -> blue gradient) with the
Morse code for CQ -.-. / --.-  (the call you send with F1) glowing in cyan-white,
plus broadcast/signal arcs radiating from the transmission. Rendered at 4x
supersampling with soft glow, then downscaled for crisp edges.
"""
from PIL import Image, ImageDraw, ImageFilter

S = 4                      # supersampling factor
N = 1024 * S               # working canvas size
R = int(0.224 * N)         # corner radius (macOS-ish squircle approximation)

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

# ---- background: diagonal gradient + radial glow -----------------------------
bg = Image.new("RGB", (N, N))
px = bg.load()
top = (30, 74, 140)        # blue
bot = (8, 20, 44)          # deep navy
for y in range(N):
    row = lerp(top, bot, y / (N - 1))
    for x in range(N):
        px[x, y] = row
# radial cyan glow behind the morse (center-ish)
glow = Image.new("L", (N, N), 0)
gd = ImageDraw.Draw(glow)
cx, cy, rr = int(N * 0.5), int(N * 0.52), int(N * 0.42)
gd.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=90)
glow = glow.filter(ImageFilter.GaussianBlur(N // 10))
cyan = Image.new("RGB", (N, N), (46, 160, 210))
bg = Image.composite(cyan, bg, glow.point(lambda v: int(v * 0.55)))

# ---- foreground layers -------------------------------------------------------
fg = Image.new("RGBA", (N, N), (0, 0, 0, 0))
fd = ImageDraw.Draw(fg)

WHITE = (233, 250, 255, 255)
CYAN  = (150, 226, 255, 255)

def rounded_h(draw, x0, y0, length, thick, fill):
    """horizontal rounded bar / dot"""
    draw.rounded_rectangle([x0, y0, x0 + length, y0 + thick],
                           radius=thick // 2, fill=fill)

def morse_row(draw, pattern, cx, cy, unit, thick, gap, fill):
    widths = [unit if c == '.' else unit * 3 for c in pattern]
    total = sum(widths) + gap * (len(pattern) - 1)
    x = cx - total // 2
    for c, w in zip(pattern, widths):
        rounded_h(draw, x, cy - thick // 2, w, thick, fill)
        x += w + gap

unit  = int(N * 0.072)     # dot length
thick = int(N * 0.072)     # bar thickness (dot is a circle)
gap   = int(N * 0.052)
row_dy = int(N * 0.135)
midx = N // 2
midy = int(N * 0.52)

# broadcast arcs radiating from the right, behind the morse
arc_layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
ad = ImageDraw.Draw(arc_layer)
ax, ay = int(N * 0.5), int(N * 0.5)
for i, rad in enumerate((int(N*0.30), int(N*0.37), int(N*0.44))):
    bbox = [ax - rad, ay - rad, ax + rad, ay + rad]
    ad.arc(bbox, start=-38, end=38, fill=(150, 226, 255, 150 - i*30), width=int(N*0.012))
arc_layer = arc_layer.filter(ImageFilter.GaussianBlur(S))

# two Morse rows: C (-.-.) over Q (--.-)
morse_row(fd, "-.-.", midx, midy - row_dy // 2, unit, thick, gap, WHITE)
morse_row(fd, "--.-", midx, midy + row_dy // 2, unit, thick, gap, WHITE)

# baseline under the morse
by = midy + row_dy // 2 + int(N * 0.11)
fd.rounded_rectangle([int(N*0.30), by, int(N*0.70), by + int(N*0.010)],
                     radius=int(N*0.005), fill=(150, 226, 255, 120))

# glow copy of the foreground
glow_fg = fg.filter(ImageFilter.GaussianBlur(int(N * 0.012)))

# compose: bg + arcs + glow + crisp fg
canvas = bg.convert("RGBA")
canvas = Image.alpha_composite(canvas, arc_layer)
canvas = Image.alpha_composite(canvas, glow_fg)
canvas = Image.alpha_composite(canvas, fg)

# top highlight sheen
sheen = Image.new("L", (N, N), 0)
sd = ImageDraw.Draw(sheen)
sd.ellipse([-int(N*0.2), -int(N*0.55), int(N*1.2), int(N*0.35)], fill=42)
sheen = sheen.filter(ImageFilter.GaussianBlur(N // 12))
white = Image.new("RGBA", (N, N), (255, 255, 255, 255))
canvas = Image.composite(white, canvas, sheen)

# ---- rounded-corner mask -----------------------------------------------------
mask = Image.new("L", (N, N), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, N - 1, N - 1], radius=R, fill=255)
out = Image.new("RGBA", (N, N), (0, 0, 0, 0))
out.paste(canvas, (0, 0), mask)

# subtle inner border
bd = ImageDraw.Draw(out)
bd.rounded_rectangle([S, S, N - 1 - S, N - 1 - S], radius=R,
                     outline=(255, 255, 255, 40), width=int(S * 1.5))

out = out.resize((1024, 1024), Image.LANCZOS)
out.save("assets/icon_master.png")
print("wrote assets/icon_master.png")
