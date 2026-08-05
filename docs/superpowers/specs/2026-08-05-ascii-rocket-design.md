# ASCII Rocket Design

## Product

ASCII Rocket is a Windows-first endless survival game rendered entirely with
Tkinter Canvas text. A player selects one of three visual themes, launches a
rocket, avoids descending ASCII asteroids, earns five points per second, and
can restart after collision. The runtime uses only Python's standard library.

## Experience

The first run opens a required theme picker. Later launches remember that
choice. The ready screen waits for Space or Enter, then automatically launches
the rocket to 55% of the viewport height. Player control begins only in the
`PLAYING` state. Escape opens a pause menu and F11 toggles fullscreen.

The three themes are Terminal Noir, Deep-Space HUD, and Neon Arcade. Themes
control palette, stars, HUD framing, scanlines, glow, menus, and explosion
colors. Theme selection remains available in Settings.

## Architecture

- `App` owns Tk, the Canvas, viewport changes, and shutdown.
- `GameController` owns one scheduled loop, state transitions, run reset, and
  snapshots passed to the renderer.
- Pure models own entities, score, difficulty, input vectors, and collision.
- `Renderer` retains Canvas IDs and never owns game rules.
- `AppConfig` validates settings and saves atomically under `%APPDATA%`.
- `AudioManager` generates temporary WAV effects and uses `winsound` when
  available.

States are `BOOT`, `THEME_SELECT`, `READY`, `LAUNCHING`, `PLAYING`, `PAUSED`,
`SETTINGS`, `GAME_OVER`, `RESTARTING`, and `EXITING`.

## Rules

- Movement uses elapsed time, a 300 px/s default, normalized diagonals, and a
  maximum delta of 0.05 seconds.
- Rocket stays inside 12 px side/bottom padding and a 48 px HUD-safe top.
- Score is always `floor(active_play_seconds) * 5`.
- Difficulty advances every 20 seconds: asteroid speed ×1.08, spawn interval
  ×0.90 down to 0.35 seconds, large-template weight up to 45%, and a live cap
  growing from 6 to 14.
- Collision first checks bounding boxes, then measured rectangles for every
  non-whitespace character. Default collision forgiveness is zero.
- Pause and game over freeze the run; stars continue. Restart preserves stars.

## Polish and Settings

The game includes persistent high score, a themed 0.6-second ASCII explosion,
procedural sound, a live FPS overlay, and advanced settings for appearance,
gameplay, sound, controls, and system behavior. Invalid or corrupt persisted
data falls back safely and records a warning.

## Delivery and Quality

Unit tests cover state transitions, input, scoring, spawning, difficulty,
collision, settings, themes, and persistence. Hidden-Tk smoke tests cover
rendering and resizing when a display is available. A PowerShell build script
runs tests and creates a one-folder, windowed PyInstaller distribution.

Target performance is 45–60 FPS at 1080p with 180 stars and 14 asteroids. The
project contains no image, network, or downloaded runtime assets.
