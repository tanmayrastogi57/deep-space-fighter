from __future__ import annotations

import math

from .config import ControlsSettings


def canonical_key(key: str) -> str:
    return key.lower() if len(key) == 1 else key


class InputManager:
    def __init__(self, controls: ControlsSettings) -> None:
        self.controls = controls
        self._pressed: set[str] = set()

    def update_controls(self, controls: ControlsSettings) -> None:
        self.controls = controls
        self.clear()

    def press(self, key: str) -> None:
        self._pressed.add(canonical_key(key))

    def release(self, key: str) -> None:
        self._pressed.discard(canonical_key(key))

    def clear(self) -> None:
        self._pressed.clear()

    def action_pressed(self, action: str) -> bool:
        return any(canonical_key(key) in self._pressed for key in self.controls.bindings[action])

    def key_matches(self, key: str, action: str) -> bool:
        normalized = canonical_key(key)
        return any(normalized == canonical_key(bound) for bound in self.controls.bindings[action])

    def pressed_vector(self) -> tuple[float, float]:
        x = float(self.action_pressed("right")) - float(self.action_pressed("left"))
        y = float(self.action_pressed("down")) - float(self.action_pressed("up"))
        length = math.hypot(x, y)
        return (x / length, y / length) if length else (0.0, 0.0)

    def rebind(self, action: str, key: str, slot: int = 0) -> None:
        if action not in self.controls.bindings:
            raise KeyError(action)
        if action == "pause" and slot == 0 and key != "Escape":
            raise ValueError("Escape is the fixed pause fallback")
        normalized = canonical_key(key)
        for other_action, keys in self.controls.bindings.items():
            for other_slot, other_key in enumerate(keys):
                if other_action == action and other_slot == slot:
                    continue
                if canonical_key(other_key) == normalized:
                    raise ValueError(f"{key} is already bound to {other_action}")
        keys = list(self.controls.bindings[action])
        while len(keys) <= slot:
            keys.append("")
        keys[slot] = key
        self.controls.bindings[action] = [item for item in keys if item]
