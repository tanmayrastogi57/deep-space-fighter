from __future__ import annotations

import tkinter as tk
import time
import unittest

from ascii_rocket.config import AppConfig
from ascii_rocket.models import FrameSnapshot, RenderEntity
from ascii_rocket.renderer import Renderer
from ascii_rocket.settings_ui import SettingsWindow


class TkSmokeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        try:
            cls.root = tk.Tk()
            cls.root.withdraw()
        except tk.TclError as exc:
            raise unittest.SkipTest(f"Tk display unavailable: {exc}")

    @classmethod
    def tearDownClass(cls) -> None:
        cls.root.destroy()

    def test_renderer_handles_resize_and_all_themes(self) -> None:
        canvas = tk.Canvas(self.root, width=800, height=600)
        canvas.pack()
        config = AppConfig()
        config.display.theme = "terminal-noir"
        config.display.star_count = 0
        renderer = Renderer(self.root, canvas, config)
        renderer.resize(1024, 768)
        snapshot = FrameSnapshot(
            "READY",
            RenderEntity(0, " /\\\n/▲\\", 450, 500, "rocket"),
            (),
            (),
            0,
            0,
            0.0,
            0,
            None,
            False,
            60.0,
        )
        renderer.render(snapshot)
        self.assertGreater(renderer.font_metrics().cell_width, 0)
        for theme in ("terminal-noir", "deep-space-hud", "neon-arcade"):
            config.display.theme = theme
            renderer.update_config(config)
            renderer.render(snapshot)
        canvas.destroy()

    def test_steady_state_renderer_meets_frame_budget(self) -> None:
        from ascii_rocket.models import RenderStar

        canvas = tk.Canvas(self.root, width=1920, height=1080)
        canvas.pack()
        config = AppConfig()
        config.display.theme = "deep-space-hud"
        renderer = Renderer(self.root, canvas, config)
        renderer.resize(1920, 1080)
        stars = tuple(
            RenderStar(index, (index * 83) % 1920, (index * 47) % 1080, ".", 0.7)
            for index in range(180)
        )
        snapshot = FrameSnapshot(
            "PLAYING",
            RenderEntity(0, " /\\\n/▲\\", 900, 800, "rocket"),
            (),
            stars,
            0,
            0,
            0.0,
            0,
            None,
            False,
            60.0,
        )
        renderer.render(snapshot)
        started = time.perf_counter()
        for _ in range(60):
            renderer.render(snapshot)
        average_ms = (time.perf_counter() - started) * 1000 / 60
        self.assertLess(average_ms, 10.0)
        canvas.destroy()

    def test_theme_selection_applies_theme_scanline_default(self) -> None:
        config = AppConfig()
        config.display.theme = "deep-space-hud"
        window = SettingsWindow(
            self.root,
            config,
            lambda _candidate: None,
            lambda _candidate: None,
            lambda _candidate: None,
        )
        window.vars["display.theme"].set("terminal-noir")
        self.root.update_idletasks()
        self.assertTrue(window.vars["display.scanlines"].get())
        window.vars["display.theme"].set("neon-arcade")
        self.root.update_idletasks()
        self.assertFalse(window.vars["display.scanlines"].get())
        window.cancel()


if __name__ == "__main__":
    unittest.main()
