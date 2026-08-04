#!/usr/bin/env python3
"""Build non-destructive race LODs that preserve UVs.

Uses face-subset decimation (keeps original vertex attributes for survivors)
instead of vertex clustering (which averaged UVs into garbage).

Writes: models/foo.glb -> models/race_lod/foo.glb
Does NOT overwrite originals.

  python tools/decimate_race_meshes.py --target-faces 50000 models/track-corner.glb
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from pygltflib import (
	GLTF2,
	FLOAT,
	UNSIGNED_INT,
	BufferFormat,
	BufferView,
	Accessor,
)

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "models" / "race_lod"

# Track + decorations only (cars stay full quality in-game).
DEFAULT_PATHS = [
	"models/track-straight.glb",
	"models/track-corner.glb",
	"models/track-finish.glb",
	"models/decoration-empty.glb",
	"models/decoration-forest.glb",
	"models/decoration-watchtower.glb",
	"models/decoration-pitstop.glb",
	"models/decoration-tents.glb",
]


def _blob(gltf: GLTF2) -> bytearray:
	gltf.convert_buffers(BufferFormat.BINARYBLOB)
	raw = gltf.binary_blob()
	if raw is None:
		raise RuntimeError("missing binary blob")
	return bytearray(raw)


def _read_accessor(gltf: GLTF2, blob: bytearray, index: int) -> np.ndarray:
	acc = gltf.accessors[index]
	bv = gltf.bufferViews[acc.bufferView]
	offset = (bv.byteOffset or 0) + (acc.byteOffset or 0)
	comp = {
		5120: (np.int8, 1),
		5121: (np.uint8, 1),
		5122: (np.int16, 2),
		5123: (np.uint16, 2),
		5125: (np.uint32, 4),
		5126: (np.float32, 4),
	}[acc.componentType]
	ncomp = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[acc.type]
	dtype, _ = comp
	arr = np.frombuffer(blob, dtype=dtype, count=acc.count * ncomp, offset=offset)
	return arr.reshape(acc.count, ncomp).copy() if ncomp > 1 else arr.copy()


def _append(blob: bytearray, data: bytes) -> int:
	while len(blob) % 4:
		blob.append(0)
	off = len(blob)
	blob.extend(data)
	return off


def _face_subset_decimate(
	positions: np.ndarray,
	indices: np.ndarray,
	target_faces: int,
	extra_attrs: dict[str, np.ndarray],
) -> tuple[np.ndarray, np.ndarray, dict[str, np.ndarray]]:
	"""Keep a spatial subset of faces; surviving verts keep exact original attrs (UVs).

	Uses denser cells + multi-pass keep so trees/structures don't dissolve into holes.
	"""
	faces = indices.reshape(-1, 3).astype(np.int64)
	n = faces.shape[0]
	if n <= target_faces:
		return positions, indices.astype(np.uint32), extra_attrs

	# Face centroids for spatial stratification.
	cents = (positions[faces[:, 0]] + positions[faces[:, 1]] + positions[faces[:, 2]]) / 3.0
	mins = cents.min(0)
	extent = np.maximum(cents.max(0) - mins, 1e-6)
	# Denser grid → more even coverage of thin props (trees, poles, walls).
	cells_1d = max(int(round((target_faces / 1.2) ** (1.0 / 3.0))), 12)
	res = np.clip(((extent / extent.max()) * cells_1d * 2.2).astype(np.int32), 8, 160)
	norm = (cents - mins) / extent
	keys = np.clip(np.floor(norm * res).astype(np.int32), 0, res - 1)
	cell = keys[:, 0] + keys[:, 1] * (res[0] + 1) + keys[:, 2] * (res[0] + 1) * (res[1] + 1)

	# Prefer larger faces first, then fill remaining budget evenly.
	e1 = positions[faces[:, 1]] - positions[faces[:, 0]]
	e2 = positions[faces[:, 2]] - positions[faces[:, 0]]
	areas = 0.5 * np.linalg.norm(np.cross(e1, e2), axis=1)

	order = np.argsort(-areas)  # large first
	keep_mask = np.zeros(n, dtype=bool)
	unique_cells, inv_all = np.unique(cell, return_inverse=True)
	# First pass: at least a few faces per occupied cell.
	min_per_cell = 3
	counts = np.zeros(len(unique_cells), dtype=np.int32)
	kept = 0
	# Map original index -> cell inverse via order
	inv_ordered = inv_all[order]
	for i in range(n):
		ci = inv_ordered[i]
		if counts[ci] < min_per_cell:
			keep_mask[order[i]] = True
			counts[ci] += 1
			kept += 1
			if kept >= target_faces:
				break

	# Second pass: fill remaining budget by area order (still spatial-aware via cap).
	if kept < target_faces:
		max_per_cell = max(int(np.ceil(target_faces / max(len(unique_cells), 1)) * 2), min_per_cell + 1)
		for i in range(n):
			if keep_mask[order[i]]:
				continue
			ci = inv_ordered[i]
			if counts[ci] >= max_per_cell:
				continue
			keep_mask[order[i]] = True
			counts[ci] += 1
			kept += 1
			if kept >= target_faces:
				break

	# Third pass: if still under budget (sparse cells), take more largest faces.
	if kept < target_faces:
		for i in range(n):
			if keep_mask[order[i]]:
				continue
			keep_mask[order[i]] = True
			kept += 1
			if kept >= target_faces:
				break

	kept_faces = faces[keep_mask]
	if kept_faces.shape[0] == 0:
		kept_faces = faces[: min(target_faces, n)]

	used = np.unique(kept_faces.reshape(-1))
	compact = -np.ones(positions.shape[0], dtype=np.int64)
	compact[used] = np.arange(used.size, dtype=np.int64)
	new_pos = positions[used]
	new_idx = compact[kept_faces].reshape(-1).astype(np.uint32)
	new_extra: dict[str, np.ndarray] = {}
	for name, arr in extra_attrs.items():
		new_extra[name] = arr[used]
	return new_pos, new_idx, new_extra


def _decimate_primitive(gltf: GLTF2, blob: bytearray, prim, target_faces: int) -> bytearray:
	attrs = prim.attributes
	if attrs.POSITION is None:
		return blob
	pos = _read_accessor(gltf, blob, attrs.POSITION).astype(np.float32)
	if prim.indices is None:
		idx = np.arange(pos.shape[0], dtype=np.uint32)
	else:
		idx = _read_accessor(gltf, blob, prim.indices).astype(np.uint32).reshape(-1)

	old_faces = idx.size // 3
	if old_faces <= target_faces:
		print(f"    skip (already {old_faces} faces)")
		return blob

	extra: dict[str, np.ndarray] = {}
	for name, acc_i in (
		("NORMAL", attrs.NORMAL),
		("TEXCOORD_0", attrs.TEXCOORD_0),
		("TEXCOORD_1", attrs.TEXCOORD_1),
		("COLOR_0", attrs.COLOR_0),
		("TANGENT", attrs.TANGENT),
	):
		if acc_i is None:
			continue
		raw = _read_accessor(gltf, blob, acc_i)
		if raw.ndim == 1:
			raw = raw.reshape(-1, 1)
		if raw.shape[0] != pos.shape[0]:
			continue
		extra[name] = raw.astype(np.float32)

	new_pos, new_idx, new_extra = _face_subset_decimate(pos, idx, target_faces, extra)
	print(f"    faces {old_faces}->{new_idx.size//3} verts {pos.shape[0]}->{new_pos.shape[0]} (UV-preserving)")

	pos_off = _append(blob, new_pos.tobytes())
	idx_off = _append(blob, new_idx.tobytes())
	gltf.bufferViews.append(BufferView(buffer=0, byteOffset=pos_off, byteLength=new_pos.nbytes, target=34962))
	pos_bv = len(gltf.bufferViews) - 1
	gltf.bufferViews.append(BufferView(buffer=0, byteOffset=idx_off, byteLength=new_idx.nbytes, target=34963))
	idx_bv = len(gltf.bufferViews) - 1
	gltf.accessors.append(
		Accessor(
			bufferView=pos_bv,
			componentType=FLOAT,
			count=int(new_pos.shape[0]),
			type="VEC3",
			min=new_pos.min(0).tolist(),
			max=new_pos.max(0).tolist(),
		)
	)
	pos_acc = len(gltf.accessors) - 1
	gltf.accessors.append(
		Accessor(bufferView=idx_bv, componentType=UNSIGNED_INT, count=int(new_idx.size), type="SCALAR")
	)
	idx_acc = len(gltf.accessors) - 1
	attrs.POSITION = pos_acc
	prim.indices = idx_acc
	attrs.NORMAL = None
	attrs.TEXCOORD_0 = None
	attrs.TEXCOORD_1 = None
	attrs.TANGENT = None
	attrs.COLOR_0 = None
	for name, data in new_extra.items():
		off = _append(blob, data.tobytes())
		gltf.bufferViews.append(BufferView(buffer=0, byteOffset=off, byteLength=data.nbytes, target=34962))
		bv = len(gltf.bufferViews) - 1
		atype = {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4"}[data.shape[1]]
		gltf.accessors.append(Accessor(bufferView=bv, componentType=FLOAT, count=int(data.shape[0]), type=atype))
		setattr(attrs, name, len(gltf.accessors) - 1)
	return blob


def decimate_glb(src: Path, dst: Path, target_faces: int) -> None:
	print(f"[race_lod] {src.relative_to(ROOT)} -> {dst.relative_to(ROOT)}")
	gltf = GLTF2().load(str(src))
	blob = _blob(gltf)
	for mi, mesh in enumerate(gltf.meshes or []):
		for pi, prim in enumerate(mesh.primitives or []):
			print(f"  mesh{mi}/prim{pi}")
			# Per-primitive budget: split total roughly if multi-surface.
			blob = _decimate_primitive(gltf, blob, prim, target_faces)
	if gltf.buffers:
		gltf.buffers[0].byteLength = len(blob)
	gltf.set_binary_blob(bytes(blob))
	dst.parent.mkdir(parents=True, exist_ok=True)
	gltf.save(str(dst))
	print(f"  wrote {dst.stat().st_size // 1024} KB")


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--target-faces", type=int, default=100000)
	ap.add_argument("paths", nargs="*")
	args = ap.parse_args()
	paths = args.paths or DEFAULT_PATHS
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	for rel in paths:
		src = ROOT / rel
		if not src.exists():
			continue
		try:
			rel_under = src.relative_to(ROOT / "models")
		except ValueError:
			rel_under = Path(src.name)
		dst = OUT_DIR / rel_under
		# Higher budgets so trees/structures stay readable (still far below full mesh).
		# target is per-primitive; multi-surface props get this budget each surface.
		faces = args.target_faces
		name = src.name.lower()
		if "forest" in name:
			faces = max(faces, 220000)  # was ~85k/surface → holes in canopy
		elif "pitstop" in name:
			faces = max(faces, 140000)
		elif "watchtower" in name:
			faces = max(faces, 120000)
		elif "empty" in name:
			faces = max(faces, 120000)
		elif "corner" in name:
			faces = max(faces, 100000)
		elif "finish" in name:
			faces = max(faces, 90000)
		elif "straight" in name:
			faces = max(faces, 70000)
		decimate_glb(src, dst, faces)


if __name__ == "__main__":
	main()
