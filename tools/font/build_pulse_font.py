"""Compile Pulse Deathrace Display proof sources into TTF and OTF fonts."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import sys
from typing import Any

from fontTools.fontBuilder import FontBuilder
from fontTools.misc.timeTools import timestampNow
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import newTable
from fontTools.ttLib.tables._k_e_r_n import KernTable_format_0

from font_geometry import draw_to_pen, ensure_within_limits, point_count


DIGIT_NAMES = {
    "0": "zero",
    "1": "one",
    "2": "two",
    "3": "three",
    "4": "four",
    "5": "five",
    "6": "six",
    "7": "seven",
    "8": "eight",
    "9": "nine",
}


def glyph_name(character: str) -> str:
    return DIGIT_NAMES.get(character, character)


def load_config(repo_root: Path) -> tuple[dict[str, Any], Path]:
    source_dir = repo_root / "assets" / "fonts" / "pulse_deathrace_display" / "source"
    with (source_dir / "font_config.json").open("r", encoding="utf-8") as handle:
        return json.load(handle), source_dir


def load_glyph_module(source_dir: Path) -> Any:
    module_path = source_dir / "glyphs.py"
    spec = importlib.util.spec_from_file_location("pulse_deathrace_glyphs", module_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load glyph source module: {module_path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def compile_font(repo_root: Path, flavor: str) -> Path:
    config, source_dir = load_config(repo_root)
    glyph_module = load_glyph_module(source_dir)
    designs = glyph_module.build_glyphs(config)
    metrics_config = config["metrics"]

    character_order = list(config["proof_characters"])
    glyph_order = [".notdef", ".null", "nonmarkingreturn", "space"] + [
        glyph_name(character) for character in character_order
    ]
    character_map = {ord(character): glyph_name(character) for character in character_order}
    character_map[32] = "space"

    designs_by_name = {
        glyph_name(source_name): design for source_name, design in designs.items()
    }
    maximum_points = int(metrics_config["maximum_points_per_glyph"])
    for name, design in designs_by_name.items():
        if design.geometry is None:
            continue
        ensure_within_limits(
            name,
            design.geometry,
            maximum_points=maximum_points,
            minimum_y=float(metrics_config["descender"]),
            maximum_y=float(metrics_config["ascender"]),
        )

    font_builder = FontBuilder(int(config["units_per_em"]), isTTF=flavor == "ttf")
    font_builder.setupGlyphOrder(glyph_order)
    font_builder.setupCharacterMap(character_map)

    horizontal_metrics = {
        name: (designs_by_name[name].advance_width, designs_by_name[name].left_side_bearing)
        for name in glyph_order
    }
    font_builder.setupHorizontalMetrics(horizontal_metrics)
    font_builder.setupHorizontalHeader(
        ascent=int(metrics_config["ascender"]),
        descent=int(metrics_config["descender"]),
        lineGap=int(metrics_config["line_gap"]),
    )

    if flavor == "ttf":
        tt_glyphs = {}
        for name in glyph_order:
            pen = TTGlyphPen(None)
            geometry = designs_by_name[name].geometry
            if geometry is not None:
                draw_to_pen(pen, geometry, outer_clockwise=True)
            tt_glyphs[name] = pen.glyph()
        font_builder.setupGlyf(tt_glyphs)
    elif flavor == "otf":
        char_strings = {}
        for name in glyph_order:
            design = designs_by_name[name]
            pen = T2CharStringPen(design.advance_width, None)
            if design.geometry is not None:
                draw_to_pen(pen, design.geometry, outer_clockwise=False)
            char_strings[name] = pen.getCharString(private=None, globalSubrs=[])
        ps_name = "PulseDeathraceDisplayProof-Regular"
        font_info = {
            "version": config["version"],
            "FullName": f'{config["family_name"]} {config["style_name"]}',
            "FamilyName": config["family_name"],
            "Weight": config["style_name"],
            "ItalicAngle": -float(metrics_config["slant_degrees"]),
            "isFixedPitch": False,
            "UnderlinePosition": -100,
            "UnderlineThickness": 50,
        }
        font_builder.setupCFF(ps_name, font_info, char_strings, {})
    else:
        raise ValueError(f"Unsupported font flavor: {flavor}")

    family = config["family_name"]
    style = config["style_name"]
    version = config["version"]
    font_builder.setupNameTable(
        {
            "familyName": family,
            "styleName": style,
            "uniqueFontIdentifier": f"PulseDeathrace:{family}:{style}:{version}",
            "fullName": f"{family} {style}",
            "psName": "PulseDeathraceDisplayProof-Regular",
            "version": f"Version {version}",
            "copyright": config["copyright"],
        }
    )
    font_builder.setupOS2(
        version=4,
        sTypoAscender=int(metrics_config["ascender"]),
        sTypoDescender=int(metrics_config["descender"]),
        sTypoLineGap=int(metrics_config["line_gap"]),
        usWinAscent=int(metrics_config["ascender"]),
        usWinDescent=abs(int(metrics_config["descender"])),
        sxHeight=0,
        sCapHeight=int(metrics_config["cap_height"]),
        usWeightClass=800,
        usWidthClass=4,
        # The outlines lean forward, but this proof is the family's Regular
        # face rather than a separate italic style.
        fsSelection=0x0040,
        achVendID="PULS",
    )
    font_builder.setupPost(
        italicAngle=-float(metrics_config["slant_degrees"]),
        underlinePosition=-100,
        underlineThickness=50,
        isFixedPitch=0,
        keepGlyphNames=True,
    )
    build_timestamp = timestampNow()
    font_builder.setupHead(fontRevision=0.1, created=build_timestamp, modified=build_timestamp)
    font_builder.setupMaxp()
    font_builder.setupDummyDSIG()
    _add_kerning(font_builder.font)

    output_dir = repo_root / config["outputs"]["directory"]
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / config["outputs"][flavor]
    font_builder.save(output_path)
    total_points = sum(
        point_count(design.geometry)
        for design in designs_by_name.values()
        if design.geometry is not None
    )
    print(
        f"[PulseFont] Built {output_path.relative_to(repo_root)} "
        f"({len(glyph_order)} glyphs, {total_points} source points)"
    )
    return output_path


def _add_kerning(font: Any) -> None:
    pairs = {
        ("P", "U"): -24,
        ("U", "L"): -14,
        ("L", "S"): -20,
        ("D", "E"): -12,
        ("A", "T"): -34,
        ("T", "H"): -18,
        ("R", "A"): -18,
        ("A", "C"): -12,
        ("C", "E"): -10,
        ("P", "L"): -18,
        ("L", "A"): -24,
    }
    kern_table = newTable("kern")
    kern_table.version = 0
    subtable = KernTable_format_0()
    subtable.version = 0
    subtable.coverage = 1
    subtable.kernTable = pairs
    kern_table.kernTables = [subtable]
    font["kern"] = kern_table


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=Path, required=True)
    arguments = parser.parse_args()
    repo_root = arguments.repo_root.resolve()
    compile_font(repo_root, "ttf")
    compile_font(repo_root, "otf")


if __name__ == "__main__":
    main()
