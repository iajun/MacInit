"""Landscape / portrait layout helpers."""

from __future__ import annotations

import os
from typing import Literal

from manim import DOWN, Mobject, ORIGIN, UP, VGroup

Format = Literal["landscape", "portrait"]


def get_format() -> Format:
    raw = os.environ.get("MANIM_FORMAT", "landscape").strip().lower()
    return "portrait" if raw.startswith("port") else "landscape"


def frame_for() -> Format:
    return get_format()


def place_hero(mob: Mobject, fmt: Format | None = None) -> Mobject:
    fmt = fmt or get_format()
    if fmt == "portrait":
        # Mid-upper: away from Douyin/Reels top UI
        return mob.move_to(UP * 1.2)
    return mob.move_to(ORIGIN)


def stack_vertical(*mobs: Mobject, buff: float = 0.45) -> VGroup:
    return VGroup(*mobs).arrange(DOWN, buff=buff)


def safe_area_shift(mob: Mobject, fmt: Format | None = None) -> Mobject:
    """Nudge content into vertical safe area."""
    fmt = fmt or get_format()
    if fmt == "portrait":
        return mob.shift(UP * 0.25)
    return mob
