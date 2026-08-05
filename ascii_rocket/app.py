from __future__ import annotations

import logging
import os
import tkinter as tk
from logging.handlers import RotatingFileHandler
from pathlib import Path
from tkinter import messagebox

from .audio import AudioManager
from .config import AppConfig, HighScoreStore
from .controller import GameController
from .input import InputManager
from .renderer import Renderer
from .settings_ui import SettingsWindow
from .state import GameState
from .themes import ThemeRegistry


class App:
    def __init__(self) -> None:
        self.logger = _configure_logging()
        self.config = AppConfig.load()
        self.root = tk.Tk()
        self.root.title("ASCII Rocket")
        self.root.configure(background="black")
        self.root.minsize(800, 600)
        self.canvas = tk.Canvas(self.root, background="black", highlightthickness=0, takefocus=True)
        self.canvas.pack(fill="both", expand=True)
        self.renderer = Renderer(self.root, self.canvas, self.config)
        self.input = InputManager(self.config.controls)
        self.audio = AudioManager(self.config.audio, self.logger)
        self.high_scores = HighScoreStore()
        self.controller = GameController(
            self.config,
            self.renderer,
            self.root,
            self.input,
            self.audio,
            self.high_scores,
        )
        self.settings_window: SettingsWindow | None = None
        self._fullscreen = False
        self._closing = False
        self._resize_after_id: str | None = None
        self._bind_events()
        self._set_fullscreen(self.config.display.fullscreen, save=False)
        self.root.update_idletasks()
        self.renderer.resize(self.canvas.winfo_width(), self.canvas.winfo_height())
        self.controller.set_viewport(self.canvas.winfo_width(), self.canvas.winfo_height())
        if self.config.load_warnings:
            self.root.after(100, self._show_load_warning)

    def run(self) -> None:
        self.controller.start()
        self.canvas.focus_set()
        self.root.mainloop()

    def _bind_events(self) -> None:
        self.root.bind("<KeyPress>", self._on_key_press)
        self.root.bind("<KeyRelease>", self._on_key_release)
        self.root.bind("<FocusOut>", lambda _event: self.input.clear())
        self.root.bind("<Configure>", self._on_configure)
        self.canvas.bind("<Button-1>", self._on_click)
        self.root.protocol("WM_DELETE_WINDOW", self.shutdown)

    def _on_key_press(self, event: tk.Event) -> str | None:
        if self.settings_window is not None:
            return None
        key = str(event.keysym)
        self.input.press(key)
        if key == "F3":
            self.renderer.toggle_fps()
            return "break"
        if self.input.key_matches(key, "fullscreen"):
            self._set_fullscreen(not self._fullscreen)
            return "break"
        if self.controller.state is GameState.READY and key in {"space", "Return", "KP_Enter"}:
            self.controller.start_launch()
            return "break"
        if self.controller.state in {GameState.READY, GameState.LAUNCHING, GameState.PLAYING} and self.input.key_matches(key, "pause"):
            self.controller.pause()
            return "break"
        if self.controller.state is GameState.PAUSED and self.input.key_matches(key, "pause"):
            self.controller.resume()
            return "break"
        if self.controller.state is GameState.GAME_OVER and self.input.key_matches(key, "restart"):
            self.controller.restart()
            return "break"
        return None

    def _on_key_release(self, event: tk.Event) -> None:
        self.input.release(str(event.keysym))

    def _on_click(self, event: tk.Event) -> None:
        command = self.renderer.hit_test(float(event.x), float(event.y))
        if command:
            self.audio.play("menu")
            self._activate(command)

    def _activate(self, command: str) -> None:
        if command.startswith("theme:"):
            theme_id = command.split(":", 1)[1]
            theme = ThemeRegistry.get(theme_id)
            self.config.display.theme = theme_id
            self.config.display.scanlines = theme.scanlines_default
            self._apply_runtime_config(self.config, save=True)
            self.controller.theme_selected()
        elif command == "resume":
            self.controller.resume()
        elif command == "settings":
            self._open_settings()
        elif command == "windowed":
            self._set_fullscreen(False)
        elif command == "restart":
            self.controller.restart()
        elif command == "quit":
            self.shutdown()

    def _open_settings(self) -> None:
        if self.settings_window is not None:
            return
        self.controller.open_settings()
        self.settings_window = SettingsWindow(
            self.root,
            self.config,
            self._preview_config,
            self._apply_settings,
            self._cancel_settings,
        )

    def _preview_config(self, candidate: AppConfig) -> None:
        self.renderer.update_config(candidate)
        self.controller.update_config(candidate)

    def _apply_settings(self, candidate: AppConfig) -> None:
        self.settings_window = None
        self._apply_runtime_config(candidate, save=True)
        self._set_fullscreen(candidate.display.fullscreen, save=False)
        self.controller.close_settings()
        self.canvas.focus_set()

    def _cancel_settings(self, original: AppConfig) -> None:
        self.settings_window = None
        self._apply_runtime_config(original, save=False)
        self._set_fullscreen(original.display.fullscreen, save=False)
        self.controller.close_settings()
        self.canvas.focus_set()

    def _apply_runtime_config(self, config: AppConfig, save: bool) -> None:
        self.config = config
        self.renderer.update_config(config)
        self.controller.update_config(config)
        self.audio.apply_volume(config.audio)
        if save:
            try:
                config.save_atomic()
            except OSError as exc:
                self.logger.warning("Settings could not be saved: %s", exc)
                messagebox.showwarning("Settings not saved", str(exc), parent=self.root)

    def _set_fullscreen(self, enabled: bool, save: bool = True) -> None:
        self._fullscreen = bool(enabled)
        self.config.display.fullscreen = self._fullscreen
        self.root.attributes("-fullscreen", self._fullscreen)
        if not self._fullscreen:
            try:
                self.root.state("zoomed")
            except tk.TclError:
                self.root.geometry("1280x800")
        if save and self.config.display.theme is not None:
            try:
                self.config.save_atomic()
            except OSError as exc:
                self.logger.warning("Display mode could not be saved: %s", exc)

    def _on_configure(self, event: tk.Event) -> None:
        if event.widget is not self.root or self._closing:
            return
        if self._resize_after_id is not None:
            self.root.after_cancel(self._resize_after_id)
        self._resize_after_id = self.root.after(40, self._apply_resize)

    def _apply_resize(self) -> None:
        self._resize_after_id = None
        width = self.canvas.winfo_width()
        height = self.canvas.winfo_height()
        self.renderer.resize(width, height)
        self.controller.set_viewport(width, height)

    def _show_load_warning(self) -> None:
        messagebox.showwarning(
            "Settings recovered",
            "Some saved settings were invalid and safe defaults were used.\n\n"
            + "\n".join(self.config.load_warnings[:5]),
            parent=self.root,
        )

    def shutdown(self) -> None:
        if self._closing:
            return
        self._closing = True
        if self._resize_after_id is not None:
            try:
                self.root.after_cancel(self._resize_after_id)
            except tk.TclError:
                pass
            self._resize_after_id = None
        try:
            self.controller.shutdown()
        finally:
            self.root.destroy()


def _configure_logging() -> logging.Logger:
    base = os.getenv("LOCALAPPDATA")
    directory = Path(base) / "AsciiRocket" if base else AppConfig.data_directory()
    directory.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("ascii_rocket")
    logger.setLevel(logging.INFO)
    if not logger.handlers:
        handler = RotatingFileHandler(
            directory / "ascii_rocket.log",
            maxBytes=1_000_000,
            backupCount=3,
            encoding="utf-8",
        )
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s"))
        logger.addHandler(handler)
    return logger
