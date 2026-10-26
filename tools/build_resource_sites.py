"""Stage 10: regenerate ONLY the four resource GLBs, never map_data.json.

Run: python tools/build_resource_sites.py
Original geometry, built with the project's GLB helpers; no third-party artwork.
"""
from pathlib import Path
import numpy as np
from glb import GLB, MeshBuilder, T, box_soup, cyl_soup, cone_soup, octa_soup

OUT = Path(__file__).resolve().parents[1] / "assets"


def color(value):
    return (np.array([(value >> 16) & 255, (value >> 8) & 255, value & 255]) / 255) ** 2.2


C = {key: color(value) for key, value in {
    "snow": 0xE5F0F6, "base": 0xA3B9CA, "rock": 0x6B8294,
    "dark": 0x273748, "wood": 0x875739, "cut": 0xC99B68,
    "metal": 0x42586B, "roof": 0x466D8E, "coal": 0x242C35,
    "iron": 0x83BED3, "food": 0xBB7860, "canvas": 0xB1C7C9,
}.items()}


def box(m, xyz, whd, col, mat="Matte", ry=0):
    m.add_soup(mat, box_soup(*whd), C[col], T(*xyz, ry=ry))


def rock(m, xyz, size, col="rock"):
    m.add_soup("Matte", octa_soup(1, np.array(size)), C[col], T(*xyz))


def roof(m, x, y, z, w=2.5, d=2.0):
    # Two pitched metal panels, with a separate snow cap and exposed eaves.
    for side in (-1, 1):
        xf = T(x, y, z + side * d * .25)
        angle = side * .43
        xf[:3, :3] = np.array([[1, 0, 0], [0, np.cos(angle), -np.sin(angle)],
                              [0, np.sin(angle), np.cos(angle)]])
        m.add_soup("Metal", box_soup(w, .14, d * .57), C["roof"], xf)
        xf[1, 3] += .13
        m.add_soup("Snow", box_soup(w * .94, .12, d * .51), C["snow"], xf)


def hut(m, x, z, w=2.1, d=1.7, col="wood"):
    box(m, (x, .1, z), (w + .22, .2, d + .22), "dark")
    box(m, (x, .3, z), (w, 1.25, d), col)
    box(m, (x, .3, z + d / 2 + .02), (.55, .92, .07), "dark")
    box(m, (x - w * .3, .85, z + d / 2 + .05), (.38, .38, .06), "cut", "Fire")
    roof(m, x, 1.65, z, w + .4, d + .4)
    box(m, (x + .5, 1.6, z - .3), (.26, .95, .27), "metal")


def log(m, x, y, z, length=2.3):
    xf = T(x, y, z)
    xf[:3, :3] = np.array([[0, 1, 0], [-1, 0, 0], [0, 0, 1]])
    m.add_soup("Matte", cyl_soup(.19, .19, length, 8, y0=-length / 2), C["wood"], xf)
    for end in (-1, 1):
        cap = xf.copy()
        cap[0, 3] += end * (length / 2 + .012)
        m.add_soup("Matte", cyl_soup(.16, .16, .025, 8, y0=-.012), C["cut"], cap)


def cart(m, x, z, ore):
    box(m, (x, .32, z), (.95, .6, .8), "metal", "Metal")
    for dx in (-.49, .49):
        for dz in (-.27, .27):
            rock(m, (x + dx, .23, z + dz), (.14, .2, .16), "dark")
    for dx in (-.22, .2):
        rock(m, (x + dx, .92, z), (.34, .29, .3), ore)


def site(kind):
    m = MeshBuilder()
    m.add_soup("Snow", cyl_soup(2.75, 2.6, .12, 12), C["base"])
    m.add_soup("Snow", cyl_soup(2.65, 2.58, .09, 12, y0=.12), C["snow"])
    if kind == "wood":
        hut(m, -.9, -.55, 1.8, 1.7)
        for row in range(3):
            for k in range(3 - row):
                log(m, .7, .38 + row * .32, .55 + k * .4 + row * .2)
        for z in (-1.7, -.9):
            box(m, (1.65, .12, z), (.14, 1.5, .14), "wood")
        roof(m, 1.55, 1.75, -1.3, 1.3, 1.6)
        box(m, (1.45, .3, -1.3), (.75, .75, .65), "wood")
        # Saw blade clearly identifies the work site.
        xf = T(1.4, 1.22, -.95)
        xf[:3, :3] = np.array([[1, 0, 0], [0, 0, -1], [0, 1, 0]])
        m.add_soup("Metal", cyl_soup(.46, .46, .08, 14), C["iron"], xf)
    elif kind in ("coal", "iron"):
        ore = kind
        rock(m, (0, 1.05, -.6), (2.15, 1.8, 1.5))
        rock(m, (-1.35, .75, -.3), (.9, 1.2, .95), "dark")
        rock(m, (.7, 2.2, -.65), (1.2, .28, .95), "snow")
        box(m, (0, .16, .73), (1.3, 1.5, .18), "dark")
        for x in (-.78, .78):
            box(m, (x, .16, .91), (.23, 1.68, .32), "wood")
        box(m, (0, 1.76, .9), (1.95, .25, .4), "wood")
        for x in (-.35, .35):
            box(m, (x, .22, 1.65), (.075, .07, 1.8), "metal", "Metal")
        for z in (1.0, 1.4, 1.8, 2.2):
            box(m, (0, .2, z), (1.05, .06, .12), "wood")
        cart(m, .05, 1.7, ore)
        for k in range(4):
            rock(m, (-1.7 + k * .33, .3, 1.65), (.36, .33, .35), ore)
        if kind == "iron":
            for x, y in ((-1, 1.1), (.8, 1.7), (1.3, .9)):
                rock(m, (x, y, .45), (.3, .46, .25), "iron")
            box(m, (1.7, .2, .4), (.18, 2.7, .18), "metal", "Metal")
            box(m, (1.2, 2.8, .4), (1.4, .16, .18), "metal", "Metal")
        else:
            hut(m, 1.75, .1, .8, 1.1)
    else:
        hut(m, -.7, -.55, 2.0, 1.8, "canvas")
        for x in (.65, 2.05):
            box(m, (x, .2, .7), (.12, 1.6, .12), "wood")
        box(m, (1.35, 1.75, .7), (1.6, .12, .12), "wood")
        for k in range(3):
            box(m, (.9 + k * .4, 1.04, .7), (.23, .6, .2), "food")
        for x, z in ((-.9, 1.5), (-1.65, 1.45), (-1.4, 1.9)):
            box(m, (x, .2, z), (.5, .48, .5), "wood")
            box(m, (x, .69, z), (.51, .06, .51), "snow", "Snow")
        for k in range(7):
            angle = k * np.pi * 2 / 7
            rock(m, (.6 + np.cos(angle) * .45, .28, 1.8 + np.sin(angle) * .45),
                 (.17, .13, .17))
        m.add_soup("Fire", cone_soup(.25, .55, 7, y0=.24), C["cut"], T(.6, 0, 1.8))
    return m


if __name__ == "__main__":
    for kind in ("wood", "coal", "iron", "food"):
        mesh = site(kind)
        writer = GLB()
        root = writer.add_node("resource_" + kind, mesh=writer.add_mesh(kind, mesh))
        writer.save(str(OUT / f"res_{kind}.glb"), [root])
        print(f"Built res_{kind}.glb")
