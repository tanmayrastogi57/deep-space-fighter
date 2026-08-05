from __future__ import annotations

import tkinter as tk
from tkinter import font as tkfont

from .config import AppConfig
from .models import FontMetrics, FrameSnapshot
from .state import GameState
from .themes import ThemeId, ThemeRegistry


class Renderer:
    def __init__(self, root: tk.Misc, canvas: tk.Canvas, config: AppConfig) -> None:
        self.root = root
        self.canvas = canvas
        self.config = config
        self.theme = ThemeRegistry.get(config.display.theme, config.display.color_overrides)
        self.width = max(320, canvas.winfo_width())
        self.height = max(240, canvas.winfo_height())
        self.show_fps = False
        self._font = self._make_font(config.display.font_size)
        self._small_font = self._make_font(max(9, config.display.font_size - 4))
        self._title_font = self._make_font(min(36, config.display.font_size + 12), bold=True)
        self._star_items: dict[int, int] = {}
        self._asteroid_items: dict[int, int] = {}
        self._buttons: list[tuple[tuple[float, float, float, float], str]] = []
        self._overlay_key: tuple | None = None
        self._rocket_shadow = canvas.create_text(0, 0, anchor="nw", tags=("game", "rocket-shadow"))
        self._rocket_item = canvas.create_text(0, 0, anchor="nw", tags=("game", "rocket"))
        self._hud_left = canvas.create_text(18, 16, anchor="nw", tags=("hud",))
        self._hud_right = canvas.create_text(self.width - 18, 16, anchor="ne", tags=("hud",))
        self._fps_item = canvas.create_text(18, 44, anchor="nw", tags=("hud",))
        self._explosion_item = canvas.create_text(0, 0, anchor="center", tags=("explosion",))
        self.update_config(config)

    def _make_font(self, size: int, bold: bool = False) -> tkfont.Font:
        family = self._resolve_monospace_family(size)
        return tkfont.Font(root=self.root, family=family, size=size, weight="bold" if bold else "normal")

    def _resolve_monospace_family(self, size: int) -> str:
        requested = self.config.display.font_family
        available = set(tkfont.families(self.root))
        family = tkfont.nametofont("TkFixedFont").actual("family")
        for candidate in (requested, "Consolas", "Courier New", "DejaVu Sans Mono"):
            if candidate not in available:
                continue
            probe = tkfont.Font(root=self.root, family=candidate, size=size)
            if probe.measure("i") == probe.measure("W") == probe.measure("M"):
                family = candidate
                break
        return str(family)

    def font_metrics(self) -> FontMetrics:
        return FontMetrics(float(self._font.measure("M")), float(self._font.metrics("linespace")))

    def update_config(self, config: AppConfig) -> None:
        self.config = config
        self.theme = ThemeRegistry.get(config.display.theme, config.display.color_overrides)
        family = self._resolve_monospace_family(config.display.font_size)
        self._font.configure(family=family, size=config.display.font_size)
        self._small_font.configure(family=family, size=max(9, config.display.font_size - 4))
        self._title_font.configure(family=family, size=min(36, config.display.font_size + 12))
        self.canvas.configure(background=self.theme.background, highlightthickness=0)
        self.canvas.itemconfigure(self._rocket_item, font=self._font, fill=self.theme.primary)
        self.canvas.itemconfigure(self._rocket_shadow, font=self._font, fill=self.theme.accent)
        for item in (self._hud_left, self._hud_right, self._fps_item):
            self.canvas.itemconfigure(item, font=self._small_font, fill=self.theme.accent)
        self.canvas.itemconfigure(self._explosion_item, font=self._title_font, fill=self.theme.hazard)
        self._overlay_key = None
        self._rebuild_decorations()

    def resize(self, width: int, height: int) -> None:
        self.width = max(320, width)
        self.height = max(240, height)
        self.canvas.coords(self._hud_right, self.width - 18, 16)
        self._overlay_key = None
        self._rebuild_decorations()

    def toggle_fps(self) -> None:
        self.show_fps = not self.show_fps

    def hit_test(self, x: float, y: float) -> str | None:
        for (left, top, right, bottom), command in reversed(self._buttons):
            if left <= x <= right and top <= y <= bottom:
                return command
        return None

    def render(self, snapshot: FrameSnapshot) -> None:
        self._sync_stars(snapshot)
        self._sync_rocket(snapshot)
        self._sync_asteroids(snapshot)
        self.canvas.itemconfigure(
            self._hud_left,
            text=f"FLIGHT {snapshot.active_seconds:06.1f}s   LEVEL {snapshot.difficulty_level + 1}",
        )
        self.canvas.itemconfigure(
            self._hud_right,
            text=f"SCORE {snapshot.score:05d}\nBEST  {snapshot.best_score:05d}",
        )
        self.canvas.itemconfigure(
            self._fps_item,
            text=f"FPS {snapshot.fps:4.0f}" if self.show_fps else "",
        )
        self._render_explosion(snapshot)
        key = (
            snapshot.state_name,
            snapshot.score,
            snapshot.best_score,
            snapshot.show_game_over,
            snapshot.new_best,
            self.theme.id,
            self.width,
            self.height,
        )
        if key != self._overlay_key:
            self._overlay_key = key
            self._render_overlay(snapshot)

    def _sync_stars(self, snapshot: FrameSnapshot) -> None:
        live = {star.id for star in snapshot.stars}
        for star_id in set(self._star_items) - live:
            self.canvas.delete(self._star_items.pop(star_id))
        for star in snapshot.stars:
            item = self._star_items.get(star.id)
            color = self.theme.primary if star.intensity > 0.78 else self.theme.accent if star.intensity > 0.55 else self.theme.muted
            if item is None:
                item = self.canvas.create_text(
                    star.x,
                    star.y,
                    text=star.symbol,
                    fill=color,
                    font=self._small_font,
                    tags=("star",),
                )
                self._star_items[star.id] = item
            else:
                self.canvas.coords(item, star.x, star.y)
                self.canvas.itemconfigure(item, text=star.symbol, fill=color, font=self._small_font)
        self.canvas.tag_lower("star")
        self.canvas.tag_lower("decor")

    def _sync_rocket(self, snapshot: FrameSnapshot) -> None:
        rocket = snapshot.rocket
        hidden = snapshot.state_name == GameState.GAME_OVER.name
        state = "hidden" if hidden else "normal"
        self.canvas.coords(self._rocket_item, rocket.x, rocket.y)
        self.canvas.itemconfigure(self._rocket_item, text=rocket.text, state=state)
        self.canvas.coords(self._rocket_shadow, rocket.x + 2, rocket.y + 2)
        self.canvas.itemconfigure(
            self._rocket_shadow,
            text=rocket.text,
            state=state if self.config.display.glow else "hidden",
        )
        self.canvas.tag_lower(self._rocket_shadow, self._rocket_item)

    def _sync_asteroids(self, snapshot: FrameSnapshot) -> None:
        live = {asteroid.id for asteroid in snapshot.asteroids}
        for asteroid_id in set(self._asteroid_items) - live:
            self.canvas.delete(self._asteroid_items.pop(asteroid_id))
        for asteroid in snapshot.asteroids:
            item = self._asteroid_items.get(asteroid.id)
            if item is None:
                item = self.canvas.create_text(
                    asteroid.x,
                    asteroid.y,
                    anchor="nw",
                    text=asteroid.text,
                    fill=self.theme.hazard,
                    font=self._font,
                    tags=("asteroid",),
                )
                self._asteroid_items[asteroid.id] = item
            else:
                self.canvas.coords(item, asteroid.x, asteroid.y)
                self.canvas.itemconfigure(item, text=asteroid.text, fill=self.theme.hazard, font=self._font)

    def _render_explosion(self, snapshot: FrameSnapshot) -> None:
        elapsed = snapshot.explosion_elapsed
        if elapsed is None or elapsed >= 0.6:
            self.canvas.itemconfigure(self._explosion_item, state="hidden")
            return
        frames = ("  ·\n· ✦ ·\n  ·", "* \\ | / *\n--  X  --\n* / | \\ *", "✦  *  ✦\n  BOOM\n✦  *  ✦")
        frame = frames[min(len(frames) - 1, int(elapsed / 0.2))]
        metrics = self.font_metrics()
        center_x = snapshot.rocket.x + len(snapshot.rocket.text.splitlines()[0]) * metrics.cell_width / 2
        center_y = snapshot.rocket.y + 3 * metrics.line_height
        self.canvas.coords(self._explosion_item, center_x, center_y)
        self.canvas.itemconfigure(self._explosion_item, text=frame, state="normal")

    def _render_overlay(self, snapshot: FrameSnapshot) -> None:
        self.canvas.delete("overlay")
        self._buttons.clear()
        state = GameState[snapshot.state_name]
        if state in {GameState.LAUNCHING, GameState.PLAYING, GameState.GAME_OVER} and not snapshot.show_game_over:
            return
        if state is GameState.THEME_SELECT:
            self._panel("CHOOSE YOUR FLIGHT SYSTEM", "Theme persists. Change later in Settings.")
            start_y = self.height / 2 - 45
            for index, theme in enumerate(ThemeRegistry.all()):
                self._button(start_y + index * 58, theme.name, f"theme:{theme.id.value}")
            self._button(start_y + 3 * 58 + 16, "QUIT", "quit", narrow=True)
        elif state is GameState.READY:
            self._panel("ASCII ROCKET", "PRESS SPACE OR ENTER TO LAUNCH\nWASD / ARROWS TO FLY   •   ESC TO PAUSE")
            self._button(self.height / 2 + 74, "SETTINGS", "settings", narrow=True)
            self._button(self.height / 2 + 126, "QUIT", "quit", narrow=True)
        elif state is GameState.PAUSED:
            self._panel("FLIGHT PAUSED", "Stars keep moving. Run clock is frozen.")
            start_y = self.height / 2 - 50
            for index, (label, command) in enumerate(
                (("RESUME", "resume"), ("SETTINGS", "settings"), ("EXIT FULLSCREEN", "windowed"), ("RESTART", "restart"), ("QUIT", "quit"))
            ):
                self._button(start_y + index * 48, label, command, narrow=True)
        elif state is GameState.SETTINGS:
            self._panel("SETTINGS", "Settings window active.")
        elif state is GameState.GAME_OVER and snapshot.show_game_over:
            new_best = "  •  NEW BEST" if snapshot.new_best else ""
            self._panel("MISSION LOST", f"SCORE {snapshot.score:05d}{new_best}\nBEST  {snapshot.best_score:05d}")
            self._button(self.height / 2 + 62, "RESTART  [R]", "restart")
            self._button(self.height / 2 + 116, "SETTINGS", "settings", narrow=True)
            self._button(self.height / 2 + 168, "QUIT", "quit", narrow=True)

    def _panel(self, title: str, subtitle: str) -> None:
        width = min(720, self.width - 40)
        height = min(380, self.height - 40)
        left = (self.width - width) / 2
        top = (self.height - height) / 2
        self.canvas.create_rectangle(
            left,
            top,
            left + width,
            top + height,
            fill=self.theme.panel,
            outline=self.theme.accent,
            width=2,
            stipple="gray75",
            tags=("overlay",),
        )
        self.canvas.create_text(
            self.width / 2,
            top + 54,
            text=title,
            fill=self.theme.primary,
            font=self._title_font,
            tags=("overlay",),
        )
        self.canvas.create_text(
            self.width / 2,
            top + 112,
            text=subtitle,
            justify="center",
            fill=self.theme.accent,
            font=self._small_font,
            tags=("overlay",),
        )

    def _button(self, y: float, label: str, command: str, narrow: bool = False) -> None:
        width = 260 if narrow else 390
        height = 38
        left = self.width / 2 - width / 2
        right = self.width / 2 + width / 2
        self.canvas.create_rectangle(
            left,
            y,
            right,
            y + height,
            fill=self.theme.background,
            outline=self.theme.muted,
            width=1,
            tags=("overlay",),
        )
        self.canvas.create_text(
            self.width / 2,
            y + height / 2,
            text=label,
            fill=self.theme.primary,
            font=self._small_font,
            tags=("overlay",),
        )
        self._buttons.append(((left, y, right, y + height), command))

    def _rebuild_decorations(self) -> None:
        self.canvas.delete("decor")
        self.canvas.delete("scanline")
        if self.theme.id is ThemeId.DEEP_SPACE_HUD:
            pad = 10
            segment = min(170, self.width / 5)
            for coords in (
                (pad, pad, pad + segment, pad),
                (self.width - pad - segment, pad, self.width - pad, pad),
                (pad, self.height - pad, pad + segment, self.height - pad),
                (self.width - pad - segment, self.height - pad, self.width - pad, self.height - pad),
            ):
                self.canvas.create_line(*coords, fill=self.theme.muted, tags=("decor",))
        if self.config.display.scanlines:
            for y in range(4, self.height, 8):
                self.canvas.create_line(0, y, self.width, y, fill=self.theme.panel, tags=("scanline",))
            self.canvas.tag_lower("scanline")
