from __future__ import annotations

import unittest

from ascii_rocket.collision import CollisionSystem
from ascii_rocket.config import AppConfig
from ascii_rocket.input import InputManager
from ascii_rocket.models import ArtTemplate, Entity, FontMetrics, Viewport
from ascii_rocket.scoring import ScoreManager
from ascii_rocket.spawning import AsteroidSpawner, difficulty_at


class CoreTests(unittest.TestCase):
    def test_score_uses_elapsed_whole_seconds(self) -> None:
        score = ScoreManager()
        score.update(0.999)
        self.assertEqual(score.score, 0)
        score.update(0.001)
        self.assertEqual(score.score, 5)
        score.update(0.999)
        self.assertEqual(score.score, 5)

    def test_diagonal_movement_is_normalized(self) -> None:
        config = AppConfig()
        manager = InputManager(config.controls)
        manager.press("w")
        manager.press("d")
        x, y = manager.pressed_vector()
        self.assertAlmostEqual(x * x + y * y, 1.0)
        self.assertGreater(x, 0)
        self.assertLess(y, 0)

    def test_focus_clear_stops_movement(self) -> None:
        manager = InputManager(AppConfig().controls)
        manager.press("Left")
        manager.clear()
        self.assertEqual(manager.pressed_vector(), (0.0, 0.0))

    def test_rebind_rejects_duplicate(self) -> None:
        manager = InputManager(AppConfig().controls)
        with self.assertRaises(ValueError):
            manager.rebind("restart", "w")

    def test_collision_ignores_spaces(self) -> None:
        metrics = FontMetrics(10, 20)
        first = Entity(1, ArtTemplate(("X ",)), 0, 0)
        second = Entity(2, ArtTemplate((" X",)), 0, 0)
        self.assertFalse(CollisionSystem.collides(first, second, metrics))

    def test_collision_detects_fractional_pixel_overlap(self) -> None:
        metrics = FontMetrics(10, 20)
        first = Entity(1, ArtTemplate(("X",)), 0, 0)
        second = Entity(2, ArtTemplate(("X",)), 9.9, 0)
        self.assertTrue(CollisionSystem.collides(first, second, metrics))

    def test_forgiveness_can_remove_edge_overlap(self) -> None:
        metrics = FontMetrics(10, 20)
        first = Entity(1, ArtTemplate(("X",)), 0, 0)
        second = Entity(2, ArtTemplate(("X",)), 9.0, 0)
        self.assertTrue(CollisionSystem.collides(first, second, metrics, 0.0))
        self.assertFalse(CollisionSystem.collides(first, second, metrics, 0.4))

    def test_difficulty_progression_caps_values(self) -> None:
        settings = AppConfig().gameplay
        difficulty = difficulty_at(1000, settings)
        self.assertEqual(difficulty.live_cap, settings.maximum_live_cap)
        self.assertEqual(difficulty.spawn_interval, settings.minimum_spawn_interval)
        self.assertEqual(difficulty.large_weight, settings.large_weight_cap)

    def test_seeded_spawning_is_reproducible(self) -> None:
        settings = AppConfig().gameplay
        settings.seed = 1234
        metrics = FontMetrics(10, 20)
        viewport = Viewport(800, 600)
        first = AsteroidSpawner(settings)
        second = AsteroidSpawner(settings)
        a = first.update(1.25, 0, 0, viewport, metrics)
        b = second.update(1.25, 0, 0, viewport, metrics)
        self.assertEqual(a, b)
        self.assertEqual(len(a), 1)
        self.assertLess(a[0].y, 0)


if __name__ == "__main__":
    unittest.main()

