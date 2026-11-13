#!/usr/bin/env python3
"""Harrow's Wake: Last Toll - title / ending music box lullaby.
Original music made for the jam (2026-11-12), pure numpy, no samples.
A mistuned music box plays a 3/4 lullaby in A minor over a low drone and a far-off bell,
through a cold reverb. Renders a 48 s seamless loop.
  python3 last_toll_theme.py out.wav   (then ffmpeg -> mono 22 kHz ogg)
Licence: GPL-3.0-or-later, Copyright (C) 2026 Tylerlikesps4.
"""
import sys
import numpy as np
from scipy import signal
import soundfile as sf

SR = 22050
BPM = 60.0
BEAT = 60.0 / BPM
BARS = 16
LEN = BARS * 3 * BEAT
TAIL = 6.0
rng = np.random.default_rng(1112)
N = int((LEN + TAIL) * SR)
t_all = np.arange(N) / SR


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def box_note(m, dur_s, vel=1.0):
    """Music box tine: a few inharmonic partials with fast decay."""
    n = int((dur_s + 3.5) * SR)
    t = np.arange(n) / SR
    f = hz(m) * 2 ** (rng.uniform(-9, 9) / 1200.0)   # mistuned
    out = np.zeros(n)
    for ratio, amp, dec in [(1.0, 1.0, 1.6), (2.0, 0.35, 1.0), (3.02, 0.22, 0.6), (5.4, 0.1, 0.35), (7.9, 0.05, 0.2)]:
        out += amp * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t / dec)
    atk = np.minimum(1.0, t / 0.003)
    return out * atk * vel


# 3/4 lullaby: (bar, beat, midi, beats)
MEL = [
    (0, 0, 69, 1), (0, 1, 72, 1), (0, 2, 76, 1), (1, 0, 74, 2), (1, 2, 72, 1),
    (2, 0, 72, 1), (2, 1, 71, 1), (2, 2, 69, 1), (3, 0, 68, 3),
    (4, 0, 69, 1), (4, 1, 72, 1), (4, 2, 76, 1), (5, 0, 77, 2), (5, 2, 76, 1),
    (6, 0, 74, 1), (6, 1, 72, 1), (6, 2, 71, 1), (7, 0, 69, 3),
    (8, 0, 81, 2), (8, 2, 76, 1), (9, 0, 77, 1), (9, 1, 76, 1), (9, 2, 74, 1),
    (10, 0, 72, 2), (10, 2, 71, 1), (11, 0, 69, 3),
    (12, 0, 74, 1), (12, 1, 72, 1), (12, 2, 71, 1), (13, 0, 72, 2), (13, 2, 69, 1),
    (14, 0, 68, 1), (14, 1, 71, 1), (14, 2, 68, 1), (15, 0, 69, 3),
]
mel = np.zeros(N)
for bar, beat, m, d in MEL:
    # a few notes are "forgotten" in the second half: the box is running down
    if bar >= 8 and rng.random() < 0.12:
        continue
    st = (bar * 3 + beat) * BEAT + rng.uniform(-0.012, 0.012)
    nt = box_note(m, d * BEAT, rng.uniform(0.7, 1.0))
    i = int(st * SR)
    mel[i:i + len(nt)] += nt[:N - i]
# quiet low octave doubling every bar's first beat
for bar in range(BARS):
    nt = box_note(33 if bar % 4 < 2 else 28 + 5 * (bar % 2), 2.0, 0.55)   # A1 / E1 / A1...
    i = int(bar * 3 * BEAT * SR)
    mel[i:i + len(nt)] += nt[:N - i]

# drone: detuned saws through a low-pass, slow swell
drone = np.zeros(N)
for f0, g in [(55.0, 1.0), (82.4, 0.5), (110.3, 0.3)]:
    for det in (-0.7, 0.0, 0.9):
        drone += g * signal.sawtooth(2 * np.pi * (f0 + det * 0.3) * t_all) / 3.0
b, a = signal.butter(2, 260 / (SR / 2))
drone = signal.lfilter(b, a, drone)
drone *= 0.55 + 0.45 * np.sin(2 * np.pi * t_all / (LEN / 2) - 1.2) ** 2

# far bell: an inharmonic toll every four bars, very washed out
bell = np.zeros(N)
for k in range(0, BARS, 4):
    n = int(7.0 * SR)
    t = np.arange(n) / SR
    f = 110.0
    s = np.zeros(n)
    for r, amp, dec in [(0.5, 0.6, 3.0), (1, 1.0, 2.6), (1.183, 0.7, 2.0), (1.506, 0.5, 1.5), (2, 0.5, 1.2), (2.514, 0.3, 0.8), (3.011, 0.2, 0.6), (4.166, 0.12, 0.4)]:
        s += amp * np.sin(2 * np.pi * f * r * t) * np.exp(-t / dec)
    s *= np.minimum(1.0, t / 0.004)
    i = int((k * 3 * BEAT + 2 * BEAT) * SR)
    bell[i:i + n] += s[:N - i] * 0.5

# wind
wind = rng.standard_normal(N)
b, a = signal.butter(2, [120 / (SR / 2), 600 / (SR / 2)], btype="band")
wind = signal.lfilter(b, a, wind) * (0.5 + 0.5 * np.sin(2 * np.pi * t_all / 11.0 + 1.0)) ** 2 * 0.5

dry = mel * 0.9 + drone * 0.5 + bell * 0.45 + wind * 0.5

# cold reverb
irn = int(2.8 * SR)
ti = np.arange(irn) / SR
ir = rng.standard_normal(irn) * np.exp(-ti / 0.9)
b, a = signal.butter(1, 3500 / (SR / 2))
ir = signal.lfilter(b, a, ir)
ir[: int(0.02 * SR)] *= 0.0
wet = signal.fftconvolve(dry, ir)[:N] * 0.05
mix = dry + wet * 1.0
# high-pass out the rumble
b, a = signal.butter(2, 40 / (SR / 2), btype="high")
mix = signal.lfilter(b, a, mix)

# fold the tail back on the start so the loop is seamless
loop_n = int(LEN * SR)
out = mix[:loop_n].copy()
tail = mix[loop_n:]
out[: len(tail)] += tail[: loop_n]
out = out / np.max(np.abs(out)) * 0.7
# tiny fade at the very ends against clicks
fade = int(0.01 * SR)
out[:fade] *= np.linspace(0, 1, fade)
out[-fade:] *= np.linspace(1, 0, fade)
sf.write(sys.argv[1] if len(sys.argv) > 1 else "last_toll_theme.wav", out.astype(np.float32), SR)
print("wrote", len(out) / SR, "s")
