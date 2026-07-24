from pathlib import Path
import json, struct

def inspect(path: Path):
    data = path.read_bytes()
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
    print("===", path.name, "===")
    print("nodes:", len(j.get("nodes", [])), "meshes:", len(j.get("meshes", [])))
    for i, n in enumerate(j.get("nodes", [])):
        print(f"  node[{i}] {n.get('name')!r} mesh={n.get('mesh')} children={n.get('children')} t={n.get('translation')} s={n.get('scale')}")
    for i, m in enumerate(j.get("meshes", [])):
        p = m["primitives"][0]
        a = j["accessors"][p["attributes"]["POSITION"]]
        mn, mx = a.get("min"), a.get("max")
        if mn and mx:
            size = [mx[k]-mn[k] for k in range(3)]
            print(f"  mesh[{i}] {m.get('name')!r} size={size} min={mn} max={mx}")
    print("materials:", [m.get("name") for m in j.get("materials", [])])
    print("images:", len(j.get("images", [])))

inspect(Path(r"D:\git\PULSE_DeathRace\models\wheel.glb"))
rp = Path(r"D:\git\PULSE_DeathRace\models\ravage.glb")
if rp.exists():
    inspect(rp)
