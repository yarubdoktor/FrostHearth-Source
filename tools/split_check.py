#!/usr/bin/env python3
"""tools/split_check.py — حارس تقسيم الملفات (لا يحتاج Godot، بايثون فقط).

التشغيل من جذر المشروع:   python3 tools/split_check.py
يفحص:
 1) حجم كل ملف .gd (تحذير > SOFT، خطأ > HARD) — سياسة «لا ملف يكبر حتى يصير خطرًا».
 2) سلاسل الطبقات (extends "res://...") للملفات الكبيرة: الملفات موجودة، بلا دورات.
 3) لا دالة معرّفة مرتين في السلسلة، والمتغيرات/الثوابت/الإشارات في الطبقة الجذرية فقط.
 4) كل طبقة تستدعي دوال طبقتها وما تحتها فقط (الاستدعاء للأعلى يكسر Godot عند التحليل).
 5) كل Game.xxx المستعمل في المشروع ما زال معرّفًا في سلسلة game_state.
خروج 0 = سليم، 1 = خطأ.
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOFT, HARD = 500, 800          # سطر
CHAIN_ENTRIES = ["scripts/game_state.gd", "scripts/city.gd", "scripts/world_map.gd"]
GAME_ENTRY = "scripts/game_state.gd"

TOP = re.compile(r"^(static func|func|var|const|signal|enum|class_name|extends|@\w+|class )")

def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        t = f.read().split("\n")
    return t[:-1] if t and t[-1] == "" else t

def strip_code(s, keep_strings=False):
    out = []; i = 0; n = len(s); strs = []
    while i < n:
        c = s[i]
        if c == "#": break
        if c in "\"'":
            q = c; j = i + 1
            while j < n and s[j] != q:
                if s[j] == "\\": j += 1
                j += 1
            strs.append(s[i+1:j]); out.append('""'); i = j + 1; continue
        out.append(c); i += 1
    return ("".join(out), strs)

def decls(lines):
    res = []
    starts = [i for i, l in enumerate(lines) if TOP.match(l)]
    for k, s in enumerate(starts):
        l = lines[s]
        m = re.match(r"^(?:static )?func (\w+)", l)
        if m: kind, name = "func", m.group(1)
        else:
            m = re.match(r"^(var|const|signal|enum) (\w+)", l)
            if m: kind, name = m.group(1), m.group(2)
            else: kind, name = ("extends" if l.startswith("extends") else "other"), l
        res.append([kind, name, s, None])
    for k, d in enumerate(res):
        d[3] = (res[k+1][2] if k + 1 < len(res) else len(lines))
    return res

def chain_of(entry, errors):
    chain = []; cur = entry; seen = set()
    while True:
        if cur in seen:
            errors.append(f"دورة extends عند {cur}"); break
        seen.add(cur)
        if not os.path.exists(os.path.join(ROOT, cur)):
            errors.append(f"ملف غير موجود في السلسلة: {cur}"); break
        lines = read(cur)
        ext = next((l for l in lines if l.startswith("extends")), "extends Node")
        chain.append(cur)
        m = re.match(r'extends "res://([^"]+)"', ext)
        if not m: break
        cur = m.group(1)
    return list(reversed(chain))   # الجذر أولًا

def check_chain(entry, errors, warns):
    chain = chain_of(entry, errors)
    if errors and len(chain) < 1: return
    if len(chain) < 2:
        return
    funcs_layer = {}; layer_lines = {}
    root_decl = set()
    for li, rel in enumerate(chain):
        lines = read(rel); layer_lines[rel] = lines
        for kind, name, s, e in decls(lines):
            if kind == "func":
                if name in funcs_layer:
                    errors.append(f"دالة مكررة في السلسلة: {name} ({rel} و{chain[funcs_layer[name]]})")
                funcs_layer[name] = li
            elif kind in ("var", "const", "signal", "enum"):
                if li != 0:
                    errors.append(f"{rel}: {kind} {name} يجب أن يكون في الطبقة الجذرية {chain[0]}")
                root_decl.add(name)
    for li, rel in enumerate(chain):
        lines = layer_lines[rel]
        for kind, name, s, e in decls(lines):
            if kind != "func": continue
            for ln in range(s, e):
                code, strs = strip_code(lines[ln])
                for m in re.finditer(r"(?<![\w.])([A-Za-z_]\w*)\s*\(", code):
                    f = m.group(1)
                    if f in funcs_layer and funcs_layer[f] > li:
                        errors.append(f"{rel}:{ln+1} {name}() يستدعي {f}() من طبقة أعلى ({chain[funcs_layer[f]]})")
                for sname in strs:
                    if sname in funcs_layer and funcs_layer[sname] > li and sname.startswith("_"):
                        errors.append(f"{rel}:{ln+1} {name}() يذكر اسم الدالة \"{sname}\" من طبقة أعلى")
    return chain, funcs_layer, root_decl

def main():
    errors, warns = [], []
    # 1) الأحجام
    for base, _, files in os.walk(ROOT):
        if any(p in base for p in (".godot", "/tools")): continue
        for fn in files:
            if not fn.endswith(".gd"): continue
            rel = os.path.relpath(os.path.join(base, fn), ROOT)
            if fn.startswith("test_"): continue
            n = len(read(rel))
            if n > HARD: errors.append(f"{rel}: {n} سطرًا > الحد الأقصى {HARD} — يجب تقسيمه قبل أي إضافة")
            elif n > SOFT: warns.append(f"{rel}: {n} سطرًا (قائمة المراقبة > {SOFT})")
    # 2-4) السلاسل
    game_info = None
    for entry in CHAIN_ENTRIES:
        if not os.path.exists(os.path.join(ROOT, entry)): continue
        r = check_chain(entry, errors, warns)
        if entry == GAME_ENTRY and r: game_info = r
    # 5) واجهة Game
    if game_info:
        chain, funcs_layer, root_decl = game_info
        known = set(funcs_layer) | root_decl
        for base, _, files in os.walk(ROOT):
            if ".godot" in base: continue
            for fn in files:
                if not fn.endswith(".gd"): continue
                rel = os.path.relpath(os.path.join(base, fn), ROOT)
                for i, l in enumerate(read(rel), 1):
                    code, _ = strip_code(l)
                    for m in re.finditer(r"\bGame\.([A-Za-z_]\w*)", code):
                        # Game.reveal ... شائع لأعضاء Node نفسه
                        nm = m.group(1)
                        if nm not in known and nm not in NODE_MEMBERS:
                            errors.append(f"{rel}:{i} Game.{nm} غير معرّف في سلسلة game_state")
    for w in warns: print("تحذير:", w)
    for e in errors: print("خطأ:", e)
    print(("✔ سليم" if not errors else f"✘ {len(errors)} خطأ"), f"— {len(warns)} تحذير")
    return 1 if errors else 0

# أعضاء Node/Object الأصلية التي قد تُستدعى عبر Game.xxx (ليست من سلسلة الطبقات)
NODE_MEMBERS = {"get_tree","add_child","remove_child","get_node","get_parent","name","queue_free","connect","disconnect","emit_signal",
                "is_connected","set_process","set_physics_process","get_children","has_method","has_signal","call","callv","call_deferred",
                "get_script","get","set","tree_exited","tree_entered","ready","process_mode","is_inside_tree","get_path","add_to_group",
                "is_in_group","notification","get_instance_id"}

if __name__ == "__main__":
    sys.exit(main())
