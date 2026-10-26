"""Builds the 1200x1200 frost strategy map as GLB for Godot 4 + gameplay data JSON.
Run: python3 build_map.py  (outputs into the project folder)
1 tile = 1 metre. Map X -> world +X, Map Y -> world +Z. Y is up.
"""
import json, math, os
import numpy as np
from scipy.ndimage import map_coordinates, binary_dilation
from glb import GLB, MeshBuilder, T, apply, box_soup, cyl_soup, cone_soup, octa_soup, ring_soup

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
os.makedirs(os.path.join(OUT, "assets"), exist_ok=True)
os.makedirs(os.path.join(OUT, "data"), exist_ok=True)
rng = np.random.default_rng(842)

N = 1200
C = N / 2
SP = 4                     # terrain vertex spacing (tiles)
G = N // SP + 1            # 301 vertices per side
R_IN, R_OUT = 165.0, 400.0  # mountain rings
GAPS_IN = np.radians([0, 90, 180, 270])
GAPS_OUT = np.radians(np.arange(8) * 45 + 22.5)


def lin(hexv):
    c = np.array([(hexv >> 16) & 255, (hexv >> 8) & 255, hexv & 255], np.float32) / 255
    return c ** 2.2


TEAM = {"me": 0x4fb4ff, "ally": 0xb57cf5, "enemy": 0xf05050, "neutral": 0xaab4be, "sun": 0xff8a3d}
COL = {k: lin(v) for k, v in dict(stone=0x8e9aa6, stoneD=0x5f6b77, wood=0x7a4b2a, roof=0xf2f6f9, metal=0x3b3f45,
                                  fire=0xffa04d, pine=0x2f5a4a, pineD=0x234538, snow=0xcbd7e2, rock=0x6d7884,
                                  coal=0x2b2b2e, iron=0x9fb7c9, food=0xe9c46a, tent=0xd9c08a, fur=0xe8eef3,
                                  eye=0xff3030, ice=0xa9d6ee, gold=0xe8b44a).items()}
for k, v in TEAM.items():
    COL[k] = lin(v)

# ---------------------------------------------------------------- noise
def hash2(ix, iz, seed):
    h = (ix.astype(np.int64) * 374761393 + iz.astype(np.int64) * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h ^ (h >> 16)) / 4294967295.0


def vnoise(x, z, seed=0):
    xi, zi = np.floor(x), np.floor(z)
    xf, zf = x - xi, z - zi
    u, v = xf * xf * (3 - 2 * xf), zf * zf * (3 - 2 * zf)
    a, b = hash2(xi, zi, seed), hash2(xi + 1, zi, seed)
    c, d = hash2(xi, zi + 1, seed), hash2(xi + 1, zi + 1, seed)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def fbm(x, z, octv=5, seed=0):
    s, amp, f = 0.0, 0.5, 1.0
    for i in range(octv):
        s = s + amp * vnoise(x * f, z * f, seed + i * 17)
        f *= 2; amp *= 0.5
    return s


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def gap_factor(ang, d, gaps, width):
    f = np.ones_like(d)
    for g in gaps:
        da = np.angle(np.exp(1j * (ang - g)))
        f = np.minimum(f, 1 - np.exp(-((np.abs(da) * d) / width) ** 2))
    return f


# ---------------------------------------------------------------- lakes & landmarks
LAKES = []
for i in range(14):
    for _ in range(200):
        a = rng.uniform(0, 2 * np.pi)
        d = rng.uniform(200, 380) if i < 5 else rng.uniform(440, 560)
        x, z = C + np.cos(a) * d, C + np.sin(a) * d
        if not (60 < x < N - 60 and 60 < z < N - 60):
            continue
        r = rng.uniform(10, 22)
        if all(math.hypot(x - lx, z - lz) > lr + r + 40 for lx, lz, lr in LAKES):
            LAKES.append((x, z, r)); break

LANDMARKS = [{"id": "sun_city", "name": "مدينة الشمس", "type": "sun_city", "x": C, "y": C, "r": 12, "ry": 0.0}]
dirs = ["الشمال الشرقي", "الجنوب الشرقي", "الجنوب الغربي", "الشمال الغربي"]
for k in range(4):
    a = np.radians(45 + 90 * k)
    LANDMARKS.append({"id": f"stronghold_{k+1}", "name": f"معقل {dirs[k]}", "type": "stronghold",
                      "x": C + np.cos(a) * 100, "y": C + np.sin(a) * 100, "r": 6, "ry": float(-a)})
fort_names = ["قلعة الجليد", "قلعة العاصفة", "قلعة الصقر", "قلعة الشفق", "قلعة البلّور", "قلعة الذئب", "قلعة الرماد", "قلعة الفجر"]
for k in range(8):
    a = np.radians(45 * k)
    LANDMARKS.append({"id": f"fortress_{k+1}", "name": fort_names[k], "type": "fortress",
                      "x": C + np.cos(a) * 285, "y": C + np.sin(a) * 285, "r": 5, "ry": float(-a)})
for k, g in enumerate(GAPS_IN):
    LANDMARKS.append({"id": f"gate_{k+1}", "name": f"بوابة المركز {k+1}", "type": "gate",
                      "x": C + np.cos(g) * R_IN, "y": C + np.sin(g) * R_IN, "r": 7, "ry": float(-g), "w": 9})
for k, g in enumerate(GAPS_OUT):
    LANDMARKS.append({"id": f"pass_{k+1}", "name": f"ممر الجبل {k+1}", "type": "pass",
                      "x": C + np.cos(g) * R_OUT, "y": C + np.sin(g) * R_OUT, "r": 9, "ry": float(-g), "w": 12})


# ---------------------------------------------------------------- height field
def height_fn(x, z):
    dx, dz = x - C, z - C
    d = np.hypot(dx, dz); ang = np.arctan2(dz, dx)
    h = fbm(x / 70, z / 70, 4, 1) * 0.5 - 0.1
    ridged = 1 - np.abs(fbm(x / 45, z / 45, 4, 7) * 2 - 1)
    var = 0.55 + 0.6 * fbm(x / 30, z / 30, 3, 3)
    # outer ring
    ring_o = np.exp(-((d - R_OUT) / (15 + 6 * fbm(x / 60, z / 60, 2, 9))) ** 2)
    h = h + ring_o * (22 + 14 * ridged) * var * gap_factor(ang, d, GAPS_OUT, 11)
    # inner ring
    ring_i = np.exp(-((d - R_IN) / 9) ** 2)
    h = h + ring_i * (13 + 8 * ridged) * var * gap_factor(ang, d, GAPS_IN, 8)
    # border mountains
    e = np.minimum.reduce([x, z, N - x, N - z])
    h = h + sstep(55, 5, e) * (30 + 22 * ridged) * var
    # scattered mountain clusters (outer & middle zones)
    m = fbm(x / 120 + 50, z / 120 + 50, 4, 21)
    zone = sstep(R_OUT + 35, R_OUT + 60, d) + sstep(R_IN + 30, R_IN + 50, d) * sstep(R_OUT - 35, R_OUT - 60, d)
    keep = gap_factor(ang, d, GAPS_OUT, 30) * gap_factor(ang, d, GAPS_IN, 20)
    h = h + sstep(0.6, 0.78, m) * (10 + 16 * ridged) * var * zone * keep
    # lakes
    for lx, lz, lr in LAKES:
        ld = np.hypot(x - lx, z - lz)
        k = 1 - sstep(lr - 2, lr + 6, ld)
        h = h * (1 - k) + (-1.0) * k
    # flatten landmarks
    for L in LANDMARKS:
        ld = np.hypot(x - L["x"], z - L["y"])
        rr = L["r"] + (4 if L["type"] in ("gate", "pass") else 6)
        k = 1 - sstep(rr, rr + 10, ld)
        h = h * (1 - k) + 0.25 * k
    return h


gx = np.linspace(0, N, G)
GX, GZ = np.meshgrid(gx, gx)          # [row=z, col=x]
H = height_fn(GX, GZ).astype(np.float32)
dHz, dHx = np.gradient(H, SP)
SLOPE = np.hypot(dHx, dHz)


def h_at(x, z):
    return map_coordinates(H, [np.atleast_1d(z) / SP, np.atleast_1d(x) / SP], order=1, mode="nearest")


# tile level fields
tc = np.arange(N) + 0.5
TX, TZ = np.meshgrid(tc, tc)
TH = map_coordinates(H, [TZ / SP, TX / SP], order=1, mode="nearest")
TS = map_coordinates(SLOPE, [TZ / SP, TX / SP], order=1, mode="nearest")
lake_mask = np.zeros((N, N), bool)
for lx, lz, lr in LAKES:
    lake_mask |= np.hypot(TX - lx, TZ - lz) < lr + 4
BLOCK = (TH > 0.9) | (TS > 0.12) | lake_mask
BLOCK[:60, :] = BLOCK[-60:, :] = BLOCK[:, :60] = BLOCK[:, -60:] = True
occ = BLOCK.copy()
for L in LANDMARKS:
    r = int(L["r"] + 6)
    x0, z0 = int(L["x"]), int(L["y"])
    occ[max(0, z0 - r):z0 + r, max(0, x0 - r):x0 + r] = True
# keep pass corridors clear of objects
for g in list(GAPS_OUT) + list(GAPS_IN):
    for d in np.arange(R_IN - 25, R_OUT + 30, 2):
        if R_IN + 25 < d < R_OUT - 30:
            continue
        x, z = int(C + np.cos(g) * d), int(C + np.sin(g) * d)
        occ[z - 5:z + 5, x - 5:x + 5] = True


def try_place(w, dmin, dmax, tries=60):
    for _ in range(tries):
        a = rng.uniform(0, 2 * np.pi); d = math.sqrt(rng.uniform(dmin ** 2, dmax ** 2))
        x = int(C + math.cos(a) * d); z = int(C + math.sin(a) * d)
        if x < 0 or z < 0 or x + w > N or z + w > N:
            continue
        if not occ[z - 1:z + w + 1, x - 1:x + w + 1].any():
            occ[z:z + w, x:x + w] = True
            return x, z
    return None


def zone_of(x, z):
    d = math.hypot(x - C, z - C)
    return 3 if d < R_IN else 2 if d < R_OUT else 1


# ---------------------------------------------------------------- gameplay data
data = {"size": N, "tile": 1.0, "center": [C, C], "rings": [R_IN, R_OUT], "landmarks": [], "resources": [],
        "beasts": [], "cities": [], "lakes": [[round(a, 1), round(b, 1), round(c, 1)] for a, b, c in LAKES]}
home = None
for _ in range(400):
    x, z = int(rng.uniform(760, 800)), int(rng.uniform(820, 860))
    if not occ[z - 1:z + 3, x - 1:x + 3].any():
        occ[z:z + 2, x:x + 2] = True; home = (x, z); break
data["home"] = {"x": home[0] + 1.0, "y": home[1] + 1.0, "n": "مدينتك", "team": "me", "l": 24}

pre = ["حصن", "برج", "قلعة", "معقل", "مخيم", "ملاذ", "ميناء", "وادي"]
suf = ["الجليد", "العاصفة", "الذئاب", "الشفق", "البلّور", "الصقر", "الرماد", "الفجر", "الريح", "الضباب", "الحديد", "النجم"]
tags = {"ally": "[NRD]", "enemy": "[ICE]", "neutral": ""}
for i in range(420):
    zone = rng.choice([1, 2, 3], p=[0.62, 0.33, 0.05])
    rr = {1: (R_OUT + 30, 560), 2: (R_IN + 25, R_OUT - 30), 3: (40, R_IN - 20)}[zone]
    p = try_place(2, *rr)
    if not p:
        continue
    team = rng.choice(["ally", "enemy", "neutral"], p=[0.3, 0.3, 0.4])
    lvl = int(np.clip(rng.normal({1: 12, 2: 20, 3: 27}[zone], 3), 1, 30))
    data["cities"].append({"x": p[0] + 1.0, "y": p[1] + 1.0, "n": f"{tags[team]} {rng.choice(pre)} {rng.choice(suf)}".strip(),
                           "team": str(team), "l": lvl})
RES = ["coal", "wood", "iron", "food"]
for i in range(3600):
    zone = rng.choice([1, 2, 3], p=[0.6, 0.32, 0.08])
    rr = {1: (R_OUT + 30, 580), 2: (R_IN + 25, R_OUT - 30), 3: (35, R_IN - 20)}[zone]
    p = try_place(1, *rr, tries=20)
    if not p:
        continue
    lo, hi = {1: (1, 4), 2: (4, 6), 3: (7, 8)}[zone]
    data["resources"].append({"x": p[0] + 0.5, "y": p[1] + 0.5, "t": RES[i % 4], "l": int(rng.integers(lo, hi + 1))})
for i in range(700):
    zone = rng.choice([1, 2, 3], p=[0.6, 0.32, 0.08])
    rr = {1: (R_OUT + 30, 580), 2: (R_IN + 25, R_OUT - 30), 3: (35, R_IN - 20)}[zone]
    p = try_place(1, *rr, tries=20)
    if not p:
        continue
    base = {1: 5, 2: 15, 3: 25}[zone]
    data["beasts"].append({"x": p[0] + 0.5, "y": p[1] + 0.5, "t": "bear" if i % 3 == 0 else "wolf",
                           "l": int(np.clip(base + rng.integers(0, 8), 1, 30)), "ry": round(float(rng.uniform(0, 6.28)), 2)})
for key in ("resources", "beasts", "cities"):
    for it in data[key]:
        it["h"] = round(float(h_at(it["x"], it["y"])[0]), 2)
data["home"]["h"] = round(float(h_at(data["home"]["x"], data["home"]["y"])[0]), 2)
for L in LANDMARKS:
    L["h"] = float(h_at(L["x"], L["y"])[0])
    data["landmarks"].append({k: (round(v, 2) if isinstance(v, float) else v) for k, v in L.items()})

with open(os.path.join(OUT, "data", "map_data.json"), "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
print("cities", len(data["cities"]), "res", len(data["resources"]), "beasts", len(data["beasts"]), "lakes", len(LAKES))

# ---------------------------------------------------------------- model builders (local, y=0 ground)
def sun_city():
    m = MeshBuilder()
    m.add_soup("Matte", cyl_soup(10.8, 10, 1, 8), COL["stoneD"], T(ry=np.pi / 8))
    m.add_soup("Matte", cyl_soup(7.6, 7.2, .6, 8, y0=1), COL["stone"], T(ry=np.pi / 8))
    for i in range(8):
        a = i / 8 * 2 * np.pi
        tx, tz = np.cos(a) * 9.4, np.sin(a) * 9.4
        m.add_soup("Matte", cyl_soup(1.05, .9, 3.6, 8, y0=1), COL["stone"], T(tx, 0, tz))
        m.add_soup("Matte", cone_soup(1.25, 1.7, 8, y0=4.6), COL["sun"], T(tx, 0, tz))
        na = a + np.pi / 8
        m.add_soup("Matte", box_soup(6.6, 2.2, .7, y0=1), COL["stone"], T(np.cos(na) * 8.7, 0, np.sin(na) * 8.7, ry=-na + np.pi / 2))
    for i in range(6):
        a = i / 6 * 2 * np.pi
        hx, hz = np.cos(a) * 4.8, np.sin(a) * 4.8
        m.add_soup("Matte", box_soup(1.8, 1.4, 1.8, y0=1.6), COL["wood"], T(hx, 0, hz, ry=-a))
        m.add_soup("Matte", cone_soup(1.5, 1.0, 4, y0=3.0), COL["roof"], T(hx, 0, hz, ry=-a + np.pi / 4))
    m.add_soup("Metal", cyl_soup(2.8, 2.2, 4, 12, y0=1.6), COL["metal"])
    m.add_soup("Matte", ring_soup(2.0, 2.6, .3, 16, y0=5.5), COL["stoneD"])
    m.add_soup("Fire", cyl_soup(1.95, 1.95, .35, 12, y0=5.3), COL["fire"])
    m.add_soup("Metal", cyl_soup(.8, .6, 4.2, 10, y0=5.6), COL["metal"])
    for i in range(4):  # banners
        a = i / 4 * 2 * np.pi + np.pi / 4
        m.add_soup("Matte", box_soup(.08, 3, .08), COL["metal"], T(np.cos(a) * 6.2, 1.6, np.sin(a) * 6.2))
        m.add_soup("Matte", box_soup(1.1, .7, .05), COL["sun"], T(np.cos(a) * 6.2 + .55, 3.8, np.sin(a) * 6.2))
    return m


def stronghold(team_col):
    m = MeshBuilder()
    m.add_soup("Matte", box_soup(9, .6, 9), COL["stoneD"])
    for (x, z, w, d) in [(0, 4.2, 8.6, .5), (0, -4.2, 8.6, .5), (4.2, 0, .5, 8.6), (-4.2, 0, .5, 8.6)]:
        m.add_soup("Matte", box_soup(w, 1.6, d, y0=.6), COL["stone"], T(x, 0, z))
    for x, z in [(4.2, 4.2), (-4.2, 4.2), (4.2, -4.2), (-4.2, -4.2)]:
        m.add_soup("Matte", cyl_soup(.85, .75, 3, 8, y0=.6), COL["stone"], T(x, 0, z))
        m.add_soup("Matte", cone_soup(1.0, 1.3, 8, y0=3.6), team_col, T(x, 0, z))
    m.add_soup("Matte", box_soup(3.2, 3.6, 3.2, y0=.6), COL["stone"])
    m.add_soup("Matte", cone_soup(2.6, 2.0, 4, y0=4.2), team_col, T(ry=np.pi / 4))
    m.add_soup("Metal", cyl_soup(.6, .5, 1.2, 8, y0=6.0), COL["metal"])
    m.add_soup("Fire", cyl_soup(.45, .45, .2, 8, y0=7.2), COL["fire"])
    return m


def fortress(team_col):
    m = MeshBuilder()
    m.add_soup("Matte", cyl_soup(5.2, 4.8, .6, 10), COL["stoneD"])
    m.add_soup("Matte", ring_soup(3.8, 4.4, 1.6, 20, y0=.6), COL["stone"])
    for i in range(5):
        a = i / 5 * 2 * np.pi
        m.add_soup("Matte", cyl_soup(.6, .5, 2.4, 8, y0=.6), COL["stone"], T(np.cos(a) * 4.1, 0, np.sin(a) * 4.1))
        m.add_soup("Matte", cone_soup(.75, 1.0, 8, y0=3.0), team_col, T(np.cos(a) * 4.1, 0, np.sin(a) * 4.1))
    m.add_soup("Matte", cyl_soup(1.6, 1.3, 4.2, 8, y0=.6), COL["stone"])
    m.add_soup("Matte", cone_soup(1.9, 1.8, 8, y0=4.8), team_col)
    m.add_soup("Matte", box_soup(.06, 2.2, .06), COL["metal"], T(0, 6.4, 0))
    m.add_soup("Matte", box_soup(1.0, .55, .04), COL["gold"], T(.5, 8.0, 0))
    return m


def gate(width):
    m = MeshBuilder()
    for s in (-1, 1):
        m.add_soup("Matte", box_soup(.9, 2.2, width - 2.4), COL["stone"], T(0, 0, s * (width / 2 + 1.2) / 2 + s * .6))
        m.add_soup("Matte", cyl_soup(1.0, .85, 3.6, 8), COL["stone"], T(0, 0, s * 1.8))
        m.add_soup("Matte", cone_soup(1.15, 1.4, 8, y0=3.6), COL["sun"], T(0, 0, s * 1.8))
        m.add_soup("Matte", cyl_soup(.8, .7, 3.0, 8), COL["stone"], T(0, 0, s * width / 2))
        m.add_soup("Matte", cone_soup(.95, 1.1, 8, y0=3.0), COL["stoneD"], T(0, 0, s * width / 2))
    m.add_soup("Matte", box_soup(.7, 2.6, 2.6), COL["wood"])
    m.add_soup("Matte", box_soup(1.1, .5, 4.4, y0=2.6), COL["stoneD"])
    return m


def city(team):
    m = MeshBuilder(); tc = COL[team]
    m.add_soup("Matte", box_soup(5.2, .4, 5.2), COL["stoneD"])
    for (x, z, w, d) in [(0, 2.4, 5, .35), (0, -2.4, 5, .35), (2.4, 0, .35, 5), (-2.4, 0, .35, 5)]:
        m.add_soup("Matte", box_soup(w, .9, d, y0=.4), COL["stone"], T(x, 0, z))
    for x, z in [(2.4, 2.4), (-2.4, 2.4), (2.4, -2.4), (-2.4, -2.4)]:
        m.add_soup("Matte", cyl_soup(.42, .38, 1.6, 6, y0=.3), COL["stone"], T(x, 0, z))
        m.add_soup("Matte", cone_soup(.5, .6, 6, y0=1.9), tc, T(x, 0, z))
    m.add_soup("Metal", cyl_soup(.95, .75, 1.6, 10, y0=.4), COL["metal"])
    m.add_soup("Fire", cyl_soup(.62, .62, .15, 10, y0=1.98), COL["fire"])
    m.add_soup("Metal", cyl_soup(.25, .2, 1.4, 6, y0=1.9), COL["metal"])
    for x, z in [(1.2, 1.2), (-1.3, 1.1), (1.1, -1.3), (-1.2, -1.2)]:
        m.add_soup("Matte", box_soup(.8, .6, .8, y0=.4), COL["wood"], T(x, 0, z))
        m.add_soup("Matte", cone_soup(.65, .5, 4, y0=1.0), COL["roof"], T(x, 0, z, ry=np.pi / 4))
    m.add_soup("Matte", box_soup(.08, 2.2, .08, y0=.4), COL["metal"], T(-1.8, 0, 1.8))
    m.add_soup("Matte", box_soup(.7, .4, .04), tc, T(-1.45, 2.2, 1.8))
    out = MeshBuilder(); out.merge(m, T(s=0.38)); return out


def resource(kind):
    m = MeshBuilder(); r = np.random.default_rng({"coal": 1, "iron": 2, "wood": 3, "food": 4}[kind])
    if kind in ("coal", "iron"):
        c = COL["coal"] if kind == "coal" else COL["iron"]
        for i in range(6):
            j = r.uniform(.7, 1.3, 3)
            m.add_soup("Matte", octa_soup(r.uniform(.35, .6), j), c, T(r.uniform(-.7, .7), .25, r.uniform(-.7, .7), ry=r.uniform(0, 6)))
        m.add_soup("Matte", box_soup(.9, .45, .6, y0=.1), COL["wood"], T(.95, 0, -.7, ry=.4))
        if kind == "iron":
            for i in range(3):
                m.add_soup("Metal", cone_soup(.15, .8, 5), lin(0x7fc6e8), T(r.uniform(-.4, .4), .3, r.uniform(-.4, .4)))
    elif kind == "wood":
        for i in range(5):
            y = .18 if i < 3 else .5
            zz = (i - 1) * .38 if i < 3 else (i - 3.5) * .38
            m.add_soup("Matte", cyl_soup(.18, .18, 1.7, 7, y0=-.85), COL["wood"], T(0, y, zz) @ np.array([[0, -1, 0, 0], [1, 0, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]], np.float32))
        m.add_soup("Matte", cyl_soup(.3, .26, .45, 8), lin(0x6b3f22), T(1.05, 0, .65))
        m.add_soup("Matte", box_soup(.06, .5, .06), COL["metal"], T(1.05, .45, .65))
    else:  # food
        m.add_soup("Matte", cone_soup(.95, 1.3, 6), COL["tent"])
        m.add_soup("Matte", box_soup(.08, 1.0, .08), COL["wood"], T(1.0, 0, .4))
        m.add_soup("Matte", box_soup(.08, 1.0, .08), COL["wood"], T(1.0, 0, -.4))
        m.add_soup("Matte", box_soup(.06, .06, .9), COL["wood"], T(1.0, .95, 0))
        m.add_soup("Matte", box_soup(.18, .35, .18), lin(0xb5523b), T(1.0, .55, .15))
        m.add_soup("Matte", box_soup(.18, .35, .18), lin(0xb5523b), T(1.0, .55, -.2))
    out = MeshBuilder(); out.merge(m, T(s=0.62)); return out


def beast(kind):
    m = MeshBuilder()
    bodies = [(0, 0, 0, 1.0)] if kind == "bear" else [(-.55, -.25, .5, .55), (.45, -.35, -.4, .55), (.1, .45, 1.9, .55)]
    for bx, bz, ry, s in bodies:
        xf = T(bx, 0, bz, ry=ry, s=s)
        parts = [(box_soup(1.2, .7, .7, y0=.3), COL["fur"]), (box_soup(.5, .45, .45, y0=.6), COL["fur"]),
                 (box_soup(.07, .07, .07, y0=.82), COL["eye"]), (box_soup(.07, .07, .07, y0=.82), COL["eye"])]
        offs = [(0, 0), (.75, 0), (1.0, .12), (1.0, -.12)]
        for (soup, c), (ox, oz) in zip(parts, offs):
            m.add_soup("Matte" if c is not COL["eye"] else "Fire", soup, c, xf @ T(ox, 0, oz))
        for x, z in [(.4, .22), (.4, -.22), (-.4, .22), (-.4, -.22)]:
            m.add_soup("Matte", box_soup(.2, .32, .2), COL["fur"], xf @ T(x, 0, z))
    out = MeshBuilder(); out.merge(m, T(s=0.7)); return out


def troop():
    m = MeshBuilder()
    for x, z in [(0, 0), (-.5, .35), (-.5, -.35), (-1.0, 0)]:
        m.add_soup("Matte", cyl_soup(.16, .13, .5, 6), COL["me"], T(x, 0, z))
        m.add_soup("Matte", octa_soup(.13), lin(0xf1d2b3), T(x, .62, z))
    m.add_soup("Matte", box_soup(.04, 1.2, .04), COL["metal"], T(.15, 0, 0))
    m.add_soup("Matte", box_soup(.45, .28, .03), COL["me"], T(-.08, .95, 0))
    return m


# ---------------------------------------------------------------- terrain + forest chunks
def terrain_colors():
    shade = fbm(GX / 9, GZ / 9, 3, 33)
    c = COL["snow"] * (1 - shade[..., None] * .35) + lin(0xa9bccd) * (shade[..., None] * .35)
    rockk = sstep(.35, .9, SLOPE)[..., None] * .9
    c = c * (1 - rockk) + COL["rock"] * rockk
    hi = sstep(14, 24, H)[..., None] * .75 * (1 - sstep(.9, 1.4, SLOPE))[..., None]
    c = c * (1 - hi) + COL["snow"] * hi
    shore = np.zeros_like(H)
    for lx, lz, lr in LAKES:
        ld = np.hypot(GX - lx, GZ - lz)
        shore = np.maximum(shore, 1 - sstep(lr + 2, lr + 10, ld))
    c = c * (1 - shore[..., None] * .5) + lin(0xd6e8f2) * shore[..., None] * .5
    # subtle zone tint (centre warmer)
    d = np.hypot(GX - C, GZ - C)
    warm = (1 - sstep(R_IN - 20, R_IN, d))[..., None] * .12
    c = c * (1 - warm) + lin(0xf3e6d8) * warm
    return c


TC = terrain_colors()
nz = np.stack([-dHx, np.ones_like(H), -dHz], -1)
NRM = nz / np.linalg.norm(nz, axis=-1, keepdims=True)

# tree template (indexed cones, smooth) -------------------------------
def cone_indexed(r, h, y0, n, cb, ca):
    a = np.linspace(0, 2 * np.pi, n, endpoint=False)
    pos = np.concatenate([np.stack([np.cos(a) * r, np.full(n, y0), np.sin(a) * r], 1), [[0, y0 + h, 0]]])
    nrm = np.concatenate([np.stack([np.cos(a) * h, np.full(n, r), np.sin(a) * h], 1), [[0, 1, 0]]])
    nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
    col = np.concatenate([np.tile(cb, (n, 1)), [ca]])
    idx = np.array([[i, n, (i + 1) % n] for i in range(n)]).ravel()
    return pos, nrm, col, idx

tp1 = cone_indexed(.48, .95, .02, 6, COL["pineD"], COL["pine"])
tp2 = cone_indexed(.34, .8, .6, 6, COL["pine"], COL["snow"])
TREE_P = np.concatenate([tp1[0], tp2[0]]).astype(np.float32)
TREE_N = np.concatenate([tp1[1], tp2[1]]).astype(np.float32)
TREE_C = np.concatenate([tp1[2], tp2[2]]).astype(np.float32)
TREE_I = np.concatenate([tp1[3], tp2[3] + len(tp1[0])])

# tree positions
cand = rng.uniform(62, N - 62, (260000, 2))
fx, fz = cand[:, 0], cand[:, 1]
dens = fbm(fx / 55 + 5, fz / 55 + 5, 4, 41)
ti = np.clip(fz.astype(int), 0, N - 1), np.clip(fx.astype(int), 0, N - 1)
occ_d = binary_dilation(occ & ~BLOCK, iterations=1)
ok = (dens > 0.56) & (~occ_d[ti]) & (~lake_mask[ti]) & (TH[ti] < 9) & (TS[ti] < .55)
ok &= rng.uniform(0, 1, len(ok)) < sstep(.56, .7, dens) * 0.9 + 0.1
trees = cand[ok][:22000]
print("trees", len(trees))
tree_h = h_at(trees[:, 0], trees[:, 1])
tree_s = rng.uniform(.65, 1.35, len(trees))
tree_r = rng.uniform(0, 2 * np.pi, len(trees))

# rocks on foothills
cand = rng.uniform(62, N - 62, (60000, 2))
ti = np.clip(cand[:, 1].astype(int), 0, N - 1), np.clip(cand[:, 0].astype(int), 0, N - 1)
okr = (TH[ti] > .6) & (TH[ti] < 12) & (~occ_d[ti] | BLOCK[ti])
rocks = cand[okr][:2600]
rock_h = h_at(rocks[:, 0], rocks[:, 1])
print("rocks", len(rocks))

CH = 12
CS = N // CH
glb = GLB()
chunk_nodes = []
cells = CS // SP
for r in range(CH):
    for c in range(CH):
        mb = MeshBuilder()
        i0, j0 = r * cells, c * cells
        sub = (slice(i0, i0 + cells + 1), slice(j0, j0 + cells + 1))
        px, pz, ph = GX[sub], GZ[sub], H[sub]
        pos = np.stack([px, ph, pz], -1).reshape(-1, 3)
        n = cells + 1
        ii = np.arange(cells)
        a = (ii[:, None] * n + ii[None, :]).ravel()
        idx = np.stack([a, a + n, a + 1, a + 1, a + n, a + n + 1], 1).ravel()
        mb.add("Snow", pos, NRM[sub].reshape(-1, 3), TC[sub].reshape(-1, 3), idx)
        x0, z0 = c * CS, r * CS
        sel = (trees[:, 0] >= x0) & (trees[:, 0] < x0 + CS) & (trees[:, 1] >= z0) & (trees[:, 1] < z0 + CS)
        if sel.any():
            tp, th, ts, tr = trees[sel], tree_h[sel], tree_s[sel], tree_r[sel]
            k = len(tp)
            cs, sn = np.cos(tr), np.sin(tr)
            P = TREE_P[None] * ts[:, None, None]
            Px = P[..., 0] * cs[:, None] + P[..., 2] * sn[:, None]
            Pz = -P[..., 0] * sn[:, None] + P[..., 2] * cs[:, None]
            Pw = np.stack([Px + tp[:, 0:1], P[..., 1] + th[:, None] - .05, Pz + tp[:, 1:2]], -1)
            Nx = TREE_N[None, :, 0] * cs[:, None] + TREE_N[None, :, 2] * sn[:, None]
            Nz = -TREE_N[None, :, 0] * sn[:, None] + TREE_N[None, :, 2] * cs[:, None]
            Nw = np.stack([Nx, np.broadcast_to(TREE_N[None, :, 1], Nx.shape), Nz], -1)
            shade = rng.uniform(.85, 1.1, (k, 1, 1))
            Cw = np.clip(TREE_C[None] * shade, 0, 1)
            I = (TREE_I[None] + (np.arange(k) * len(TREE_P))[:, None]).ravel()
            mb.add("Matte", Pw.reshape(-1, 3), Nw.reshape(-1, 3), Cw.reshape(-1, 3), I)
        sel = (rocks[:, 0] >= x0) & (rocks[:, 0] < x0 + CS) & (rocks[:, 1] >= z0) & (rocks[:, 1] < z0 + CS)
        for (rx, rz), rh in zip(rocks[sel], rock_h[sel]):
            s = rng.uniform(.3, 1.1)
            mb.add_soup("Matte", octa_soup(1, rng.uniform(.6, 1.4, 3)), COL["rock"] * rng.uniform(.8, 1.15), T(rx, rh, rz, ry=rng.uniform(0, 6), s=s))
        mi = glb.add_mesh(f"Chunk_{r}_{c}", mb)
        chunk_nodes.append(glb.add_node(f"Chunk_{r}_{c}", mesh=mi))
terrain_root = glb.add_node("Terrain", children=chunk_nodes)

lake_nodes = []
for i, (lx, lz, lr) in enumerate(LAKES):
    mb = MeshBuilder()
    k = 40; a = np.linspace(0, 2 * np.pi, k, endpoint=False)
    rr = (lr + 3.5) * (1 + .08 * np.sin(a * 3 + i))
    pos = np.concatenate([[[0, 0, 0]], np.stack([np.cos(a) * rr, np.zeros(k), np.sin(a) * rr], 1)])
    idx = np.array([[0, (j + 1) % k + 1, j + 1] for j in range(k)]).ravel()
    mb.add("Ice", pos, np.tile([0, 1, 0], (k + 1, 1)), np.tile(COL["ice"], (k + 1, 1)), idx)
    lake_nodes.append(glb.add_node(f"Lake_{i+1}", mesh=glb.add_mesh(f"Lake_{i+1}", mb), translation=[lx, -0.3, lz]))
lakes_root = glb.add_node("Lakes", children=lake_nodes)

lm_nodes = []
cache = {}
for L in LANDMARKS:
    t = L["type"]
    key = (t, L.get("w"))
    if key not in cache:
        mb = {"sun_city": sun_city, "stronghold": lambda: stronghold(COL["neutral"]), "fortress": lambda: fortress(COL["neutral"]),
              "gate": lambda: gate(L["w"]), "pass": lambda: gate(L["w"])}[t]()
        cache[key] = glb.add_mesh(t if t != "pass" else "pass_gate", mb)
    node = glb.add_node(L["id"], mesh=cache[key], translation=[L["x"], L["h"] - .05, L["y"]], extras={"name": L["name"], "type": t})
    q = L["ry"]  # rotation about Y
    glb.nodes[node]["rotation"] = [0.0, float(np.sin(q / 2)), 0.0, float(np.cos(q / 2))]
    lm_nodes.append(node)
lm_root = glb.add_node("Landmarks", children=lm_nodes)
root = glb.add_node("FrostMap_1200", children=[terrain_root, lakes_root, lm_root], extras={"size": N, "tile": 1})
glb.save(os.path.join(OUT, "assets", "frost_map.glb"), [root])


def save_asset(name, mb):
    g = GLB(); n = g.add_node(name, mesh=g.add_mesh(name, mb)); g.save(os.path.join(OUT, "assets", f"{name}.glb"), [n])


for team in ["me", "ally", "enemy", "neutral"]:
    save_asset(f"city_{team}", city(team))
for k in RES:
    save_asset(f"res_{k}", resource(k))
save_asset("beast_wolf", beast("wolf"))
save_asset("beast_bear", beast("bear"))
save_asset("troop", troop())
save_asset("sun_city", sun_city())
save_asset("fortress", fortress(COL["neutral"]))
save_asset("stronghold", stronghold(COL["neutral"]))
for f in sorted(os.listdir(os.path.join(OUT, "assets"))):
    print(f, round(os.path.getsize(os.path.join(OUT, "assets", f)) / 1e6, 2), "MB")
