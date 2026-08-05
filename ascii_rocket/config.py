from __future__ import annotations

import copy
import json
import os
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

from .themes import ThemeId, ThemeRegistry


def _default_bindings() -> dict[str, list[str]]:
    return {
        "up": ["w", "Up"],
        "down": ["s", "Down"],
        "left": ["a", "Left"],
        "right": ["d", "Right"],
        "pause": ["Escape", "p"],
        "restart": ["r"],
        "fullscreen": ["F11"],
    }


def _default_effect_volumes() -> dict[str, int]:
    return {"launch": 80, "menu": 55, "collision": 100, "restart": 70}


@dataclass(slots=True)
class DisplaySettings:
    theme: str | None = None
    fullscreen: bool = True
    target_fps: int = 60
    font_family: str = "Consolas"
    font_size: int = 18
    star_count: int = 180
    glow: bool = True
    scanlines: bool = False
    color_overrides: dict[str, str] = field(default_factory=dict)


@dataclass(slots=True)
class GameplaySettings:
    preset: str = "normal"
    rocket_speed: float = 300.0
    launch_speed: float = 220.0
    flight_target: float = 0.55
    asteroid_speed: float = 140.0
    initial_spawn_interval: float = 1.25
    minimum_spawn_interval: float = 0.35
    difficulty_step: float = 20.0
    initial_live_cap: int = 6
    maximum_live_cap: int = 14
    speed_growth: float = 1.08
    interval_decay: float = 0.90
    large_weight_start: float = 0.15
    large_weight_step: float = 0.05
    large_weight_cap: float = 0.45
    collision_forgiveness: float = 0.0
    star_speed_min: float = 25.0
    star_speed_max: float = 180.0
    seed: int | None = None


@dataclass(slots=True)
class AudioSettings:
    enabled: bool = True
    master_volume: int = 80
    effect_volumes: dict[str, int] = field(default_factory=_default_effect_volumes)


@dataclass(slots=True)
class ControlsSettings:
    bindings: dict[str, list[str]] = field(default_factory=_default_bindings)

    def conflicts(self) -> dict[str, list[str]]:
        owners: dict[str, list[str]] = {}
        for action, keys in self.bindings.items():
            for key in keys:
                normalized = key.lower() if len(key) == 1 else key
                owners.setdefault(normalized, []).append(action)
        return {key: actions for key, actions in owners.items() if len(actions) > 1}


@dataclass(slots=True)
class AppConfig:
    version: int = 1
    display: DisplaySettings = field(default_factory=DisplaySettings)
    gameplay: GameplaySettings = field(default_factory=GameplaySettings)
    audio: AudioSettings = field(default_factory=AudioSettings)
    controls: ControlsSettings = field(default_factory=ControlsSettings)
    load_warnings: list[str] = field(default_factory=list, repr=False, compare=False)

    @staticmethod
    def data_directory() -> Path:
        base = os.getenv("APPDATA")
        return (Path(base) if base else Path.home() / ".config") / "AsciiRocket"

    @classmethod
    def settings_path(cls) -> Path:
        return cls.data_directory() / "settings.json"

    @classmethod
    def load(cls, path: Path | None = None) -> "AppConfig":
        source = path or cls.settings_path()
        if not source.exists():
            return cls()
        try:
            raw = json.loads(source.read_text(encoding="utf-8"))
            config = cls.from_dict(raw)
        except (OSError, ValueError, TypeError, json.JSONDecodeError) as exc:
            config = cls()
            config.load_warnings.append(f"Settings could not be loaded: {exc}")
            return config
        config.validate()
        return config

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "AppConfig":
        if not isinstance(raw, dict):
            raise TypeError("settings root must be an object")
        display = DisplaySettings(**_known_fields(DisplaySettings, raw.get("display", {})))
        gameplay = GameplaySettings(**_known_fields(GameplaySettings, raw.get("gameplay", {})))
        audio = AudioSettings(**_known_fields(AudioSettings, raw.get("audio", {})))
        controls = ControlsSettings(**_known_fields(ControlsSettings, raw.get("controls", {})))
        return cls(
            version=int(raw.get("version", 1)),
            display=display,
            gameplay=gameplay,
            audio=audio,
            controls=controls,
        )

    def clone(self) -> "AppConfig":
        return copy.deepcopy(self)

    def validate(self) -> list[str]:
        warnings: list[str] = []
        display = self.display
        gameplay = self.gameplay
        audio = self.audio

        if display.theme not in {None, *(theme.value for theme in ThemeId)}:
            warnings.append("Unknown theme reset to Deep-Space HUD")
            display.theme = ThemeId.DEEP_SPACE_HUD.value
        display.target_fps = _choice(display.target_fps, (30, 60, 120), 60, warnings, "target FPS")
        display.font_family = str(display.font_family).strip() or "Consolas"
        display.font_size = _clamp_int(display.font_size, 8, 36, warnings, "font size")
        display.star_count = _clamp_int(display.star_count, 0, 500, warnings, "star count")
        display.color_overrides = {
            key: value
            for key, value in display.color_overrides.items()
            if ThemeRegistry.is_color(value)
        }

        gameplay.preset = gameplay.preset if gameplay.preset in {"easy", "normal", "hard", "custom"} else "custom"
        gameplay.rocket_speed = _clamp_float(gameplay.rocket_speed, 100, 700, warnings, "rocket speed")
        gameplay.launch_speed = _clamp_float(gameplay.launch_speed, 80, 500, warnings, "launch speed")
        gameplay.flight_target = _clamp_float(gameplay.flight_target, 0.30, 0.75, warnings, "flight target")
        gameplay.asteroid_speed = _clamp_float(gameplay.asteroid_speed, 60, 500, warnings, "asteroid speed")
        gameplay.initial_spawn_interval = _clamp_float(gameplay.initial_spawn_interval, 0.30, 4.0, warnings, "spawn interval")
        gameplay.minimum_spawn_interval = _clamp_float(gameplay.minimum_spawn_interval, 0.15, gameplay.initial_spawn_interval, warnings, "minimum spawn interval")
        gameplay.difficulty_step = _clamp_float(gameplay.difficulty_step, 5, 120, warnings, "difficulty step")
        gameplay.initial_live_cap = _clamp_int(gameplay.initial_live_cap, 1, 30, warnings, "initial live cap")
        gameplay.maximum_live_cap = _clamp_int(gameplay.maximum_live_cap, gameplay.initial_live_cap, 30, warnings, "maximum live cap")
        gameplay.speed_growth = _clamp_float(gameplay.speed_growth, 1.0, 1.25, warnings, "speed growth")
        gameplay.interval_decay = _clamp_float(gameplay.interval_decay, 0.70, 1.0, warnings, "interval decay")
        gameplay.large_weight_start = _clamp_float(gameplay.large_weight_start, 0, 1, warnings, "large weight start")
        gameplay.large_weight_step = _clamp_float(gameplay.large_weight_step, 0, 0.25, warnings, "large weight step")
        gameplay.large_weight_cap = _clamp_float(gameplay.large_weight_cap, gameplay.large_weight_start, 1, warnings, "large weight cap")
        gameplay.collision_forgiveness = _clamp_float(gameplay.collision_forgiveness, 0, 0.40, warnings, "collision forgiveness")
        gameplay.star_speed_min = _clamp_float(gameplay.star_speed_min, 5, 500, warnings, "minimum star speed")
        gameplay.star_speed_max = _clamp_float(gameplay.star_speed_max, gameplay.star_speed_min, 600, warnings, "maximum star speed")
        if gameplay.seed is not None:
            gameplay.seed = _clamp_int(gameplay.seed, -(2**31), 2**31 - 1, warnings, "seed")

        audio.master_volume = _clamp_int(audio.master_volume, 0, 100, warnings, "master volume")
        defaults = _default_effect_volumes()
        audio.effect_volumes = {
            name: _clamp_int(audio.effect_volumes.get(name, default), 0, 100, warnings, f"{name} volume")
            for name, default in defaults.items()
        }
        required_actions = set(_default_bindings())
        if set(self.controls.bindings) != required_actions or self.controls.conflicts():
            warnings.append("Invalid or conflicting controls reset to defaults")
            self.controls = ControlsSettings()
        else:
            self.controls.bindings = {
                action: [str(key) for key in keys if str(key)]
                for action, keys in self.controls.bindings.items()
            }
        pause_keys = [key for key in self.controls.bindings["pause"] if key != "Escape"]
        self.controls.bindings["pause"] = ["Escape", *pause_keys]
        self.load_warnings.extend(warnings)
        return warnings

    def save_atomic(self, path: Path | None = None) -> None:
        destination = path or self.settings_path()
        destination.parent.mkdir(parents=True, exist_ok=True)
        payload = asdict(self)
        payload.pop("load_warnings", None)
        temporary = destination.with_suffix(destination.suffix + ".tmp")
        temporary.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
        os.replace(temporary, destination)

    def reset_defaults(self) -> None:
        fresh = type(self)()
        self.version = fresh.version
        self.display = fresh.display
        self.gameplay = fresh.gameplay
        self.audio = fresh.audio
        self.controls = fresh.controls
        self.load_warnings.clear()


class HighScoreStore:
    def __init__(self, path: Path | None = None) -> None:
        self.path = path or AppConfig.data_directory() / "high_score.json"

    def load(self) -> int:
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
            return max(0, int(raw.get("high_score", 0)))
        except (OSError, ValueError, TypeError, json.JSONDecodeError):
            return 0

    def save(self, score: int) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(".json.tmp")
        temporary.write_text(json.dumps({"high_score": max(0, int(score))}, indent=2), encoding="utf-8")
        os.replace(temporary, self.path)


def apply_preset(gameplay: GameplaySettings, preset: str) -> None:
    values = {
        "easy": dict(
            asteroid_speed=110.0,
            initial_spawn_interval=1.55,
            minimum_spawn_interval=0.50,
            difficulty_step=25.0,
            initial_live_cap=5,
            maximum_live_cap=11,
            speed_growth=1.06,
            interval_decay=0.93,
            large_weight_step=0.04,
            large_weight_cap=0.35,
        ),
        "normal": dict(
            asteroid_speed=140.0,
            initial_spawn_interval=1.25,
            minimum_spawn_interval=0.35,
            difficulty_step=20.0,
            initial_live_cap=6,
            maximum_live_cap=14,
            speed_growth=1.08,
            interval_decay=0.90,
            large_weight_step=0.05,
            large_weight_cap=0.45,
        ),
        "hard": dict(
            asteroid_speed=175.0,
            initial_spawn_interval=1.0,
            minimum_spawn_interval=0.25,
            difficulty_step=15.0,
            initial_live_cap=7,
            maximum_live_cap=18,
            speed_growth=1.10,
            interval_decay=0.87,
            large_weight_step=0.07,
            large_weight_cap=0.55,
        ),
    }
    if preset not in values:
        gameplay.preset = "custom"
        return
    gameplay.preset = preset
    for name, value in values[preset].items():
        setattr(gameplay, name, value)


def _known_fields(data_type: type, raw: object) -> dict[str, Any]:
    if not isinstance(raw, dict):
        return {}
    return {name: value for name, value in raw.items() if name in data_type.__dataclass_fields__}


def _clamp_float(value: Any, minimum: float, maximum: float, warnings: list[str], label: str) -> float:
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        parsed = minimum
        warnings.append(f"Invalid {label} replaced")
    clamped = max(minimum, min(maximum, parsed))
    if clamped != parsed:
        warnings.append(f"{label.capitalize()} clamped")
    return clamped


def _clamp_int(value: Any, minimum: int, maximum: int, warnings: list[str], label: str) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        parsed = minimum
        warnings.append(f"Invalid {label} replaced")
    clamped = max(minimum, min(maximum, parsed))
    if clamped != parsed:
        warnings.append(f"{label.capitalize()} clamped")
    return clamped


def _choice(value: Any, allowed: tuple[int, ...], default: int, warnings: list[str], label: str) -> int:
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        parsed = default
    if parsed not in allowed:
        warnings.append(f"Invalid {label} reset")
        return default
    return parsed
