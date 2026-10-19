"""Generates RetroShift's original pixel art: cars, scenery, backgrounds, HUD.

Writes PNGs to assets/sprites/ and the region table to
scripts/rendering/sprite_atlas.gd. Usage: python3 tools/assets/gen_sprites.py
"""

import math
import os
import random

from gen_font import GLYPHS
from pixel import CLEAR, Canvas, hex_color

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT_DIR = os.path.join(ROOT, "assets", "sprites")
ATLAS_SCRIPT = os.path.join(ROOT, "scripts", "rendering", "sprite_atlas.gd")

OUTLINE = hex_color("10101c")
SHADOW = (0, 0, 0, 96)

# Body ramps: dark, mid, light, highlight. Row 0 is the player.
CAR_COLORS = {
    "red": ["7a1020", "c02030", "e84848", "ff9c8c"],
    "blue": ["182c78", "2850c8", "4c84f0", "a8d0ff"],
    "yellow": ["805810", "d0a020", "f0d040", "fff0a0"],
    "green": ["105830", "209850", "48c870", "b0f0b0"],
    "orange": ["803010", "d06020", "f09040", "ffd0a0"],
    "purple": ["401870", "7030b0", "a058e0", "e0b8ff"],
    "white": ["606878", "a8b0c0", "e0e4ec", "ffffff"],
}
CAR_W, CAR_H = 48, 30
# Frames left to right: hard left, left, center, right, hard right.
CAR_TURNS = [-2, -1, 0, 1, 2]


def draw_car(ramp, turn):
    """Rear view of an original wedge-shaped sports car. Left turns mirror
    right turns; see draw_car_right."""
    car = draw_car_right(ramp, abs(turn))
    return car.mirror_x() if turn < 0 else car


def draw_car_right(ramp, turn):
    """`turn` 0..2 = yawing right: the rear face narrows, the right flank comes
    into view, and parts further forward (cabin) shift right in perspective."""
    dark, mid, light, high = (hex_color(c) for c in ramp)
    tyre = hex_color("1c1c24")
    tyre_hi = hex_color("4a4a58")
    glass = hex_color("1a2440")
    glass_hi = hex_color("6a8cc8")
    lamp = hex_color("e02028")
    lamp_hi = hex_color("ffb080")
    trim = hex_color("2a2a34")
    plate = hex_color("e8e8d8")

    c = Canvas(CAR_W, CAR_H)
    flank = turn * 3  # visible right side panel
    lean = turn * 2  # top of the rear face, further forward, shifts right
    face_l, face_r = 2, 46 - flank  # rear face at bumper height
    face_w = face_r - face_l

    c.ellipse(24, 27.5, 23, 2.4, SHADOW)
    # Tyres: the right one shows its sidewall as the car yaws.
    c.rect(3, 21, 8, 7, tyre)
    c.rect(face_r - 8, 21, 8 + flank, 7, tyre)
    for y in (23, 25):
        c.hline(4, 9, y, tyre_hi)
        c.hline(face_r - 7, face_r - 2 + flank, y, tyre_hi)
    # Bumper / diffuser.
    c.polygon([(4, 19), (face_r - 2, 19), (face_r - 4, 24), (6, 24)], trim)
    c.rect(face_l + face_w * 12 // 44, 21, 3, 2, OUTLINE)
    c.rect(face_l + face_w * 29 // 44, 21, 3, 2, OUTLINE)

    # Rear face (wedge) and the right flank joining it.
    top_l, top_r = 6 + lean, face_r - 4 + lean
    c.polygon([(face_l, 20), (face_r, 20), (top_r, 9), (top_l, 9)], mid)
    c.polygon([(face_l, 20), (face_l + 4, 20), (top_l + 3, 9), (top_l, 9)], dark)
    if flank:
        c.polygon([(face_r, 20), (face_r + flank, 19), (min(47, top_r + flank), 10), (top_r, 9)], dark)
        c.hline(face_r + 1, face_r + flank - 1, 15, mid)  # side crease catches light
    else:
        c.polygon([(face_r - 4, 20), (face_r, 20), (top_r, 9), (top_r - 3, 9)], dark)
    c.hline(top_l + 1, top_r - 1, 9, high)
    c.hline(top_l, top_r, 10, light)
    c.hline(face_l + 2, face_r - 2, 16, dark)  # crease under the lights

    # Tail light bar and plate, laid out across the (narrower) face.
    shift = lean // 2
    bar_l = face_l + face_w * 4 // 44 + shift
    bar_r = face_r - face_w * 4 // 44 + shift
    c.rect(bar_l, 12, bar_r - bar_l, 3, trim)
    lamp_w = face_w * 9 // 44
    for x0 in (bar_l + 1, bar_r - 1 - lamp_w):
        c.rect(x0, 12, lamp_w, 3, lamp)
        c.hline(x0 + 2, x0 + lamp_w - 3, 13, lamp_hi)
    plate_x = face_l + face_w // 2 - 4 + shift
    c.rect(plate_x, 17, 8, 3, plate)

    # Cabin and rear window, further forward so they shift the most.
    cab = turn * 3
    cl, cr = 12 + cab, 36 + cab - flank // 2
    c.polygon([(cl - 2, 9), (cr + 2, 9), (cr - 2, 1), (cl + 2, 1)], dark)
    c.polygon([(cl, 8), (cr, 8), (cr - 3, 2), (cl + 3, 2)], glass)
    for i in range(4):
        c.set(cl + 6 + i, 7 - i, glass_hi)
        c.set(cl + 7 + i, 7 - i, glass_hi)
    # Rear wing, kept within the body's outline.
    wl, wr = 4 + lean, min(46, face_r - 2 + lean)
    c.rect(wl + 9, 7, 2, 3, trim)
    c.rect(wr - 11, 7, 2, 3, trim)
    c.rect(wl, 5, wr - wl, 2, dark)
    c.hline(wl, wr - 1, 5, light)
    c.outline(OUTLINE)
    return c


def build_cars():
    sheet = Canvas(CAR_W * len(CAR_TURNS), CAR_H * len(CAR_COLORS))
    for row, ramp in enumerate(CAR_COLORS.values()):
        for col, turn in enumerate(CAR_TURNS):
            sheet.blit(draw_car(ramp, turn), col * CAR_W, row * CAR_H)
    sheet.save(os.path.join(OUT_DIR, "cars.png"))


# --- Scenery -----------------------------------------------------------------

def pine(seed):
    rng = random.Random(seed)
    c = Canvas(32, 64)
    greens = [hex_color(h) for h in ("0c3a1c", "185c2c", "2a8040", "52a860")]
    trunk = hex_color("5a3a20")
    c.rect(14, 50, 4, 12, trunk)
    c.rect(14, 50, 1, 12, hex_color("3a2410"))
    tiers = [(56, 15), (44, 13), (33, 11), (23, 8), (14, 5)]
    for i, (base, half) in enumerate(tiers):
        top = base - 16 + i
        c.polygon([(16 - half, base), (16 + half, base), (16, top)], greens[1])
        c.polygon([(16, base), (16 + half, base), (16, top)], greens[0])  # shaded side
        for _ in range(half * 2):
            x = rng.randint(16 - half + 2, 16)
            y = rng.randint(top + 4, base - 2)
            if c.get(x, y)[3]:
                c.set(x, y, greens[2])
        c.hline(16 - half + 1, 16 - 1, base - 1, greens[3])
    c.ellipse(16, 62, 9, 1.5, SHADOW)
    c.outline(OUTLINE)
    return c


def palm(lean, seed):
    """Curved trunk with drooping fronds; `lean` > 0 bends right."""
    rng = random.Random(seed)
    c = Canvas(40, 64)
    trunk = [hex_color(h) for h in ("6a4424", "8c5e30", "b07c44")]
    top_x, top_y = 20 + lean * 6, 12
    for y in range(top_y, 62):
        t = (62 - y) / (62 - top_y)
        x = int(round(20 + lean * 6 * t * t))
        w = 3 if y > 30 else 2
        c.rect(x - w // 2, y, w, 1, trunk[1])
        c.set(x - w // 2, y, trunk[0])
        if y % 4 == 0:
            c.hline(x - w // 2, x + w // 2, y, trunk[2])  # ring marks
    greens = [hex_color(h) for h in ("145a2c", "23803c", "47a854")]
    for angle in (-170, -140, -110, -70, -40, -10, 200, 230):
        a = math.radians(angle + rng.uniform(-8, 8))
        length = rng.uniform(13, 17)
        for i in range(int(length)):
            t = i / length
            x = top_x + math.cos(a) * i
            y = top_y + math.sin(a) * i + 7 * t * t  # fronds droop
            shade = greens[2] if t < 0.3 else greens[1]
            c.set(int(x), int(y), shade)
            c.set(int(x), int(y) + 1, greens[0])
            if 0.2 < t < 0.85:
                c.set(int(x), int(y) + 2, greens[0])
    c.ellipse(top_x, top_y + 1, 2.5, 2, hex_color("5a3a1c"))  # coconuts
    c.ellipse(20, 62, 8, 1.5, SHADOW)
    c.outline(OUTLINE)
    return c


def bush():
    c = Canvas(24, 14)
    g = [hex_color(h) for h in ("185c2c", "2a8040", "52a860")]
    for cx, cy, r in ((7, 8, 6), (16, 8, 6), (12, 5, 5)):
        c.ellipse(cx, cy, r, r * 0.8, g[1])
    for cx, cy in ((9, 5), (14, 3), (18, 7)):
        c.ellipse(cx, cy, 2, 1.5, g[2])
    c.polygon([(2, 13), (22, 13), (20, 10), (4, 10)], g[0])
    c.outline(OUTLINE)
    return c


def rock():
    c = Canvas(20, 12)
    shades = [hex_color(h) for h in ("54505a", "807a86", "aaa4b0")]
    c.polygon([(1, 11), (19, 11), (16, 3), (9, 1), (3, 4)], shades[1])
    c.polygon([(10, 11), (19, 11), (16, 3), (10, 5)], shades[0])
    c.polygon([(4, 5), (9, 2), (11, 4), (6, 6)], shades[2])
    c.outline(OUTLINE)
    return c


def marker_post():
    c = Canvas(6, 24)
    c.rect(1, 2, 4, 22, hex_color("f0f0f0"))
    c.rect(1, 2, 4, 3, hex_color("202020"))
    c.rect(2, 6, 2, 3, hex_color("ff4030"))
    c.rect(4, 2, 1, 22, hex_color("b0b0b8"))
    c.outline(OUTLINE)
    return c


def chevron_sign():
    """Points right (for right-hand curves); mirror for left."""
    c = Canvas(18, 24)
    c.rect(8, 14, 2, 10, hex_color("707078"))
    c.rect(1, 1, 16, 13, hex_color("ffd020"))
    black = hex_color("181818")
    for i in range(4):
        c.rect(5 + i, 3 + i, 3, 1, black)
        c.rect(5 + i, 11 - i, 3, 1, black)
    c.rect(8, 7, 3, 1, black)
    c.outline(OUTLINE)
    return c


def text_into(c, text, x, y, color):
    for ch in text:
        glyph = GLYPHS.get(ch.upper())
        if glyph:
            c.from_ascii(glyph, {"#": color}, x, y)
        x += 6


def gantry_pillar():
    c = Canvas(8, 64)
    c.rect(1, 0, 6, 64, hex_color("9098a8"))
    c.rect(1, 0, 2, 64, hex_color("c8d0e0"))
    for y in range(4, 64, 8):
        c.hline(1, 6, y, hex_color("606878"))
    c.outline(OUTLINE)
    return c


def gantry_banner():
    c = Canvas(96, 16)
    c.rect(0, 0, 96, 16, hex_color("181820"))
    for x in range(0, 96, 4):
        for y in (0, 12):
            c.rect(x, y + (2 if (x // 4) % 2 else 0), 2, 2, hex_color("f0f0f0"))
            c.rect(x + 2, y + (0 if (x // 4) % 2 else 2), 2, 2, hex_color("f0f0f0"))
    text_into(c, "RETROSHIFT", 18, 4, hex_color("ffd040"))
    return c


def billboard(text, bg, fg):
    w = max(64, len(text) * 6 + 14)
    c = Canvas(w, 36)
    c.rect(10, 22, 3, 14, hex_color("707078"))
    c.rect(w - 13, 22, 3, 14, hex_color("707078"))
    c.rect(1, 1, w - 2, 22, hex_color("e0e0e8"))
    c.rect(3, 3, w - 6, 18, hex_color(bg))
    text_into(c, text, w // 2 - len(text) * 3 + 1, 9, hex_color(fg))
    c.outline(OUTLINE)
    return c


# --- Backgrounds (tile horizontally) --------------------------------------------

def tile_noise(x, width, terms):
    return sum(a * math.sin(2 * math.pi * (k * x / width) + p) for k, a, p in terms)


def mountains():
    w, h = 256, 48
    c = Canvas(w, h)
    body = hex_color("5868a0")
    shade = hex_color("44528a")
    snow = hex_color("e8f0ff")
    terms = [(2, 9, 0.3), (5, 6, 1.1), (9, 3, 2.0), (17, 1.5, 0.7)]
    for x in range(w):
        top = int(22 - tile_noise(x, w, terms))
        slope = tile_noise(x + 3, w, terms) - tile_noise(x - 3, w, terms)
        for y in range(max(0, top), h):
            c.set(x, y, shade if slope < 0 else body)
        for y in range(max(0, top), min(h, top + 3)):
            if top < 16:
                c.set(x, y, snow)
    return c


def hills():
    w, h = 256, 32
    c = Canvas(w, h)
    g = [hex_color(x) for x in ("2f7a44", "3c9050", "4ca860")]
    terms = [(3, 5, 0.9), (7, 3, 0.2), (13, 1.5, 1.7)]
    rng = random.Random(7)
    for x in range(w):
        top = int(14 - tile_noise(x, w, terms))
        for y in range(max(0, top), h):
            c.set(x, y, g[1] if y > top + 3 else g[2])
        if rng.random() < 0.25:
            for y in range(top - 3, top + 1):
                c.set(x, y, g[0])  # tree tufts on the ridge
    return c


def sea():
    """Ocean to the horizon with a distant island; sits on the horizon line."""
    w, h = 256, 24
    c = Canvas(w, h)
    deep, mid, light = hex_color("2c5a9c"), hex_color("3c78bc"), hex_color("a8d8f0")
    island = hex_color("4c6a7c")
    terms = [(1, 5, 0.4), (3, 2, 1.3)]
    for x in range(w):
        top = int(8 - max(0.0, tile_noise(x, w, terms)))
        if top < 8:
            for y in range(top, 9):
                c.set(x, y, island)
    for y in range(9, h):
        t = (y - 9) / (h - 10)
        for x in range(w):
            c.set(x, y, mid if t < 0.5 else deep)
    rng = random.Random(9)
    for _ in range(40):
        x, y = rng.randint(0, w - 1), rng.randint(10, h - 2)
        for dx in range(rng.randint(2, 5)):
            c.set((x + dx) % w, y, light)
    return c


def clouds():
    w, h = 256, 40
    c = Canvas(w, h)
    white = hex_color("f4f8ff")
    shade = hex_color("c8d8f0")
    rng = random.Random(3)
    for _ in range(7):
        cx = rng.randint(0, w - 1)
        cy = rng.randint(10, 28)
        for i in range(4):
            r = rng.randint(5, 10)
            ox = cx + i * rng.randint(5, 8)
            for dx in (-w, 0, w):  # wrap so the strip tiles
                c.ellipse(ox + dx, cy, r, r * 0.55, shade)
                c.ellipse(ox + dx, cy - 2, r - 1, r * 0.45, white)
    return c


# --- HUD -------------------------------------------------------------------

def nitro_icon(lit):
    c = Canvas(8, 10)
    body = hex_color("40c8ff" if lit else "28384c")
    high = hex_color("c8f0ff" if lit else "3c5068")
    c.rect(2, 0, 4, 2, hex_color("909aa8" if lit else "3c4450"))
    c.rect(1, 2, 6, 8, body)
    c.rect(2, 3, 1, 6, high)
    c.outline(OUTLINE)
    return c


def start_light(color):
    c = Canvas(14, 14)
    c.ellipse(7, 7, 6.5, 6.5, hex_color("202028"))
    c.ellipse(7, 7, 4.6, 4.6, hex_color(color))
    c.ellipse(5.5, 5.5, 1.6, 1.6, (255, 255, 255, 170))
    return c


# --- Touch controls ----------------------------------------------------------

TOUCH_SIZE = 32


def touch_button(icon, pressed):
    """Translucent round button with a white pixel icon (ASCII, 16x16)."""
    c = Canvas(TOUCH_SIZE, TOUCH_SIZE)
    fill = (255, 255, 255, 110 if pressed else 40)
    edge = (255, 255, 255, 230 if pressed else 150)
    c.ellipse(16, 16, 15.5, 15.5, edge)
    c.ellipse(16, 16, 14.0, 14.0, fill)
    c.from_ascii(icon, {"#": (255, 255, 255, 255 if pressed else 220)}, 8, 8)
    return c


TOUCH_ICONS = {
    "left": [
        "................", "......##........", ".....###........", "....####........",
        "...#####........", "..##############", ".###############", "################",
        "################", ".###############", "..##############", "...#####........",
        "....####........", ".....###........", "......##........", "................",
    ],
    "gas": [
        ".......##.......", "......####......", ".....######.....", "....########....",
        "...##########...", "..############..", ".....######.....", ".....######.....",
        ".....######.....", ".....######.....", ".....######.....", ".....######.....",
        ".....######.....", ".....######.....", ".....######.....", "................",
    ],
    "nitro": [
        ".......#........", "......##........", "......###.......", ".....####.......",
        ".....#####......", "....######.#....", "....#######.....", "...########.#...",
        "...##########...", "..####..######..", "..###....#####..", "..###.....####..",
        "..###.....####..", "...###...####...", "....########....", "......####......",
    ],
    "pause": [
        "................", "................", "...####..####...", "...####..####...",
        "...####..####...", "...####..####...", "...####..####...", "...####..####...",
        "...####..####...", "...####..####...", "...####..####...", "...####..####...",
        "...####..####...", "...####..####...", "................", "................",
    ],
}


def touch_sprites():
    sprites = {}
    for name, icon in TOUCH_ICONS.items():
        variants = {name: icon}
        if name == "left":
            variants["right"] = [row[::-1] for row in icon]
        if name == "gas":
            variants["brake"] = icon[::-1]
        for variant, rows in variants.items():
            sprites[f"touch_{variant}"] = touch_button(rows, False)
            sprites[f"touch_{variant}_pressed"] = touch_button(rows, True)
    return sprites


# --- App icon ------------------------------------------------------------------

def app_icon():
    """128x128 pixel art (sunset, road, the player's car), upscaled 8x."""
    c = Canvas(128, 128)
    top, bottom = hex_color("20347a"), hex_color("f09a6e")
    for y in range(70):
        t = y / 69
        c.hline(0, 127, y, tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    c.ellipse(64, 66, 22, 22, hex_color("ffd060"))
    c.blit(mountains(), -64, 70 - 40)
    c.rect(0, 70, 128, 58, hex_color("3c9050"))
    c.polygon([(56, 70), (72, 70), (124, 128), (4, 128)], hex_color("6c6c76"))
    for i, y in enumerate(range(72, 128, 9)):
        w = 1 + i
        c.rect(64 - w // 2, y, w, 4 + i, hex_color("f0f0f0"))
    car = draw_car(list(CAR_COLORS.values())[0], 0)
    big = Canvas(CAR_W * 2, CAR_H * 2)
    for y in range(big.height):
        for x in range(big.width):
            big.set(x, y, car.get(x // 2, y // 2))
    c.blit(big, 64 - CAR_W, 128 - CAR_H * 2 - 2)
    out = Canvas(1024, 1024)
    for y in range(1024):
        for x in range(1024):
            out.pixels[y * 1024 + x] = c.pixels[(y // 8) * 128 + x // 8]
    return out


# --- Packing ---------------------------------------------------------------

def pack(sprites, width):
    """Shelf-packs {name: Canvas} into one sheet. Returns (sheet, {name: rect})."""
    x = y = shelf = 0
    rects = {}
    for name, sprite in sprites.items():
        if x + sprite.width > width:
            x, y, shelf = 0, y + shelf + 1, 0
        rects[name] = (x, y, sprite.width, sprite.height)
        x += sprite.width + 1
        shelf = max(shelf, sprite.height)
    sheet = Canvas(width, y + shelf)
    for name, sprite in sprites.items():
        sheet.blit(sprite, rects[name][0], rects[name][1])
    return sheet, rects


def write_atlas(scenery_rects, hud_rects):
    def rect_lines(rects):
        return "\n".join(f'\t&"{n}": Rect2({x}, {y}, {w}, {h}),' for n, (x, y, w, h) in rects.items())

    text = f'''class_name SpriteAtlas
extends RefCounted
## Sprite sheet regions. GENERATED by tools/assets/gen_sprites.py; do not edit.

const CARS := preload("res://assets/sprites/cars.png")
const SCENERY := preload("res://assets/sprites/scenery.png")
const HUD := preload("res://assets/sprites/hud.png")
const BG_CLOUDS := preload("res://assets/sprites/bg_clouds.png")
const BG_MOUNTAINS := preload("res://assets/sprites/bg_mountains.png")
const BG_HILLS := preload("res://assets/sprites/bg_hills.png")
const BG_SEA := preload("res://assets/sprites/bg_sea.png")

const CAR_SIZE := Vector2({CAR_W}, {CAR_H})
const CAR_COLORS := {len(CAR_COLORS)}
## Columns: hard left, left, center, right, hard right.
const CAR_FRAMES := {len(CAR_TURNS)}

const SCENERY_RECTS := {{
{rect_lines(scenery_rects)}
}}

const HUD_RECTS := {{
{rect_lines(hud_rects)}
}}


static func car_rect(color_row: int, frame: int) -> Rect2:
	return Rect2(Vector2(frame, color_row) * CAR_SIZE, CAR_SIZE)
'''
    with open(ATLAS_SCRIPT, "w", encoding="utf-8") as f:
        f.write(text)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    build_cars()

    chevron = chevron_sign()
    scenery = {
        "pine_a": pine(1),
        "pine_b": pine(2),
        "bush": bush(),
        "palm_a": palm(1, 4),
        "palm_b": palm(-1, 5),
        "rock": rock(),
        "post": marker_post(),
        "chevron_right": chevron,
        "chevron_left": chevron.mirror_x(),
        "gantry_pillar": gantry_pillar(),
        "gantry_banner": gantry_banner(),
        "billboard_retroshift": billboard("RETROSHIFT", "c02030", "ffffff"),
        "billboard_nitro": billboard("NITRO!", "1838a0", "ffd040"),
        "billboard_upgrade": billboard("UPGRADE", "185c2c", "ffffff"),
    }
    scenery_sheet, scenery_rects = pack(scenery, 256)
    scenery_sheet.save(os.path.join(OUT_DIR, "scenery.png"))

    hud = {
        "nitro_on": nitro_icon(True),
        "nitro_off": nitro_icon(False),
        "light_off": start_light("402020"),
        "light_red": start_light("ff3020"),
        "light_green": start_light("30f040"),
    }
    hud.update(touch_sprites())
    hud_sheet, hud_rects = pack(hud, 132)
    hud_sheet.save(os.path.join(OUT_DIR, "hud.png"))

    app_icon().save(os.path.join(ROOT, "assets", "icon.png"))
    clouds().save(os.path.join(OUT_DIR, "bg_clouds.png"))
    sea().save(os.path.join(OUT_DIR, "bg_sea.png"))
    mountains().save(os.path.join(OUT_DIR, "bg_mountains.png"))
    hills().save(os.path.join(OUT_DIR, "bg_hills.png"))

    write_atlas(scenery_rects, hud_rects)
    print(f"sprites: {len(CAR_COLORS) * len(CAR_TURNS)} car frames, {len(scenery)} scenery, {len(hud)} hud")


if __name__ == "__main__":
    main()
