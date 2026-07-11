from pathlib import Path
import re

t = Path(r"D:\git\PULSE_DeathRace\models\Library\mesh-library.tres").read_text(
    encoding="utf-8", errors="replace"
)
for name in ["ConcavePolygonShape3D_ftcqc", "ConcavePolygonShape3D_oxy43"]:
    pat = name + r'"\]\ndata = PackedVector3Array\(([^)]+)\)'
    m = re.search(pat, t)
    if not m:
        print(name, "NOT FOUND")
        continue
    nums = [float(x.strip()) for x in m.group(1).split(",") if x.strip()]
    pts = list(zip(nums[0::3], nums[1::3], nums[2::3]))
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    zs = [p[2] for p in pts]
    print(
        f"{name}: {len(pts)} verts  "
        f"x[{min(xs):.2f},{max(xs):.2f}] "
        f"y[{min(ys):.2f},{max(ys):.2f}] "
        f"z[{min(zs):.2f},{max(zs):.2f}]"
    )
    base = sorted(
        set((round(p[0], 1), round(p[2], 1)) for p in pts if abs(p[1]) < 0.1)
    )
    print("  floor outline samples:", base[:40], "total", len(base))
    # points at y=3 (top of wall)
    top = sorted(
        set((round(p[0], 1), round(p[2], 1)) for p in pts if abs(p[1] - 3.0) < 0.2)
    )
    print("  top outline samples:", top[:40], "total", len(top))

v = Path(r"D:\git\PULSE_DeathRace\scenes\vehicle.tscn").read_text(encoding="utf-8")
for line in v.splitlines():
    if any(k in line for k in ("Sphere", "radius", "continuous", "collision", "mass")):
        print("vehicle:", line)
