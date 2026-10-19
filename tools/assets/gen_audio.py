"""Synthesizes RetroShift's original sound effects and chiptune music.

Writes 16-bit mono WAVs to assets/audio/. The engine sound is synthesized
live in-game (scripts/audio/engine_synth.gd), not here.
Usage: python3 tools/assets/gen_audio.py
"""

import math
import os
import random
import struct
import wave

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio")
RATE = 22050


def write_wav(name, samples, peak=0.89):
    top = max(1e-9, max(abs(s) for s in samples))
    scale = peak / top * 32767
    with wave.open(os.path.join(OUT_DIR, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale)) for s in samples))


def note_hz(name):
    """'A4', 'C#5', 'Bb3' → Hz."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]]
    rest = name[1:]
    if rest[0] in "#b":
        semis += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 440.0 * 2 ** ((semis + 12 * (int(rest) - 4)) / 12)


# --- Oscillators -----------------------------------------------------------

def pulse(phase, duty):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def envelope(t, length, attack=0.004, release=0.03):
    if t < attack:
        return t / attack
    if t > length - release:
        return max(0.0, (length - t) / release)
    return 1.0


# --- Sound effects -----------------------------------------------------------

def beep(freq, length, duty=0.5):
    n = int(RATE * length)
    return [0.6 * pulse(freq * i / RATE, duty) * envelope(i / RATE, length, release=0.05) for i in range(n)]


def sweep(f0, f1, length, duty=0.25, volume=0.5):
    out, phase = [], 0.0
    n = int(RATE * length)
    for i in range(n):
        t = i / n
        phase += (f0 + (f1 - f0) * t) / RATE
        out.append(volume * pulse(phase, duty) * envelope(i / RATE, length))
    return out


def whoosh(length=0.9):
    """Nitro: filtered noise swelling up, with a rising tone underneath."""
    rng = random.Random(11)
    out, lp, phase = [], 0.0, 0.0
    n = int(RATE * length)
    for i in range(n):
        t = i / n
        cutoff = 0.05 + 0.5 * t
        lp += cutoff * (rng.uniform(-1, 1) - lp)
        phase += (180 + 520 * t) / RATE
        amp = math.sin(math.pi * min(1.0, t * 1.4)) ** 0.7
        out.append(amp * (0.8 * lp + 0.25 * pulse(phase, 0.3) * (1 - t)))
    return out


def thud(length=0.3):
    rng = random.Random(5)
    out, lp, phase = [], 0.0, 0.0
    n = int(RATE * length)
    for i in range(n):
        t = i / RATE
        phase += (95 * math.exp(-t * 9) + 40) / RATE
        lp += 0.15 * (rng.uniform(-1, 1) - lp)
        decay = math.exp(-t * 14)
        out.append(decay * (0.9 * math.sin(2 * math.pi * phase) + 0.6 * lp * math.exp(-t * 30)))
    return out


def squeal(length=1.0):
    """Seamless loop: every partial and the wobble complete whole cycles."""
    out = []
    n = int(RATE * length)
    partials = [(1700, 0.5), (2100, 0.3), (2550, 0.2)]
    for i in range(n):
        t = i / RATE
        wobble = math.sin(2 * math.pi * 7 * t)
        s = sum(a * math.sin(2 * math.pi * (f * t + 3 * wobble / (2 * math.pi))) for f, a in partials)
        out.append(0.5 * s)
    return out


def jingle(notes, step, duty=0.25):
    out = []
    for name in notes:
        out += beep(note_hz(name), step, duty) if name != "." else [0.0] * int(RATE * step)
    return out


# --- Music tracker -------------------------------------------------------------

def render_song(bpm, bars, channels, steps_per_bar=8, loops=1):
    """Each channel: (kind, volume, pattern) with pattern = list of bars, each a
    list of `steps_per_bar` tokens: note name, '-' to hold, '.' for rest.
    Drum tokens: 'k' kick, 's' snare, 'h' hat."""
    step_len = 60.0 / bpm * 4 / steps_per_bar
    total = int(RATE * step_len * steps_per_bar * bars * loops)
    mix = [0.0] * total
    rng = random.Random(1)
    noise = [rng.uniform(-1, 1) for _ in range(RATE)]
    for kind, volume, pattern in channels:
        tokens = [tok for bar in pattern for tok in bar] * loops
        i = 0
        while i < len(tokens):
            tok = tokens[i]
            if tok in ("-", "."):
                i += 1
                continue
            hold = 1
            while i + hold < len(tokens) and tokens[i + hold] == "-":
                hold += 1
            start = int(RATE * step_len * i)
            length = step_len * hold
            n = min(int(RATE * length), total - start)
            if kind == "drums":
                for j in range(n):
                    t = j / RATE
                    if tok == "k":
                        v = math.sin(2 * math.pi * (60 * t + 18 * (1 - math.exp(-t * 40)))) * math.exp(-t * 18)
                    elif tok == "s":
                        v = noise[j % RATE] * math.exp(-t * 22) * 0.8
                    else:
                        v = noise[(j * 7) % RATE] * math.exp(-t * 80) * 0.4
                    mix[start + j] += volume * v
            else:
                freq = note_hz(tok)
                for j in range(n):
                    t = j / RATE
                    phase = freq * t
                    if kind == "bass":
                        v = triangle(phase)
                    elif kind == "lead":
                        v = pulse(phase + 0.004 * math.sin(2 * math.pi * 5.5 * t) * (t > 0.12), 0.25)
                    else:  # "pad"
                        v = pulse(phase, 0.125)
                    decay = 1.0 if kind == "bass" else max(0.35, math.exp(-t * 3))
                    mix[start + j] += volume * v * decay * envelope(t, length)
            i += hold
    return mix


def bars(text):
    """'A4 C5 E5 ... | F4 ...' → list of bars of tokens."""
    return [bar.split() for bar in text.split("|")]


def race_theme():
    lead = bars(
        "A4 C5 E5 A5 G5 E5 D5 C5 | A4 C5 F5 A5 G5 F5 E5 C5 | G4 C5 E5 G5 E5 C5 D5 E5 | D5 - B4 G4 D5 - G5 - |"
        "A5 - G5 E5 - C5 D5 E5 | F5 - E5 C5 - A4 C5 F5 | G5 - F5 D5 - B4 D5 G5 | G#5 - E5 B4 - G#4 B4 E5"
    )
    pad = bars(
        ". C5 . E5 . C5 . E5 | . C5 . F5 . C5 . F5 | . E5 . G5 . E5 . G5 | . D5 . G5 . D5 . G5 |"
        ". C5 . E5 . C5 . E5 | . C5 . F5 . C5 . F5 | . D5 . G5 . D5 . G5 | . E5 . G#5 . E5 . G#5"
    )
    roots = ["A", "F", "C", "G", "A", "F", "G", "E"]
    bass = [[f"{r}2", f"{r}3"] * 4 for r in roots]
    drums = [["k", "h", "s", "h", "k", "k", "s", "h"]] * 7 + [["k", "s", "s", "h", "s", "s", "s", "s"]]
    return render_song(144, 8, [
        ("lead", 0.30, lead), ("pad", 0.12, pad), ("bass", 0.38, bass), ("drums", 0.32, drums),
    ])


def garage_theme():
    # Laid-back arpeggios: Cmaj7 - Am7 - Fmaj7 - G6, twice with a turnaround.
    arps = {
        "C": "C4 E4 G4 B4 C5 B4 G4 E4", "A": "A3 C4 E4 G4 A4 G4 E4 C4",
        "F": "F3 A3 C4 E4 F4 E4 C4 A3", "G": "G3 B3 D4 E4 G4 E4 D4 B3",
    }
    order = ["C", "A", "F", "G", "C", "A", "F", "G"]
    pad = [arps[c].split() for c in order]
    lead = bars(
        "E5 - - - D5 - C5 - | C5 - - - . - A4 - | A4 - C5 - E5 - D5 - | D5 - - - - - . - |"
        "G5 - - - E5 - C5 - | E5 - D5 - C5 - A4 - | C5 - - - A4 - G4 - | B4 - - - D5 - - -"
    )
    bass = [[f"{c}2", "-", "-", "-", f"{c}2", "-", f"{c}3", "-"] for c in order]
    drums = [["k", ".", "h", ".", "s", ".", "h", "h"]] * 8
    return render_song(100, 8, [
        ("pad", 0.16, pad), ("lead", 0.24, lead), ("bass", 0.34, bass), ("drums", 0.18, drums),
    ])


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    write_wav("beep_low.wav", beep(440, 0.18), 0.6)
    write_wav("beep_high.wav", beep(880, 0.45), 0.7)
    write_wav("nitro.wav", whoosh(), 0.8)
    write_wav("thud.wav", thud(), 0.9)
    write_wav("squeal.wav", squeal(), 0.5)
    write_wav("lap.wav", jingle(["E5", "A5"], 0.09), 0.6)
    write_wav("finish.wav", jingle(["C5", "E5", "G5", "C6", ".", "G5", "C6"], 0.1), 0.7)
    write_wav("ui_move.wav", sweep(900, 1200, 0.04, volume=0.4), 0.4)
    write_wav("ui_buy.wav", jingle(["B5", "E6"], 0.07, 0.5), 0.55)
    write_wav("ui_denied.wav", sweep(220, 160, 0.18, duty=0.5), 0.5)
    write_wav("music_race.wav", race_theme(), 0.8)
    write_wav("music_garage.wav", garage_theme(), 0.75)
    print("audio:", ", ".join(sorted(os.listdir(OUT_DIR))))


if __name__ == "__main__":
    main()
