"""Deterministic geometry helpers for Pulse Deathrace Display.

The proof font is constructed from deliberate vector primitives. This module
keeps geometry validation, winding, slant, and pen output consistent between
glyphs and generated font flavors.
"""

from __future__ import annotations

from collections.abc import Iterable, Iterator, Sequence
from math import radians, tan
from typing import Any

from shapely import affinity
from shapely.geometry import GeometryCollection, MultiPolygon, Point, Polygon, box
from shapely.geometry.polygon import orient
from shapely.ops import unary_union
from shapely.validation import explain_validity, make_valid


Geometry = Polygon | MultiPolygon
Point2D = tuple[float, float]


def polygon(points: Sequence[Point2D]) -> Polygon:
    """Create and validate a closed polygon from design-grid points."""
    if len(points) < 3:
        raise ValueError("A polygon requires at least three points")
    return _polygonal(make_valid(Polygon(points)))


def rectangle(x_min: float, y_min: float, x_max: float, y_max: float) -> Polygon:
    if x_max <= x_min or y_max <= y_min:
        raise ValueError("Rectangle bounds must have positive width and height")
    return box(x_min, y_min, x_max, y_max)


def ellipse(
    center_x: float,
    center_y: float,
    radius_x: float,
    radius_y: float,
    *,
    points: int = 48,
) -> Polygon:
    """Return a bounded-point ellipse suitable for distressed display forms."""
    if radius_x <= 0 or radius_y <= 0:
        raise ValueError("Ellipse radii must be positive")
    if points < 16 or points > 128:
        raise ValueError("Ellipse point count must be between 16 and 128")
    resolution = max(4, points // 4)
    unit_circle = Point(center_x, center_y).buffer(1.0, resolution=resolution)
    return affinity.scale(unit_circle, radius_x, radius_y, origin=(center_x, center_y))


def combine(*geometries: Geometry) -> Geometry:
    parts = [geometry for geometry in geometries if not geometry.is_empty]
    if not parts:
        raise ValueError("Cannot combine an empty geometry list")
    return clean(unary_union(parts))


def subtract(base: Geometry, *cuts: Geometry) -> Geometry:
    result: Any = base
    for cut in cuts:
        if not cut.is_empty:
            result = result.difference(cut)
    return clean(result)


def slant(geometry: Geometry, degrees: float = 9.0) -> Geometry:
    """Apply a baseline-anchored forward slant: x' = x + tan(angle) * y."""
    shear = tan(radians(degrees))
    return clean(affinity.affine_transform(geometry, [1.0, shear, 0.0, 1.0, 0.0, 0.0]))


def translate(geometry: Geometry, x: float = 0.0, y: float = 0.0) -> Geometry:
    return clean(affinity.translate(geometry, xoff=x, yoff=y))


def scale(
    geometry: Geometry,
    x: float,
    y: float,
    *,
    origin: Point2D = (0.0, 0.0),
) -> Geometry:
    if x <= 0 or y <= 0:
        raise ValueError("Scale factors must be positive")
    return clean(affinity.scale(geometry, xfact=x, yfact=y, origin=origin))


def clean(geometry: Any, *, minimum_area: float = 1.0) -> Geometry:
    """Repair geometry and discard fragments too small to survive rasterization."""
    fixed = make_valid(geometry)
    polygons = [part for part in _flatten_polygons(fixed) if part.area >= minimum_area]
    if not polygons:
        raise ValueError("Geometry has no usable polygonal area")
    merged = unary_union(polygons)
    result = _polygonal(merged)
    if not result.is_valid:
        raise ValueError(f"Invalid geometry after cleanup: {explain_validity(result)}")
    return result


def point_count(geometry: Geometry) -> int:
    return sum(len(ring.coords) - 1 for polygon_part in polygons(geometry) for ring in _rings(polygon_part))


def polygons(geometry: Geometry) -> list[Polygon]:
    if isinstance(geometry, Polygon):
        return [geometry]
    return list(geometry.geoms)


def contour_coordinates(
    geometry: Geometry,
    *,
    outer_clockwise: bool,
) -> Iterator[list[Point2D]]:
    """Yield font contours with deterministic component and winding order."""
    sorted_polygons = sorted(
        polygons(geometry),
        key=lambda part: (-part.area, part.bounds[0], part.bounds[1]),
    )
    for part in sorted_polygons:
        oriented = orient(part, sign=-1.0 if outer_clockwise else 1.0)
        yield _rounded_ring(oriented.exterior.coords)
        for interior in sorted(oriented.interiors, key=lambda ring: -Polygon(ring).area):
            yield _rounded_ring(interior.coords)


def draw_to_pen(
    pen: Any,
    geometry: Geometry,
    *,
    outer_clockwise: bool,
) -> None:
    """Draw polygonal contours into a FontTools-compatible segment pen."""
    for contour in contour_coordinates(geometry, outer_clockwise=outer_clockwise):
        if len(contour) < 3:
            raise ValueError("A font contour requires at least three unique points")
        pen.moveTo(contour[0])
        for point in contour[1:]:
            pen.lineTo(point)
        pen.closePath()


def ensure_within_limits(
    name: str,
    geometry: Geometry,
    *,
    maximum_points: int,
    minimum_y: float = -220.0,
    maximum_y: float = 780.0,
) -> None:
    if geometry.is_empty:
        raise ValueError(f"{name}: geometry is empty")
    if not geometry.is_valid:
        raise ValueError(f"{name}: {explain_validity(geometry)}")
    count = point_count(geometry)
    if count > maximum_points:
        raise ValueError(f"{name}: {count} points exceeds limit {maximum_points}")
    _, y_min, _, y_max = geometry.bounds
    if y_min < minimum_y or y_max > maximum_y:
        raise ValueError(
            f"{name}: vertical bounds {y_min:.1f}..{y_max:.1f} exceed "
            f"{minimum_y:.1f}..{maximum_y:.1f}"
        )


def _rings(polygon_part: Polygon) -> Iterable[Any]:
    yield polygon_part.exterior
    yield from polygon_part.interiors


def _rounded_ring(coordinates: Any) -> list[Point2D]:
    points = [(round(float(x), 2), round(float(y), 2)) for x, y in coordinates[:-1]]
    if len(set(points)) < 3:
        raise ValueError("Contour collapsed after coordinate rounding")
    return points


def _flatten_polygons(geometry: Any) -> Iterator[Polygon]:
    if isinstance(geometry, Polygon):
        yield geometry
    elif isinstance(geometry, MultiPolygon):
        yield from geometry.geoms
    elif isinstance(geometry, GeometryCollection):
        for item in geometry.geoms:
            yield from _flatten_polygons(item)


def _polygonal(geometry: Any) -> Geometry:
    if isinstance(geometry, (Polygon, MultiPolygon)):
        return geometry
    polygon_parts = list(_flatten_polygons(geometry))
    if not polygon_parts:
        raise ValueError("Expected polygonal geometry")
    merged = unary_union(polygon_parts)
    if not isinstance(merged, (Polygon, MultiPolygon)):
        raise ValueError("Geometry did not resolve to polygons")
    return merged
