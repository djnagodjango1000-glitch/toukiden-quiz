"""Generate original offline BGM; requires numpy and ffmpeg only at development time.

All melodies and synthesized tones are new for this project. The running game
loads the resulting Ogg files and does not run Python or access the network.
"""
from pathlib import Path
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "music"
OUT.mkdir(parents=True, exist_ok=True)


def tone(midi, seconds, style="koto"):
    t = np.arange(round(seconds * RATE), dtype=np.float64) / RATE
    freq = 440 * 2 ** ((midi - 69) / 12)
    if style == "koto":
        envelope = np.exp(-3.7 * t) * np.minimum(1, t * 220)
        signal = (np.sin(2 * np.pi * freq * t)
                  + 0.32 * np.sin(2 * np.pi * freq * 2.01 * t)
                  + 0.15 * np.sin(2 * np.pi * freq * 3.03 * t)) * envelope
    else:
        envelope = np.minimum(1, t * 6) * np.exp(-1.35 * t)
        signal = (np.sin(2 * np.pi * freq * t)
                  + 0.20 * np.sin(2 * np.pi * freq * 2 * t)) * envelope
    return signal


def drum(seconds, high=False):
    t = np.arange(round(seconds * RATE), dtype=np.float64) / RATE
    freq = 135 if high else 72
    phase = 2 * np.pi * (freq * t + 11 * (1 - np.exp(-18 * t)) / 18)
    rng = np.random.default_rng(51 if high else 17)
    return ((np.sin(phase) * np.exp(-8 * t)
             + rng.standard_normal(len(t)) * np.exp(-35 * t) * 0.12)
            * np.minimum(1, t * 500))


def add_wrap(buffer, start, signal, gain):
    start %= len(buffer)
    indices = (start + np.arange(len(signal))) % len(buffer)
    np.add.at(buffer, indices, signal * gain)


def make(name, bpm, bars, melody, beat_notes, pulse):
    beat = 60.0 / bpm
    total = round(bars * 4 * beat * RATE)
    audio = np.zeros(total, dtype=np.float64)
    for offset, pitch, duration, loudness in melody:
        add_wrap(audio, round(offset * beat * RATE), tone(pitch, duration * beat), loudness)
    for offset, pitch in beat_notes:
        add_wrap(audio, round(offset * beat * RATE), tone(pitch, beat * 1.6, "bell"), 0.038)
    if pulse:
        for i in range(bars * 4):
            if i % 2 == 0:
                add_wrap(audio, round(i * beat * RATE), drum(0.42), 0.21)
            if i % 4 in (1, 3):
                add_wrap(audio, round((i + 0.5) * beat * RATE), drum(0.2, True), 0.06)
    # The drone has an integer number of cycles across the loop boundary.
    cycles = round(110 * total / RATE)
    audio += 0.025 * np.sin(2 * np.pi * cycles * np.arange(total) / total)
    peak = max(float(np.max(np.abs(audio))), 1e-9)
    audio = np.clip(audio * min(0.80 / peak, 1.0), -1, 1)
    pcm = (audio * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        with wave.open(tmp.name, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
                        "-c:a", "libvorbis", "-q:a", "4", str(OUT / (name + ".ogg"))], check=True)
    print(name, "seconds", round(total / RATE, 2), "peak", round(peak, 3))


def phrase(notes, pattern, repeats=4, spacing=8):
    return [(r * spacing + offset, notes[index], length, strength)
            for r in range(repeats)
            for offset, index, length, strength in pattern]


scale = [62, 65, 67, 69, 72, 74, 77, 81]
home_pattern = [(0, 0, 1.4, .15), (1.5, 2, .9, .12), (3, 4, 1.2, .14),
                (4.5, 3, .8, .11), (6, 1, 1.2, .12), (7, 2, .8, .10)]
battle_pattern = [(0, 0, .55, .17), (.75, 2, .45, .11), (1.5, 3, .5, .15),
                  (2, 4, .5, .15), (3, 2, .65, .14), (4, 5, .5, .16),
                  (4.75, 4, .45, .11), (5.5, 3, .55, .14), (6, 1, .5, .13), (7, 0, .7, .15)]
musuhi_pattern = [(0, 4, .38, .15), (.5, 5, .38, .13), (1, 6, .45, .16),
                  (1.5, 5, .35, .12), (2, 4, .42, .14), (2.5, 3, .4, .12),
                  (3, 2, .6, .15), (4, 3, .4, .13), (4.5, 4, .4, .14),
                  (5, 5, .45, .16), (6, 4, .4, .13), (7, 2, .65, .14)]
result_pattern = [(0, 0, 1.2, .13), (1, 2, 1.1, .12), (2, 4, 1.6, .15),
                  (4, 3, 1, .11), (5.5, 2, 1.2, .11), (7, 0, 1.3, .13)]
make("village", 80, 8, phrase(scale, home_pattern), [(i, 50 + (i // 4 % 2) * 5) for i in range(0, 32, 4)], False)
make("battle", 120, 8, phrase(scale, battle_pattern), [(i, 50 + (i // 4 % 2) * 5) for i in range(0, 32, 4)], True)
make("boss", 100, 8, phrase([50, 53, 55, 57, 60, 62, 65, 69], battle_pattern), [(i, 38 + (i // 4 % 2) * 5) for i in range(0, 32, 4)], True)
make("musuhi", 120, 8, phrase(scale, musuhi_pattern), [(i, 57 + (i // 4 % 2) * 3) for i in range(0, 32, 4)], True)
make("result", 80, 8, phrase(scale, result_pattern), [(i, 50 + (i // 4 % 2) * 5) for i in range(0, 32, 4)], False)
make("defeat", 80, 8, phrase([57, 60, 62, 65, 69, 72, 74, 77], result_pattern), [(i, 45 + (i // 4 % 2) * 5) for i in range(0, 32, 4)], False)
