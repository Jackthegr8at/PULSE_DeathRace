from pathlib import Path
import json, struct

path = Path(r"D:\git\PULSE_DeathRace\models\ravage.glb")
data = path.read_bytes()
offset = 12
json_chunk = None
bin_chunk = None
while offset < len(data):
    chunk_len, chunk_type = struct.unpack_from("<I4s", data, offset)
    offset += 8
    chunk = data[offset : offset + chunk_len]
    offset += chunk_len
    if chunk_type == b"JSON":
        json_chunk = json.loads(chunk.decode("utf-8"))
    elif chunk_type == b"BIN\x00":
        bin_chunk = chunk

accessors = json_chunk["accessors"]
views = json_chunk["bufferViews"]
# POSITION accessor is usually first primitive attributes
prim = json_chunk["meshes"][0]["primitives"][0]
pos_idx = prim["attributes"]["POSITION"]
acc = accessors[pos_idx]
print("POSITION accessor:", acc)
# min/max often present
if "min" in acc and "max" in acc:
    mn, mx = acc["min"], acc["max"]
    size = [mx[i] - mn[i] for i in range(3)]
    center = [(mx[i] + mn[i]) / 2 for i in range(3)]
    print(f"min={mn}\nmax={mx}\nsize={size}\ncenter={center}")
else:
    print("no min/max on accessor")

# Kenney truck for comparison if available
kpath = Path(r"D:\git\PULSE_DeathRace\models\vehicle-truck-yellow.glb")
if kpath.exists():
    data = kpath.read_bytes()
    offset = 12
    j = None
    while offset < len(data):
        chunk_len, chunk_type = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk = data[offset : offset + chunk_len]
        offset += chunk_len
        if chunk_type == b"JSON":
            j = json.loads(chunk.decode("utf-8"))
            break
    print("\nKenney nodes:")
    for i, n in enumerate(j.get("nodes", [])):
        print(f"  [{i}] {n.get('name')} mesh={n.get('mesh')} children={n.get('children')}")
    for i, m in enumerate(j.get("meshes", [])):
        p = m["primitives"][0]
        a = j["accessors"][p["attributes"]["POSITION"]]
        if "min" in a:
            mn, mx = a["min"], a["max"]
            print(f"  mesh {m.get('name')}: size={[mx[k]-mn[k] for k in range(3)]} min={mn} max={mx}")
