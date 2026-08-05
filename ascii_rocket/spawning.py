from __future__ import annotations

import random
from dataclasses import dataclass

from .config import GameplaySettings
from .models import ASTEROID_TEMPLATES, ArtTemplate, FontMetrics, Viewport


@dataclass(frozen=True, slots=True)
class DifficultyState:
    level: int
    asteroid_speed: float
    spawn_interval: float
    large_weight: float
    live_cap: int


@dataclass(frozen=True, slots=True)
class SpawnRequest:
    art: ArtTemplate
    x: float
    y: float
    speed: float


def difficulty_at(active_seconds: float, settings: GameplaySettings) -> DifficultyState:
    level = int(max(0.0, active_seconds) // settings.difficulty_step)
    return DifficultyState(
        level=level,
        asteroid_speed=settings.asteroid_speed * (settings.speed_growth**level),
        spawn_interval=max(
            settings.minimum_spawn_interval,
            settings.initial_spawn_interval * (settings.interval_decay**level),
        ),
        large_weight=min(
            settings.large_weight_cap,
            settings.large_weight_start + settings.large_weight_step * level,
        ),
        live_cap=min(settings.maximum_live_cap, settings.initial_live_cap + level),
    )


class AsteroidSpawner:
    def __init__(self, settings: GameplaySettings) -> None:
        self.settings = settings
        self.rng = random.Random(settings.seed)
        self.elapsed = 0.0

    def reset(self) -> None:
        self.rng.seed(self.settings.seed)
        self.elapsed = 0.0

    def update(
        self,
        elapsed: float,
        active_seconds: float,
        live_count: int,
        viewport: Viewport,
        metrics: FontMetrics,
    ) -> tuple[SpawnRequest, ...]:
        self.elapsed += max(0.0, elapsed)
        difficulty = difficulty_at(active_seconds, self.settings)
        requests: list[SpawnRequest] = []
        while self.elapsed >= difficulty.spawn_interval and live_count + len(requests) < difficulty.live_cap:
            self.elapsed -= difficulty.spawn_interval
            requests.append(self._spawn(difficulty, viewport, metrics))
        return tuple(requests)

    def _spawn(
        self, difficulty: DifficultyState, viewport: Viewport, metrics: FontMetrics
    ) -> SpawnRequest:
        small = ASTEROID_TEMPLATES[:4]
        large = ASTEROID_TEMPLATES[4:]
        art = self.rng.choice(large if self.rng.random() < difficulty.large_weight else small)
        width = art.columns * metrics.cell_width
        height = art.row_count * metrics.line_height
        x = self.rng.uniform(0.0, max(0.0, viewport.width - width))
        speed = difficulty.asteroid_speed * self.rng.uniform(0.85, 1.15)
        return SpawnRequest(art, x, -height, speed)

