from __future__ import annotations

from enum import Enum, auto


class GameState(Enum):
    BOOT = auto()
    THEME_SELECT = auto()
    READY = auto()
    LAUNCHING = auto()
    PLAYING = auto()
    PAUSED = auto()
    SETTINGS = auto()
    GAME_OVER = auto()
    RESTARTING = auto()
    EXITING = auto()


LEGAL_TRANSITIONS: dict[GameState, set[GameState]] = {
    GameState.BOOT: {GameState.THEME_SELECT, GameState.READY, GameState.EXITING},
    GameState.THEME_SELECT: {GameState.READY, GameState.EXITING},
    GameState.READY: {GameState.LAUNCHING, GameState.PAUSED, GameState.SETTINGS, GameState.EXITING},
    GameState.LAUNCHING: {GameState.PLAYING, GameState.PAUSED, GameState.EXITING},
    GameState.PLAYING: {GameState.PAUSED, GameState.GAME_OVER, GameState.EXITING},
    GameState.PAUSED: {
        GameState.READY,
        GameState.LAUNCHING,
        GameState.PLAYING,
        GameState.SETTINGS,
        GameState.RESTARTING,
        GameState.EXITING,
    },
    GameState.SETTINGS: {
        GameState.READY,
        GameState.LAUNCHING,
        GameState.PLAYING,
        GameState.PAUSED,
        GameState.GAME_OVER,
        GameState.EXITING,
    },
    GameState.GAME_OVER: {GameState.RESTARTING, GameState.SETTINGS, GameState.EXITING},
    GameState.RESTARTING: {GameState.READY, GameState.EXITING},
    GameState.EXITING: set(),
}

