"""Validate generated Pulse Deathrace Display proof font binaries."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from fontTools.pens.recordingPen import RecordingPen
from fontTools.ttLib import TTFont


COMMON_TABLES = {"head", "hhea", "maxp", "OS/2", "hmtx", "cmap", "name", "post"}


def validate_font(path: Path, config: dict, flavor: str) -> dict:
    font = TTFont(path, lazy=False)
    expected_tables = COMMON_TABLES | ({"glyf", "loca"} if flavor == "ttf" else {"CFF "})
    missing_tables = sorted(expected_tables - set(font.keys()))
    if missing_tables:
        raise ValueError(f"{path.name}: missing tables {missing_tables}")

    cmap = font.getBestCmap() or {}
    required_characters = set(config["proof_characters"] + " ")
    for specimen in config["specimen_strings"]:
        required_characters.update(specimen)
    missing_characters = sorted(character for character in required_characters if ord(character) not in cmap)
    if missing_characters:
        raise ValueError(f"{path.name}: missing characters {missing_characters}")

    specimen_sequences: dict[str, list[str]] = {}
    for specimen in config["specimen_strings"]:
        sequence = [cmap.get(ord(character), ".notdef") for character in specimen]
        if ".notdef" in sequence:
            raise ValueError(f"{path.name}: specimen falls back to .notdef: {specimen}")
        specimen_sequences[specimen] = sequence

    glyph_order = font.getGlyphOrder()
    required_names = {".notdef", ".null", "nonmarkingreturn", "space"}
    required_names.update(cmap[ord(character)] for character in config["proof_characters"])
    missing_names = sorted(required_names - set(glyph_order))
    if missing_names:
        raise ValueError(f"{path.name}: missing glyphs {missing_names}")

    metrics = font["hmtx"].metrics
    for name in required_names:
        if name not in metrics:
            raise ValueError(f"{path.name}: {name} has no horizontal metrics")
    for name in required_names - {".null", "nonmarkingreturn"}:
        if metrics[name][0] <= 0:
            raise ValueError(f"{path.name}: {name} has a non-positive advance")

    maximum_points = int(config["metrics"]["maximum_points_per_glyph"])
    maximum_observed_points = 0
    nonempty_glyphs = 0
    glyph_set = font.getGlyphSet()
    for name in required_names - {".null", "nonmarkingreturn", "space"}:
        pen = RecordingPen()
        glyph_set[name].draw(pen)
        if not pen.value:
            raise ValueError(f"{path.name}: expected nonempty outline for {name}")
        nonempty_glyphs += 1
        if flavor == "ttf":
            coordinates, _, _ = font["glyf"][name].getCoordinates(font["glyf"])
            maximum_observed_points = max(maximum_observed_points, len(coordinates))
            if len(coordinates) > maximum_points:
                raise ValueError(
                    f"{path.name}: {name} has {len(coordinates)} points, limit is {maximum_points}"
                )

    if "kern" not in font:
        raise ValueError(f"{path.name}: proof kerning table is missing")

    cap_height = int(config["metrics"]["cap_height"])
    if font["OS/2"].sCapHeight != cap_height:
        raise ValueError(
            f"{path.name}: cap height {font['OS/2'].sCapHeight} does not match {cap_height}"
        )
    if font["head"].unitsPerEm != int(config["units_per_em"]):
        raise ValueError(f"{path.name}: unexpected units-per-em")

    font.close()
    return {
        "glyphs": len(glyph_order),
        "mapped_characters": len(cmap),
        "nonempty_glyphs": nonempty_glyphs,
        "maximum_points": maximum_observed_points,
        "specimen_sequences": specimen_sequences,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    arguments = parser.parse_args()
    repo_root = arguments.repo_root.resolve()
    source_dir = repo_root / "assets" / "fonts" / "pulse_deathrace_display" / "source"
    with (source_dir / "font_config.json").open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    output_dir = repo_root / config["outputs"]["directory"]

    results = {}
    for flavor in ("ttf", "otf"):
        path = output_dir / config["outputs"][flavor]
        if not path.is_file():
            raise FileNotFoundError(path)
        results[flavor] = validate_font(path, config, flavor)
        print(f"[PulseFont] Validated {path.relative_to(repo_root)}: {results[flavor]}")

    report_path = output_dir / "PulseDeathraceDisplay-Proof-Validation.json"
    report_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"[PulseFont] Wrote {report_path.relative_to(repo_root)}")


if __name__ == "__main__":
    main()
