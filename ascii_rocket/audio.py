from __future__ import annotations

import logging
import math
import shutil
import struct
import tempfile
import wave
from pathlib import Path

from .config import AudioSettings

try:
    import winsound
except ImportError:  # pragma: no cover - Windows is primary target
    winsound = None  # type: ignore[assignment]


_EFFECTS: dict[str, tuple[tuple[int, float], ...]] = {
    "launch": ((220, 0.08), (330, 0.08), (440, 0.10), (660, 0.14)),
    "menu": ((720, 0.045),),
    "collision": ((180, 0.12), (120, 0.16), (70, 0.22)),
    "restart": ((330, 0.07), (520, 0.07), (780, 0.10)),
}


class AudioManager:
    def __init__(self, settings: AudioSettings, logger: logging.Logger | None = None) -> None:
        self.settings = settings
        self.logger = logger or logging.getLogger(__name__)
        self.cache = Path(tempfile.mkdtemp(prefix="ascii-rocket-audio-"))
        self.files: dict[str, Path] = {}
        self.available = winsound is not None
        self.apply_volume()

    def apply_volume(self, settings: AudioSettings | None = None) -> None:
        if settings is not None:
            self.settings = settings
        if not self.available:
            return
        for name, tones in _EFFECTS.items():
            path = self.cache / f"{name}.wav"
            effect_volume = self.settings.effect_volumes.get(name, 100) / 100
            volume = self.settings.master_volume / 100 * effect_volume
            try:
                _write_wave(path, tones, volume)
                self.files[name] = path
            except OSError as exc:
                self.available = False
                self.logger.warning("Procedural audio disabled: %s", exc)
                break

    def play(self, effect: str) -> None:
        if not self.settings.enabled or not self.available or effect not in self.files:
            return
        try:
            winsound.PlaySound(  # type: ignore[union-attr]
                str(self.files[effect]),
                winsound.SND_FILENAME | winsound.SND_ASYNC | winsound.SND_NODEFAULT,  # type: ignore[union-attr]
            )
        except (RuntimeError, OSError) as exc:
            self.available = False
            self.logger.warning("Audio playback disabled: %s", exc)

    def shutdown(self) -> None:
        if winsound is not None:
            try:
                winsound.PlaySound(None, 0)
            except RuntimeError:
                pass
        shutil.rmtree(self.cache, ignore_errors=True)


def _write_wave(path: Path, tones: tuple[tuple[int, float], ...], volume: float) -> None:
    sample_rate = 22_050
    amplitude = int(20_000 * max(0.0, min(1.0, volume)))
    frames = bytearray()
    for frequency, duration in tones:
        count = int(sample_rate * duration)
        fade = max(1, int(sample_rate * min(0.02, duration / 3)))
        for index in range(count):
            envelope = min(1.0, index / fade, (count - index) / fade)
            sample = int(amplitude * envelope * math.sin(2 * math.pi * frequency * index / sample_rate))
            frames.extend(struct.pack("<h", sample))
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(frames)
