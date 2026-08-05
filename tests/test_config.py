from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from ascii_rocket.config import AppConfig, HighScoreStore, apply_preset
from ascii_rocket.themes import ThemeId, ThemeRegistry


class ConfigTests(unittest.TestCase):
    def test_round_trip_and_atomic_save(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            config = AppConfig()
            config.display.theme = ThemeId.NEON_ARCADE.value
            config.gameplay.seed = 42
            config.save_atomic(path)
            loaded = AppConfig.load(path)
            self.assertEqual(loaded.display.theme, ThemeId.NEON_ARCADE.value)
            self.assertEqual(loaded.gameplay.seed, 42)
            self.assertFalse(path.with_suffix(".json.tmp").exists())

    def test_corrupt_file_recovers(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            path.write_text("{broken", encoding="utf-8")
            loaded = AppConfig.load(path)
            self.assertIsNone(loaded.display.theme)
            self.assertTrue(loaded.load_warnings)

    def test_validation_clamps_and_resets_conflicting_controls(self) -> None:
        config = AppConfig()
        config.display.font_size = 100
        config.display.target_fps = 77
        config.gameplay.collision_forgiveness = 0.9
        config.controls.bindings["up"] = ["x", "Up"]
        config.controls.bindings["down"] = ["x", "Down"]
        warnings = config.validate()
        self.assertEqual(config.display.font_size, 36)
        self.assertEqual(config.display.target_fps, 60)
        self.assertEqual(config.gameplay.collision_forgiveness, 0.4)
        self.assertEqual(config.controls.bindings["up"], ["w", "Up"])
        self.assertTrue(warnings)

    def test_unknown_fields_are_ignored(self) -> None:
        config = AppConfig.from_dict({"display": {"theme": "terminal-noir", "future": True}, "future": 2})
        self.assertEqual(config.display.theme, "terminal-noir")

    def test_presets_have_distinct_difficulty(self) -> None:
        easy = AppConfig().gameplay
        hard = AppConfig().gameplay
        apply_preset(easy, "easy")
        apply_preset(hard, "hard")
        self.assertLess(easy.asteroid_speed, hard.asteroid_speed)
        self.assertGreater(easy.initial_spawn_interval, hard.initial_spawn_interval)

    def test_high_score_store(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "score.json"
            store = HighScoreStore(path)
            self.assertEqual(store.load(), 0)
            store.save(125)
            self.assertEqual(store.load(), 125)
            path.write_text(json.dumps({"high_score": -9}), encoding="utf-8")
            self.assertEqual(store.load(), 0)

    def test_all_themes_and_overrides(self) -> None:
        self.assertEqual(len(ThemeRegistry.all()), 3)
        theme = ThemeRegistry.get(ThemeId.TERMINAL_NOIR, {"primary": "#ABCDEF", "hazard": "bad"})
        self.assertEqual(theme.primary, "#ABCDEF")
        self.assertNotEqual(theme.hazard, "bad")


if __name__ == "__main__":
    unittest.main()

