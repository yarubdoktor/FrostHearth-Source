#!/usr/bin/env python3
"""محاكاة موازنة المعارك (Stage 33) — نسخة بايثون من scripts/combat.gd لقياس منحنى الفوز والخسائر دون تشغيل Godot.

التشغيل (من جذر المشروع):  python3 tools/war_balance_sim.py
غيّر ATTACK (dmg_scale/retreat/max_rounds) هنا ثم انقل القيم المناسبة إلى WarRules.ATTACK_OPTS في scripts/game/war_rules.gd.
ملاحظة: مولّد الأرقام العشوائية مختلف عن Godot، فالنسب تقريبية لا مطابقة حرفيًا.
"""
import random

T = {"shield": dict(atk=8, df=14, hp=30, row=0, beats="bow"),
     "spear": dict(atk=13, df=9, hp=24, row=1, beats="shield"),
     "bow": dict(atk=16, df=5, hp=18, row=2, beats="spear")}
COUNTER = 1.35
ATTACK = dict(dmg_scale=0.45, retreat=0.5, max_rounds=16)   # يطابق WarRules.ATTACK_OPTS
LEGACY = dict(dmg_scale=1.0, retreat=0.0, max_rounds=12)    # سلوك الغارات القديم


def groups(units):
    out = []
    for k, n in units.items():
        tp, tier = k.split("_")
        t, m = T[tp], 1.5 ** (int(tier) - 1)
        out.append(dict(n=float(n), type=tp, row=t["row"], atk=t["atk"] * m, df=t["df"] * m, hp=t["hp"] * m))
    return sorted(out, key=lambda g: g["row"])


def alive(gs):
    return [g for g in gs if g["n"] >= 0.5]


def damage(att, df, rng):
    al = alive(df)
    if not al:
        return 0.0
    tg, tot = al[0], 0.0
    for g in att:
        if g["n"] < 0.5:
            continue
        m = COUNTER if T[g["type"]]["beats"] == tg["type"] else 1.0
        tot += g["n"] * g["atk"] * m * rng.uniform(.92, 1.08)
    return tot


def apply(df, dmg):
    for g in df:
        if dmg <= 0:
            break
        if g["n"] < 0.5:
            continue
        per = g["hp"] * (1 + g["df"] / 40)
        cap = g["n"] * per
        if dmg >= cap:
            dmg -= cap
            g["n"] = 0.0
        else:
            g["n"] -= dmg / per
            dmg = 0.0


def fight(a_units, d_units, seed, opts):
    rng = random.Random(seed)
    A, D = groups(a_units), groups(d_units)
    a0, d0 = sum(a_units.values()), sum(d_units.values())
    retreated = False
    for _ in range(opts["max_rounds"]):
        if not alive(A) or not alive(D):
            break
        da = damage(A, D, rng) * opts["dmg_scale"]
        dd = damage(D, A, rng) * opts["dmg_scale"]
        apply(D, da)
        apply(A, dd)
        al, dl = sum(g["n"] for g in A), sum(g["n"] for g in D)
        if opts["retreat"] and al / a0 < opts["retreat"] and al / a0 < dl / d0 and al >= 0.5:
            retreated = True
            break
    al, dl = sum(round(g["n"]) for g in A), sum(round(g["n"]) for g in D)
    win = not retreated and (dl < 0.5 or (al >= 0.5 and al / a0 > dl / d0 * 1.15))
    return win, (a0 - al) / a0, (d0 - dl) / d0


def comp(n):
    return {"shield_1": n // 3, "spear_1": n // 3, "bow_1": n - 2 * (n // 3)}


if __name__ == "__main__":
    for name, opts in (("القديم (الغارات)", LEGACY), ("الهجوم الجديد", ATTACK)):
        print(f"--- {name}: {opts}")
        print("نسبة القوة (مهاجم/مدافع) | فوز | خسارة المهاجم | خسارة المدافع")
        for ratio in (.5, .7, .9, 1.0, 1.1, 1.25, 1.5, 2.0):
            n, w, la, ld = 150, 0, 0.0, 0.0
            for s in range(n):
                ok, a, d = fight(comp(120), comp(int(120 / ratio)), s + 1, opts)
                w += ok
                la += a
                ld += d
            print(f"{ratio:>6}                  | {w / n * 100:3.0f}% | {la / n * 100:4.0f}%         | {ld / n * 100:4.0f}%")
