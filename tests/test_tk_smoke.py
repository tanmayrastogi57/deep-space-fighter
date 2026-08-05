from __future__ import annotations

import tkinter as tk
import unittest

from ascii_rocket.config import AppConfig
from ascii_rocket.models import FrameSnapshot, RenderEntity
from ascii_rocket.renderer import Renderer


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


if __name__ == "__main__":
    unittest.main()

