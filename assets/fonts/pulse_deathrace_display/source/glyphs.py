"""Authoritative proof glyph geometry for Pulse Deathrace Display.

The forms are original constructions based on a shared design grammar.  They
are intentionally angular and use bounded polygonal detail so the generated
font remains editable, deterministic, and reliable at game UI sizes.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import sys
from typing import Any


TOOLS_DIR = Path(__file__).resolve().parents[4] / "tools" / "font"
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from font_geometry import (  # noqa: E402
    Geometry,
    clean,
    combine,
    ellipse,
    polygon,
    rectangle,
    slant,
    subtract,
    translate,
)


CAP = 720.0
STEM = 112.0
BAR = 104.0


@dataclass(frozen=True)
class GlyphDesign:
    geometry: Geometry | None
    advance_width: int
    left_side_bearing: int


def _diag(x1: float, y1: float, x2: float, y2: float, thickness: float = STEM) -> Geometry:
    """Construct a robust diagonal as a four-point polygon."""
    dx = x2 - x1
    dy = y2 - y1
    length = (dx * dx + dy * dy) ** 0.5
    if length == 0:
        raise ValueError("Diagonal endpoints must differ")
    nx = -dy / length * thickness / 2.0
    ny = dx / length * thickness / 2.0
    return polygon(
        [
            (x1 + nx, y1 + ny),
            (x2 + nx, y2 + ny),
            (x2 - nx, y2 - ny),
            (x1 - nx, y1 - ny),
        ]
    )


def _bar(x1: float, x2: float, y: float, height: float = BAR, rake: float = 28.0) -> Geometry:
    return polygon([(x1, y), (x2 + rake, y), (x2, y + height), (x1 - 12, y + height)])


def _stem(x: float, width: float = STEM, top: float = CAP, bottom: float = 0.0) -> Geometry:
    return polygon([(x, bottom), (x + width, bottom + 10), (x + width + 18, top), (x + 8, top)])


def _ring(width: float, *, inner_x: float = 130.0, inner_y: float = 120.0) -> Geometry:
    # Low segment counts keep round glyphs muscular and faceted instead of
    # reading like a clean geometric sans.
    outer = ellipse(width / 2.0, CAP / 2.0, width / 2.0, CAP / 2.0, points=20)
    inner = ellipse(width / 2.0 + 5.0, CAP / 2.0, width / 2.0 - inner_x, CAP / 2.0 - inner_y, points=16)
    return subtract(outer, inner)


def _edge_notch(side: str, at: float, depth: float, span: float, width: float) -> Geometry:
    half = span / 2.0
    if side == "left":
        return polygon([(-24, at - half), (depth, at), (-24, at + half)])
    if side == "right":
        return polygon([(width + 24, at - half), (width - depth, at), (width + 24, at + half)])
    if side == "top":
        return polygon([(at - half, CAP + 24), (at, CAP - depth), (at + half, CAP + 24)])
    if side == "bottom":
        return polygon([(at - half, -24), (at, depth), (at + half, -24)])
    raise ValueError(f"Unknown notch side: {side}")


DISTRESS: dict[str, list[tuple[str, float, float, float]]] = {
    "A": [("left", 168, 26, 44), ("right", 522, 30, 52), ("top", 270, 22, 38)],
    "C": [("left", 330, 25, 48), ("top", 210, 22, 44), ("bottom", 350, 20, 42)],
    "D": [("right", 205, 28, 52), ("top", 300, 20, 38), ("bottom", 160, 18, 38)],
    "E": [("right", 620, 34, 50), ("left", 248, 24, 42), ("top", 330, 20, 38)],
    "H": [("left", 575, 26, 44), ("right", 170, 28, 50), ("top", 380, 22, 40)],
    "L": [("left", 455, 24, 46), ("right", 42, 30, 46), ("bottom", 260, 18, 34)],
    "M": [("left", 188, 28, 48), ("right", 545, 30, 48), ("top", 370, 24, 40)],
    "N": [("left", 520, 24, 44), ("right", 205, 28, 46), ("bottom", 335, 20, 36)],
    "O": [("left", 252, 24, 46), ("right", 510, 28, 48), ("top", 335, 18, 38)],
    "P": [("left", 150, 24, 42), ("right", 565, 26, 46), ("top", 285, 18, 34)],
    "R": [("left", 556, 24, 40), ("right", 214, 28, 48), ("bottom", 420, 20, 38)],
    "S": [("left", 552, 28, 46), ("right", 160, 30, 50), ("top", 360, 20, 38)],
    "T": [("left", 665, 30, 44), ("right", 668, 30, 46), ("bottom", 295, 20, 36)],
    "U": [("left", 485, 24, 44), ("right", 318, 28, 48), ("bottom", 292, 18, 38)],
    "0": [("left", 248, 24, 44), ("right", 510, 28, 48), ("top", 260, 18, 36)],
    "1": [("right", 430, 25, 42), ("left", 116, 22, 38), ("bottom", 280, 18, 34)],
    "2": [("left", 610, 28, 44), ("right", 420, 26, 46), ("bottom", 350, 20, 38)],
    "3": [("left", 650, 30, 48), ("right", 205, 26, 42), ("bottom", 260, 18, 34)],
    "4": [("left", 298, 24, 42), ("right", 545, 28, 48), ("top", 360, 20, 36)],
    "5": [("right", 650, 30, 46), ("left", 198, 26, 44), ("bottom", 340, 18, 36)],
    "6": [("left", 510, 24, 42), ("right", 180, 28, 46), ("top", 330, 18, 34)],
    "7": [("left", 665, 28, 44), ("right", 610, 26, 44), ("bottom", 255, 20, 34)],
    "8": [("left", 180, 24, 42), ("right", 520, 28, 48), ("top", 310, 18, 34)],
    "9": [("left", 540, 26, 44), ("right", 205, 28, 46), ("bottom", 300, 18, 36)],
}


def _finish(name: str, geometry: Geometry, width: float, metrics: dict[str, Any]) -> GlyphDesign:
    # Wedge scars must survive rasterization at game HUD sizes.
    cuts = [
        _edge_notch(side, at, depth * 1.6, span * 1.35, width)
        for side, at, depth, span in DISTRESS.get(name, [])
    ]
    if cuts:
        geometry = subtract(geometry, *cuts)
    geometry = slant(clean(geometry), float(metrics["slant_degrees"]))
    left = int(metrics["default_left_side_bearing"])
    right = int(metrics["default_right_side_bearing"])
    min_x, _, max_x, _ = geometry.bounds
    geometry = translate(geometry, left - min_x, 0)
    advance = int(round((max_x - min_x) + left + right))
    return GlyphDesign(geometry=geometry, advance_width=advance, left_side_bearing=left)


def _letter_geometry(name: str) -> tuple[Geometry, float]:
    if name == "A":
        width = 540.0
        shape = combine(_diag(72, 0, 270, CAP, 120), _diag(468, 0, 270, CAP, 120), _bar(145, 395, 278, 92, 12))
    elif name == "C":
        width = 520.0
        shape = subtract(_ring(width), rectangle(342, 198, 570, 525))
        shape = combine(shape, polygon([(340, 520), (505, 620), (470, 720), (320, 615)]), polygon([(332, 205), (488, 118), (438, 0), (304, 102)]))
    elif name == "D":
        width = 545.0
        bowl = subtract(ellipse(260, 360, 285, 360, points=20), ellipse(250, 360, 150, 238, points=16))
        shape = combine(_stem(0), clean(bowl.intersection(rectangle(70, -20, 560, 740))))
    elif name == "E":
        width = 515.0
        shape = combine(_stem(0), _bar(38, 490, 616), _bar(40, 410, 304, 96), _bar(30, 480, 0))
    elif name == "H":
        width = 540.0
        shape = combine(_stem(0), _stem(410), _bar(65, 475, 302, 106, 6))
    elif name == "L":
        width = 475.0
        shape = combine(_stem(0), _bar(34, 455, 0, 112, 28))
    elif name == "M":
        width = 650.0
        shape = combine(_stem(0, 105), _diag(86, 700, 320, 250, 108), _diag(320, 250, 560, 700, 108), _stem(545, 105))
    elif name == "N":
        width = 590.0
        shape = combine(_stem(0), _diag(78, 676, 500, 42, 112), _stem(470))
    elif name == "O":
        width = 540.0
        shape = _ring(width, inner_x=132, inner_y=122)
    elif name == "P":
        width = 520.0
        outer = ellipse(245, 520, 275, 200, points=20)
        inner = ellipse(250, 520, 135, 88, points=16)
        bowl = clean(subtract(outer, inner).intersection(rectangle(72, 300, 550, 740)))
        shape = combine(_stem(0), bowl)
    elif name == "R":
        width = 565.0
        outer = ellipse(245, 520, 275, 200, points=20)
        inner = ellipse(250, 520, 135, 88, points=16)
        bowl = clean(subtract(outer, inner).intersection(rectangle(72, 300, 550, 740)))
        shape = combine(_stem(0), bowl, _diag(285, 350, 520, 0, 112))
    elif name == "S":
        width = 525.0
        shape = combine(
            _bar(62, 474, 616, 104, 30),
            _bar(65, 445, 305, 104, 10),
            _bar(38, 465, 0, 108, 30),
            _diag(85, 650, 110, 355, 112),
            _diag(430, 360, 455, 62, 112),
        )
    elif name == "T":
        width = 540.0
        shape = combine(_bar(0, 520, 612, 108, 30), _stem(215, 112, 650, 0))
    elif name == "U":
        width = 545.0
        lower_outer = ellipse(270, 168, 270, 205, points=20)
        lower_inner = ellipse(270, 180, 145, 88, points=16)
        bottom = clean(subtract(lower_outer, lower_inner).intersection(rectangle(-20, -20, 570, 245)))
        shape = combine(_stem(0, 112, CAP, 150), _stem(420, 112, CAP, 150), bottom)
    else:
        raise KeyError(name)
    return clean(shape), width


def _digit_geometry(name: str) -> tuple[Geometry, float]:
    width = 500.0
    if name == "0":
        shape = _ring(width, inner_x=128, inner_y=118)
        shape = subtract(shape, _diag(205, 170, 315, 555, 30))
    elif name == "1":
        shape = combine(_stem(205, 112), _diag(110, 590, 250, 700, 90), _bar(105, 400, 0, 104, 18))
    elif name == "2":
        shape = combine(_bar(48, 440, 616), _diag(438, 650, 400, 355, 108), _bar(80, 410, 304, 100, 12), _diag(105, 340, 70, 70, 108), _bar(42, 455, 0, 108, 26))
    elif name == "3":
        shape = combine(_bar(45, 440, 616), _bar(90, 415, 305, 98, 8), _bar(42, 440, 0, 106, 24), _stem(390, 100, 660, 352), _stem(390, 100, 360, 60))
    elif name == "4":
        shape = combine(_diag(75, 320, 280, 700, 105), _bar(72, 450, 272, 102, 14), _stem(360, 108))
    elif name == "5":
        shape = combine(_bar(55, 450, 616), _stem(45, 105, 660, 330), _bar(62, 415, 305, 98, 10), _stem(390, 100, 350, 58), _bar(45, 440, 0, 106, 24))
    elif name == "6":
        lower = subtract(ellipse(250, 225, 245, 225, points=20), ellipse(255, 230, 120, 100, points=16))
        shape = combine(lower, _stem(42, 105, 600, 190), _bar(65, 430, 610, 102, 26), _diag(90, 630, 180, 700, 92))
    elif name == "7":
        shape = combine(_bar(35, 460, 616, 104, 30), _diag(430, 650, 175, 0, 110))
    elif name == "8":
        upper = subtract(ellipse(250, 530, 230, 190, points=20), ellipse(250, 530, 110, 76, points=16))
        lower = subtract(ellipse(250, 205, 245, 205, points=20), ellipse(250, 205, 118, 86, points=16))
        shape = combine(upper, lower)
    elif name == "9":
        upper = subtract(ellipse(250, 500, 245, 220, points=20), ellipse(245, 505, 120, 98, points=16))
        shape = combine(upper, _stem(390, 100, 530, 110), _bar(55, 430, 0, 102, 22))
    else:
        raise KeyError(name)
    return clean(shape), width


def _notdef(metrics: dict[str, Any]) -> GlyphDesign:
    outer = rectangle(40, 0, 500, CAP)
    inner = rectangle(135, 105, 405, 615)
    frame = subtract(outer, inner)
    cross = combine(_diag(150, 130, 390, 590, 48), _diag(390, 130, 150, 590, 48))
    return _finish(".notdef", combine(frame, cross), 500.0, metrics)


def build_glyphs(config: dict[str, Any]) -> dict[str, GlyphDesign]:
    metrics = config["metrics"]
    glyphs: dict[str, GlyphDesign] = {
        ".notdef": _notdef(metrics),
        ".null": GlyphDesign(None, 0, 0),
        "nonmarkingreturn": GlyphDesign(None, 0, 0),
        "space": GlyphDesign(None, 280, 0),
    }
    for character in config["proof_characters"]:
        geometry, width = _digit_geometry(character) if character.isdigit() else _letter_geometry(character)
        glyphs[character] = _finish(character, geometry, width, metrics)
    return glyphs
