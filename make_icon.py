#!/usr/bin/env python3
"""
Generate Recorder.app icon: dark gradient background + animated waveform bars.
Outputs an iconset directory ready for iconutil.
"""
import struct, zlib, math, os, sys

def make_png(width, height, pixels_rgba):
    """Encode raw RGBA pixel list as PNG bytes."""
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
    return a + (b - a) * t


def draw_icon(size):
    w = h = size
    s = size / 512          # scale factor
    pixels = [0] * (w * h * 4)

    # ── Gradient stop colours ──────────────────────────────────────────────
    # Top-left  : deep indigo  #1A1040
    # Bottom-right: dark blue  #0D2460
    top_col    = (0x1A, 0x10, 0x40)
    bot_col    = (0x0D, 0x24, 0x60)

    # ── Rounded-rect corner radius (macOS icon = ~22.5 % of size) ──────────
    cr = size * 0.225

    def in_rounded_rect(x, y):
        cx, cy = x - w / 2, y - h / 2
        hw, hh = w * 0.5, h * 0.5
        if abs(cx) > hw or abs(cy) > hh:
            return False, 0.0
        ox = abs(cx) - (hw - cr)
        oy = abs(cy) - (hh - cr)
        if ox > 0 and oy > 0:
            d = math.sqrt(ox * ox + oy * oy)
            if d > cr:
                return False, 0.0
            # anti-alias within 1px of edge
            return True, max(0.0, min(1.0, cr - d))
        return True, 1.0

    # ── Waveform bar definitions (7 bars, heights mimic a speech waveform) ──
    bar_count  = 7
    bar_w      = size * 0.055
    bar_gap    = size * 0.032
    total_w    = bar_count * bar_w + (bar_count - 1) * bar_gap
    bar_left   = (w - total_w) / 2
    bar_heights = [0.28, 0.50, 0.72, 0.88, 0.72, 0.50, 0.28]   # symmetrical
    max_bar_h  = size * 0.52
    bar_cr     = bar_w * 0.5   # fully-rounded caps

    # Pre-compute bar rects
    bars = []
    for i, bh_frac in enumerate(bar_heights):
        bh   = max_bar_h * bh_frac
        bx   = bar_left + i * (bar_w + bar_gap)
        by   = (h - bh) / 2
        bars.append((bx, by, bar_w, bh, bar_cr))

    # ── Accent glow behind bars: soft radial ellipse ───────────────────────
    glow_cx, glow_cy = w / 2, h / 2
    glow_rx, glow_ry = w * 0.38, h * 0.28

    for y in range(h):
        for x in range(w):
            in_rect, aa = in_rounded_rect(x, y)
            if not in_rect:
                continue

            # Background gradient (top-left → bottom-right)
            t = (x / w + y / h) * 0.5
            r_bg = int(lerp(top_col[0], bot_col[0], t))
            g_bg = int(lerp(top_col[1], bot_col[1], t))
            b_bg = int(lerp(top_col[2], bot_col[2], t))

            # Glow contribution
            gx = (x - glow_cx) / glow_rx
            gy = (y - glow_cy) / glow_ry
            glow = max(0.0, 1.0 - (gx * gx + gy * gy))
            glow = glow ** 2 * 0.18
            r_bg = min(255, int(r_bg + glow * 80))
            g_bg = min(255, int(g_bg + glow * 100))
            b_bg = min(255, int(b_bg + glow * 180))

            # Check if inside any bar (with anti-alias on rounded caps)
            bar_alpha = 0.0
            for (bx, by, bw, bh, bcr) in bars:
                # Is point inside the bar bounding box?
                inside_x = bx <= x <= bx + bw
                inside_y = by <= y <= by + bh
                if not (inside_x and inside_y):
                    continue
                # Rounded caps (top and bottom)
                local_x = x - (bx + bw / 2)
                local_y_top = y - (by + bcr)
                local_y_bot = y - (by + bh - bcr)
                if local_y_top < 0:
                    d = math.sqrt(local_x ** 2 + local_y_top ** 2)
                    bar_alpha = max(bar_alpha, max(0.0, min(1.0, bcr - d + 0.5)))
                elif local_y_bot > 0:
                    d = math.sqrt(local_x ** 2 + local_y_bot ** 2)
                    bar_alpha = max(bar_alpha, max(0.0, min(1.0, bcr - d + 0.5)))
                else:
                    bar_alpha = 1.0
                    break

            # Bar colour: white with subtle blue tint, brighter in the centre
            if bar_alpha > 0:
                centre_dist = abs(x - w / 2) / (total_w / 2)
                brightness  = lerp(1.0, 0.78, min(1.0, centre_dist))
                br = int(lerp(r_bg, min(255, int(220 * brightness + 35)), bar_alpha))
                bg = int(lerp(g_bg, min(255, int(230 * brightness + 25)), bar_alpha))
                bb = int(lerp(b_bg, 255, bar_alpha))
            else:
                br, bg, bb = r_bg, g_bg, b_bg

            alpha = int(aa * 255)
            idx = (y * w + x) * 4
            pixels[idx]     = br
            pixels[idx + 1] = bg
            pixels[idx + 2] = bb
            pixels[idx + 3] = alpha

    return make_png(w, h, pixels)


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "AppIcon.iconset"
    os.makedirs(out_dir, exist_ok=True)

    # macOS iconset requires these sizes
    sizes = [
        (16,   "icon_16x16"),
        (32,   "icon_16x16@2x"),
        (32,   "icon_32x32"),
        (64,   "icon_32x32@2x"),
        (128,  "icon_128x128"),
        (256,  "icon_128x128@2x"),
        (256,  "icon_256x256"),
        (512,  "icon_256x256@2x"),
        (512,  "icon_512x512"),
        (1024, "icon_512x512@2x"),
    ]

    for size, name in sizes:
        path = os.path.join(out_dir, f"{name}.png")
        png  = draw_icon(size)
        with open(path, 'wb') as f:
            f.write(png)
        print(f"  {name}.png  ({size}×{size})")


if __name__ == '__main__':
    main()
