from __future__ import annotations

import copy
import tkinter as tk
from tkinter import messagebox, ttk
from typing import Callable

from .config import AppConfig, apply_preset
from .themes import ThemeId, ThemeRegistry


class SettingsWindow:
    def __init__(
        self,
        parent: tk.Misc,
        config: AppConfig,
        on_preview: Callable[[AppConfig], None],
        on_apply: Callable[[AppConfig], None],
        on_cancel: Callable[[AppConfig], None],
    ) -> None:
        self.original = config.clone()
        self.on_preview = on_preview
        self.on_apply = on_apply
        self.on_cancel = on_cancel
        self.window = tk.Toplevel(parent)
        self.window.title("ASCII Rocket — Settings")
        self.window.geometry("860x680")
        self.window.minsize(760, 600)
        self.window.transient(parent)
        self.window.protocol("WM_DELETE_WINDOW", self.cancel)
        self.window.bind("<Escape>", lambda _event: self.cancel())
        self._closing = False
        self._loading = True
        self.vars: dict[str, tk.Variable] = {}
        self.binding_buttons: dict[tuple[str, int], ttk.Button] = {}
        self.bindings = copy.deepcopy(config.controls.bindings)
        self._capturing: tuple[str, int] | None = None
        self._build_style(config)
        self._build(config)
        self._load(config)
        self._loading = False
        self.window.grab_set()
        self.window.focus_force()

    def _build_style(self, config: AppConfig) -> None:
        theme = ThemeRegistry.get(config.display.theme, config.display.color_overrides)
        self.window.configure(background=theme.panel)
        style = ttk.Style(self.window)
        style.configure("Rocket.TFrame", background=theme.panel)
        style.configure("Rocket.TLabel", background=theme.panel, foreground=theme.primary)
        style.configure("Rocket.TCheckbutton", background=theme.panel, foreground=theme.primary)
        style.configure("Rocket.TButton", padding=(12, 7))
        style.configure("Rocket.TLabelframe", background=theme.panel, foreground=theme.accent)
        style.configure("Rocket.TLabelframe.Label", background=theme.panel, foreground=theme.accent)

    def _build(self, config: AppConfig) -> None:
        outer = ttk.Frame(self.window, padding=14, style="Rocket.TFrame")
        outer.pack(fill="both", expand=True)
        title = ttk.Label(outer, text="FLIGHT SYSTEM SETTINGS", style="Rocket.TLabel", font=("Consolas", 17, "bold"))
        title.pack(anchor="w", pady=(0, 10))
        self.notebook = ttk.Notebook(outer)
        self.notebook.pack(fill="both", expand=True)
        self.pages: dict[str, ttk.Frame] = {}
        for name in ("Appearance", "Gameplay", "Audio", "Controls", "System"):
            page = ttk.Frame(self.notebook, padding=16, style="Rocket.TFrame")
            self.notebook.add(page, text=name)
            self.pages[name] = page
        self._build_appearance(self.pages["Appearance"])
        self._build_gameplay(self.pages["Gameplay"])
        self._build_audio(self.pages["Audio"])
        self._build_controls(self.pages["Controls"])
        self._build_system(self.pages["System"])

        footer = ttk.Frame(outer, style="Rocket.TFrame")
        footer.pack(fill="x", pady=(12, 0))
        ttk.Button(footer, text="Reset Page", command=self.reset_page, style="Rocket.TButton").pack(side="left")
        ttk.Button(footer, text="Reset All", command=self.reset_all, style="Rocket.TButton").pack(side="left", padx=8)
        ttk.Button(footer, text="Cancel", command=self.cancel, style="Rocket.TButton").pack(side="right")
        ttk.Button(footer, text="Apply", command=self.apply, style="Rocket.TButton").pack(side="right", padx=8)

    def _build_appearance(self, page: ttk.Frame) -> None:
        self._combo(page, "Theme", "display.theme", [theme.id.value for theme in ThemeRegistry.all()])
        self._entry(page, "Font family", "display.font_family")
        self._spin(page, "Font size", "display.font_size", 8, 36)
        self._spin(page, "Star count", "display.star_count", 0, 500)
        self._check(page, "Text glow", "display.glow")
        self._check(page, "Scanlines", "display.scanlines")
        colors = ttk.LabelFrame(page, text="Color overrides (#RRGGBB, blank = theme default)", padding=10, style="Rocket.TLabelframe")
        colors.pack(fill="x", pady=12)
        for name in ("background", "primary", "accent", "hazard", "muted", "panel"):
            self._entry(colors, name.title(), f"color.{name}", compact=True)
        for key, variable in self.vars.items():
            if key.startswith("display.") or key.startswith("color."):
                if key != "display.theme":
                    variable.trace_add("write", self._appearance_changed)
        self.vars["display.theme"].trace_add("write", self._theme_changed)

    def _build_gameplay(self, page: ttk.Frame) -> None:
        self._combo(page, "Preset", "gameplay.preset", ["easy", "normal", "hard", "custom"])
        fields = (
            ("Rocket speed (px/s)", "gameplay.rocket_speed", 100, 700),
            ("Launch speed (px/s)", "gameplay.launch_speed", 80, 500),
            ("Flight target (%)", "gameplay.flight_target", 30, 75),
            ("Asteroid speed (px/s)", "gameplay.asteroid_speed", 60, 500),
            ("Initial spawn interval", "gameplay.initial_spawn_interval", 0.30, 4.0),
            ("Minimum spawn interval", "gameplay.minimum_spawn_interval", 0.15, 4.0),
            ("Difficulty step (s)", "gameplay.difficulty_step", 5, 120),
            ("Initial live cap", "gameplay.initial_live_cap", 1, 30),
            ("Maximum live cap", "gameplay.maximum_live_cap", 1, 30),
            ("Speed growth", "gameplay.speed_growth", 1.0, 1.25),
            ("Interval decay", "gameplay.interval_decay", 0.70, 1.0),
            ("Large weight start (%)", "gameplay.large_weight_start", 0, 100),
            ("Large weight step (%)", "gameplay.large_weight_step", 0, 25),
            ("Large weight cap (%)", "gameplay.large_weight_cap", 0, 100),
            ("Collision forgiveness (%)", "gameplay.collision_forgiveness", 0, 40),
        )
        grid = ttk.Frame(page, style="Rocket.TFrame")
        grid.pack(fill="both", expand=True, pady=8)
        for index, (label, key, minimum, maximum) in enumerate(fields):
            self._entry_grid(grid, label, key, index, minimum, maximum)
        self.vars["gameplay.preset"].trace_add("write", self._preset_changed)
        for _label, key, _minimum, _maximum in fields:
            self.vars[key].trace_add("write", self._gameplay_changed)

    def _build_audio(self, page: ttk.Frame) -> None:
        self._check(page, "Enable sound", "audio.enabled")
        self._scale(page, "Master volume", "audio.master_volume")
        for effect in ("launch", "menu", "collision", "restart"):
            self._scale(page, f"{effect.title()} volume", f"audio.{effect}")

    def _build_controls(self, page: ttk.Frame) -> None:
        ttk.Label(page, text="Click binding, then press replacement key. Escape remains pause fallback.", style="Rocket.TLabel").pack(anchor="w", pady=(0, 12))
        grid = ttk.Frame(page, style="Rocket.TFrame")
        grid.pack(fill="x")
        for row, action in enumerate(("up", "down", "left", "right", "pause", "restart", "fullscreen")):
            ttk.Label(grid, text=action.title(), style="Rocket.TLabel", width=16).grid(row=row, column=0, sticky="w", padx=4, pady=6)
            slots = 2 if action in {"up", "down", "left", "right", "pause"} else 1
            for slot in range(slots):
                button = ttk.Button(
                    grid,
                    text="—",
                    command=lambda current_action=action, current_slot=slot: self.capture_binding(current_action, current_slot),
                    width=16,
                )
                button.grid(row=row, column=slot + 1, padx=5, pady=6)
                self.binding_buttons[(action, slot)] = button
                if action == "pause" and slot == 0:
                    button.configure(state="disabled")

    def _build_system(self, page: ttk.Frame) -> None:
        self._check(page, "Borderless fullscreen", "display.fullscreen")
        self._combo(page, "Target FPS", "display.target_fps", ["30", "60", "120"])
        self._entry(page, "Deterministic seed (blank = random)", "gameplay.seed")

    def _label_row(self, page: ttk.Frame, label: str) -> ttk.Frame:
        row = ttk.Frame(page, style="Rocket.TFrame")
        row.pack(fill="x", pady=4)
        ttk.Label(row, text=label, style="Rocket.TLabel", width=30).pack(side="left")
        return row

    def _entry(self, page: ttk.Frame, label: str, key: str, compact: bool = False) -> None:
        variable = tk.StringVar(self.window)
        self.vars[key] = variable
        row = self._label_row(page, label)
        ttk.Entry(row, textvariable=variable, width=22 if compact else 34).pack(side="left", fill="x", expand=True)

    def _spin(self, page: ttk.Frame, label: str, key: str, minimum: int, maximum: int) -> None:
        variable = tk.IntVar(self.window)
        self.vars[key] = variable
        row = self._label_row(page, label)
        ttk.Spinbox(row, textvariable=variable, from_=minimum, to=maximum, width=12).pack(side="left")

    def _combo(self, page: ttk.Frame, label: str, key: str, values: list[str]) -> None:
        variable = tk.StringVar(self.window)
        self.vars[key] = variable
        row = self._label_row(page, label)
        ttk.Combobox(row, textvariable=variable, values=values, state="readonly", width=28).pack(side="left")

    def _check(self, page: ttk.Frame, label: str, key: str) -> None:
        variable = tk.BooleanVar(self.window)
        self.vars[key] = variable
        ttk.Checkbutton(page, text=label, variable=variable, style="Rocket.TCheckbutton").pack(anchor="w", pady=5)

    def _scale(self, page: ttk.Frame, label: str, key: str) -> None:
        variable = tk.IntVar(self.window)
        self.vars[key] = variable
        row = self._label_row(page, label)
        ttk.Scale(row, variable=variable, from_=0, to=100, orient="horizontal").pack(side="left", fill="x", expand=True)
        ttk.Label(row, textvariable=variable, style="Rocket.TLabel", width=4).pack(side="left", padx=8)

    def _entry_grid(
        self, page: ttk.Frame, label: str, key: str, index: int, minimum: float, maximum: float
    ) -> None:
        variable = tk.StringVar(self.window)
        self.vars[key] = variable
        column_group = index % 2
        row = index // 2
        base = column_group * 2
        ttk.Label(page, text=label, style="Rocket.TLabel").grid(row=row, column=base, sticky="w", padx=(0, 7), pady=4)
        entry = ttk.Entry(page, textvariable=variable, width=12)
        entry.grid(row=row, column=base + 1, sticky="ew", padx=(0, 18), pady=4)
        entry._rocket_range = (minimum, maximum)  # type: ignore[attr-defined]
        page.columnconfigure(base + 1, weight=1)

    def _load(self, config: AppConfig) -> None:
        display = config.display
        gameplay = config.gameplay
        audio = config.audio
        values: dict[str, object] = {
            "display.theme": display.theme or ThemeId.DEEP_SPACE_HUD.value,
            "display.font_family": display.font_family,
            "display.font_size": display.font_size,
            "display.star_count": display.star_count,
            "display.glow": display.glow,
            "display.scanlines": display.scanlines,
            "display.fullscreen": display.fullscreen,
            "display.target_fps": str(display.target_fps),
            "gameplay.preset": gameplay.preset,
            "gameplay.rocket_speed": gameplay.rocket_speed,
            "gameplay.launch_speed": gameplay.launch_speed,
            "gameplay.flight_target": gameplay.flight_target * 100,
            "gameplay.asteroid_speed": gameplay.asteroid_speed,
            "gameplay.initial_spawn_interval": gameplay.initial_spawn_interval,
            "gameplay.minimum_spawn_interval": gameplay.minimum_spawn_interval,
            "gameplay.difficulty_step": gameplay.difficulty_step,
            "gameplay.initial_live_cap": gameplay.initial_live_cap,
            "gameplay.maximum_live_cap": gameplay.maximum_live_cap,
            "gameplay.speed_growth": gameplay.speed_growth,
            "gameplay.interval_decay": gameplay.interval_decay,
            "gameplay.large_weight_start": gameplay.large_weight_start * 100,
            "gameplay.large_weight_step": gameplay.large_weight_step * 100,
            "gameplay.large_weight_cap": gameplay.large_weight_cap * 100,
            "gameplay.collision_forgiveness": gameplay.collision_forgiveness * 100,
            "gameplay.seed": "" if gameplay.seed is None else str(gameplay.seed),
            "audio.enabled": audio.enabled,
            "audio.master_volume": audio.master_volume,
        }
        values.update({f"color.{name}": display.color_overrides.get(name, "") for name in ("background", "primary", "accent", "hazard", "muted", "panel")})
        values.update({f"audio.{name}": value for name, value in audio.effect_volumes.items()})
        for key, value in values.items():
            self.vars[key].set(value)
        self.bindings = copy.deepcopy(config.controls.bindings)
        self._refresh_binding_buttons()

    def _collect(self) -> AppConfig:
        candidate = self.original.clone()
        display = candidate.display
        gameplay = candidate.gameplay
        audio = candidate.audio
        display.theme = str(self.vars["display.theme"].get())
        display.font_family = str(self.vars["display.font_family"].get()).strip()
        display.font_size = self._number("display.font_size", 8, 36, integer=True)
        display.star_count = self._number("display.star_count", 0, 500, integer=True)
        display.glow = bool(self.vars["display.glow"].get())
        display.scanlines = bool(self.vars["display.scanlines"].get())
        display.fullscreen = bool(self.vars["display.fullscreen"].get())
        display.target_fps = self._number("display.target_fps", 30, 120, integer=True)
        if display.target_fps not in {30, 60, 120}:
            raise ValueError("Target FPS must be 30, 60, or 120")
        display.color_overrides = {}
        for name in ("background", "primary", "accent", "hazard", "muted", "panel"):
            value = str(self.vars[f"color.{name}"].get()).strip()
            if value:
                if not ThemeRegistry.is_color(value):
                    raise ValueError(f"{name.title()} color must use #RRGGBB")
                display.color_overrides[name] = value.upper()

        gameplay.preset = str(self.vars["gameplay.preset"].get())
        gameplay.rocket_speed = self._number("gameplay.rocket_speed", 100, 700)
        gameplay.launch_speed = self._number("gameplay.launch_speed", 80, 500)
        gameplay.flight_target = self._number("gameplay.flight_target", 30, 75) / 100
        gameplay.asteroid_speed = self._number("gameplay.asteroid_speed", 60, 500)
        gameplay.initial_spawn_interval = self._number("gameplay.initial_spawn_interval", 0.30, 4.0)
        gameplay.minimum_spawn_interval = self._number("gameplay.minimum_spawn_interval", 0.15, gameplay.initial_spawn_interval)
        gameplay.difficulty_step = self._number("gameplay.difficulty_step", 5, 120)
        gameplay.initial_live_cap = self._number("gameplay.initial_live_cap", 1, 30, integer=True)
        gameplay.maximum_live_cap = self._number("gameplay.maximum_live_cap", gameplay.initial_live_cap, 30, integer=True)
        gameplay.speed_growth = self._number("gameplay.speed_growth", 1.0, 1.25)
        gameplay.interval_decay = self._number("gameplay.interval_decay", 0.70, 1.0)
        gameplay.large_weight_start = self._number("gameplay.large_weight_start", 0, 100) / 100
        gameplay.large_weight_step = self._number("gameplay.large_weight_step", 0, 25) / 100
        gameplay.large_weight_cap = self._number("gameplay.large_weight_cap", gameplay.large_weight_start * 100, 100) / 100
        gameplay.collision_forgiveness = self._number("gameplay.collision_forgiveness", 0, 40) / 100
        seed = str(self.vars["gameplay.seed"].get()).strip()
        if seed:
            try:
                gameplay.seed = int(seed)
            except ValueError as exc:
                raise ValueError("Seed must be a signed integer or blank") from exc
            if not -(2**31) <= gameplay.seed <= 2**31 - 1:
                raise ValueError("Seed must fit a signed 32-bit integer")
        else:
            gameplay.seed = None

        audio.enabled = bool(self.vars["audio.enabled"].get())
        audio.master_volume = self._number("audio.master_volume", 0, 100, integer=True)
        audio.effect_volumes = {
            name: self._number(f"audio.{name}", 0, 100, integer=True)
            for name in ("launch", "menu", "collision", "restart")
        }
        candidate.controls.bindings = copy.deepcopy(self.bindings)
        conflicts = candidate.controls.conflicts()
        if conflicts:
            key, actions = next(iter(conflicts.items()))
            raise ValueError(f"Key {key} is assigned to: {', '.join(actions)}")
        if "Escape" not in candidate.controls.bindings["pause"]:
            candidate.controls.bindings["pause"].insert(0, "Escape")
        candidate.validate()
        return candidate

    def _number(self, key: str, minimum: float, maximum: float, integer: bool = False):
        try:
            value = float(self.vars[key].get())
        except (TypeError, ValueError, tk.TclError) as exc:
            raise ValueError(f"{key.split('.')[-1].replace('_', ' ').title()} must be numeric") from exc
        if not minimum <= value <= maximum:
            raise ValueError(f"{key.split('.')[-1].replace('_', ' ').title()} must be {minimum}–{maximum}")
        return int(value) if integer else value

    def _appearance_changed(self, *_args) -> None:
        if self._loading or self._closing:
            return
        try:
            candidate = self._collect()
        except (ValueError, tk.TclError):
            return
        self.on_preview(candidate)

    def _theme_changed(self, *_args) -> None:
        if self._loading or self._closing:
            return
        theme = ThemeRegistry.get(str(self.vars["display.theme"].get()))
        self.vars["display.scanlines"].set(theme.scanlines_default)

    def _preset_changed(self, *_args) -> None:
        if self._loading:
            return
        preset = str(self.vars["gameplay.preset"].get())
        if preset not in {"easy", "normal", "hard"}:
            return
        candidate = self.original.clone()
        apply_preset(candidate.gameplay, preset)
        self._loading = True
        self._load_gameplay(candidate)
        self._loading = False

    def _gameplay_changed(self, *_args) -> None:
        if self._loading:
            return
        if self.vars["gameplay.preset"].get() in {"easy", "normal", "hard"}:
            self.vars["gameplay.preset"].set("custom")

    def _load_gameplay(self, config: AppConfig) -> None:
        gameplay = config.gameplay
        values = {
            "gameplay.preset": gameplay.preset,
            "gameplay.rocket_speed": gameplay.rocket_speed,
            "gameplay.launch_speed": gameplay.launch_speed,
            "gameplay.flight_target": gameplay.flight_target * 100,
            "gameplay.asteroid_speed": gameplay.asteroid_speed,
            "gameplay.initial_spawn_interval": gameplay.initial_spawn_interval,
            "gameplay.minimum_spawn_interval": gameplay.minimum_spawn_interval,
            "gameplay.difficulty_step": gameplay.difficulty_step,
            "gameplay.initial_live_cap": gameplay.initial_live_cap,
            "gameplay.maximum_live_cap": gameplay.maximum_live_cap,
            "gameplay.speed_growth": gameplay.speed_growth,
            "gameplay.interval_decay": gameplay.interval_decay,
            "gameplay.large_weight_start": gameplay.large_weight_start * 100,
            "gameplay.large_weight_step": gameplay.large_weight_step * 100,
            "gameplay.large_weight_cap": gameplay.large_weight_cap * 100,
            "gameplay.collision_forgiveness": gameplay.collision_forgiveness * 100,
        }
        for key, value in values.items():
            self.vars[key].set(value)

    def capture_binding(self, action: str, slot: int) -> None:
        if action == "pause" and slot == 0:
            return
        if self._capturing is not None:
            self._refresh_binding_buttons()
        self._capturing = (action, slot)
        self.binding_buttons[(action, slot)].configure(text="Press key…")
        self.window.bind("<KeyPress>", self._capture_key)
        self.window.focus_force()

    def _capture_key(self, event: tk.Event) -> str:
        if self._capturing is None:
            return "break"
        action, slot = self._capturing
        key = str(event.keysym)
        normalized = key.lower() if len(key) == 1 else key
        for other_action, keys in self.bindings.items():
            for other_slot, other_key in enumerate(keys):
                if (other_action, other_slot) == (action, slot):
                    continue
                compare = other_key.lower() if len(other_key) == 1 else other_key
                if compare == normalized:
                    messagebox.showerror("Binding conflict", f"{key} is already bound to {other_action}.", parent=self.window)
                    return "break"
        keys = self.bindings.setdefault(action, [])
        while len(keys) <= slot:
            keys.append("")
        keys[slot] = key
        self.bindings[action] = [item for item in keys if item]
        if action == "pause":
            self.bindings[action] = [
                "Escape",
                *[item for item in self.bindings[action] if item != "Escape"],
            ]
        self._capturing = None
        self.window.unbind("<KeyPress>")
        self._refresh_binding_buttons()
        return "break"

    def _refresh_binding_buttons(self) -> None:
        for (action, slot), button in self.binding_buttons.items():
            keys = self.bindings.get(action, [])
            button.configure(text=keys[slot] if slot < len(keys) else "—")

    def reset_page(self) -> None:
        defaults = AppConfig()
        defaults.display.theme = ThemeId.DEEP_SPACE_HUD.value
        name = self.notebook.tab(self.notebook.select(), "text")
        candidate = self._safe_current()
        if name == "Appearance":
            candidate.display = defaults.display
        elif name == "Gameplay":
            candidate.gameplay = defaults.gameplay
        elif name == "Audio":
            candidate.audio = defaults.audio
        elif name == "Controls":
            candidate.controls = defaults.controls
        elif name == "System":
            candidate.display.fullscreen = defaults.display.fullscreen
            candidate.display.target_fps = defaults.display.target_fps
            candidate.gameplay.seed = defaults.gameplay.seed
        self._loading = True
        self._load(candidate)
        self._loading = False
        self.on_preview(candidate)

    def reset_all(self) -> None:
        defaults = AppConfig()
        defaults.display.theme = ThemeId.DEEP_SPACE_HUD.value
        self._loading = True
        self._load(defaults)
        self._loading = False
        self.on_preview(defaults)

    def _safe_current(self) -> AppConfig:
        try:
            return self._collect()
        except ValueError:
            return self.original.clone()

    def apply(self) -> None:
        try:
            candidate = self._collect()
        except ValueError as exc:
            messagebox.showerror("Invalid setting", str(exc), parent=self.window)
            return
        self._closing = True
        self.window.grab_release()
        self.on_apply(candidate)
        self.window.destroy()

    def cancel(self) -> None:
        if self._closing:
            return
        self._closing = True
        self.window.grab_release()
        self.on_cancel(self.original)
        self.window.destroy()
