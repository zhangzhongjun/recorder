#!/usr/bin/env python3
"""Generate DMG background image: dark gradient + arrow + instruction text."""
import struct, zlib, math, os, sys


def make_png(width, height, pixels_rgba):
    def chunk(tag, data):
        c = tag + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xFFFFFFFF)
    raw = b''
    for y in range(height):
        raw += b'\x00'
        raw += bytes(pixels_rgba[y * width * 4:(y + 1) * width * 4])
    out  = b'\x89PNG\r\n\x1a\n'
    out += chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    out += chunk(b'IDAT', zlib.compress(raw, 9))
    out += chunk(b'IEND', b'')
    return out


def lerp(a, b, t):
    return int(a + (b - a) * max(0.0, min(1.0, t)))


def draw_bg(width=660, height=400):
    pixels = []

    # Colours
    top    = (0x12, 0x0E, 0x2E)   # very dark indigo (top)
    bot    = (0x08, 0x18, 0x48)   # dark navy (bottom)

    # Pre-draw into a 2D RGBA array for easy pixel access
    buf = [[0, 0, 0, 255] for _ in range(width * height)]

    # ── Background gradient ────────────────────────────────────────────────
    for y in range(height):
        t = y / height
        r = lerp(top[0], bot[0], t)
        g = lerp(top[1], bot[1], t)
        b = lerp(top[2], bot[2], t)
        for x in range(width):
            buf[y * width + x] = [r, g, b, 255]

    # ── Subtle grid lines ──────────────────────────────────────────────────
    for y in range(0, height, 40):
        for x in range(width):
            p = buf[y * width + x]
            buf[y * width + x] = [min(255, p[0] + 8), min(255, p[1] + 8), min(255, p[2] + 16), 255]
    for x in range(0, width, 40):
        for y in range(height):
            p = buf[y * width + x]
            buf[y * width + x] = [min(255, p[0] + 6), min(255, p[1] + 6), min(255, p[2] + 12), 255]

    # ── Arrow (center of image, pointing right) ───────────────────────────
    ax, ay = width // 2, height // 2
    aw, ah = 80, 28          # arrow body width/height
    head_w = 44              # arrowhead width
    head_h = 56              # arrowhead height

    def set_px(x, y, r, g, b, a=200):
        if 0 <= x < width and 0 <= y < height:
            buf[y * width + x] = [r, g, b, a]

    def fill_rect(x0, y0, x1, y1, r, g, b, a=180):
        for yy in range(y0, y1):
            for xx in range(x0, x1):
                if 0 <= xx < width and 0 <= yy < height:
                    buf[yy * width + xx] = [r, g, b, a]

    # Arrow shaft
    shaft_x0 = ax - aw // 2
    shaft_x1 = ax + aw // 2
    shaft_y0 = ay - ah // 2
    shaft_y1 = ay + ah // 2
    fill_rect(shaft_x0, shaft_y0, shaft_x1, shaft_y1, 100, 160, 255, 160)

    # Arrowhead (triangle pointing right)
    tip_x = ax + aw // 2 + head_w
    for yy in range(ay - head_h // 2, ay + head_h // 2):
        t = abs(yy - ay) / (head_h / 2)
        x_start = ax + aw // 2
        x_end   = int(tip_x - t * head_w)
        for xx in range(x_start, x_end):
            if 0 <= xx < width and 0 <= yy < height:
                buf[yy * width + xx] = [100, 160, 255, 180]

    # ── Simple pixel-art text: "拖入 Applications 文件夹以安装" ───────────
    # Use a tiny 5×7 ASCII font for the English part below the arrow
    label = "Drag to Applications to install"
    font5x7 = {
        'D': [0b11110,0b10001,0b10001,0b10001,0b10001,0b10001,0b11110],
        'r': [0b00000,0b00000,0b10110,0b11001,0b10000,0b10000,0b10000],
        'a': [0b00000,0b00000,0b01110,0b10001,0b11111,0b10001,0b10001],
        'g': [0b00000,0b00000,0b01111,0b10001,0b10001,0b01111,0b00001,0b01110],
        ' ': [0b00000]*7,
        't': [0b00100,0b00100,0b11111,0b00100,0b00100,0b00100,0b00011],
        'o': [0b00000,0b00000,0b01110,0b10001,0b10001,0b10001,0b01110],
        'A': [0b01110,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
        'p': [0b00000,0b00000,0b11110,0b10001,0b11110,0b10000,0b10000],
        'l': [0b01100,0b00100,0b00100,0b00100,0b00100,0b00100,0b01110],
        'i': [0b00100,0b00000,0b01100,0b00100,0b00100,0b00100,0b01110],
        'c': [0b00000,0b00000,0b01110,0b10001,0b10000,0b10001,0b01110],
        'e': [0b00000,0b00000,0b01110,0b10001,0b11111,0b10000,0b01110],
        'n': [0b00000,0b00000,0b11010,0b10110,0b10010,0b10010,0b10010],
        's': [0b00000,0b00000,0b01111,0b10000,0b01110,0b00001,0b11110],
        'h': [0b10000,0b10000,0b10110,0b11001,0b10001,0b10001,0b10001],
        'I': [0b01110,0b00100,0b00100,0b00100,0b00100,0b00100,0b01110],
        'f': [0b00110,0b01000,0b11100,0b01000,0b01000,0b01000,0b01000],
        'y': [0b00000,0b00000,0b10001,0b10001,0b01111,0b00001,0b01110],
        'T': [0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b00100],
        'k': [0b10000,0b10000,0b10010,0b10100,0b11000,0b10100,0b10010],
    }

    char_w, char_h, char_gap = 5, 7, 2
    total_w = len(label) * (char_w + char_gap)
    tx = (width - total_w) // 2
    ty = ay + head_h // 2 + 18

    for ci, ch in enumerate(label):
        glyph = font5x7.get(ch, font5x7[' '])
        for row_i, row_bits in enumerate(glyph[:char_h]):
            for col_i in range(char_w):
                if row_bits & (1 << (char_w - 1 - col_i)):
                    px = tx + ci * (char_w + char_gap) + col_i
                    py = ty + row_i
                    if 0 <= px < width and 0 <= py < height:
                        buf[py * width + px] = [200, 220, 255, 200]

    # Flatten to bytes
    flat = []
    for p in buf:
        flat.extend(p)
    return make_png(width, height, flat)


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'dmg_background.png'
    png = draw_bg()
    with open(out, 'wb') as f:
        f.write(png)
    print(f"Background: {out}  (660×400)")
