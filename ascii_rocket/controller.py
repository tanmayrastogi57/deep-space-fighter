from __future__ import annotations

import random
import time
from typing import Callable, Protocol

from .audio import AudioManager
from .collision import CollisionSystem, entity_bounds
from .config import AppConfig, HighScoreStore
from .input import InputManager
from .models import (
    Asteroid,
    FontMetrics,
    FrameSnapshot,
    RenderEntity,
    RenderStar,
    Rocket,
    ROCKET_TEMPLATE,
    Star,
    Viewport,
)
from .scoring import ScoreManager
from .spawning import AsteroidSpawner, difficulty_at
from .state import GameState, LEGAL_TRANSITIONS
from .themes import ThemeRegistry


class Scheduler(Protocol):
    def after(self, milliseconds: int, callback: Callable[[], None]) -> object: ...
    def after_cancel(self, callback_id: object) -> None: ...


class RenderTarget(Protocol):
    def font_metrics(self) -> FontMetrics: ...
    def render(self, snapshot: FrameSnapshot) -> None: ...


class GameController:
    def __init__(
        self,
        config: AppConfig,
        renderer: RenderTarget,
        scheduler: Scheduler,
        input_manager: InputManager,
        audio: AudioManager,
        high_scores: HighScoreStore,
        clock: Callable[[], float] = time.perf_counter,
    ) -> None:
        self.config = config
        self.renderer = renderer
        self.scheduler = scheduler
        self.input = input_manager
        self.audio = audio
        self.high_scores = high_scores
        self.clock = clock
        self.state = GameState.BOOT
        self.viewport = Viewport(1280, 720)
        self.rocket = Rocket(0, ROCKET_TEMPLATE, 0, 0)
        self.asteroids: list[Asteroid] = []
        self.stars: list[Star] = []
        self.score = ScoreManager()
        self.spawner = AsteroidSpawner(config.gameplay)
        self.best_score = high_scores.load()
        self.explosion_elapsed: float | None = None
        self._new_best = False
        self._resume_state = GameState.PLAYING
        self._settings_return_state = GameState.PAUSED
        self._scheduled_id: object | None = None
        self._last_time: float | None = None
        self._running = False
        self._next_id = 1
        self._star_rng = random.Random(_star_seed(config.gameplay.seed))
        self._fps = 0.0

    @property
    def scheduled_id(self) -> object | None:
        return self._scheduled_id

    def transition(self, new_state: GameState) -> None:
        if new_state == self.state:
            return
        if new_state not in LEGAL_TRANSITIONS[self.state]:
            raise ValueError(f"Illegal state transition: {self.state.name} -> {new_state.name}")
        self.state = new_state
        self.input.clear()

    def start(self) -> None:
        if self._running:
            return
        self._running = True
        self.reset_run()
        self.transition(
            GameState.THEME_SELECT if self.config.display.theme is None else GameState.READY
        )
        self._last_time = self.clock()
        self._schedule_next()

    def tick(self, now: float | None = None) -> FrameSnapshot:
        current = self.clock() if now is None else now
        if self._last_time is None:
            elapsed = 0.0
        else:
            elapsed = max(0.0, min(0.05, current - self._last_time))
        self._last_time = current
        if elapsed > 0:
            current_fps = 1.0 / elapsed
            self._fps = current_fps if self._fps == 0 else self._fps * 0.9 + current_fps * 0.1
        self._update(elapsed)
        snapshot = self.snapshot()
        self.renderer.render(snapshot)
        return snapshot

    def _run_frame(self) -> None:
        self._scheduled_id = None
        if not self._running or self.state is GameState.EXITING:
            return
        self.tick()
        self._schedule_next()

    def _schedule_next(self) -> None:
        if self._scheduled_id is None and self._running and self.state is not GameState.EXITING:
            interval = max(1, round(1000 / self.config.display.target_fps))
            self._scheduled_id = self.scheduler.after(interval, self._run_frame)

    def shutdown(self) -> None:
        if self.state is not GameState.EXITING:
            self.transition(GameState.EXITING)
        self._running = False
        if self._scheduled_id is not None:
            try:
                self.scheduler.after_cancel(self._scheduled_id)
            except Exception:
                pass
            self._scheduled_id = None
        self.audio.shutdown()

    def reset_run(self) -> None:
        self.asteroids.clear()
        self.score.reset()
        self.spawner = AsteroidSpawner(self.config.gameplay)
        self.explosion_elapsed = None
        self._new_best = False
        self.input.clear()
        self._position_rocket_for_ready()
        self._sync_stars(reset=not self.stars)

    def restart(self) -> None:
        if self.state not in {GameState.GAME_OVER, GameState.PAUSED}:
            return
        self.transition(GameState.RESTARTING)
        self.reset_run()
        self.audio.play("restart")
        self.transition(GameState.READY)

    def theme_selected(self) -> None:
        if self.state is GameState.THEME_SELECT:
            self._sync_stars(reset=True)
            self.transition(GameState.READY)

    def start_launch(self) -> None:
        if self.state is GameState.READY:
            self.audio.play("launch")
            self.transition(GameState.LAUNCHING)

    def pause(self) -> None:
        if self.state in {GameState.READY, GameState.LAUNCHING, GameState.PLAYING}:
            self._resume_state = self.state
            self.transition(GameState.PAUSED)

    def resume(self) -> None:
        if self.state is GameState.PAUSED:
            self.transition(self._resume_state)

    def open_settings(self) -> None:
        if self.state in {GameState.READY, GameState.LAUNCHING, GameState.PLAYING}:
            self.pause()
        if self.state in {GameState.PAUSED, GameState.GAME_OVER, GameState.READY}:
            self._settings_return_state = self.state
            self.transition(GameState.SETTINGS)

    def close_settings(self) -> None:
        if self.state is GameState.SETTINGS:
            self.transition(self._settings_return_state)

    def update_config(self, config: AppConfig) -> None:
        self.config = config
        self.input.update_controls(config.controls)
        self.spawner.settings = config.gameplay
        self._star_rng.seed(_star_seed(config.gameplay.seed))
        self._sync_stars(reset=False)
        self._clamp_rocket()

    def set_viewport(self, width: float, height: float) -> None:
        self.viewport = Viewport(max(320.0, width), max(240.0, height))
        self._sync_stars(reset=False)
        if self.state in {GameState.BOOT, GameState.THEME_SELECT, GameState.READY}:
            self._position_rocket_for_ready()
        else:
            self._clamp_rocket()
        metrics = self.renderer.font_metrics()
        self.asteroids = [
            asteroid
            for asteroid in self.asteroids
            if entity_bounds(asteroid, metrics)[2] > 0
            and entity_bounds(asteroid, metrics)[0] < self.viewport.width
        ]

    def snapshot(self) -> FrameSnapshot:
        difficulty = difficulty_at(self.score.active_seconds, self.config.gameplay)
        return FrameSnapshot(
            state_name=self.state.name,
            rocket=RenderEntity(
                self.rocket.id,
                self.rocket.art.text,
                self.rocket.x,
                self.rocket.y,
                "rocket",
            ),
            asteroids=tuple(
                RenderEntity(item.id, item.art.text, item.x, item.y, "asteroid")
                for item in self.asteroids
            ),
            stars=tuple(
                RenderStar(item.id, item.x, item.y, item.symbol, item.intensity)
                for item in self.stars
            ),
            score=self.score.score,
            best_score=self.best_score,
            active_seconds=self.score.active_seconds,
            difficulty_level=difficulty.level,
            explosion_elapsed=self.explosion_elapsed,
            show_game_over=(
                self.state is GameState.GAME_OVER
                and self.explosion_elapsed is not None
                and self.explosion_elapsed >= 0.6
            ),
            fps=self._fps,
            new_best=self._new_best,
        )

    def _update(self, elapsed: float) -> None:
        self._update_stars(elapsed)
        if self.state is GameState.LAUNCHING:
            target = self.viewport.height * self.config.gameplay.flight_target
            self.rocket.y -= self.config.gameplay.launch_speed * elapsed
            if self.rocket.y <= target:
                self.rocket.y = target
                self.score.reset()
                self.transition(GameState.PLAYING)
        elif self.state is GameState.PLAYING:
            self._update_playing(elapsed)
        elif self.state is GameState.GAME_OVER and self.explosion_elapsed is not None:
            self.explosion_elapsed += elapsed

    def _update_playing(self, elapsed: float) -> None:
        x_direction, y_direction = self.input.pressed_vector()
        speed = self.config.gameplay.rocket_speed
        self.rocket.x += x_direction * speed * elapsed
        self.rocket.y += y_direction * speed * elapsed
        self._clamp_rocket()
        self.score.update(elapsed)

        metrics = self.renderer.font_metrics()
        for request in self.spawner.update(
            elapsed,
            self.score.active_seconds,
            len(self.asteroids),
            self.viewport,
            metrics,
        ):
            self.asteroids.append(
                Asteroid(self._allocate_id(), request.art, request.x, request.y, request.speed)
            )
        for asteroid in self.asteroids:
            asteroid.y += asteroid.speed * elapsed
        self.asteroids = [
            asteroid
            for asteroid in self.asteroids
            if asteroid.y < self.viewport.height + asteroid.art.row_count * metrics.line_height
        ]
        for asteroid in self.asteroids:
            if CollisionSystem.collides(
                self.rocket,
                asteroid,
                metrics,
                self.config.gameplay.collision_forgiveness,
            ):
                self._game_over()
                break

    def _game_over(self) -> None:
        self.explosion_elapsed = 0.0
        self._new_best = self.score.score > self.best_score
        if self.score.score > self.best_score:
            self.best_score = self.score.score
            try:
                self.high_scores.save(self.best_score)
            except OSError:
                pass
        self.audio.play("collision")
        self.transition(GameState.GAME_OVER)

    def _position_rocket_for_ready(self) -> None:
        metrics = self.renderer.font_metrics()
        width = self.rocket.art.columns * metrics.cell_width
        height = self.rocket.art.row_count * metrics.line_height
        self.rocket.x = max(12.0, (self.viewport.width - width) / 2)
        self.rocket.y = max(48.0, self.viewport.height - height - 24.0)

    def _clamp_rocket(self) -> None:
        metrics = self.renderer.font_metrics()
        width = self.rocket.art.columns * metrics.cell_width
        height = self.rocket.art.row_count * metrics.line_height
        self.rocket.x = max(12.0, min(self.viewport.width - width - 12.0, self.rocket.x))
        self.rocket.y = max(48.0, min(self.viewport.height - height - 12.0, self.rocket.y))

    def _sync_stars(self, reset: bool) -> None:
        count = self.config.display.star_count
        if reset:
            self.stars.clear()
        theme = ThemeRegistry.get(
            self.config.display.theme, self.config.display.color_overrides
        )
        while len(self.stars) < count:
            self.stars.append(
                Star(
                    self._allocate_id(),
                    self._star_rng.uniform(0, self.viewport.width),
                    self._star_rng.uniform(0, self.viewport.height),
                    self._star_rng.uniform(
                        self.config.gameplay.star_speed_min,
                        self.config.gameplay.star_speed_max,
                    ),
                    self._star_rng.choice(theme.star_symbols),
                    self._star_rng.uniform(0.35, 1.0),
                )
            )
        if len(self.stars) > count:
            del self.stars[count:]

    def _update_stars(self, elapsed: float) -> None:
        if not self.stars:
            return
        theme = ThemeRegistry.get(
            self.config.display.theme, self.config.display.color_overrides
        )
        for star in self.stars:
            star.y += star.speed * elapsed
            if star.y > self.viewport.height:
                star.y = 0
                star.x = self._star_rng.uniform(0, self.viewport.width)
                star.speed = self._star_rng.uniform(
                    self.config.gameplay.star_speed_min,
                    self.config.gameplay.star_speed_max,
                )
                star.symbol = self._star_rng.choice(theme.star_symbols)

    def _allocate_id(self) -> int:
        entity_id = self._next_id
        self._next_id += 1
        return entity_id


def _star_seed(seed: int | None) -> int:
    return (seed if seed is not None else random.SystemRandom().randint(0, 2**31 - 1)) ^ 0x5A17
