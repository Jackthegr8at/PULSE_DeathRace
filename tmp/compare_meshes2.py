from pathlib import Path
import re
import hashlib

t = Path(r"D:\git\PULSE_DeathRace\models\Library\mesh-library.tres").read_text(
    encoding="utf-8", errors="replace"
)

def extract_mesh(mesh_id: str) -> dict:
    m = re.search(
        rf'\[sub_resource type="ArrayMesh" id="{mesh_id}"\]\n(.*?)(?=\n\[sub_resource|\nitem/|\Z)',
        t,
        re.S,
    )
    if not m:
        return {}
    block = m.group(1)
    out = {"id": mesh_id, "block_len": len(block)}
    for key in ["resource_name", "aabb", "index_count", "vertex_count"]:
        if key == "aabb":
            mm = re.search(r'"aabb": AABB\(([^)]+)\)', block)
        elif key == "resource_name":
            mm = re.search(r'resource_name = "([^"]+)"', block)
        else:
            mm = re.search(rf'"{key}": (\d+)', block)
        out[key] = mm.group(1) if mm else None
    for key in ["index_data", "vertex_data", "attribute_data"]:
        mm = re.search(rf'"{key}": PackedByteArray\("([^"]*)"\)', block)
        if not mm:
            mm = re.search(rf"{key} = PackedByteArray\(\"([^\"]*)\"\)", block)
        if mm:
            raw = mm.group(1)
            out[key + "_len"] = len(raw)
            out[key + "_md5"] = hashlib.md5(raw.encode()).hexdigest()[:16]
        else:
            out[key + "_md5"] = None
    return out

for mid in ["ArrayMesh_60f5r", "ArrayMesh_th6qu", "ArrayMesh_tvhd4", "ArrayMesh_yn5hr"]:
    info = extract_mesh(mid)
    print(mid, info)

print("\nSame vertex_data ramp vs straight?", end=" ")
r = extract_mesh("ArrayMesh_60f5r")
s = extract_mesh("ArrayMesh_th6qu")
print(r.get("vertex_data_md5") == s.get("vertex_data_md5"))
print("Same index_data?", r.get("index_data_md5") == s.get("index_data_md5"))
print("Same attribute_data?", r.get("attribute_data_md5") == s.get("attribute_data_md5"))

# collision shape of straight - describe
print("\n=== Straight/Finish wall collision (oxy43) ===")
print("Left/right wall boxes only (no road floor):")
print("  x ~ +/-4.5 to +/-5.0, y 0..3, z -5..5")
print("  → tall side rails, open front/back for driving")

print("\n=== Ramp collision ===")
print("  shapes = []  → NO physics at all")

print("\n=== Source files ===")
models = Path(r"D:\git\PULSE_DeathRace\models")
print("  track-straight.glb:", (models / "track-straight.glb").exists())
print("  track-ramp.glb:    ", (models / "track-ramp.glb").exists(), "(referenced by mesh-library.tscn)")
print("  track-bump.glb:    ", (models / "track-bump.glb").exists(), "(exists but NOT in mesh library items)")
print("  collision-track-straight.fbx:", (models / "collision-track-straight.fbx").exists())
print("  collision-track-ramp.fbx:    ", (models / "collision-track-ramp.fbx").exists() if True else None)
print("  collision for ramp: MISSING")

# ROAD_ITEMS in code
print("\n=== Game code ===")
print("  ROAD_ITEMS = [3,4,5,6] includes both ramp(5) and straight(6)")
print("  So both count as road for AI path / crates / (old) solid walls")
