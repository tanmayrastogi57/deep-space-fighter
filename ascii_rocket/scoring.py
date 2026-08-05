from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(slots=True)
class ScoreManager:
    active_seconds: float = 0.0

    @property
    def score(self) -> int:
        return math.floor(self.active_seconds) * 5

    def update(self, elapsed: float) -> int:
        self.active_seconds += max(0.0, elapsed)
        return self.score

    def reset(self) -> None:
        self.active_seconds = 0.0

