"""Original Stage 11 city meshes. Regenerates no world data or resource assets."""
from pathlib import Path
import math
import numpy as np
from glb import GLB, MeshBuilder, T, box_soup, cyl_soup, cone_soup, MATERIALS

OUT = Path(__file__).resolve().parents[1] / "assets" / "city_skins"
SCALE = 3.2  # authored in world units, stored in shared city-local coordinates
PALETTE = {
    "snow": 0xE9F3F7, "stone": 0x596F83, "edge": 0x93AFC0, "dark": 0x273A4A,
    "wood": 0x785A46, "roof": 0x3C617C, "copper": 0xA86E42, "warm": 0xF6B268,
    "ice": 0x8DCFE0, "aurora": 0x67B7B3, "brass": 0xC8A36B,
    "me": 0x59B9DA, "ally": 0x719DCF, "enemy": 0xC57064, "neutral": 0xABAFB5,
}
C = {k: (np.array([(v >> 16) & 255, (v >> 8) & 255, v & 255]) / 255) ** 2.2
     for k, v in PALETTE.items()}


def box(m, x, y, z, w, h, d, color, mat="Matte", ry=0):
    m.add_soup(mat, box_soup(w, h, d), C[color], T(x, y, z, ry=ry))


def cylinder(m, x, y, z, radius, height, color, mat="Matte", n=12):
    m.add_soup(mat, cyl_soup(radius, radius, height, n), C[color], T(x, y, z))


def roof(m, x, y, z, w, d, color="roof"):
    for side in (-1, 1):
        xf = T(x, y, z + side * d * .24)
        a = side * .48
        xf[:3, :3] = [[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]]
        m.add_soup("Metal", box_soup(w, .12, d * .58), C[color], xf)
        xf[1, 3] += .10
        m.add_soup("Snow", box_soup(w * .94, .10, d * .51), C["snow"], xf)


def house(m, x, z, rotation=0):
    sub = MeshBuilder()
    box(sub, 0, .25, 0, .92, .72, 1.12, "wood")
    box(sub, 0, .63, .57, .36, .25, .04, "warm", "Fire")
    box(sub, -.32, .33, .57, .22, .53, .05, "dark")
    roof(sub, 0, 1.13, 0, 1.12, 1.34)
    box(sub, .28, 1.05, -.27, .14, .56, .15, "dark", "Metal")
    m.merge(sub, T(x, 0, z, ry=rotation))


def furnace(m, skin):
    cylinder(m, 0, .22, -.3, 1.25, .27, "dark", "Metal")
    cylinder(m, 0, .49, -.3, 1.04, .47, "stone", "Metal")
    cylinder(m, 0, .97, -.3, .85, .16, "copper", "Metal")
    cylinder(m, 0, 1.13, -.3, .72, 1.02, "dark", "Metal")
    for i in range(8):
        a = i * math.tau / 8
        box(m, .74 * math.sin(a), 1.25, -.3 + .74 * math.cos(a),
            .19, .53, .12, "warm", "Fire", a)
    cylinder(m, 0, 2.15, -.3, .91, .16, "copper", "Metal")
    cylinder(m, 0, 2.31, -.3, .68, .13, "warm", "Fire")
    cylinder(m, 0, 2.44, -.3, .38, .78, "dark", "Metal")
    cylinder(m, 0, 3.12, -.3, .48, .15, "copper", "Metal")
    cylinder(m, 0, 3.27, -.3, .25, .09, "warm", "Fire")
    for side in (-1, 1):
        box(m, side * .97, .65, -.3, .18, 1.45, .29, "brass", "Metal")
        if skin == "forge":
            cylinder(m, side * 1.28, .27, -.9, .25, 2.72, "dark", "Metal", 8)
            cylinder(m, side * 1.28, 2.8, -.9, .34, .16, "copper", "Metal", 8)
            for z in (.3, .65, 1.0):
                box(m, side * 1.32, .38, z, .24, .65, .17, "copper", "Metal")


def city(skin, team):
    m = MeshBuilder()
    # Identical footprint and anchor for every skin.
    box(m, 0, 0, 0, 7.0, .20, 7.0, "dark")
    box(m, 0, .2, 0, 6.75, .12, 6.75, "snow", "Snow")
    wall_color = "dark" if skin == "forge" else "stone"
    for x, z, w, d in [(0, -3.12, 6.35, .34), (-3.12, 0, .34, 6.35),
                       (3.12, 0, .34, 6.35), (-2.02, 3.12, 2.33, .34),
                       (2.02, 3.12, 2.33, .34)]:
        box(m, x, .25, z, w, .95, d, wall_color)
        box(m, x, 1.2, z, w + .08, .12, d + .12, "snow", "Snow")
    for s in (-1, 1):
        for k in (-2, -1, 0, 1, 2):
            box(m, s * 3.12, 1.3, k, .4, .3, .3, "edge")
            if k:
                box(m, k, 1.3, s * 3.12, .3, .3, .4, "edge")
    for x in (-2.9, 2.9):
        for z in (-2.9, 2.9):
            if skin == "aurora":
                cylinder(m, x, .25, z, .45, 1.75, "stone", n=8)
                m.add_soup("Ice", cone_soup(.43, 1.08, 5), C["ice"], T(x, 2, z))
                cylinder(m, x, 1.8, z, .5, .12, "aurora", "Metal", 8)
            else:
                box(m, x, .25, z, .85, 1.45, .85, wall_color)
                box(m, x, 1.7, z, .97, .15, .97, "snow", "Snow")
                roof(m, x, 2.02, z, 1.1, 1.1, "copper" if skin == "forge" else "roof")
            box(m, x, .95, z + .46, .22, .38, .04, team)
    # Gateway and faction banner remain visible regardless of skin palette.
    for x in (-.88, .88):
        box(m, x, .25, 3.15, .30, 1.45, .5, "stone")
        cylinder(m, x, 1.75, 3.15, .18, .1, "warm", "Fire", 8)
    box(m, 0, 1.66, 3.15, 2.1, .24, .6, "copper" if skin == "forge" else "edge")
    box(m, 0, 1.91, 3.15, 2.2, .12, .66, "snow", "Snow")
    box(m, 0, 1.94, 3.48, .5, .44, .04, team)
    for z in (1.6, 2.1, 2.6, 3.1):
        box(m, 0, .33, z, .85, .035, .34, "edge")
    for x, z, a in [(-2, -1.2, .2), (2, -1.2, -.2), (-2, 1.2, -.3), (2, 1.2, .3)]:
        house(m, x, z, a)
    furnace(m, skin)
    if skin == "forge":
        for x in (-2, 2):
            box(m, x, .32, -2.18, .95, .45, .45, "copper", "Metal")
    elif skin == "aurora":
        for x in (-1.05, 1.05):
            m.add_soup("Ice", cone_soup(.22, 1.42, 5), C["ice"], T(x, .32, 1.27))
        box(m, 0, .35, -2.28, 1.8, .16, .48, "aurora", "Metal")
    else:
        for x in (-1, 1):
            box(m, x, .32, -2.3, .6, .42, .45, "wood")
            box(m, x, .74, -2.3, .64, .08, .49, "snow", "Snow")
    normalized = MeshBuilder()
    normalized.merge(m, T(s=1 / SCALE))
    return normalized


if __name__ == "__main__":
    # Warm, readable furnace/window lights rather than clipped white emission.
    fire = next(material for material in MATERIALS if material["name"] == "Fire")
    fire["pbrMetallicRoughness"]["baseColorFactor"] = [1.0, .72, .38, 1.0]
    fire["emissiveFactor"] = [1.0, .25, .045]
    fire["extensions"]["KHR_materials_emissive_strength"]["emissiveStrength"] = 1.4
    OUT.mkdir(exist_ok=True)
    for skin in ("frontier", "forge", "aurora"):
        for team in ("me", "ally", "enemy", "neutral"):
            writer = GLB()
            mesh = city(skin, team)
            node = writer.add_node(f"{skin}_{team}", mesh=writer.add_mesh(f"{skin}_{team}", mesh))
            path = OUT / f"{skin}_{team}.glb"
            writer.save(str(path), [node])
            print(path.name)
