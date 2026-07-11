from pathlib import Path

root = Path(__file__).resolve().parents[1]
cells = (root / "tmp" / "gridmap_cells.txt").read_text(encoding="utf-8").strip()
out = root / "scenes" / "tracks_3d" / "TrackDefault.tscn"
out.parent.mkdir(parents=True, exist_ok=True)

scene = f"""[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/tracks_3d/Track3DBase.gd" id="1_script"]
[ext_resource type="MeshLibrary" uid="uid://b6myd2b7l2o2j" path="res://models/Library/mesh-library.tres" id="2_mesh"]

[sub_resource type="PhysicsMaterial" id="PhysicsMaterial_track"]
friction = 0.0
bounce = 0.1

[node name="TrackDefault" type="Node3D"]
script = ExtResource("1_script")
track_display_name = "Starter Circuit"

[node name="GridMap" type="GridMap" parent="."]
transform = Transform3D(0.75, 0, 0, 0, 0.75, 0, 0, 0, 0.75, 0, -0.5, 0)
mesh_library = ExtResource("2_mesh")
physics_material = SubResource("PhysicsMaterial_track")
cell_size = Vector3(9.99, 1, 9.99)
data = {{
"cells": PackedInt32Array({cells})
}}

[node name="SpawnPoint" type="Marker3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3.5, 0.2, 5)
"""

out.write_text(scene, encoding="utf-8")
print("wrote", out, "bytes", out.stat().st_size)
