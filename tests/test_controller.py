from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from ascii_rocket.config import AppConfig, HighScoreStore
from ascii_rocket.controller import GameController
from ascii_rocket.input import InputManager
from ascii_rocket.models import FontMetrics
from ascii_rocket.state import GameState


class FakeRenderer:
    def __init__(self) -> None:
        self.snapshots = []

    def font_metrics(self) -> FontMetrics:
        return FontMetrics(10, 20)

    def render(self, snapshot) -> None:
        self.snapshots.append(snapshot)


class FakeScheduler:
    def __init__(self) -> None:
        self.callbacks = {}
        self.next_id = 1
        self.cancelled = []

    def after(self, _milliseconds, callback):
        callback_id = self.next_id
        self.next_id += 1
        self.callbacks[callback_id] = callback
        return callback_id

    def after_cancel(self, callback_id):
        self.cancelled.append(callback_id)
        self.callbacks.pop(callback_id, None)


class FakeAudio:
    def __init__(self) -> None:
        self.played = []
        self.closed = False

    def play(self, effect):
        self.played.append(effect)

    def shutdown(self):
        self.closed = True


class ControllerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.config = AppConfig()
        self.config.display.theme = "deep-space-hud"
        self.config.display.star_count = 0
        self.renderer = FakeRenderer()
        self.scheduler = FakeScheduler()
        self.audio = FakeAudio()
        self.clock_value = 0.0
        self.controller = GameController(
            self.config,
            self.renderer,
            self.scheduler,
            InputManager(self.config.controls),
            self.audio,
            HighScoreStore(Path(self.temp.name) / "score.json"),
            clock=lambda: self.clock_value,
        )
        self.controller.set_viewport(800, 600)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_start_schedules_exactly_one_loop(self) -> None:
        self.controller.start()
        self.controller.start()
        self.assertEqual(self.controller.state, GameState.READY)
        self.assertEqual(len(self.scheduler.callbacks), 1)

    def test_launch_enables_play_only_at_target(self) -> None:
        self.controller.start()
        self.controller.start_launch()
        self.assertEqual(self.controller.state, GameState.LAUNCHING)
        for _ in range(80):
            self.clock_value += 0.05
            self.controller.tick(self.clock_value)
            if self.controller.state is GameState.PLAYING:
                break
        self.assertEqual(self.controller.state, GameState.PLAYING)
        self.assertIn("launch", self.audio.played)

    def test_pause_freezes_score(self) -> None:
        self.controller.start()
        self.controller.transition(GameState.LAUNCHING)
        self.controller.transition(GameState.PLAYING)
        self.clock_value = 1.2
        self.controller.tick(self.clock_value)
        before = self.controller.score.active_seconds
        self.controller.pause()
        self.clock_value += 1.0
        self.controller.tick(self.clock_value)
        self.assertEqual(self.controller.score.active_seconds, before)
        self.controller.resume()
        self.assertEqual(self.controller.state, GameState.PLAYING)

    def test_restart_clears_run_without_second_loop(self) -> None:
        self.controller.start()
        self.controller.transition(GameState.LAUNCHING)
        self.controller.transition(GameState.PLAYING)
        self.controller.transition(GameState.GAME_OVER)
        scheduled = self.controller.scheduled_id
        self.controller.restart()
        self.assertEqual(self.controller.state, GameState.READY)
        self.assertEqual(self.controller.score.score, 0)
        self.assertEqual(self.controller.scheduled_id, scheduled)

    def test_shutdown_cancels_callback(self) -> None:
        self.controller.start()
        callback_id = self.controller.scheduled_id
        self.controller.shutdown()
        self.assertEqual(self.controller.state, GameState.EXITING)
        self.assertIn(callback_id, self.scheduler.cancelled)
        self.assertTrue(self.audio.closed)

    def test_illegal_transition_rejected(self) -> None:
        with self.assertRaises(ValueError):
            self.controller.transition(GameState.GAME_OVER)


if __name__ == "__main__":
    unittest.main()

