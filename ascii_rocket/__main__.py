from __future__ import annotations

import logging
import tkinter as tk
from tkinter import messagebox

from .app import App


def main() -> int:
    try:
        App().run()
    except tk.TclError as exc:
        logging.getLogger("ascii_rocket").exception("Tk startup failed")
        try:
            root = tk.Tk()
            root.withdraw()
            messagebox.showerror("ASCII Rocket", f"The game could not start:\n{exc}", parent=root)
            root.destroy()
        except tk.TclError:
            pass
        return 1
    except Exception:
        logging.getLogger("ascii_rocket").exception("Fatal application error")
        raise
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
