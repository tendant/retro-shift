"""Tiny RGBA canvas and PNG writer for authoring pixel art in code (stdlib only)."""

import struct
import zlib

CLEAR = (0, 0, 0, 0)


def hex_color(text, alpha=255):
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), alpha)


class Canvas:
    def __init__(self, width, height, fill=CLEAR):
        self.width = width
        self.height = height
        self.pixels = [fill] * (width * height)

    def get(self, x, y):
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.pixels[y * self.width + x]
        return CLEAR

    def set(self, x, y, color):
        if 0 <= x < self.width and 0 <= y < self.height:
            self.pixels[y * self.width + x] = color

    def rect(self, x, y, w, h, color):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, color)

    def hline(self, x0, x1, y, color):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.set(x, y, color)

    def polygon(self, points, color):
        """Scanline fill; pixel centers inside the polygon are painted."""
        ys = [p[1] for p in points]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            cy = y + 0.5
            xs = []
            for i, (x0, y0) in enumerate(points):
                x1, y1 = points[(i + 1) % len(points)]
                if (y0 <= cy < y1) or (y1 <= cy < y0):
                    xs.append(x0 + (cy - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for a, b in zip(xs[0::2], xs[1::2]):
                for x in range(int(round(a)), int(round(b))):
                    self.set(x, y, color)

    def ellipse(self, cx, cy, rx, ry, color):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    self.set(x, y, color)

    def outline(self, color):
        """Paints `color` on transparent pixels touching opaque ones (4-neighbour)."""
        edge = []
        for y in range(self.height):
            for x in range(self.width):
                if self.get(x, y)[3] == 0 and any(
                    self.get(x + dx, y + dy)[3] > 0 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                ):
                    edge.append((x, y))
        for x, y in edge:
            self.set(x, y, color)

    def mirror_x(self):
        out = Canvas(self.width, self.height)
        for y in range(self.height):
            for x in range(self.width):
                out.set(self.width - 1 - x, y, self.get(x, y))
        return out

    def blit(self, other, ox, oy):
        for y in range(other.height):
            for x in range(other.width):
                c = other.get(x, y)
                if c[3] > 0:
                    self.set(ox + x, oy + y, c)

    def from_ascii(self, rows, palette, ox=0, oy=0):
        """Paints rows of characters; each char maps through `palette` ('.' = skip)."""
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in palette:
                    self.set(ox + x, oy + y, palette[ch])

    def save(self, path):
        raw = bytearray()
        for y in range(self.height):
            raw.append(0)
            for x in range(self.width):
                raw.extend(self.pixels[y * self.width + x])

        def chunk(tag, data):
            body = tag + data
            return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)
