"""Renders the wood-and-bell sound set to app/Queens/Resources/Sounds as 16-bit mono WAVs.

Everything is synthesised (marimba bars, a woodblock, small bells), so there are no samples to licence.
Pitches sit on a D major pentatonic scale from D4, so crowns climb the scale and the finale resolves home.
"""
import wave
from pathlib import Path

import numpy as np

OUT = Path(__file__).resolve().parent.parent / "app/Queens/Resources/Sounds"
SR = 44100
PENTA = [0, 2, 4, 7, 9]
rng = np.random.default_rng(7)


def hz(semi):
    return 293.66 * 2 ** (semi / 12)


def step(i):
    return PENTA[i % 5] + 12 * (i // 5)


def buf(seconds):
    return np.zeros(int(SR * seconds))


def tone(out, start, f, amp, decay, attack=0.003):
    """A sine partial with a short linear attack and exponential decay, mixed into `out` at `start` seconds."""
    i0 = int(start * SR)
    n = min(len(out) - i0, int(SR * (attack + decay * 7)))
    if n <= 0 or f >= SR / 2:
        return
    t = np.arange(n) / SR
    env = np.minimum(t / attack, 1) * np.exp(-np.maximum(t - attack, 0) / decay)
    out[i0:i0 + n] += amp * env * np.sin(2 * np.pi * f * t)


def bandpass(x, f, q):
    """RBJ biquad band-pass."""
    w = 2 * np.pi * f / SR
    alpha = np.sin(w) / (2 * q)
    b0, b2 = alpha, -alpha
    a0, a1, a2 = 1 + alpha, -2 * np.cos(w), 1 - alpha
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = (b0 * v + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def noise(out, start, seconds, amp, f, q):
    i0 = int(start * SR)
    n = min(len(out) - i0, int(SR * seconds))
    t = np.arange(n) / SR
    burst = bandpass(rng.uniform(-1, 1, n), f, q) * np.exp(-t / (seconds / 4))
    out[i0:i0 + n] += amp * burst / (np.abs(burst).max() + 1e-9)


def marimba(out, start, f, amp=1.0):
    """A struck wooden bar: fundamental, the tuned fourth harmonic, a bright click, and a mallet thump."""
    d = 0.42 * (293.66 / f) ** 0.35
    tone(out, start, f, amp, d)
    tone(out, start, f * 4, amp * 0.16, d * 0.22)
    tone(out, start, f * 9.9, amp * 0.05, 0.012)
    noise(out, start, 0.02, amp * 0.06, min(f * 3, 6000), 2)


def bell(out, start, f, amp=1.0, length=1.8):
    """A small bell: inharmonic partials of a free bar, upper ones dying first."""
    for ratio, a, d in [(1, 1.0, 0.55), (2.76, 0.45, 0.22), (5.40, 0.22, 0.09), (8.93, 0.1, 0.04)]:
        tone(out, start, f * ratio, amp * a, d * length / 1.8, attack=0.002)


def save(name, x, peak=0.85):
    x = x / (np.abs(x).max() + 1e-9) * peak
    # Trim trailing silence, keep a 20 ms tail fade so nothing clicks.
    loud = np.nonzero(np.abs(x) > 1e-3)[0]
    x = x[: (loud[-1] + int(0.02 * SR)) if len(loud) else len(x)]
    fade = min(len(x), int(0.02 * SR))
    x[-fade:] *= np.linspace(1, 0, fade)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def main():
    # Cross: a dry woodblock tick.
    x = buf(0.12)
    tone(x, 0, 1750, 1.0, 0.012, attack=0.001)
    tone(x, 0, 2900, 0.3, 0.006, attack=0.001)
    noise(x, 0, 0.03, 0.35, 2500, 3)
    save("tick", x, 0.7)

    # Crowns, kingdom chimes and the gilding run: one marimba bar per scale step, D4 up three octaves.
    for i in range(16):
        x = buf(1.6)
        marimba(x, 0, hz(step(i)))
        save(f"note_{i:02d}", x)

    # Clash: two bars a semitone apart, low, with a wooden knock under them.
    x = buf(1.0)
    marimba(x, 0, hz(-12))
    marimba(x, 0.015, hz(-11))
    tone(x, 0, 90, 0.6, 0.06)
    noise(x, 0, 0.08, 0.3, 300, 1)
    save("clash", x)

    # Finale: a strummed bell chord on D5.
    x = buf(3.0)
    for k, s in enumerate([12, 16, 19, 24]):
        bell(x, k * 0.014, hz(s), 0.8)
    marimba(x, 0, hz(0), 0.6)
    save("chord", x)

    # Lanterns: single high bells, picked at random in the app so no two solves ring the same.
    for k, s in enumerate(PENTA):
        x = buf(2.0)
        bell(x, 0, hz(s + 24), 1.0, 1.4)
        save(f"lantern_{k}", x)

    # Wax seal: a low wooden thump with a bell under it.
    x = buf(2.0)
    i = np.arange(int(0.3 * SR)) / SR
    x[: len(i)] += np.exp(-i / 0.07) * np.sin(2 * np.pi * (78 - 30 * i) * i)
    noise(x, 0, 0.08, 0.3, 180, 0.8)
    bell(x, 0.005, hz(-12), 0.35, 2.2)
    save("seal", x)

    # A new best: the bells run up a major ninth over the seal.
    x = buf(2.2)
    for k, s in enumerate([24, 28, 31, 35, 38]):
        bell(x, k * 0.08, hz(s), 0.7 + k * 0.06, 1.5)
    save("best", x, 0.75)

    # Shooting star: bells tumbling down the scale over a soft rush of air.
    x = buf(2.0)
    for k, i in enumerate(range(17, 7, -1)):
        bell(x, k * 0.05, hz(step(i)), 0.5 - k * 0.025, 1.1)
    noise(x, 0, 0.9, 0.12, 3000, 0.5)
    save("comet", x, 0.7)

    print(f"wrote {len(list(OUT.glob('*.wav')))} sounds to {OUT}")


if __name__ == "__main__":
    main()
