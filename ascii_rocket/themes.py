from __future__ import annotations

from dataclasses import dataclass, replace
from enum import StrEnum


class ThemeId(StrEnum):
    TERMINAL_NOIR = "terminal-noir"
    DEEP_SPACE_HUD = "deep-space-hud"
    NEON_ARCADE = "neon-arcade"


@dataclass(frozen=True, slots=True)
class ThemeProfile:
    id: ThemeId
    name: str
    background: str
    primary: str
    accent: str
    hazard: str
    muted: str
    panel: str
    star_symbols: tuple[str, ...]
    scanlines_default: bool = False


class ThemeRegistry:
    _themes = {
        ThemeId.TERMINAL_NOIR: ThemeProfile(
            ThemeId.TERMINAL_NOIR,
            "Terminal Noir",
            "#020704",
            "#75FF91",
            "#24FF5A",
            "#A6FFB7",
            "#2E7A43",
            "#06110A",
            (".", "+", "*", "·"),
            True,
        ),
        ThemeId.DEEP_SPACE_HUD: ThemeProfile(
            ThemeId.DEEP_SPACE_HUD,
            "Deep-Space HUD",
            "#02040A",
            "#E8F7FF",
            "#67E8F9",
            "#FFB454",
            "#526779",
            "#071321",
            (".", "·", "*", "+"),
        ),
        ThemeId.NEON_ARCADE: ThemeProfile(
            ThemeId.NEON_ARCADE,
            "Neon Arcade",
            "#09031B",
            "#7DF9FF",
            "#FF70B8",
            "#FFDF6C",
            "#8E69B8",
            "#180629",
            (".", "✦", "·", "+"),
        ),
    }

    @classmethod
    def all(cls) -> tuple[ThemeProfile, ...]:
        return tuple(cls._themes.values())

    @classmethod
    def get(
        cls, theme_id: str | ThemeId | None, overrides: dict[str, str] | None = None
    ) -> ThemeProfile:
        try:
            key = ThemeId(theme_id) if theme_id else ThemeId.DEEP_SPACE_HUD
        except ValueError:
            key = ThemeId.DEEP_SPACE_HUD
        theme = cls._themes[key]
        allowed = {"background", "primary", "accent", "hazard", "muted", "panel"}
        valid = {
            name: value
            for name, value in (overrides or {}).items()
            if name in allowed and cls.is_color(value)
        }
        return replace(theme, **valid) if valid else theme

    @staticmethod
    def is_color(value: object) -> bool:
        if not isinstance(value, str) or len(value) != 7 or not value.startswith("#"):
            return False
        try:
            int(value[1:], 16)
        except ValueError:
            return False
        return True

