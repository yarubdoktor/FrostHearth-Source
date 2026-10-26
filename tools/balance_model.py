#!/usr/bin/env python3
"""نموذج موازنة «مدينة الصقيع» (Stage 17): يقرأ scripts/defs.gd ويطبع جدولًا بما يستهلكه كل مبنى من دخل المدينة.

التشغيل (من جذر المشروع):  python3 tools/balance_model.py

المقياس φ = (تكلفة المورد ÷ زمن البناء بالساعات) ÷ دخل المدينة الكلي من ذلك المورد في الساعة.
  φ = 1  → بنّاء واحد يلتهم كل دخل المورد طوال البناء.   φ = 0.3 → الوقت هو العائق لا الموارد.
الافتراض: كل مباني المورد بمستوى L-1 (طعام 3، خشب 3، فحم 2، حديد 2)، بلا أبحاث ولا مكافآت.
الهدف المعتمد: φ ≤ ~1.3 عند المستوى 12 لكل المباني، ويهبط نحو 0.6 عند 20 و0.35 عند 30 (الوقت يتولى الإبطاء).
غيّر قيم "pace" في BUILDINGS (defs.gd) ثم أعد التشغيل لترى الأثر.
"""
import re, os, sys

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "defs.gd")
RATE = {"food": 720.0, "wood": 600.0, "coal": 330.0, "iron": 140.0}
N = {"food": 3, "wood": 3, "coal": 2, "iron": 2}
G, GR = 1.58, 1.55
PACE_FROM, PACE_TO = 6, 12


def load():
    txt = open(SRC, encoding="utf8").read()
    pd = lambda s: {a: int(b) for a, b in re.findall(r'"(\w+)": (\d+)', s)}
    out = {}
    pat = (r'\t"(\w+)": \{"name": "[^"]*", "max": (\d+), "time": ([\d.]+)(?:, "pace": ([\d.]+))?'
           r'(?:, "prod": "(\w+)", "rate": ([\d.]+))?,\n\t\t"cost": (\{[^}]*\}), "from": (\{[^}]*\})')
    for m in re.finditer(pat, txt):
        k, mx, tm, pace, prod, rate, cost, frm = m.groups()
        out[k] = {"time": float(tm), "pace": float(pace) if pace else 1.0, "cost": pd(cost), "from": pd(frm)}
    return out


def pace(b, L):
    if b["pace"] >= 1.0 or L <= PACE_FROM:
        return 1.0
    return b["pace"] ** min(max((L - PACE_FROM) / (PACE_TO - PACE_FROM), 0.0), 1.0)


def cost(b, L):
    return {r: round(c * G ** (L - b["from"][r]) * pace(b, L) / 10) * 10 for r, c in b["cost"].items() if L >= b["from"][r]}


def income(r, L):
    return N[r] * RATE[r] * L * (1 + 0.09 * L)


def phi(b, L):
    hrs = b["time"] * GR ** (L - 1) / 3600
    c = cost(b, L)
    return max((c[r] / hrs / income(r, L - 1) for r in ("wood", "coal", "iron") if r in c), default=0.0)


if __name__ == "__main__":
    B = load()
    levels = (8, 10, 12, 15, 20, 25, 30)
    print("φ لكل مبنى (أعلى مورد استهلاكًا)")
    print(f"{'المبنى':12s}" + "".join(f"{('م%d' % L):>7s}" for L in levels))
    for t, b in B.items():
        print(f"{t:12s}" + "".join(f"{phi(b, L):7.2f}" for L in levels))
    at12 = [phi(b, 12) for b in B.values()]
    print(f"\nنسبة أثقل/أخف مبنى عند م12: {max(at12) / min(at12):.2f}  (الهدف ≤ 2.6)")
