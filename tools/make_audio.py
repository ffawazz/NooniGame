#!/usr/bin/env python3
"""Generates every sound effect and music loop for the game as 16-bit mono WAV files (22.05 kHz).

    python3 tools/make_audio.py            # writes godot/audio/*.wav

Everything is synthesised from sine/saw/noise, so there are no licensing questions and the files can be
regenerated or tweaked here. Music loops are built with wrap-around mixing so they loop seamlessly.
"""
import math
import os
import random
import struct
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "audio")
rng = np.random.default_rng(7)
random.seed(7)


# ---- building blocks ------------------------------------------------------------------

def t_axis(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def env(n, attack=0.005, decay=0.1, sustain=0.0, release=0.0):
    """Simple attack/decay envelope over n samples (sustain level then optional release)."""
    e = np.ones(n)
    a = max(1, int(attack * RATE))
    d = max(1, int(decay * RATE))
    e[:a] = np.linspace(0, 1, a)
    tail = n - a
    if tail > 0:
        dd = min(d, tail)
        e[a:a + dd] = np.linspace(1, sustain, dd)
        e[a + dd:] = sustain
    r = int(release * RATE)
    if r > 0 and r < n:
        e[-r:] *= np.linspace(1, 0, r)
    return e


def sine(freq, seconds):
    t = t_axis(seconds)
    f = freq if np.isscalar(freq) else freq
    phase = 2 * np.pi * np.cumsum(np.broadcast_to(f, t.shape)) / RATE
    return np.sin(phase)


def saw(freq, seconds):
    t = t_axis(seconds)
    phase = np.cumsum(np.broadcast_to(freq, t.shape)) / RATE
    return 2 * (phase % 1.0) - 1


def square(freq, seconds, duty=0.5):
    t = t_axis(seconds)
    phase = np.cumsum(np.broadcast_to(freq, t.shape)) / RATE
    return np.where((phase % 1.0) < duty, 1.0, -1.0)


def noise(seconds):
    return rng.uniform(-1, 1, int(seconds * RATE))


def lowpass(x, cutoff):
    """One-pole low-pass; cutoff may be a scalar or per-sample array."""
    cutoff = np.broadcast_to(cutoff, x.shape)
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def midi(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def mix(*waves):
    """Sum waves of different lengths (shorter ones are padded with silence)."""
    n = max(len(w) for w in waves)
    out = np.zeros(n)
    for w in waves:
        out[: len(w)] += w
    return out


def normalise(x, peak=0.8):
    m = np.max(np.abs(x))
    return x if m == 0 else x * (peak / m)


def save(name, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"  {name}.wav  {len(x) / RATE:.2f}s")


# ---- sound effects --------------------------------------------------------------------

def pluck(freq, seconds, bright=0.5):
    s = sine(freq, seconds) + bright * 0.5 * sine(freq * 2, seconds) + bright * 0.25 * sine(freq * 3, seconds)
    return s * env(len(s), 0.004, seconds * 0.9, 0.0)


def sfx():
    os.makedirs(OUT, exist_ok=True)
    save("ui_click", normalise(pluck(880, 0.07) * 0.9, 0.5))
    save("ui_confirm", normalise(np.concatenate([pluck(660, 0.08), pluck(990, 0.14)]), 0.5))

    # "Spotted" sting: two sharp rising notes.
    save("alert", normalise(np.concatenate([saw(520, 0.09) * env(int(0.09 * RATE), 0.002, 0.08), saw(780, 0.16) * env(int(0.16 * RATE), 0.002, 0.15)]), 0.55))
    # Caught: a falling, wobbling dramatic descent.
    f = np.linspace(520, 110, int(0.9 * RATE))
    s = saw(f, 0.9) * 0.6 + square(f * 0.5, 0.9) * 0.4
    save("caught", normalise(lowpass(s * env(len(s), 0.01, 0.9, 0.0), 2500), 0.7))

    # Victory arpeggio.
    notes = [60, 64, 67, 72, 76, 79, 84]
    win = np.concatenate([pluck(midi(n), 0.14, 0.8) for n in notes] + [pluck(midi(84), 0.7, 0.8) + pluck(midi(79), 0.7, 0.6)])
    save("win", normalise(win, 0.7))

    # Semba's Mighty Roar: a growl that swells and sweeps up.
    dur = 1.3
    t = t_axis(dur)
    f0 = 140 + 90 * np.sin(np.pi * t / dur) + 12 * np.sin(2 * np.pi * 28 * t)
    growl = saw(f0, dur) * 0.6 + square(f0 * 2.01, dur) * 0.3 + noise(dur) * 0.25
    growl = lowpass(growl, 700 + 1800 * np.sin(np.pi * t / dur))
    save("roar", normalise(growl * env(len(growl), 0.05, dur, 0.9, 0.35), 0.85))

    # Bruce purring: a low rumble with amplitude wobble.
    dur = 1.2
    t = t_axis(dur)
    purr = lowpass(saw(52, dur) + 0.6 * noise(dur), 220) * (0.55 + 0.45 * np.sin(2 * np.pi * 24 * t))
    save("purr", normalise(purr * env(len(purr), 0.1, dur, 1.0, 0.2), 0.6))
    # A cute "mrrp" for the Bat-Nap flop.
    f = np.concatenate([np.linspace(420, 640, int(0.09 * RATE)), np.linspace(640, 380, int(0.16 * RATE))])
    m = sine(f, len(f) / RATE) + 0.4 * sine(f * 2, len(f) / RATE)
    save("meow", normalise(m * env(len(m), 0.01, 0.25, 0.0), 0.6))

    # Hack: quick digital chirps.
    chirps = [pluck(f, 0.05, 1.2) for f in (1200, 1600, 1000, 2000, 1500)]
    save("hack", normalise(np.concatenate(chirps), 0.5))
    # Detective Vision glint: a sparkling rising shimmer.
    f = np.linspace(900, 3200, int(0.4 * RATE))
    s = sine(f, 0.4) * env(len(f), 0.01, 0.4, 0.0) + 0.4 * sine(f * 1.5, 0.4) * env(len(f), 0.05, 0.35, 0.0)
    save("vision_on", normalise(s, 0.5))
    # Wiping glasses: a squeaky swipe.
    s = lowpass(noise(0.3), np.linspace(900, 3500, int(0.3 * RATE))) * (0.5 + 0.5 * np.sin(np.linspace(0, 9 * np.pi, int(0.3 * RATE))))
    save("wipe", normalise(s * env(len(s), 0.02, 0.3, 0.0), 0.5))

    # Grapple: launch whoosh + a click, and a landing thud.
    s = lowpass(noise(0.35), np.linspace(400, 5000, int(0.35 * RATE))) * env(int(0.35 * RATE), 0.02, 0.33, 0.0)
    save("grapple_fire", normalise(np.concatenate([pluck(1800, 0.03, 1.5), s]), 0.65))
    s = sine(np.linspace(150, 45, int(0.3 * RATE)), 0.3) * env(int(0.3 * RATE), 0.002, 0.28, 0.0)
    save("grapple_land", normalise(s + lowpass(noise(0.3), 500) * 0.4 * env(int(0.3 * RATE), 0.002, 0.1, 0.0), 0.8))

    # Sliding door and pressure plate.
    s = lowpass(noise(0.6), np.linspace(300, 1200, int(0.6 * RATE))) * np.sin(np.linspace(0, np.pi, int(0.6 * RATE))) ** 0.5
    save("door", normalise(s, 0.5))
    save("plate", normalise(mix(sine(np.linspace(220, 140, int(0.14 * RATE)), 0.14) * env(int(0.14 * RATE), 0.002, 0.13, 0.0), pluck(660, 0.1) * 0.4), 0.6))

    # Cat-ical Wheel: opening swoosh and the switch whoosh.
    s = lowpass(noise(0.3), np.linspace(2500, 300, int(0.3 * RATE))) * env(int(0.3 * RATE), 0.01, 0.3, 0.0)
    save("wheel_open", normalise(s + sine(np.linspace(300, 600, int(0.3 * RATE)), 0.3) * 0.3 * env(int(0.3 * RATE), 0.01, 0.3, 0.0), 0.5))
    save("switch", normalise(np.concatenate([pluck(500, 0.05), pluck(750, 0.05), pluck(1000, 0.12)]), 0.5))

    # Stress: a heartbeat double thump.
    thump = lambda: sine(np.linspace(110, 50, int(0.16 * RATE)), 0.16) * env(int(0.16 * RATE), 0.004, 0.15, 0.0)
    gap = np.zeros(int(0.1 * RATE))
    save("heartbeat", normalise(np.concatenate([thump(), gap, thump() * 0.7, np.zeros(int(0.35 * RATE))]), 0.8))

    # Driving: crash, light chirp, horn, and the engine loop.
    crash = lowpass(noise(0.6), np.linspace(4000, 300, int(0.6 * RATE))) * env(int(0.6 * RATE), 0.002, 0.5, 0.0)
    thud = sine(np.linspace(120, 40, int(0.5 * RATE)), 0.5) * env(int(0.5 * RATE), 0.002, 0.45, 0.0)
    save("crash", normalise(crash[: len(thud)] + thud * 1.2, 0.85))
    save("chirp", normalise(np.concatenate([pluck(1300, 0.06), pluck(1950, 0.12)]), 0.5))
    horn = (square(392, 0.5, 0.45) + square(494, 0.5, 0.45)) * 0.5
    save("horn", normalise(lowpass(horn, 3000) * env(len(horn), 0.01, 0.5, 0.9, 0.08), 0.5))
    dur = 1.0
    t = t_axis(dur)
    engine = saw(70, dur) * 0.6 + square(35, dur) * 0.4 + lowpass(noise(dur), 400) * 0.2
    engine *= 0.8 + 0.2 * np.sin(2 * np.pi * 70 * t)
    save("engine", normalise(lowpass(engine, 1200), 0.55))


# ---- music ----------------------------------------------------------------------------

class Track:
    """A looping mono buffer: add() mixes notes with wrap-around so the loop is seamless."""

    def __init__(self, bpm, bars, beats_per_bar=4):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.seconds = bars * beats_per_bar * self.beat
        self.n = int(self.seconds * RATE)
        self.buf = np.zeros(self.n)

    def add(self, start_beat, wave_, gain=1.0):
        i = int(start_beat * self.beat * RATE)
        idx = (i + np.arange(len(wave_))) % self.n
        np.add.at(self.buf, idx, wave_ * gain)

    def finish(self, name, peak=0.55):
        save(name, normalise(self.buf, peak))


def kick(gain=1.0):
    n = int(0.22 * RATE)
    return sine(np.linspace(150, 45, n), 0.22) * env(n, 0.002, 0.2, 0.0) * gain


def hat(gain=1.0, length=0.05):
    n = int(length * RATE)
    return noise(length) * env(n, 0.001, length, 0.0) * gain * 0.35


def snare(gain=1.0):
    n = int(0.16 * RATE)
    return (noise(0.16) * 0.6 + sine(190, 0.16) * 0.5) * env(n, 0.001, 0.15, 0.0) * gain


def pad(freqs, seconds, gain=0.18):
    s = sum(saw(f, seconds) + 0.5 * saw(f * 1.004, seconds) for f in freqs)
    s = lowpass(s, 900)
    return s * env(len(s), seconds * 0.35, seconds * 0.4, 0.8, seconds * 0.25) * gain


def music():
    # Menu: warm, cozy major arpeggios (C - Am - F - G).
    tr = Track(96, 8)
    chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]]
    for bar in range(8):
        chord = chords[(bar // 2) % 4]
        for step in range(8):
            note = chord[[0, 1, 2, 1, 0, 1, 2, 1][step]] + (12 if step % 4 == 2 else 0)
            tr.add(bar * 4 + step * 0.5, pluck(midi(note + 12), 0.45, 0.6), 0.45)
        tr.add(bar * 4, pad([midi(n) for n in chord], 4 * tr.beat), 0.9)
        tr.add(bar * 4, pluck(midi(chord[0] - 12), 1.4, 0.3), 0.7)
        tr.add(bar * 4 + 2, pluck(midi(chord[0] - 12), 1.4, 0.3), 0.5)
    tr.finish("music_menu", 0.5)

    # Stealth: slow, brooding minor pulse with a heartbeat (Am - F - C - E).
    tr = Track(84, 8)
    chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [52, 56, 59]]
    for bar in range(8):
        chord = chords[(bar // 2) % 4]
        tr.add(bar * 4, pad([midi(n - 12) for n in chord], 4 * tr.beat, 0.22), 1.0)
        for beat in range(4):
            tr.add(bar * 4 + beat, lowpass(saw(midi(chord[0] - 24), 0.35), 300) * env(int(0.35 * RATE), 0.01, 0.34, 0.0), 0.8 if beat % 2 == 0 else 0.4)
        tr.add(bar * 4, kick(0.55))
        tr.add(bar * 4 + 0.35, kick(0.35))
        tr.add(bar * 4 + 2, kick(0.45))
        tr.add(bar * 4 + 2.35, kick(0.3))
        if bar % 2 == 1:
            for k, n in enumerate([chord[2] + 12, chord[1] + 12, chord[0] + 24]):
                tr.add(bar * 4 + 2.5 + k * 0.5, pluck(midi(n), 0.7, 0.4), 0.35)
        tr.add(bar * 4 + 1.5, hat(0.6, 0.03))
        tr.add(bar * 4 + 3.5, hat(0.6, 0.03))
    tr.finish("music_stealth", 0.5)

    # Driving: upbeat four-on-the-floor with an arpeggio lead (Em - C - G - D).
    tr = Track(128, 8)
    chords = [[52, 55, 59], [48, 52, 55], [55, 59, 62], [50, 54, 57]]
    for bar in range(8):
        chord = chords[(bar // 2) % 4]
        for beat in range(4):
            tr.add(bar * 4 + beat, kick(0.9))
            tr.add(bar * 4 + beat + 0.5, hat(0.9))
            tr.add(bar * 4 + beat, lowpass(saw(midi(chord[0] - 12), 0.22), 500) * env(int(0.22 * RATE), 0.005, 0.2, 0.0), 0.6)
            tr.add(bar * 4 + beat + 0.5, lowpass(saw(midi(chord[0] - 12), 0.18), 500) * env(int(0.18 * RATE), 0.005, 0.15, 0.0), 0.45)
        tr.add(bar * 4 + 1, snare(0.8))
        tr.add(bar * 4 + 3, snare(0.8))
        for step in range(16):
            note = chord[[0, 1, 2, 1][step % 4]] + 24
            tr.add(bar * 4 + step * 0.25, pluck(midi(note), 0.22, 0.9), 0.32)
        tr.add(bar * 4, pad([midi(n) for n in chord], 4 * tr.beat, 0.12), 1.0)
    tr.finish("music_drive", 0.55)


if __name__ == "__main__":
    print("Writing sound effects...")
    sfx()
    print("Writing music...")
    music()
