"""Render a deterministic raster specimen from the built proof TTF."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


BACKGROUND = "#070b0e"
BONE = "#f5edda"
MAGENTA = "#ed1769"
CYAN = "#18c9d2"
YELLOW = "#f6b600"


def fit_font(path: Path, text: str, maximum_size: int, maximum_width: int) -> ImageFont.FreeTypeFont:
    size = maximum_size
    while size >= 24:
        font = ImageFont.truetype(path, size=size)
        left, _, right, _ = font.getbbox(text)
        if right - left <= maximum_width:
            return font
        size -= 2
    raise ValueError(f"Unable to fit specimen text: {text}")


def centered_text(
    draw: ImageDraw.ImageDraw,
    position: tuple[int, int],
    text: str,
    font: ImageFont.FreeTypeFont,
    color: str,
    *,
    accent: str = MAGENTA,
) -> None:
    x, y = position
    draw.text((x + 5, y + 7), text, font=font, fill=accent, anchor="mm", stroke_width=1)
    draw.text((x, y), text, font=font, fill=color, anchor="mm", stroke_width=2, stroke_fill="#020304")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    arguments = parser.parse_args()
    repo_root = arguments.repo_root.resolve()
    source_dir = repo_root / "assets" / "fonts" / "pulse_deathrace_display" / "source"
    with (source_dir / "font_config.json").open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    output_dir = repo_root / config["outputs"]["directory"]
    font_path = output_dir / config["outputs"]["ttf"]
    output_path = output_dir / config["outputs"]["specimen"]

    width, height = 2048, 1360
    image = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(image)
    draw.rectangle((48, 48, width - 48, height - 48), outline="#26343a", width=3)
    draw.line((120, 225, width - 120, 225), fill=CYAN, width=4)

    title = fit_font(font_path, config["specimen_strings"][0], 190, width - 180)
    line_two = fit_font(font_path, config["specimen_strings"][1], 142, width - 220)
    line_three = fit_font(font_path, config["specimen_strings"][2], 186, width - 280)
    numbers = fit_font(font_path, config["specimen_strings"][3], 138, width - 260)

    centered_text(draw, (width // 2, 155), config["specimen_strings"][0], title, BONE)
    centered_text(draw, (width // 2, 460), config["specimen_strings"][1], line_two, CYAN)
    centered_text(draw, (width // 2, 760), config["specimen_strings"][2], line_three, YELLOW)
    centered_text(draw, (width // 2, 1080), config["specimen_strings"][3], numbers, BONE)

    # The proof face intentionally lacks the full alphabet and punctuation;
    # keep the utility footer separate from the glyph proof itself.
    draw.text(
        (width // 2, 1272),
        "PULSE DEATHRACE DISPLAY - PROOF 0.1",
        font=ImageFont.load_default(size=34),
        fill="#8c9aa0",
        anchor="mm",
    )
    image.save(output_path, format="PNG", optimize=True)
    print(f"[PulseFont] Rendered {output_path.relative_to(repo_root)} ({width}x{height})")


if __name__ == "__main__":
    main()
