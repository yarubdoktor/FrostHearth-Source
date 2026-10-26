"""Minimal glTF 2.0 binary (GLB) writer + mesh building helpers (numpy)."""
import json, struct
import numpy as np

# ---------------------------------------------------------------- materials
MATERIALS = [
    {"name": "Snow", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.92}},
    {"name": "Matte", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.85}},
    {"name": "Metal", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.55, "roughnessFactor": 0.45}},
    {"name": "Fire", "pbrMetallicRoughness": {"baseColorFactor": [1, 0.62, 0.3, 1], "metallicFactor": 0.0, "roughnessFactor": 0.6},
     "emissiveFactor": [1.0, 0.45, 0.12], "extensions": {"KHR_materials_emissive_strength": {"emissiveStrength": 4.0}}},
    {"name": "Ice", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.05, "roughnessFactor": 0.12}},
    {"name": "Glow", "pbrMetallicRoughness": {"baseColorFactor": [0.6, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.3},
     "emissiveFactor": [0.35, 0.95, 1.0], "extensions": {"KHR_materials_emissive_strength": {"emissiveStrength": 3.0}}},
    {"name": "Shadow", "pbrMetallicRoughness": {"baseColorFactor": [0, 0, 0, 1], "metallicFactor": 0.0, "roughnessFactor": 1.0},
     "alphaMode": "BLEND"},
]
MAT = {m["name"]: i for i, m in enumerate(MATERIALS)}


class MeshBuilder:
    """Accumulates indexed geometry per material."""

    def __init__(self):
        self.parts = {}  # mat -> [pos list, nrm list, col list, idx list, count]

    def _p(self, mat):
        if mat not in self.parts:
            self.parts[mat] = [[], [], [], [], 0]
        return self.parts[mat]

    def add(self, mat, pos, nrm, col, idx):
        p = self._p(mat)
        p[0].append(np.asarray(pos, np.float32))
        p[1].append(np.asarray(nrm, np.float32))
        c = np.asarray(col, np.float32)
        if c.ndim == 1:
            c = np.tile(c, (len(pos), 1))
        if c.shape[1] == 3:
            c = np.hstack([c, np.ones((len(c), 1), np.float32)])
        p[2].append(c)
        p[3].append(np.asarray(idx, np.uint32) + p[4])
        p[4] += len(pos)

    def add_soup(self, mat, tris, col, xf=None):
        """tris: (n,3,3) triangle soup -> flat shaded."""
        tris = np.asarray(tris, np.float32)
        if xf is not None:
            tris = apply(xf, tris.reshape(-1, 3)).reshape(-1, 3, 3)
        a, b, c = tris[:, 0], tris[:, 1], tris[:, 2]
        n = np.cross(b - a, c - a)
        n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-9
        pos = tris.reshape(-1, 3)
        nrm = np.repeat(n, 3, axis=0)
        self.add(mat, pos, nrm, col, np.arange(len(pos)))

    def merge(self, other, xf=None):
        for mat, (P, N, C, I, cnt) in other.parts.items():
            pos = np.concatenate(P); nrm = np.concatenate(N)
            if xf is not None:
                pos = apply(xf, pos)
                nrm = nrm @ xf[:3, :3].T
                nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-9
            self.add(mat, pos, nrm, np.concatenate(C), np.concatenate(I))

    def empty(self):
        return not self.parts


def apply(xf, pts):
    pts = np.asarray(pts, np.float32)
    return pts @ xf[:3, :3].T + xf[:3, 3]


def T(x=0, y=0, z=0, ry=0.0, s=1.0, sx=None, sy=None, sz=None):
    sx = s if sx is None else sx; sy = s if sy is None else sy; sz = s if sz is None else sz
    c, si = np.cos(ry), np.sin(ry)
    m = np.eye(4, dtype=np.float32)
    m[:3, :3] = np.array([[c, 0, si], [0, 1, 0], [-si, 0, c]]) @ np.diag([sx, sy, sz])
    m[:3, 3] = [x, y, z]
    return m


# ---------------------------------------------------------------- primitive soups (unit-sized)
def box_soup(w, h, d, y0=0.0):
    x, z = w / 2, d / 2
    v = np.array([[-x, y0, -z], [x, y0, -z], [x, y0 + h, -z], [-x, y0 + h, -z],
                  [-x, y0, z], [x, y0, z], [x, y0 + h, z], [-x, y0 + h, z]], np.float32)
    f = [(4, 5, 6), (4, 6, 7), (1, 0, 3), (1, 3, 2), (0, 4, 7), (0, 7, 3), (5, 1, 2), (5, 2, 6), (3, 7, 6), (3, 6, 2)]
    return v[np.array(f)]


def cyl_soup(r0, r1, h, n=8, y0=0.0, cap=True):
    a = np.linspace(0, 2 * np.pi, n, endpoint=False)
    b = np.stack([np.cos(a) * r0, np.full(n, y0), np.sin(a) * r0], 1)
    t = np.stack([np.cos(a) * r1, np.full(n, y0 + h), np.sin(a) * r1], 1)
    tris = []
    for i in range(n):
        j = (i + 1) % n
        tris += [(b[i], t[j], b[j]), (b[i], t[i], t[j])]
        if cap and r1 > 0:
            tris.append((t[i], [0, y0 + h, 0], t[j]))
    return np.array(tris, np.float32)


def cone_soup(r, h, n=8, y0=0.0):
    a = np.linspace(0, 2 * np.pi, n, endpoint=False)
    b = np.stack([np.cos(a) * r, np.full(n, y0), np.sin(a) * r], 1)
    apex = np.array([0, y0 + h, 0], np.float32)
    return np.array([(b[i], apex, b[(i + 1) % n]) for i in range(n)], np.float32)


def octa_soup(r=1.0, jitter=None):
    v = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]], np.float32) * r
    if jitter is not None:
        v = v * jitter
    f = [(0, 2, 4), (4, 2, 1), (1, 2, 5), (5, 2, 0), (4, 3, 0), (1, 3, 4), (5, 3, 1), (0, 3, 5)]
    return v[np.array(f)]


def ring_soup(r0, r1, h, n=24, y0=0.0):
    a = np.linspace(0, 2 * np.pi, n, endpoint=False)
    tris = []
    for i in range(n):
        j = (i + 1) % n
        p = lambda r, k, y: [np.cos(a[k]) * r, y, np.sin(a[k]) * r]
        tris += [(p(r0, i, y0 + h), p(r1, j, y0 + h), p(r1, i, y0 + h)), (p(r0, i, y0 + h), p(r0, j, y0 + h), p(r1, j, y0 + h))]
        tris += [(p(r1, i, y0), p(r1, i, y0 + h), p(r1, j, y0 + h)), (p(r1, i, y0), p(r1, j, y0 + h), p(r1, j, y0))]
        tris += [(p(r0, i, y0), p(r0, j, y0 + h), p(r0, i, y0 + h)), (p(r0, i, y0), p(r0, j, y0), p(r0, j, y0 + h))]
    return np.array(tris, np.float32)


# ---------------------------------------------------------------- GLB writer
class GLB:
    def __init__(self):
        self.bin = bytearray()
        self.views, self.accessors, self.meshes, self.nodes = [], [], [], []
        self.used_ext = set()

    def _view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin += data
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            v["target"] = target
        self.views.append(v)
        return len(self.views) - 1

    def _acc(self, arr, ctype, typ, target, normalized=False, minmax=False):
        view = self._view(arr.tobytes(), target)
        a = {"bufferView": view, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
        if normalized:
            a["normalized"] = True
        if minmax:
            a["min"] = arr.min(0).astype(float).tolist(); a["max"] = arr.max(0).astype(float).tolist()
        self.accessors.append(a)
        return len(self.accessors) - 1

    def add_mesh(self, name, mb: MeshBuilder):
        prims = []
        for mat, (P, N, C, I, cnt) in mb.parts.items():
            pos = np.concatenate(P).astype(np.float32)
            nrm = np.concatenate(N).astype(np.float32)
            col = (np.clip(np.concatenate(C), 0, 1) * 255 + 0.5).astype(np.uint8)
            idx = np.concatenate(I)
            idx = idx.astype(np.uint16) if pos.shape[0] < 65535 else idx.astype(np.uint32)
            prims.append({"attributes": {
                "POSITION": self._acc(pos, 5126, "VEC3", 34962, minmax=True),
                "NORMAL": self._acc(nrm, 5126, "VEC3", 34962),
                "COLOR_0": self._acc(col, 5121, "VEC4", 34962, normalized=True)},
                "indices": self._acc(idx, 5123 if idx.dtype == np.uint16 else 5125, "SCALAR", 34963),
                "material": MAT[mat]})
            if mat in ("Fire", "Glow"):
                self.used_ext.add("KHR_materials_emissive_strength")
        self.meshes.append({"name": name, "primitives": prims})
        return len(self.meshes) - 1

    def add_node(self, name, mesh=None, children=None, translation=None, extras=None):
        n = {"name": name}
        if mesh is not None:
            n["mesh"] = mesh
        if children:
            n["children"] = children
        if translation is not None:
            n["translation"] = [float(v) for v in translation]
        if extras:
            n["extras"] = extras
        self.nodes.append(n)
        return len(self.nodes) - 1

    def save(self, path, roots):
        while len(self.bin) % 4:
            self.bin.append(0)
        gltf = {"asset": {"version": "2.0", "generator": "frost-map-builder"},
                "scene": 0, "scenes": [{"nodes": roots}], "nodes": self.nodes, "meshes": self.meshes,
                "materials": MATERIALS, "accessors": self.accessors, "bufferViews": self.views,
                "buffers": [{"byteLength": len(self.bin)}]}
        self.used_ext.add("KHR_materials_emissive_strength")
        if self.used_ext:
            gltf["extensionsUsed"] = sorted(self.used_ext)
        js = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        while len(js) % 4:
            js += b" "
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A)); f.write(js)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942)); f.write(self.bin)
