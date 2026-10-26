"""Builds the city (base) 3D assets as GLB for Godot 4.
Run: python3 build_city.py   -> ../assets/city/*.glb
City space: 120 x 120 metres, furnace at (60, 60). Y is up. Models face +Z.
"""
import os
import numpy as np
from glb import GLB, MeshBuilder, T, box_soup, cyl_soup, cone_soup, octa_soup, ring_soup
from city_style import roof_snow, contact_shadow, timber_frame, chimney_snow, SNOW_WHITE

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "city")
os.makedirs(OUT, exist_ok=True)


def lin(h):
    return (np.array([(h >> 16) & 255, (h >> 8) & 255, h & 255], np.float32) / 255) ** 2.2


C = {k: lin(v) for k, v in dict(
    snow=0xcbd7e2, snowD=0xa9bccd, path=0x8a8f96, stone=0x8e9aa6, stoneD=0x5f6b77, wood=0x7a4b2a, woodL=0xa36a3e,
    woodD=0x4e2f1a, roof=0x5d6d7e, roofD=0x46545f, metal=0x3b3f45, metalL=0x6c737c, fire=0xffa04d, pine=0x2f5a4a, rock=0x6d7884,
    coal=0x2b2b2e, iron=0x86b6d6, meat=0xb5523b, canvas=0xd9c08a, red=0xd33f3f, blue=0x4fb4ff, gold=0xe8b44a,
    coat=0x3d6e9e, coat2=0x9e4a3d, skin=0xf1d2b3, white=0xf4f6f8, glass=0xffd38a).items()}

ROT_X = np.array([[1, 0, 0, 0], [0, 0, -1, 0], [0, 1, 0, 0], [0, 0, 0, 1]], np.float32)   # y->z
ROT_Z = np.array([[0, -1, 0, 0], [1, 0, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]], np.float32)   # y->-x


def save(name, mb):
    g = GLB()
    n = g.add_node(name, mesh=g.add_mesh(name, mb))
    g.save(os.path.join(OUT, f"{name}.glb"), [n])


def roof_gable(m, w, d, h, y0, col, xf=np.eye(4, dtype=np.float32), snow=True, ridge=True):
    """Triangular prism roof along X — slate surface + snow caps + wooden ridge beam (Stage 32)."""
    x, z = w / 2, d / 2
    v = np.array([[-x, y0, -z], [x, y0, -z], [x, y0, z], [-x, y0, z], [-x, y0 + h, 0], [x, y0 + h, 0]], np.float32)
    f = [(0, 4, 5), (0, 5, 1), (3, 2, 5), (3, 5, 4), (0, 3, 4), (1, 5, 2)]
    m.add_soup("Matte", v[np.array(f)], col, xf)
    if ridge:
        m.add_soup("Matte", box_soup(w + .06, .09, .14, y0=y0 + h - .04), C["woodD"], xf)
    if snow:
        # غطاء ثلجي فوق الميلين + حرف علوية — يُبنى في إحداثيات السقف ثم يُحوَّل
        sm = MeshBuilder()
        roof_snow(sm, w, d, h, y0, seed=int(abs(x0_hash(w, d, h, y0))) % 999)
        m.merge(sm, xf)


def x0_hash(*vals):
    return hash(tuple(round(float(v), 3) for v in vals))


def window(m, x, y, z, ry=0.0, s=1.0):
    m.add_soup("Fire", box_soup(.36 * s, .4 * s, .05), C["glass"], T(x, y, z, ry=ry))


# ================================================================ buildings (3 visual tiers)
def furnace(t):
    m = MeshBuilder()
    r = 4.2 + t * .6
    contact_shadow(m, r + 2.6, seed=31 + t)
    m.add_soup("Matte", cyl_soup(r + 1.2, r + 1.0, .5, 10), C["stoneD"], T(ry=np.pi / 10))
    m.add_soup("Matte", cyl_soup(r, r - .3, 1.4, 10, y0=.5), C["stone"], T(ry=np.pi / 10))
    # المرحلة 32: جمر متوهّج حول القاعدة
    m.add_soup("Fire", ring_soup(r * .8, r * .95, .12, 20, y0=.52), C["fire"], T(ry=np.pi / 10))
    h = 3.5 + t * 1.6
    m.add_soup("Metal", cyl_soup(r * .62, r * .5, h, 14, y0=1.9), C["metal"])
    for k in range(2 + t):
        m.add_soup("Metal", ring_soup(r * .5, r * .66, .25, 18, y0=2.4 + k * 1.3), C["metalL"])
    top = 1.9 + h
    m.add_soup("Matte", ring_soup(r * .42, r * .6, .35, 16, y0=top), C["stoneD"])
    m.add_soup("Fire", cyl_soup(r * .44, r * .44, .45, 16, y0=top - .1), C["fire"])
    m.add_soup("Metal", cyl_soup(.7 + t * .1, .55, 3.5 + t, 10, y0=top), C["metal"])
    # furnace doors with fire glow
    for a in range(4):
        ang = a * np.pi / 2 + np.pi / 4
        m.add_soup("Fire", box_soup(1.2, 1.1, .2), C["fire"], T(np.cos(ang) * r * .6, 2.0, np.sin(ang) * r * .6, ry=-ang + np.pi / 2))
    # pipes and coal heaps
    for a in range(3 + t):
        ang = a / (3 + t) * 2 * np.pi
        px, pz = np.cos(ang) * (r * .9), np.sin(ang) * (r * .9)
        m.add_soup("Metal", cyl_soup(.25, .25, 2.4 + t * .5, 6, y0=1.9), C["metalL"], T(px, 0, pz))
        m.add_soup("Metal", cyl_soup(.35, .35, .3, 6, y0=4.2 + t * .5), C["metal"], T(px, 0, pz))
    for k in range(4):
        ang = k * np.pi / 2
        m.add_soup("Matte", octa_soup(.6, np.array([1.3, .6, 1.1])), C["coal"], T(np.cos(ang) * (r + .6), .5, np.sin(ang) * (r + .6)))
    if t >= 2:
        for a in range(6):
            ang = a / 6 * 2 * np.pi
            m.add_soup("Matte", cyl_soup(.5, .45, 2.2, 8, y0=.5), C["stone"], T(np.cos(ang) * (r - .1), 0, np.sin(ang) * (r - .1)))
            m.add_soup("Matte", cone_soup(.65, .8, 8, y0=2.7), C["gold"], T(np.cos(ang) * (r - .1), 0, np.sin(ang) * (r - .1)))
    return m


def shelter(t):
    m = MeshBuilder()
    if t == 0:
        contact_shadow(m, 2.1, seed=1)
        m.add_soup("Matte", cone_soup(1.5, 2.2, 6), C["canvas"])
        m.add_soup("Matte", cone_soup(.9, .5, 6, y0=1.75), C["roof"])
        m.add_soup("Snow", cone_soup(.95, .28, 6, y0=1.9), SNOW_WHITE)
        m.add_soup("Matte", box_soup(.06, 2.6, .06), C["woodD"])
        m.add_soup("Matte", box_soup(.5, .8, .1), C["woodD"], T(0, 0, 1.25))
    else:
        w, d, h = (2.6, 2.2, 1.4) if t == 1 else (3.0, 2.6, 1.9)
        contact_shadow(m, (w + d) * .38 + .6, seed=2 + t)
        m.add_soup("Matte", box_soup(w + .3, .25, d + .3), C["stoneD"])
        m.add_soup("Matte", box_soup(w, h, d, y0=.25), C["wood"] if t == 1 else C["stone"])
        timber_frame(m, w, h, d, .25, C["wood"], C["woodD"])
        roof_gable(m, w + .5, d + .6, 1.2, .25 + h, C["roof"])
        m.add_soup("Matte", box_soup(.6, .95, .08), C["woodD"], T(0, .25, d / 2 + .02))
        window(m, -w * .3, .25 + h * .55, d / 2 + .03)
        window(m, w * .3, .25 + h * .55, d / 2 + .03)
        m.add_soup("Matte", box_soup(.35, 1.0, .35, y0=.25 + h + .3), C["stoneD"], T(w * .3, 0, -d * .2))
        if t == 2:
            m.add_soup("Matte", box_soup(.9, .4, .9, y0=.25), C["woodL"], T(-w / 2 - .7, 0, .4))
            chimney_snow(m, -w * .38, -d * .1, .9, .25 + h + 1.0, C["stoneD"], seed=5)
    return m


def hunter(t):
    m = MeshBuilder()
    s = 1 + t * .15
    contact_shadow(m, 3.1 * s, seed=7)
    m.add_soup("Matte", box_soup(2.4 * s, .2, 2.0 * s), C["woodD"])
    m.add_soup("Matte", box_soup(2.0 * s, 1.3 * s, 1.6 * s, y0=.2), C["woodL"])
    roof_gable(m, 2.5 * s, 2.1 * s, 1.0 * s, .2 + 1.3 * s, C["roof"])
    m.add_soup("Matte", box_soup(.5, .8, .08), C["woodD"], T(0, .2, .8 * s + .02))
    # drying rack with meat
    for x in (1.7, 2.9):
        m.add_soup("Matte", box_soup(.08, 1.3, .08), C["woodD"], T(x * s, 0, .4))
    m.add_soup("Matte", box_soup(1.3 * s, .06, .06), C["woodD"], T(2.3 * s, 1.25, .4))
    for k in range(2 + t):
        m.add_soup("Matte", box_soup(.18, .4, .12), C["meat"], T((1.9 + k * .32) * s, .85, .4))
    # antlers on roof
    m.add_soup("Matte", box_soup(.08, .5, .08), C["white"], T(-.2, .2 + 2.3 * s, .9 * s))
    m.add_soup("Matte", box_soup(.08, .5, .08), C["white"], T(.2, .2 + 2.3 * s, .9 * s))
    if t >= 1:
        m.add_soup("Matte", cyl_soup(.35, .3, .5, 8), C["woodD"], T(-1.7 * s, 0, .6))
    return m


def sawmill(t):
    m = MeshBuilder()
    s = 1 + t * .15
    contact_shadow(m, 4.0 * s, seed=9)
    m.add_soup("Matte", box_soup(3.4 * s, .2, 2.4 * s), C["woodD"])
    for x in (-1.5, 1.5):
        for z in (-1.0, 1.0):
            m.add_soup("Matte", box_soup(.15, 1.8 * s, .15, y0=.2), C["wood"], T(x * s, 0, z * s))
    roof_gable(m, 3.6 * s, 2.6 * s, .9, .2 + 1.8 * s, C["roof"])
    m.add_soup("Matte", box_soup(2.2 * s, .6, .5, y0=.2), C["woodD"], T(0, 0, 0))
    m.add_soup("Metal", cyl_soup(.6, .6, .06, 16, y0=-.03), C["metalL"], T(0, .9, 0) @ ROT_X)
    for k in range(3 + t * 2):
        y = .35 + (k % 3) * .36
        zz = 1.7 * s + (k // 3) * .45
        m.add_soup("Matte", cyl_soup(.18, .18, 2.2, 7, y0=-1.1), C["woodL"], T(-.2, y, zz) @ ROT_Z)
    return m


def coal_mine(t, ore="coal"):
    m = MeshBuilder()
    s = 1 + t * .15
    oc = C["coal"] if ore == "coal" else C["iron"]
    contact_shadow(m, 3.4 * s, seed=11)
    m.add_soup("Matte", octa_soup(2.0 * s, np.array([1.3, .9, 1.0])), C["rock"], T(0, .2, -.6))
    m.add_soup("Matte", octa_soup(1.2 * s, np.array([1.0, .8, 1.0])), C["stoneD"], T(1.3 * s, .1, -.9))
    m.add_soup("Matte", box_soup(1.4, 1.5, .5), C["woodD"], T(0, 0, .9 * s))
    m.add_soup("Matte", box_soup(1.0, 1.1, .52), C["coal"], T(0, 0, .92 * s))
    m.add_soup("Matte", box_soup(1.7, .2, .55, y0=1.5), C["wood"], T(0, 0, .9 * s))
    # rails + cart
    for x in (-.3, .3):
        m.add_soup("Metal", box_soup(.06, .05, 2.4), C["metalL"], T(x, 0, 2.0 * s))
    m.add_soup("Metal", box_soup(.8, .45, .6, y0=.12), C["metal"], T(0, 0, 2.3 * s))
    m.add_soup("Matte", octa_soup(.3, np.array([1.2, .7, 1])), oc, T(0, .6, 2.3 * s))
    for k in range(2 + t):
        m.add_soup("Matte", octa_soup(.45, np.array([1.2, .7, 1.1])), oc, T(-1.6 * s + k * .5, .25, 1.4 * s))
    if ore == "iron":
        m.add_soup("Matte", box_soup(.15, 2.6 * s, .15), C["wood"], T(1.6 * s, 0, 1.2 * s))
        m.add_soup("Matte", box_soup(1.4, .12, .12), C["wood"], T(1.1 * s, 2.5 * s, 1.2 * s))
        for k in range(3):
            m.add_soup("Metal", cone_soup(.14, .7, 5), C["iron"], T(-1.2 + k * .4, .4, -.0 + .4 * s))
    return m


def storehouse(t):
    m = MeshBuilder()
    s = 1 + t * .2
    w, d, h = 3.6 * s, 2.6 * s, 1.6 * s
    contact_shadow(m, (w + d) * .34 + .5, seed=13)
    m.add_soup("Matte", box_soup(w + .4, .25, d + .4), C["stoneD"])
    m.add_soup("Matte", box_soup(w, h, d, y0=.25), C["wood"])
    timber_frame(m, w, h, d, .25, C["wood"], C["woodD"])
    roof_gable(m, w + .4, d + .5, 1.3 * s, .25 + h, C["roof"])
    chimney_snow(m, -w * .34, -d * .1, .8, .25 + h + 1.1, C["stoneD"], seed=15)
    m.add_soup("Matte", box_soup(1.2, 1.2, .08), C["woodD"], T(0, .25, d / 2 + .02))
    m.add_soup("Matte", box_soup(1.25, .08, .1), C["woodL"], T(0, .85, d / 2 + .05))
    for k in range(3 + t * 2):
        m.add_soup("Matte", box_soup(.6, .6, .6), C["woodL"], T(-w / 2 - .5 + (k % 2) * .1, (k // 2) * .6, d / 2 - .2 - (k % 2) * .7))
    for k in range(2 + t):
        m.add_soup("Matte", cyl_soup(.3, .3, .8, 8), C["woodD"], T(w / 2 + .5, 0, d / 2 - .3 - k * .7))
    return m


def infirmary(t):
    m = MeshBuilder()
    s = 1 + t * .15
    if t == 0:
        contact_shadow(m, 2.1, seed=17)
        m.add_soup("Matte", box_soup(2.6, .15, 2.0), C["woodD"])
        roof_gable(m, 2.6, 2.0, 1.6, .15, C["white"])
    else:
        w, d, h = 3.0 * s, 2.2 * s, 1.5 * s
        contact_shadow(m, (w + d) * .36 + .5, seed=18 + t)
        m.add_soup("Matte", box_soup(w + .3, .2, d + .3), C["stoneD"])
        m.add_soup("Matte", box_soup(w, h, d, y0=.2), C["white"])
        timber_frame(m, w, h, d, .2, C["white"], C["woodD"])
        roof_gable(m, w + .4, d + .5, 1.0, .2 + h, C["roof"])
        window(m, -w * .3, .2 + h * .55, d / 2 + .03)
        window(m, w * .3, .2 + h * .55, d / 2 + .03)
        m.add_soup("Matte", box_soup(.6, 1.0, .08), C["woodD"], T(0, .2, d / 2 + .02))
    y = 1.85 if t == 0 else .2 + 1.5 * s + 1.1
    m.add_soup("Matte", box_soup(.9, .25, .1), C["red"], T(0, y, .0))
    m.add_soup("Matte", box_soup(.25, .9, .1), C["red"], T(0, y - .32, .0))
    m.add_soup("Matte", box_soup(.08, 2.4, .08), C["woodD"], T(1.8 * s, 0, .9))
    m.add_soup("Matte", box_soup(.6, .4, .04), C["red"], T(1.5 * s, 2.0, .9))
    return m


BUILDERS = {"furnace": furnace, "shelter": shelter, "hunter": hunter, "sawmill": sawmill,
            "coal_mine": coal_mine, "iron_mine": lambda t: coal_mine(t, "iron"),
            "storehouse": storehouse, "infirmary": infirmary}


def plot():
    m = MeshBuilder()
    contact_shadow(m, 2.4, seed=21)
    m.add_soup("Snow", cyl_soup(1.9, 1.8, .08, 8), C["snowD"], T(ry=np.pi / 8))
    for k in range(4):
        a = k * np.pi / 2 + np.pi / 4
        m.add_soup("Matte", box_soup(.12, .6, .12), C["woodD"], T(np.cos(a) * 1.6, 0, np.sin(a) * 1.6))
        m.add_soup("Matte", box_soup(.2, .1, .2), C["blue"], T(np.cos(a) * 1.6, .6, np.sin(a) * 1.6))
    return m


def scaffold():
    m = MeshBuilder()
    contact_shadow(m, 2.5, seed=23)
    for x in (-1.4, 1.4):
        for z in (-1.4, 1.4):
            m.add_soup("Matte", box_soup(.1, 2.6, .1), C["woodL"], T(x, 0, z))
    for y in (.9, 1.8, 2.6):
        for (x, z, w, d) in [(0, 1.4, 2.9, .08), (0, -1.4, 2.9, .08), (1.4, 0, .08, 2.9), (-1.4, 0, .08, 2.9)]:
            m.add_soup("Matte", box_soup(w, .08, d, y0=y), C["woodL"], T(x, 0, z))
    m.add_soup("Matte", box_soup(.8, .4, .5), C["woodD"], T(1.9, 0, 1.0))
    m.add_soup("Matte", octa_soup(.4, np.array([1.3, .6, 1])), C["stone"], T(-1.9, .2, .8))
    m.add_soup("Matte", box_soup(.6, .12, .6), C["gold"], T(0, 2.7, 0))
    return m


def citizen(col):
    m = MeshBuilder()
    # المرحلة 32: مواطن بأطراف ووشاح — بلا كبسولات عائمة
    m.add_soup("Matte", box_soup(.07, .18, .07, y0=0), C["woodD"], T(-.06, 0, 0))
    m.add_soup("Matte", box_soup(.07, .18, .07, y0=0), C["woodD"], T(.06, 0, 0))
    m.add_soup("Matte", cyl_soup(.16, .13, .38, 6, y0=.18), col)
    m.add_soup("Matte", box_soup(.05, .2, .05, y0=.2), col, T(-.15, 0, 0))
    m.add_soup("Matte", box_soup(.05, .2, .05, y0=.2), col, T(.15, 0, 0))
    m.add_soup("Matte", octa_soup(.11), C["skin"], T(0, .56, 0))
    m.add_soup("Matte", cone_soup(.13, .15, 6, y0=.6), col)
    m.add_soup("Matte", box_soup(.2, .05, .12, y0=.5), C["red"], T(0, 0, .02))
    return m


def heightfield(rng):
    """Terrain shared by ground() and the wall rings. Returns xs, GX, GZ, H, noise, d."""
    N = 161
    xs = np.linspace(-20, 140, N)
    GX, GZ = np.meshgrid(xs, xs)
    d = np.hypot(GX - 60, GZ - 60)
    noise = np.zeros_like(GX)
    for f, a in [(.05, 1), (.11, .5), (.23, .25)]:
        ph = rng.uniform(0, 6, 2)
        noise += a * np.sin(GX * f + ph[0]) * np.cos(GZ * f * 1.3 + ph[1])
    k = np.clip((d - 50) / 30, 0, 1)
    H = k * k * (6 + 10 * (noise + 1)) + np.clip((d - 72) / 10, 0, 1) * 8 * (noise + 1.2)
    H += (noise * .15) * (d > 46)
    return xs, GX, GZ, H, noise, d


def ground():
    """Heightfield 160x160 (from -20 to 140), flat inside r<44, hills outside, trees, paths. (The wall ring is a separate model since Stage 26.)"""
    rng = np.random.default_rng(7)
    N = 161
    xs, GX, GZ, H, noise, d = heightfield(rng)
    # colors
    col = np.tile(C["snow"], (N, N, 1))
    col = col * (1 - .25 * (noise[..., None] + 1) / 2) + C["snowD"] * (.25 * (noise[..., None] + 1) / 2)
    dHz, dHx = np.gradient(H, xs, xs)
    slope = np.hypot(dHx, dHz)
    rk = np.clip((slope - .5) / .6, 0, .85)[..., None]
    col = col * (1 - rk) + C["rock"] * rk
    # paths: ring roads + radial roads to the gate
    ang = np.arctan2(GZ - 60, GX - 60)
    p = np.zeros_like(d)
    for rr in (11.5, 24.0, 36.0):
        p = np.maximum(p, np.clip(1 - np.abs(d - rr) / 1.4, 0, 1))
    for a0 in np.radians([90, 210, 330, 30, 150, 270]):
        da = np.abs(np.angle(np.exp(1j * (ang - a0)))) * d
        p = np.maximum(p, np.clip(1 - da / 1.2, 0, 1) * (d < 47) * (d > 6))
    col = col * (1 - p[..., None] * .55) + C["path"] * (p[..., None] * .55)
    m = MeshBuilder()
    pos = np.stack([GX, H, GZ], -1).reshape(-1, 3)
    nrm = np.stack([-dHx, np.ones_like(H), -dHz], -1)
    nrm = (nrm / np.linalg.norm(nrm, axis=-1, keepdims=True)).reshape(-1, 3)
    idx = []
    for r in range(N - 1):
        for c in range(N - 1):
            a = r * N + c
            idx += [a, a + N, a + 1, a + 1, a + N, a + N + 1]
    m.add("Snow", pos, nrm, col.reshape(-1, 3), idx)

    def h_at(x, z):
        i = int(round((z + 20))); j = int(round((x + 20)))
        return H[min(max(i, 0), N - 1), min(max(j, 0), N - 1)]

    # trees outside the wall — المرحلة 32: ثلاث سلالات وأحمال ثلج متنوعة
    trunk = cyl_soup(.12, .1, .6, 5)
    cones = [cone_soup(.9, 1.4, 6, y0=.5), cone_soup(.7, 1.2, 6, y0=1.2), cone_soup(.45, .9, 6, y0=1.9)]
    cones_tall = [cone_soup(.75, 1.6, 6, y0=.5), cone_soup(.6, 1.5, 6, y0=1.5), cone_soup(.45, 1.2, 6, y0=2.5), cone_soup(.3, .9, 6, y0=3.4)]
    cnt = 0
    while cnt < 700:
        x, z = rng.uniform(-18, 138, 2)
        dd = np.hypot(x - 60, z - 60)
        if dd < 48.5 or (abs(x - 60) < 4 and z > 100):
            continue
        s = rng.uniform(.8, 1.6)
        kind = rng.random()
        xf = T(x, h_at(x, z) - .05, z, ry=rng.uniform(0, 6), s=s)
        m.add_soup("Matte", trunk, C["woodD"], xf)
        if kind < 0.3:
            # صنوبر طويل نحيل
            for kk, cn in enumerate(cones_tall):
                m.add_soup("Matte", cn, C["pine"] if kk < 2 else C["snow"], xf)
            m.add_soup("Snow", octa_soup(.28, np.array([1, 1.3, 1])), SNOW_WHITE, T(x, h_at(x, z) + 4.2 * s, z))
        else:
            green = C["pine"] * (0.85 + rng.random() * .3)
            for kk, cn in enumerate(cones):
                m.add_soup("Matte", cn, green if kk < 2 else C["snow"], xf)
            if kind > 0.6:
                # كتل ثلج على الأغصان
                for kk in range(3):
                    a = rng.uniform(0, 6.28)
                    rr = rng.uniform(.3, .7)
                    m.add_soup("Snow", octa_soup(rng.uniform(.18, .3), np.array([1.4, .7, 1.2])),
                               SNOW_WHITE, T(x + np.cos(a) * rr, h_at(x, z) + 1.4 + kk * .55, z + np.sin(a) * rr))
        cnt += 1
    for i in range(120):
        x, z = rng.uniform(-18, 138, 2)
        if np.hypot(x - 60, z - 60) < 50:
            continue
        m.add_soup("Matte", octa_soup(rng.uniform(.6, 1.6), rng.uniform(.6, 1.3, 3)), C["rock"], T(x, h_at(x, z), z, ry=rng.uniform(0, 6)))
    # inner decoration: lamp posts along inner road
    for i in range(12):
        a = i / 12 * 2 * np.pi + .26
        x, z = 60 + np.cos(a) * 17.5, 60 + np.sin(a) * 17.5
        m.add_soup("Metal", box_soup(.1, 2.0, .1), C["metal"], T(x, 0, z))
        m.add_soup("Fire", box_soup(.28, .28, .28, y0=2.0), C["fire"], T(x, 0, z))
    return m


def barracks(t):
    """Training camp: walled yard, long hall, banners, weapon racks."""
    m = MeshBuilder()
    s = 1 + t * .15
    w, d = 4.6 * s, 3.4 * s
    contact_shadow(m, (w + d) * .36 + .6, seed=25)
    m.add_soup("Matte", box_soup(w + .6, .2, d + .6), C["stoneD"])
    m.add_soup("Matte", box_soup(w, 1.5 * s, d * .55, y0=.2), C["wood"] if t < 2 else C["stone"], T(0, 0, -d * .2))
    roof_gable(m, w + .4, d * .55 + .5, 1.1 * s, .2 + 1.5 * s, C["roof"], T(0, 0, -d * .2))
    m.add_soup("Matte", box_soup(.7, 1.0, .08), C["woodD"], T(0, .2, -d * .2 + d * .275 + .02))
    for x in (-w * .32, w * .32):
        window(m, x, .2 + .9 * s, -d * .2 + d * .275 + .03)
    # palisade yard
    for i in range(9):
        x = -w / 2 + i * w / 8
        m.add_soup("Matte", cyl_soup(.1, .09, .9, 5), C["woodD"], T(x, .2, d / 2))
    # banners
    for x in (-w / 2 - .1, w / 2 + .1):
        m.add_soup("Matte", box_soup(.08, 2.6 + t * .6, .08), C["woodD"], T(x, .2, d / 2))
        m.add_soup("Matte", box_soup(.04, .8, .55), C["red"], T(x, 1.9 + t * .6, d / 2 - .3))
    # weapon rack + training dummy
    m.add_soup("Matte", box_soup(1.2, .08, .1, y0=.9), C["woodD"], T(-w * .25, .2, d * .25))
    for k in range(3 + t):
        m.add_soup("Metal", box_soup(.05, 1.1, .05), C["metalL"], T(-w * .25 - .45 + k * .3, .2, d * .25))
    m.add_soup("Matte", cyl_soup(.12, .12, 1.2, 6), C["woodD"], T(w * .25, .2, d * .25))
    m.add_soup("Matte", box_soup(.7, .12, .12, y0=1.0), C["woodD"], T(w * .25, .2, d * .25))
    m.add_soup("Matte", octa_soup(.2), C["canvas"], T(w * .25, 1.55, d * .25))
    if t >= 1:
        m.add_soup("Matte", cyl_soup(.5, .45, 2.4 * s, 8), C["stone"], T(w / 2 - .4, .2, -d / 2 + .4))
        m.add_soup("Matte", cone_soup(.7, .9, 8, y0=2.4 * s), C["blue"], T(w / 2 - .4, .2, -d / 2 + .4))
    return m


def hero_hall(t):
    """Hall of heroes: columns, dome, statues and a braziers."""
    m = MeshBuilder()
    s = 1 + t * .15
    r = 2.4 * s
    contact_shadow(m, r + 2.2, seed=27)
    m.add_soup("Matte", cyl_soup(r + .9, r + .8, .35, 8), C["stoneD"], T(ry=np.pi / 8))
    m.add_soup("Matte", cyl_soup(r + .5, r + .4, .3, 8, y0=.35), C["stone"], T(ry=np.pi / 8))
    m.add_soup("Matte", cyl_soup(r * .8, r * .8, 1.9 * s, 8, y0=.65), C["white"], T(ry=np.pi / 8))
    for k in range(8):
        a = k * np.pi / 4
        m.add_soup("Matte", cyl_soup(.16, .16, 1.9 * s, 6, y0=.65), C["stone"], T(np.cos(a) * r, 0, np.sin(a) * r))
    m.add_soup("Matte", cyl_soup(r + .2, r + .2, .25, 8, y0=.65 + 1.9 * s), C["stone"], T(ry=np.pi / 8))
    m.add_soup("Metal", cone_soup(r * .95, 1.4 * s, 12, y0=.9 + 1.9 * s), C["gold"] if t == 2 else C["iron"])
    m.add_soup("Glow", octa_soup(.3), C["blue"], T(0, 2.5 + 3.3 * s, 0))
    m.add_soup("Matte", box_soup(.8, 1.2, .08), C["woodD"], T(0, .65, r * .8 + .02))
    for x in (-1.0, 1.0):
        m.add_soup("Metal", cyl_soup(.25, .15, .7, 6), C["metal"], T(x * (r + .3), .65, r + .3))
        m.add_soup("Fire", octa_soup(.2), C["fire"], T(x * (r + .3), 1.45, r + .3))
    if t >= 1:
        for x in (-1.6, 1.6):
            m.add_soup("Matte", box_soup(.5, .4, .5), C["stoneD"], T(x * s, .65, r + 1.2))
            m.add_soup("Matte", cyl_soup(.15, .18, .8, 6, y0=.4), C["stone"], T(x * s, .65, r + 1.2))
            m.add_soup("Matte", octa_soup(.17), C["stone"], T(x * s, 1.95, r + 1.2))
    return m


def lab(t):
    """Ember laboratory: workshop with telescope, glowing vats and pipes."""
    m = MeshBuilder()
    s = 1 + t * .15
    w, d, h = 3.2 * s, 2.6 * s, 1.7 * s
    contact_shadow(m, (w + d) * .36 + .5, seed=29)
    m.add_soup("Matte", box_soup(w + .4, .2, d + .4), C["stoneD"])
    m.add_soup("Matte", box_soup(w, h, d, y0=.2), C["stone"] if t else C["woodL"])
    m.add_soup("Metal", box_soup(w + .2, .15, d + .2, y0=.2 + h), C["metal"])
    m.add_soup("Matte", cyl_soup(d * .45, d * .45, .9 * s, 10, y0=.35 + h), C["white"], T(-w * .2, 0, 0))
    m.add_soup("Metal", cone_soup(d * .47, .7 * s, 10, y0=.35 + h + .9 * s), C["iron"], T(-w * .2, 0, 0))
    # telescope
    m.add_soup("Metal", cyl_soup(.12, .18, 1.6, 8), C["gold"], T(w * .25, .35 + h + .1, 0) @ ROT_Z @ T(ry=0))
    for x in (-w * .3, w * .3):
        window(m, x, .2 + h * .55, d / 2 + .03)
    m.add_soup("Matte", box_soup(.6, .95, .08), C["woodD"], T(0, .2, d / 2 + .02))
    # vats with glowing liquid
    for k in range(1 + t):
        x = w / 2 + .6
        z = -d * .3 + k * .9
        m.add_soup("Metal", cyl_soup(.38, .34, .8, 10), C["metalL"], T(x, 0, z))
        m.add_soup("Glow", cyl_soup(.3, .3, .06, 10, y0=.8), C["blue"], T(x, 0, z))
    m.add_soup("Metal", box_soup(.1, .1, d * .8, y0=1.2), C["metal"], T(w / 2 + .1, 0, 0))
    return m


def workshop(t):
    """Stage 19: war workshop — forge hall with chimney, anvil, glowing forge, weapon racks and shield wall (3 tiers)."""
    m = MeshBuilder()
    s = 1 + t * .16
    w, d, h = 3.6 * s, 2.8 * s, 1.6 * s
    contact_shadow(m, (w + d) * .36 + .5, seed=33)
    m.add_soup("Matte", box_soup(w + .5, .2, d + .5), C["stoneD"])
    m.add_soup("Matte", box_soup(w, h, d, y0=.2), C["stone"] if t else C["woodL"])
    roof_gable(m, w + .5, d + .5, 1.1 * s, .2 + h, C["woodD"] if t < 2 else C["metal"])
    # chimney + fire glow
    cx = -w * .28
    m.add_soup("Matte", box_soup(.6, 1.7 * s, .6, y0=.2 + h), C["stoneD"], T(cx, 0, -d * .2))
    m.add_soup("Fire", box_soup(.34, .12, .34, y0=.2 + h + 1.7 * s), C["fire"], T(cx, 0, -d * .2))
    # forge opening and door
    m.add_soup("Fire", box_soup(.9, .6, .06, y0=.5), C["fire"], T(-w * .22, 0, d / 2 + .02))
    m.add_soup("Matte", box_soup(.7, 1.05, .08, y0=.2), C["woodD"], T(w * .2, 0, d / 2 + .02))
    window(m, w * .38, .2 + h * .6, d / 2 + .03)
    # anvil
    ax = w * .0
    m.add_soup("Matte", cyl_soup(.22, .26, .45, 8), C["woodD"], T(ax, 0, d / 2 + .9))
    m.add_soup("Metal", box_soup(.7, .22, .32, y0=.45), C["metal"], T(ax, 0, d / 2 + .9))
    m.add_soup("Metal", cone_soup(.16, .3, 6, y0=.67), C["metalL"], T(ax + .38, 0, d / 2 + .9) @ ROT_Z)
    # weapon rack at the side: spears
    for k in range(3 + t):
        z = -d * .3 + k * .42
        m.add_soup("Matte", box_soup(.06, 1.8, .06, y0=.0), C["wood"], T(w / 2 + .5, 0, z))
        m.add_soup("Metal", cone_soup(.09, .3, 6, y0=1.8), C["iron"], T(w / 2 + .5, 0, z))
    m.add_soup("Matte", box_soup(.1, .1, d * .8, y0=1.1), C["woodD"], T(w / 2 + .5, 0, 0))
    # shields on the front wall
    for i, col in enumerate((C["red"], C["blue"], C["gold"])[:1 + t]):
        m.add_soup("Metal", cyl_soup(.3, .3, .06, 10, y0=0), col, T(-w * .34 + i * .55, .2 + h * .62, d / 2 + .05) @ ROT_X)
    # banner on top at higher tiers
    if t >= 2:
        m.add_soup("Matte", box_soup(.06, 1.6, .06, y0=.2 + h + 1.1 * s), C["woodD"], T(w * .32, 0, 0))
        m.add_soup("Matte", box_soup(.04, .7, .5, y0=1.1 + .2 + h + 1.1 * s), C["red"], T(w * .32, 0, .3))
    return m

def scout_tower(t):
    """Stage 20: scouting tower — tall legged watchtower with platform, spyglass, beacon fire and banner (3 tiers)."""
    m = MeshBuilder()
    s = 1 + t * .2
    h = 4.6 * s + t * .9           # height to platform
    b = 1.5 * s                    # base half-width at ground
    top = .85 * s                  # half-width at platform
    contact_shadow(m, b + 1.6, seed=35)
    m.add_soup("Matte", box_soup(b * 2 + .6, .2, b * 2 + .6), C["stoneD"])
    stone = C["stone"] if t >= 1 else C["woodL"]
    # four slanted legs (approximated by stacked segments)
    for sx in (-1, 1):
        for sz in (-1, 1):
            for k in range(6):
                f0 = k / 6
                w = (b + (top - b) * (f0 + .08))
                m.add_soup("Matte", box_soup(.22 * s, h / 6 + .05, .22 * s, y0=.2 + h * f0), C["wood"] if t < 2 else C["metalL"], T(sx * w, 0, sz * w))
    # cross braces
    for k in (1, 3):
        f0 = k / 6 + .05
        w = (b + (top - b) * f0)
        for sgn in (-1, 1):
            m.add_soup("Matte", box_soup(w * 2, .1, .1, y0=.2 + h * f0), C["woodD"], T(0, 0, sgn * w))
            m.add_soup("Matte", box_soup(.1, .1, w * 2, y0=.2 + h * f0), C["woodD"], T(sgn * w, 0, 0))
    # platform + rails
    pw = top + .5
    m.add_soup("Matte", box_soup(pw * 2, .22, pw * 2, y0=.2 + h), C["woodD"])
    for sgn in (-1, 1):
        m.add_soup("Matte", box_soup(pw * 2, .5, .08, y0=.42 + h), stone, T(0, 0, sgn * pw))
        m.add_soup("Matte", box_soup(.08, .5, pw * 2, y0=.42 + h), stone, T(sgn * pw, 0, 0))
    # cabin + roof
    cw = top * .9
    m.add_soup("Matte", box_soup(cw * 2, 1.0 * s, cw * 2, y0=.42 + h), stone)
    window(m, 0, .42 + h + .55 * s, cw + .03)
    window(m, 0, .42 + h + .55 * s, -cw - .03, ry=np.pi)
    m.add_soup("Matte", cone_soup(cw * 1.5, 1.2 * s, 4, y0=.42 + h + 1.0 * s), C["blue"] if t >= 1 else C["woodD"], T(ry=np.pi / 4))
    # beacon fire on a pole beside the cabin
    bx = pw - .12
    m.add_soup("Matte", box_soup(.07, 1.6, .07, y0=.42 + h), C["woodD"], T(bx, 0, bx))
    m.add_soup("Metal", cyl_soup(.22, .14, .18, 6, y0=.42 + h + 1.5), C["metal"], T(bx, 0, bx))
    m.add_soup("Fire", octa_soup(.2), C["fire"], T(bx, .42 + h + 1.95, bx))
    # spyglass
    m.add_soup("Metal", cyl_soup(.07, .09, .9, 8), C["gold"], T(-pw * .6, .42 + h + .7, pw * .55) @ ROT_X)
    # banner
    m.add_soup("Matte", box_soup(.05, 1.9 + t * .5, .05, y0=.42 + h + 1.0 * s), C["woodD"], T(-bx, 0, -bx))
    m.add_soup("Matte", box_soup(.04, .7, .5, y0=.42 + h + 1.0 * s + 1.1 + t * .5), C["red"], T(-bx, 0, -bx + .3))
    # ground details: lantern + crates
    m.add_soup("Matte", box_soup(.5, .45, .5, y0=.2), C["woodL"], T(b + .6, 0, .4))
    m.add_soup("Fire", box_soup(.14, .14, .14, y0=.7), C["fire"], T(b + .6, 0, .4))
    if t >= 2:
        for sx in (-1, 1):
            m.add_soup("Matte", cyl_soup(.5, .55, 1.2, 8, y0=.2), stone, T(sx * (b + 1.1), 0, -b - .6))
    return m

def war_depot(t):
    """Stage 21: war depot — long storehouse with big doors, stacked crates, barrels, a supply cart and a banner (3 tiers)."""
    m = MeshBuilder()
    s = 1 + t * .16
    w, d, h = 4.4 * s, 2.8 * s, 1.5 * s
    contact_shadow(m, (w + d) * .36 + .6, seed=37)
    m.add_soup("Matte", box_soup(w + .6, .2, d + .6), C["stoneD"])
    m.add_soup("Matte", box_soup(w, h, d, y0=.2), C["woodL"] if t == 0 else C["stone"])
    # plank stripes on the front wall
    for k in range(5):
        m.add_soup("Matte", box_soup(.08, h * .98, .05, y0=.2), C["woodD"], T(-w * .4 + k * w * .2, 0, d / 2 + .02))
    roof_gable(m, w + .5, d + .5, 1.0 * s, .2 + h, C["roof"] if t < 2 else C["blue"])
    # big double doors with iron bands
    m.add_soup("Matte", box_soup(1.5, 1.15, .1, y0=.2), C["woodD"], T(0, 0, d / 2 + .04))
    for yy in (.6, 1.0):
        m.add_soup("Metal", box_soup(1.5, .07, .12, y0=yy), C["metal"], T(0, 0, d / 2 + .06))
    window(m, -w * .36, .2 + h * .62, d / 2 + .05, s=.9)
    window(m, w * .36, .2 + h * .62, d / 2 + .05, s=.9)
    # crates stack
    for i, (x, z, y) in enumerate([(w / 2 + .7, .2, 0), (w / 2 + .7, 1.0, 0), (w / 2 + .7, .6, .5)][:2 + t]):
        m.add_soup("Matte", box_soup(.7, .5, .7, y0=.2 + y), C["wood"], T(x, 0, z))
    # barrels
    for i in range(2 + t):
        m.add_soup("Matte", cyl_soup(.26, .26, .6, 8, y0=.2), C["woodD"], T(-w / 2 - .6, 0, -.6 + i * .6))
        m.add_soup("Metal", ring_soup(.24, .29, .05, 8, y0=.45), C["metal"], T(-w / 2 - .6, 0, -.6 + i * .6))
    # supply cart
    cx, cz = -w * .15, d / 2 + 1.5
    m.add_soup("Matte", box_soup(1.1, .35, .7, y0=.45), C["wood"], T(cx, 0, cz))
    for sz in (-1, 1):
        m.add_soup("Matte", cyl_soup(.3, .3, .08, 10), C["woodD"], T(cx, .3, cz + sz * .4) @ ROT_X)
    m.add_soup("Matte", box_soup(.6, .3, .5, y0=.8), C["canvas"], T(cx, 0, cz))
    # banner pole
    m.add_soup("Matte", box_soup(.06, 2.4 + t * .5, .06), C["woodD"], T(w / 2 + .1, .2 + h, d / 2 - .1))
    m.add_soup("Matte", box_soup(.04, .7, .5, y0=.2 + h + 1.5 + t * .5), C["gold"] if t >= 1 else C["red"], T(w / 2 + .1, 0, d / 2 + .15))
    if t >= 2:
        m.add_soup("Fire", box_soup(.16, .16, .16, y0=1.0), C["fire"], T(-.9, 0, d / 2 + .3))
        m.add_soup("Fire", box_soup(.16, .16, .16, y0=1.0), C["fire"], T(.9, 0, d / 2 + .3))
    return m

def market(t):
    """Stage 22: market — open timber stalls with striped awnings, goods crates, a hanging balance scale and a gold sign (3 tiers)."""
    m = MeshBuilder()
    s = 1 + t * .14
    contact_shadow(m, 3.4 * s, seed=39)
    m.add_soup("Matte", box_soup(5.0 * s, .18, 3.6 * s), C["stoneD"])
    n = 2 + t   # عدد الأكشاك
    span = 4.2 * s
    for i in range(n):
        x = -span / 2 + (i + .5) * span / n
        sw = span / n * .92
        # counter + back posts
        m.add_soup("Matte", box_soup(sw, .55, .7, y0=.18), C["woodL"], T(x, 0, .5 * s))
        for px in (-sw / 2 + .06, sw / 2 - .06):
            m.add_soup("Matte", box_soup(.1, 1.7, .1, y0=.18), C["woodD"], T(x + px, 0, -.55 * s))
            m.add_soup("Matte", box_soup(.1, 1.45, .1, y0=.18), C["woodD"], T(x + px, 0, .85 * s))
        # slanted awning (two stripe colours)
        col = C["red"] if i % 2 == 0 else C["canvas"]
        m.add_soup("Matte", box_soup(sw + .12, .08, 1.9 * s, y0=1.75), col, T(x, 0, .15 * s) @ np.array([[1, 0, 0, 0], [0, 1, -.16, 0], [0, 0, 1, 0], [0, 0, 0, 1]], np.float32))
        # goods on counter
        m.add_soup("Matte", box_soup(.32, .3, .32, y0=.73), C["wood"], T(x - sw * .25, 0, .5 * s))
        m.add_soup("Matte", cyl_soup(.15, .15, .3, 8, y0=.73), C["woodD"], T(x + sw * .05, 0, .5 * s))
        m.add_soup("Matte", box_soup(.28, .22, .28, y0=.73), C["metal"] if (i + t) % 2 else C["canvas"], T(x + sw * .3, 0, .5 * s))
    # central sign pole with gold coin and scale beam
    m.add_soup("Matte", box_soup(.12, 2.8 + t * .4, .12), C["woodD"], T(0, 0, -.9 * s))
    m.add_soup("Matte", box_soup(1.3, .08, .08, y0=2.4 + t * .4), C["woodD"], T(0, 0, -.9 * s))
    for sx in (-.6, .6):
        m.add_soup("Matte", cyl_soup(.22, .22, .05, 10, y0=2.0 + t * .4), C["gold"], T(sx, 0, -.9 * s))
    m.add_soup("Matte", cyl_soup(.34, .34, .07, 12, y0=2.9 + t * .4), C["gold"], T(0, 0, -.9 * s))
    # side crates and barrels
    for i in range(2 + t):
        m.add_soup("Matte", box_soup(.6, .5, .6, y0=.18 + (.5 if i == 2 else 0)), C["wood"], T(span / 2 + .5, 0, .2 + (i % 2) * .7))
    for i in range(2):
        m.add_soup("Matte", cyl_soup(.25, .25, .6, 8, y0=.18), C["woodD"], T(-span / 2 - .5, 0, .1 + i * .6))
    if t >= 2:
        m.add_soup("Fire", box_soup(.16, .16, .16, y0=1.1), C["fire"], T(-span / 2 + .1, 0, 1.3 * s))
        m.add_soup("Fire", box_soup(.16, .16, .16, y0=1.1), C["fire"], T(span / 2 - .1, 0, 1.3 * s))
    return m


WALL_R = 46.0
WALL_GATE = 0.09          # half gate gap (radians) toward +Z / south


def _wall_h(H, x, z):
    i = int(round(z + 20)); j = int(round(x + 20))
    return float(H[min(max(i, 0), 160), min(max(j, 0), 160)])


def _gate_gap(a):
    return abs(np.angle(np.exp(1j * (a - np.pi / 2)))) < WALL_GATE


def _gate_tower(m, a, t, H):
    x, z = 60 + np.cos(a) * WALL_R, 60 + np.sin(a) * WALL_R
    y = _wall_h(H, x, z)
    if t == 0:
        m.add_soup("Matte", cyl_soup(.8, .7, 3.4, 8), C["stone"], T(x, y, z))
        m.add_soup("Matte", cone_soup(1.0, 1.2, 8, y0=3.4), C["blue"], T(x, y, z))
        m.add_soup("Fire", box_soup(.3, .3, .3, y0=3.2), C["fire"], T(x, y, z + .75))
    elif t == 1:
        m.add_soup("Matte", box_soup(1.5, 4.0, 1.5), C["woodL"], T(x, y, z))
        m.add_soup("Matte", box_soup(2.0, .3, 2.0, y0=4.0), C["woodD"], T(x, y, z))
        m.add_soup("Matte", cone_soup(1.5, 1.4, 4, y0=4.3), C["woodD"], T(x, y, z, ry=np.pi / 4))
        m.add_soup("Fire", box_soup(.3, .3, .3, y0=3.4), C["fire"], T(x, y, z + .85))
    else:
        r = 1.0 + .2 * t
        h = 3.4 + t * 1.0
        m.add_soup("Matte", cyl_soup(r, r - .1, h, 10), C["stone"], T(x, y, z))
        m.add_soup("Matte", cyl_soup(r + .35, r + .3, .35, 10, y0=h), C["stoneD"], T(x, y, z))
        m.add_soup("Matte", cone_soup(r + .5, 1.2 + .3 * t, 10, y0=h + .35), C["blue"], T(x, y, z))
        m.add_soup("Fire", box_soup(.34, .34, .34, y0=h - .4), C["fire"], T(x, y, z + r))
        if t >= 3:
            m.add_soup("Matte", box_soup(.08, 2.0, .08, y0=h + 1.4), C["woodD"], T(x, y, z))
            m.add_soup("Matte", box_soup(.04, .8, .55, y0=h + 2.4), C["red"], T(x, y, z + .3))


def city_wall(t):
    """Stage 26: the real city wall ring (r=46, gate to the south). Tier 0 palisade, 1 reinforced wood, 2 stone, 3 stone + towers, 4 fortress.
    Built in city space (origin of the city node) so it sits on the same terrain as ground()."""
    m = MeshBuilder()
    _, _, _, H, _, _ = heightfield(np.random.default_rng(7))
    if t <= 1:
        n = 150 if t == 0 else 170
        for i in range(n):
            a = i / n * 2 * np.pi
            if _gate_gap(a):
                continue
            x, z = 60 + np.cos(a) * WALL_R, 60 + np.sin(a) * WALL_R
            y = _wall_h(H, x, z) - .1
            if t == 0:
                hh = 1.6 + (i % 3) * .25
                m.add_soup("Matte", cyl_soup(.22, .2, hh, 5), C["wood"], T(x, y, z))
                m.add_soup("Matte", cone_soup(.22, .35, 5, y0=hh - .1), C["woodD"], T(x, y, z))
            else:
                hh = 2.5 + (i % 3) * .3
                m.add_soup("Matte", cyl_soup(.28, .26, hh, 6), C["woodL"], T(x, y, z))
                m.add_soup("Matte", cone_soup(.28, .5, 6, y0=hh - .1), C["woodD"], T(x, y, z))
        if t == 1:
            # horizontal rails + watch posts
            seg = 90
            for i in range(seg):
                a = (i + .5) / seg * 2 * np.pi
                if _gate_gap(a) or _gate_gap(a - .05) or _gate_gap(a + .05):
                    continue
                x, z = 60 + np.cos(a) * (WALL_R + .2), 60 + np.sin(a) * (WALL_R + .2)
                L = 2 * np.pi * WALL_R / seg + .15
                for yy in (.9, 1.8):
                    m.add_soup("Matte", box_soup(L, .16, .16), C["woodD"], T(x, _wall_h(H, x, z) + yy, z, ry=-a - np.pi / 2))
            for k in range(10):
                a = (k + .5) / 10 * 2 * np.pi
                if abs(np.angle(np.exp(1j * (a - np.pi / 2)))) < .35:
                    continue
                x, z = 60 + np.cos(a) * WALL_R, 60 + np.sin(a) * WALL_R
                y = _wall_h(H, x, z)
                m.add_soup("Matte", box_soup(1.1, 3.4, 1.1), C["woodD"], T(x, y, z))
                m.add_soup("Matte", box_soup(1.8, .25, 1.8, y0=3.4), C["woodL"], T(x, y, z))
                m.add_soup("Matte", cone_soup(1.3, 1.0, 4, y0=3.65), C["roof"], T(x, y, z, ry=np.pi / 4))
    else:
        wh = {2: 2.6, 3: 3.4, 4: 4.4}[t]          # wall height
        wt = {2: .9, 3: 1.1, 4: 1.5}[t]           # thickness
        seg = 120
        L = 2 * np.pi * WALL_R / seg + .2
        for i in range(seg):
            a = (i + .5) / seg * 2 * np.pi
            if _gate_gap(a - .02) or _gate_gap(a + .02) or _gate_gap(a):
                continue
            x, z = 60 + np.cos(a) * WALL_R, 60 + np.sin(a) * WALL_R
            y = _wall_h(H, x, z) - .15
            ry = -a - np.pi / 2
            m.add_soup("Matte", box_soup(L, wh, wt), C["stone"], T(x, y, z, ry=ry))
            m.add_soup("Matte", box_soup(L, .22, wt + .25, y0=wh - .1), C["stoneD"], T(x, y, z, ry=ry))
            # المرحلة 32: ممر ثلجي فوق السور يقرأ ارتفاعه
            if i % 2 == 0:
                m.add_soup("Snow", box_soup(L * .9, .12, wt * .5, y0=wh + .14), SNOW_WHITE, T(x, y, z, ry=ry))
            if i % 2 == 0:
                # merlon on the outer face
                xo, zo = 60 + np.cos(a) * (WALL_R + wt * .32), 60 + np.sin(a) * (WALL_R + wt * .32)
                m.add_soup("Matte", box_soup(L * .6, .55, wt * .36, y0=wh + .1), C["stone"], T(xo, y, zo, ry=ry))
                m.add_soup("Snow", box_soup(L * .5, .1, wt * .3, y0=wh + .68), SNOW_WHITE, T(xo, y, zo, ry=ry))
        # gate towers + arch posts
        for sgn in (-1, 1):
            _gate_tower(m, np.pi / 2 + sgn * (.11 if t == 2 else .125), t, H)
        # round towers along the wall
        if t >= 3:
            nt = 8 if t == 3 else 12
            for k in range(nt):
                a = (k + .5) / nt * 2 * np.pi
                if abs(np.angle(np.exp(1j * (a - np.pi / 2)))) < .3:
                    continue
                x, z = 60 + np.cos(a) * WALL_R, 60 + np.sin(a) * WALL_R
                y = _wall_h(H, x, z) - .15
                r = 1.35 if t == 3 else 1.7
                h = wh + (1.3 if t == 3 else 2.4)
                m.add_soup("Matte", cyl_soup(r, r - .12, h, 10), C["stone"], T(x, y, z))
                m.add_soup("Matte", cyl_soup(r + .3, r + .25, .35, 10, y0=h), C["stoneD"], T(x, y, z))
                m.add_soup("Matte", cone_soup(r + .45, 1.5 if t == 3 else 2.0, 10, y0=h + .35), C["blue"], T(x, y, z))
                m.add_soup("Fire", box_soup(.3, .3, .3, y0=h - .5), C["fire"], T(x + np.cos(a) * r, y, z + np.sin(a) * r))
        if t == 4:
            # gatehouse lintel and banners over the gate
            for sgn in (-1, 1):
                a = np.pi / 2 + sgn * .125
                x, z = 60 + np.cos(a) * WALL_R, 60 + np.sin(a) * WALL_R
                m.add_soup("Matte", box_soup(.1, 2.6, .1, y0=9.6), C["woodD"], T(x, 0, z + 1.9))
                m.add_soup("Matte", box_soup(.05, 1.3, .8, y0=10.6), C["red"], T(x, 0, z + 1.9))
    # torches either side of the gate on every tier above the palisade
    if t >= 1:
        for sgn in (-1, 1):
            a = np.pi / 2 + sgn * .075
            x, z = 60 + np.cos(a) * WALL_R, 60 + np.sin(a) * WALL_R + 1.0
            m.add_soup("Metal", cyl_soup(.12, .1, 1.1, 6), C["metal"], T(x, 0, z))
            m.add_soup("Fire", octa_soup(.17), C["fire"], T(x, 1.2, z))
    for sgn in (-1, 1):
        if t <= 1:
            _gate_tower(m, np.pi / 2 + sgn * .11, t, H)
    return m


BUILDERS.update({"barracks": barracks, "hero_hall": hero_hall, "lab": lab, "workshop": workshop, "scout_tower": scout_tower, "war_depot": war_depot, "market": market})


def soldier(kind):
    m = MeshBuilder()
    col = {"shield": C["coat"], "spear": C["coat2"], "bow": C["pine"]}[kind]
    m.add_soup("Matte", box_soup(.07, .2, .07, y0=0), C["woodD"], T(-.06, 0, 0))
    m.add_soup("Matte", box_soup(.07, .2, .07, y0=0), C["woodD"], T(.06, 0, 0))
    m.add_soup("Matte", cyl_soup(.17, .13, .38, 6, y0=.2), col)
    m.add_soup("Matte", box_soup(.05, .22, .05, y0=.22), col, T(-.15, 0, 0))
    m.add_soup("Matte", box_soup(.05, .22, .05, y0=.22), col, T(.15, 0, 0))
    m.add_soup("Matte", octa_soup(.12), C["skin"], T(0, .58, 0))
    m.add_soup("Metal", cone_soup(.15, .14, 6, y0=.64), C["metalL"])
    m.add_soup("Matte", box_soup(.22, .05, .12, y0=.52), C["red"], T(0, 0, .02))
    if kind == "shield":
        m.add_soup("Metal", cyl_soup(.26, .26, .05, 10), C["iron"], T(0, .38, .2) @ ROT_X)
    elif kind == "spear":
        m.add_soup("Matte", box_soup(.03, 1.3, .03), C["woodD"], T(.2, 0, .05))
        m.add_soup("Metal", cone_soup(.05, .2, 4, y0=1.3), C["white"], T(.2, 0, .05))
    else:
        m.add_soup("Matte", ring_soup(.26, .3, .03, 10, y0=0), C["woodD"], T(.18, .45, 0) @ ROT_Z)
        m.add_soup("Matte", box_soup(.1, .35, .1, y0=.25), C["wood"], T(0, 0, -.17))
    return m


def wolf():
    m = MeshBuilder()
    fur, dark = lin(0x8d96a3), lin(0x4b525c)
    m.add_soup("Matte", box_soup(.36, .32, .9, y0=.32), fur)
    m.add_soup("Matte", box_soup(.3, .28, .34, y0=.48), fur, T(0, 0, .55))
    m.add_soup("Matte", box_soup(.16, .14, .22, y0=.5), dark, T(0, 0, .78))
    for x in (-.11, .11):
        m.add_soup("Matte", cone_soup(.06, .16, 4, y0=.76), dark, T(x, 0, .52))
        for z in (-.32, .32):
            m.add_soup("Matte", box_soup(.08, .34, .08), dark, T(x, 0, z))
    m.add_soup("Matte", box_soup(.08, .08, .4, y0=.5), fur, T(0, 0, -.6))
    m.add_soup("Glow", box_soup(.04, .03, .02, y0=.62), lin(0xffd36b), T(-.08, 0, .72))
    m.add_soup("Glow", box_soup(.04, .03, .02, y0=.62), lin(0xffd36b), T(.08, 0, .72))
    return m


def crystal():
    m = MeshBuilder()
    m.add_soup("Glow", octa_soup(.35, np.array([.7, 1.6, .7])), lin(0x7ff0ff), T(0, .5, 0))
    m.add_soup("Glow", octa_soup(.22, np.array([.7, 1.4, .7])), lin(0xb48cff), T(.28, .3, .1, ry=.6))
    m.add_soup("Glow", octa_soup(.18, np.array([.7, 1.3, .7])), lin(0x7ff0ff), T(-.22, .25, -.12, ry=1.2))
    m.add_soup("Snow", cyl_soup(.5, .45, .08, 8), C["snowD"])
    return m



if __name__ == "__main__":
    for name, fn in BUILDERS.items():
        for t in range(3):
            save(f"{name}_t{t}", fn(t))
    for t in range(5):
        save(f"city_wall_t{t}", city_wall(t))
    save("plot", plot())
    save("scaffold", scaffold())
    save("citizen_a", citizen(C["coat"]))
    save("citizen_b", citizen(C["coat2"]))
    for k in ("shield", "spear", "bow"):
        save(f"soldier_{k}", soldier(k))
    save("wolf", wolf())
    save("crystal", crystal())
    if "--no-ground" not in __import__("sys").argv:
        save("ground", ground())
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".glb"):
            print(f, round(os.path.getsize(os.path.join(OUT, f)) / 1e3, 1), "KB")
