from pathlib import Path
import re
import struct

root = Path(r"D:\git\PULSE_DeathRace")
t = (root / "models/Library/mesh-library.tres").read_text(encoding="utf-8", errors="replace")

print("=== MeshLibrary item entries ===")
for item_id, name in [(5, "track-ramp"), (6, "track-straight"), (3, "track-corner"), (4, "track-finish")]:
    m = re.search(
        rf'item/{item_id}/name = "{re.escape(name)}"\n(.*?)(?=item/\d+/name |\Z)',
        t,
        re.S,
    )
    print(f"\nitem/{item_id} {name}:")
    if not m:
        print("  NOT FOUND")
        continue
    for line in m.group(0).splitlines():
        if "preview" in line:
            continue
        print(" ", line[:160])

print("\n=== Mesh AABBs (from ArrayMesh resource_name) ===")
# Find blocks: resource_name then later aabb is wrong order; in file aabb comes before name often
# Pattern: "aabb": AABB(...) then within ~30 lines resource_name = "track-..."
for m in re.finditer(
    r'"aabb": AABB\(([^)]+)\)[\s\S]{0,800}?resource_name = "(track-[^"]+)"',
    t,
):
    print(f"  {m.group(2)}: AABB({m.group(1)})")

print("\n=== Concave collision shape usage ===")
for shape_id in ["ConcavePolygonShape3D_ftcqc", "ConcavePolygonShape3D_oxy43"]:
    m = re.search(
        rf'\[sub_resource type="ConcavePolygonShape3D" id="{shape_id}"\]\ndata = PackedVector3Array\(([^)]+)\)',
        t,
    )
    if not m:
        print(shape_id, "missing")
        continue
    nums = [float(x.strip()) for x in m.group(1).split(",") if x.strip()]
    pts = list(zip(nums[0::3], nums[1::3], nums[2::3]))
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    zs = [p[2] for p in pts]
    print(
        f"  {shape_id}: {len(pts)} verts "
        f"x[{min(xs):.2f},{max(xs):.2f}] y[{min(ys):.2f},{max(ys):.2f}] z[{min(zs):.2f},{max(zs):.2f}]"
    )
    # which items use it
    uses = re.findall(rf'item/(\d+)/shapes = \[SubResource\("{shape_id}"\)', t)
    print(f"    used by items: {uses}")

print("\n=== Files on disk ===")
for p in sorted((root / "models").glob("track-*")):
    print(f"  {p.name:30} {p.stat().st_size:10} bytes")
for p in sorted((root / "models").glob("collision-*")):
    print(f"  {p.name:30} {p.stat().st_size:10} bytes")

# mesh-library.tscn references
tscn = (root / "models/Library/mesh-library.tscn").read_text(encoding="utf-8", errors="replace")
print("\n=== mesh-library.tscn nodes ===")
for line in tscn.splitlines():
    if "track-ramp" in line or "track-straight" in line or "collision" in line.lower() or line.startswith("[node"):
        if "PackedByteArray" in line or len(line) > 200:
            continue
        print(" ", line[:140])

# GLB header / rough size
print("\n=== GLB presence ===")
for name in ["track-ramp.glb", "track-straight.glb", "track-bump.glb", "track-corner.glb", "track-finish.glb"]:
    p = root / "models" / name
    print(f"  {name}: {'EXISTS ' + str(p.stat().st_size) if p.exists() else 'MISSING'}")
