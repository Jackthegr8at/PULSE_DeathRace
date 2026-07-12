"""Inspect ravage.glb node hierarchy / meshes without Godot."""
from pathlib import Path
import json
import struct

path = Path(r"D:\git\PULSE_DeathRace\models\ravage.glb")
data = path.read_bytes()
assert data[:4] == b"glTF", data[:4]
version, length = struct.unpack_from("<II", data, 4)
print(f"GLB version={version} length={length} file={path.stat().st_size}")

offset = 12
json_chunk = None
while offset < len(data):
    chunk_len, chunk_type = struct.unpack_from("<I4s", data, offset)
    offset += 8
    chunk = data[offset : offset + chunk_len]
    offset += chunk_len
    if chunk_type == b"JSON":
        json_chunk = json.loads(chunk.decode("utf-8"))
        break

if not json_chunk:
    raise SystemExit("No JSON chunk")

print("asset:", json_chunk.get("asset"))
print("nodes:", len(json_chunk.get("nodes", [])))
print("meshes:", len(json_chunk.get("meshes", [])))
print("materials:", len(json_chunk.get("materials", [])))
print("skins:", len(json_chunk.get("skins", [])))
print("animations:", [a.get("name") for a in json_chunk.get("animations", [])])
print("scenes:", json_chunk.get("scenes"))

nodes = json_chunk.get("nodes", [])
# print all node names
print("\n=== Nodes ===")
for i, n in enumerate(nodes):
    name = n.get("name", f"node_{i}")
    kids = n.get("children", [])
    mesh = n.get("mesh")
    skin = n.get("skin")
    t = n.get("translation")
    r = n.get("rotation")
    s = n.get("scale")
    extras = []
    if mesh is not None:
        extras.append(f"mesh={mesh}")
    if skin is not None:
        extras.append(f"skin={skin}")
    if t:
        extras.append(f"t={t}")
    if r:
        extras.append(f"r={r}")
    if s:
        extras.append(f"s={s}")
    print(f"  [{i:3d}] {name!r:40s} children={kids} {' '.join(extras)}")

# hierarchy from scene root
def walk(idx, depth=0):
    n = nodes[idx]
    name = n.get("name", f"node_{idx}")
    mesh = n.get("mesh")
    mname = ""
    if mesh is not None:
        m = json_chunk["meshes"][mesh]
        mname = f" mesh={m.get('name')} prims={len(m.get('primitives', []))}"
    print("  " * depth + f"- {name}{mname}")
    for c in n.get("children", []):
        walk(c, depth + 1)

print("\n=== Hierarchy ===")
for scene in json_chunk.get("scenes", [{"nodes": [0]}]):
    for root in scene.get("nodes", []):
        walk(root)

# mesh names
print("\n=== Meshes ===")
for i, m in enumerate(json_chunk.get("meshes", [])):
    print(f"  [{i}] {m.get('name')} primitives={len(m.get('primitives', []))}")

# materials
print("\n=== Materials ===")
for i, m in enumerate(json_chunk.get("materials", [])):
    print(f"  [{i}] {m.get('name')}")

# images / textures
print("\n=== Images ===", len(json_chunk.get("images", [])))
for i, im in enumerate(json_chunk.get("images", [])[:20]):
    print(f"  [{i}] {im}")
