from __future__ import annotations

from dataclasses import dataclass, field


ROCKET_ART = (
    "   /▲\\",
    "  /▲ ▲\\",
    "  | ||| |",
    " /▲     ▲\\",
    "/▲_______▲\\",
    "( ▼▼   ▼▼ )",
)

ASTEROID_ART = (
    ("##", "###"),
    ("@@@", " @@"),
    ("()", "( )"),
    ("OO", "OOOO"),
    ("  @@@", " @@@@@", "@@@ @@", " @@@@"),
    ("  OOO ", " O   O", "O OOO O", " OOOO "),
)


@dataclass(frozen=True, slots=True)
class ArtTemplate:
    rows: tuple[str, ...]
    occupied: tuple[tuple[int, int], ...] = field(init=False)
    columns: int = field(init=False)

    def __post_init__(self) -> None:
        width = max((len(row) for row in self.rows), default=0)
        cells = tuple(
            (column, row_index)
            for row_index, row in enumerate(self.rows)
            for column, character in enumerate(row)
            if not character.isspace()
        )
        object.__setattr__(self, "columns", width)
        object.__setattr__(self, "occupied", cells)

    @property
    def text(self) -> str:
        return "\n".join(self.rows)

    @property
    def row_count(self) -> int:
        return len(self.rows)


ROCKET_TEMPLATE = ArtTemplate(ROCKET_ART)
ASTEROID_TEMPLATES = tuple(ArtTemplate(rows) for rows in ASTEROID_ART)


@dataclass(slots=True)
class Entity:
    id: int
    art: ArtTemplate
    x: float
    y: float


@dataclass(slots=True)
class Rocket(Entity):
    pass


@dataclass(slots=True)
class Asteroid(Entity):
    speed: float = 140.0


@dataclass(slots=True)
class Star:
    id: int
    x: float
    y: float
    speed: float
    symbol: str
    intensity: float = 1.0


@dataclass(frozen=True, slots=True)
class FontMetrics:
    cell_width: float
    line_height: float


@dataclass(frozen=True, slots=True)
class Viewport:
    width: float
    height: float


@dataclass(frozen=True, slots=True)
class RenderEntity:
    id: int
    text: str
    x: float
    y: float
    kind: str


@dataclass(frozen=True, slots=True)
class RenderStar:
    id: int
    x: float
    y: float
    symbol: str
    intensity: float


@dataclass(frozen=True, slots=True)
class FrameSnapshot:
    state_name: str
    rocket: RenderEntity
    asteroids: tuple[RenderEntity, ...]
    stars: tuple[RenderStar, ...]
    score: int
    best_score: int
    active_seconds: float
    difficulty_level: int
    explosion_elapsed: float | None
    show_game_over: bool
    fps: float
    new_best: bool = False
