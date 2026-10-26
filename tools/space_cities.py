"""Deterministic city-only layout repair; preserve resources, beasts and landmarks.

Reuse the existing terrain function without importing its map-generating side
effects. Four CITY plots = 2x2 plots, five existing world units per plot.
Run from the project directory: python tools/space_cities.py
"""
import ast
import json
import math
from pathlib import Path

import numpy as np
from scipy.ndimage import map_coordinates, maximum_filter

ROOT = Path(__file__).resolve().parents[1]
PLOT = 5
SIDE = PLOT * 2
CITY_SPACING = SIDE + 2
RESOURCE_CLEARANCE = SIDE / 2 + 2.3
BEAST_CLEARANCE = SIDE / 2 + 1.0


def terrain(data):
    # Explicit allow-list: never execute the generator's file writes.
    tree = ast.parse((ROOT / "tools/build_map.py").read_text())
    names = {"hash2", "vnoise", "fbm", "sstep", "gap_factor", "height_fn"}
    functions = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in names]
    namespace = {
        "np": np, "C": 600, "N": 1200, "R_IN": 165.0, "R_OUT": 400.0,
        "GAPS_IN": np.radians([0, 90, 180, 270]),
        "GAPS_OUT": np.radians(np.arange(8) * 45 + 22.5),
        "LAKES": data["lakes"], "LANDMARKS": data["landmarks"],
    }
    exec(compile(ast.Module(body=functions, type_ignores=[]), "terrain_functions", "exec"), namespace)
    gx, gz = np.meshgrid(np.arange(0, 1201, 4), np.arange(0, 1201, 4))
    heights = namespace["height_fn"](gx, gz).astype(np.float32)
    dz, dx = np.gradient(heights, 4)
    tx, tz = np.meshgrid(np.arange(1200) + 0.5, np.arange(1200) + 0.5)
    h = map_coordinates(heights, [tz / 4, tx / 4], order=1)
    slope = map_coordinates(np.hypot(dx, dz), [tz / 4, tx / 4], order=1)
    blocked = (h > 0.9) | (h < -0.2) | (slope > 0.12)
    for x, z, r in data["lakes"]:
        blocked |= np.hypot(tx - x, tz - z) < r + 4
    blocked[:60] = blocked[-60:] = True
    blocked[:, :60] = blocked[:, -60:] = True
    safe = maximum_filter(blocked.astype(np.uint8), size=13, mode="constant", cval=1) == 0
    return heights, safe


def main():
    path = ROOT / "data/map_data.json"
    data = json.loads(path.read_text())
    heights, safe = terrain(data)
    # Block all city centres whose full footprint would touch another object.
    allowed = safe.copy()

    def block_point(x, z, half):
        x0, x1 = max(0, math.floor(x - half) + 1), min(1200, math.ceil(x + half))
        z0, z1 = max(0, math.floor(z - half) + 1), min(1200, math.ceil(z + half))
        allowed[z0:z1, x0:x1] = False

    for obj in data["resources"]:
        block_point(obj["x"], obj["y"], RESOURCE_CLEARANCE)
    for obj in data["beasts"]:
        block_point(obj["x"], obj["y"], BEAST_CLEARANCE)
    for obj in data["landmarks"]:
        block_point(obj["x"], obj["y"], SIDE / 2 + obj["r"] + 3)
    block_point(700.5, 920.5, 7)
    home = data["home"]
    block_point(home["x"] + 0.5, home["y"] + 0.5, CITY_SPACING)
    moved = 0
    for city in data["cities"]:
        old_x, old_z = int(city["x"]), int(city["y"])
        found = None
        for radius in range(0, 181):
            candidates = [(old_x, old_z)] if radius == 0 else (
                [(x, old_z - radius) for x in range(old_x - radius, old_x + radius + 1)]
                + [(x, old_z + radius) for x in range(old_x - radius, old_x + radius + 1)]
                + [(old_x - radius, z) for z in range(old_z - radius + 1, old_z + radius)]
                + [(old_x + radius, z) for z in range(old_z - radius + 1, old_z + radius)]
            )
            # Stable nearest-first ordering within each square shell.
            candidates.sort(key=lambda p: ((p[0] - old_x) ** 2 + (p[1] - old_z) ** 2, p))
            for x, z in candidates:
                if 0 <= x < 1200 and 0 <= z < 1200 and allowed[z, x]:
                    found = (x, z)
                    break
            if found is not None:
                break
        if found is None:
            raise RuntimeError(f"No safe city plot found near {old_x},{old_z}")
        x, z = found
        moved += (x, z) != (old_x, old_z)
        city["x"], city["y"] = float(x), float(z)
        city["h"] = round(float(map_coordinates(heights, [[z / 4], [x / 4]], order=1)[0]), 2)
        block_point(x, z, CITY_SPACING)
    rows = []
    for row in safe:
        edges = np.diff(np.pad(row.astype(np.int8), (1, 1)))
        rows.append(list(zip(np.flatnonzero(edges == 1).tolist(), np.flatnonzero(edges == -1).tolist())))
    grid = {"version": 1, "plot_side": PLOT, "plots": [2, 2], "spacing": CITY_SPACING, "rows": rows}
    (ROOT / "data/city_placement_grid.json").write_text(json.dumps(grid, separators=(",", ":")))
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    print(f"Cities: {len(data['cities'])}; moved: {moved}; resources/beasts/landmarks unchanged")


if __name__ == "__main__":
    main()
