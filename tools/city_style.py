"""Stage 32 — AA→AAA visual style helpers for the procedural city builder.
Snow caps, contact shadows, timber framing, chimney details. Pure numpy, no new files in engine.
"""
import numpy as np
from glb import MeshBuilder, T, box_soup

SNOW_WHITE = np.array([0.93, 0.95, 0.99], np.float32)


def roof_snow(m: MeshBuilder, w, d, h, y0, seed=0, col=SNOW_WHITE):
    """Snow lying on both slopes of a gable roof (ridge along X) — طبقة رقيقة + كتل غير منتظمة."""
    x, z = w / 2, d / 2
    rng = np.random.default_rng(seed)
    for sgn in (-1, 1):
        # شريحة رقيقة تتبع ميل السطح من الحرف حتى ~78% من الميل
        p0 = np.array([-x, y0 + h + 0.015, sgn * 0.03], np.float32)
        p1 = np.array([x, y0 + h + 0.015, sgn * 0.03], np.float32)
        p2 = np.array([x * 0.92, y0 + h * 0.22 + 0.015, sgn * (z * 0.78)], np.float32)
        p3 = np.array([-x * 0.92, y0 + h * 0.22 + 0.015, sgn * (z * 0.78)], np.float32)
        m.add_soup("Snow", np.array([(p0, p1, p2), (p0, p2, p3)], np.float32), col)
        # حواف متكتلة غير منتظمة عند أسفل الغطاء
        n = 6
        for k in range(n):
            xx = -x * 0.88 + (k + 0.5) / n * x * 1.76
            l = 0.2 + 0.3 * rng.random()
            m.add_soup("Snow", octa_soup(l * 0.5, np.array([1.7, .45, 1.2])),
                       col * 0.97, T(xx, y0 + h * 0.2, sgn * z * 0.8, ry=rng.uniform(0, 6)))
    # حرف علوية رقيقة
    m.add_soup("Snow", box_soup(w + 0.04, 0.05, 0.16, y0=y0 + h), col)
    return m


def contact_shadow(m: MeshBuilder, r, seed=0, y=0.02, strength=0.55):
    """Radial-gradient dark disc that visually grounds the building (cheap baked AO)."""
    rng = np.random.default_rng(seed)
    n = 22
    a = np.linspace(0, 2 * np.pi, n, endpoint=False)
    # two rings for a soft falloff: inner ring 0.45r at high alpha, outer at r fading to 0
    inner = np.stack([np.cos(a) * r * 0.45, np.full(n, y), np.sin(a) * r * 0.45], 1)
    outer = np.stack([np.cos(a) * r, np.full(n, y), np.sin(a) * r], 1)
    pos = np.concatenate([inner, outer])
    nrm = np.tile(np.array([[0, 1, 0]], np.float32), (pos.shape[0], 1))
    col = np.concatenate([
        np.tile(np.array([0, 0, 0, strength], np.float32), (n, 1)),
        np.tile(np.array([0, 0, 0, 0.0], np.float32), (n, 1))])
    idx = []
    for i in range(n):
        j = (i + 1) % n
        idx += [i, n + i, n + j, i, n + j, j]
    m.add("Shadow", pos, nrm, col, np.array(idx, np.uint32))
    return m


def timber_frame(m: MeshBuilder, w, h, d, y0, col_wood, col_beam):
    """Half-timber framing: dark beams over the front and back faces."""
    for sgn in (-1, 1):
        z = sgn * (d / 2 + 0.03)
        # horizontal rail mid-height
        m.add_soup("Matte", box_soup(w + 0.06, 0.09, 0.05), col_beam, T(0, y0 + h * 0.55, z))
        # vertical posts at the corners and mid
        for xx in (-w / 2 + 0.05, 0, w / 2 - 0.05):
            m.add_soup("Matte", box_soup(0.09, h * 0.8, 0.05, y0=y0 + h * 0.1), col_beam, T(xx, 0, z))
        # diagonal braces
        for k in (-1, 1):
            m.add_soup("Matte", box_soup(0.07, h * 0.55, 0.05), col_beam,
                       T(k * w * 0.25, y0 + h * 0.25, z) @ np.array([[1, 0, 0, 0], [0, .8, .6, 0], [0, -.6, .8, 0], [0, 0, 0, 1]], np.float32))
    return m


def chimney_snow(m: MeshBuilder, x, z, h, y0, col_stone, seed=0):
    """Chimney with a snow cap on top — cozy winter storytelling."""
    m.add_soup("Matte", box_soup(0.45, h, 0.45, y0=y0), col_stone, T(x, 0, z))
    m.add_soup("Snow", box_soup(0.56, 0.10, 0.56, y0=y0 + h), SNOW_WHITE, T(x, 0, z))
    return m


def octa_soup(r=1.0, jitter=None):
    v = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]], np.float32) * r
    if jitter is not None:
        v = v * jitter
    f = [(0, 2, 4), (4, 2, 1), (1, 2, 5), (5, 2, 0), (4, 3, 0), (1, 3, 4), (5, 3, 1), (0, 3, 5)]
    return v[np.array(f)]
