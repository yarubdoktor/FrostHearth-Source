extends RefCounted
## محرك المعارك: جولات متزامنة، صفوف (دروع ← رماح ← رماة)، مثلث التفوق، وتأثير الطقس ومهارات الأبطال.

const Defs := preload("res://scripts/defs.gd")
const MAX_ROUNDS := 12


## units: {"shield_1": 40, ...} أو {"beast": 30}
## mods: {"atk": {type: pct}, "def": {...}, "hp": {...}, "all": pct, "skill": hero_id, "taken": mult, "beast": {atk, def, hp, name}}
static func _groups(units: Dictionary, mods: Dictionary, storm: bool) -> Array:
	var out: Array = []
	var skill: String = mods.get("skill", "")
	var all_b: float = float(mods.get("all", 0.0))
	for key in units:
		var n := float(units[key])
		if n < 0.5:
			continue
		var g := {"key": key, "n": n, "start": n}
		if key == "beast":
			var b: Dictionary = mods["beast"]
			g["type"] = "beast"
			g["row"] = 0
			g["atk"] = float(b["atk"])
			g["def"] = float(b["def"])
			g["hp"] = float(b["hp"])
		else:
			var parts: PackedStringArray = String(key).split("_")
			var tp := parts[0]
			var tier := int(parts[1])
			var t: Dictionary = Defs.TROOPS[tp]
			var m := Defs.tier_mult(tier)
			g["type"] = tp
			g["row"] = int(t["row"])
			g["atk"] = float(t["atk"]) * m * (1.0 + float(mods.get("atk", {}).get(tp, 0.0)) + all_b)
			g["def"] = float(t["def"]) * m * (1.0 + float(mods.get("def", {}).get(tp, 0.0)) + all_b)
			g["hp"] = float(t["hp"]) * m * (1.0 + float(mods.get("hp", {}).get(tp, 0.0)) + float(mods.get("hp_all", 0.0)))
			if storm and tp == "bow" and skill != "siraj":
				g["atk"] *= 0.8
			if storm and tp == "shield":
				g["def"] *= 1.1
		out.append(g)
	out.sort_custom(func(a, b): return a["row"] < b["row"])
	return out


static func _alive(gs: Array) -> Array:
	return gs.filter(func(g): return g["n"] >= 0.5)


static func _damage(att: Array, def: Array, mods: Dictionary, rnd: int, rng: RandomNumberGenerator) -> float:
	var alive := _alive(def)
	if alive.is_empty():
		return 0.0
	var target: Dictionary = alive[0]
	var skill: String = mods.get("skill", "")
	var total := 0.0
	for g in att:
		if g["n"] < 0.5:
			continue
		var mult := 1.0
		# Crafted rune damage is per troop type and never applies against beasts.
		if target["type"] != "beast":
			mult *= 1.0 + float(mods.get("damage", {}).get(g["type"], 0.0))
		if g["type"] != "beast" and Defs.TROOPS[g["type"]]["beats"] == target["type"]:
			mult *= Defs.COUNTER_BONUS
		if target["type"] == "beast":
			if g["type"] == "spear":
				mult *= 1.2
			if skill == "bariq":
				mult *= 1.25
		if skill == "nimr" and rnd == 1:
			mult *= 2.0
		if skill == "siraj" and rnd <= 3 and g["type"] == "bow":
			mult *= 1.15
		total += float(g["n"]) * float(g["atk"]) * mult * rng.randf_range(0.92, 1.08)
	return total


static func _apply(def: Array, dmg: float, taken: float) -> Dictionary:
	var lost := {}
	dmg *= taken
	for g in def:
		if dmg <= 0.0:
			break
		if g["n"] < 0.5:
			continue
		var per := float(g["hp"]) * (1.0 + float(g["def"]) / 40.0)
		var cap := float(g["n"]) * per
		var k := 0.0
		if dmg >= cap:
			k = g["n"]
			dmg -= cap
		else:
			k = dmg / per
			dmg = 0.0
		g["n"] = float(g["n"]) - k
		lost[g["key"]] = float(lost.get(g["key"], 0.0)) + k
	return lost


static func _name(key: String, mods: Dictionary) -> String:
	if key == "beast":
		return mods["beast"]["name"]
	return Defs.TROOPS[key.split("_")[0]]["plural"]


static func _alive_total(gs: Array) -> float:
	var s := 0.0
	for g in gs:
		s += maxf(float(g["n"]), 0.0)
	return s


static func _sum(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += float(d[k])
	return s


## تطبيق تشكيل قتالي على قواميس تعديلات الجيش — نسخة عميقة، لا يغيّر «متوازنة» شيئًا
## يُحفظ عامل القتلى داخل «formation_dead» لتُستخدم عند توزيع الجرحى والقتلى
static func with_formation(mods: Dictionary, formation: String) -> Dictionary:
	var f: Dictionary = Defs.FORMATIONS.get(formation, Defs.FORMATIONS["balanced"])
	var out := mods.duplicate(true)
	var a := float(f["atk"])
	var d := float(f["def"])
	for tp in ["shield", "spear", "bow"]:
		out["atk"][tp] = float(out["atk"].get(tp, 0.0)) + a
		out["def"][tp] = float(out["def"].get(tp, 0.0)) + d
	out["taken"] = float(out.get("taken", 1.0)) * float(f["taken"])
	out["formation_dead"] = float(f["dead"])
	return out


## Stage 33: opts اختيارية — الافتراضي يطابق السلوك القديم تمامًا (الغارات والاختبارات القديمة لا تتأثر):
##   dmg_scale: مضاعف ضرر الجولة (أقل من 1 = معارك أطول وأقل حدّة) • retreat: نسبة بقاء المهاجم التي يتراجع عندها وهو خاسر
##   max_rounds: عدد الجولات الأقصى
static func fight(att_units: Dictionary, att_mods: Dictionary, def_units: Dictionary, def_mods: Dictionary, storm: bool, seed_v: int = 0, opts: Dictionary = {}) -> Dictionary:
	var dmg_scale := float(opts.get("dmg_scale", 1.0))
	var retreat := float(opts.get("retreat", 0.0))
	var max_rounds := int(opts.get("max_rounds", MAX_ROUNDS))
	var a_start := maxf(_sum(att_units), 1.0)
	var d_start := maxf(_sum(def_units), 1.0)
	var retreated := false
	var rng := RandomNumberGenerator.new()
	if seed_v != 0:
		rng.seed = seed_v
	else:
		rng.randomize()
	var A := _groups(att_units, att_mods, storm)
	var D := _groups(def_units, def_mods, storm)
	var lines: Array[String] = []
	var rounds := 0
	for rnd in range(1, max_rounds + 1):
		if _alive(A).is_empty() or _alive(D).is_empty():
			break
		rounds = rnd
		var da := _damage(A, D, att_mods, rnd, rng) * dmg_scale
		var dd := _damage(D, A, def_mods, rnd, rng) * dmg_scale
		var ld := _apply(D, da, float(def_mods.get("taken", 1.0)))
		var la := _apply(A, dd, float(att_mods.get("taken", 1.0)))
		if rnd <= 4:
			var p1: Array[String] = []
			for k in la:
				if la[k] >= 1.0:
					p1.append("%d %s" % [int(la[k]), _name(k, att_mods)])
			var p2: Array[String] = []
			for k in ld:
				if ld[k] >= 1.0:
					p2.append("%d %s" % [int(ld[k]), _name(k, def_mods)])
			lines.append("الجولة %d: سقط من المهاجمين %s • ومن المدافعين %s" % [rnd,
					"، ".join(p1) if not p1.is_empty() else "لا أحد", "، ".join(p2) if not p2.is_empty() else "لا أحد"])
		if retreat > 0.0:
			var ar := _alive_total(A) / a_start
			var dr := _alive_total(D) / d_start
			if ar < retreat and ar < dr and _alive_total(A) >= 0.5:   # لا «تراجع» لجيش أُبيد بالكامل
				retreated = true
				lines.append("تراجع المهاجمون في الجولة %d للحفاظ على ما تبقى من قوتهم." % rnd)
				break
	var a_left := {}
	var a_loss := {}
	for g in A:
		a_left[g["key"]] = int(round(g["n"]))
		a_loss[g["key"]] = int(round(g["start"])) - int(round(g["n"]))
	var d_left := {}
	var d_loss := {}
	for g in D:
		d_left[g["key"]] = int(round(g["n"]))
		d_loss[g["key"]] = int(round(g["start"])) - int(round(g["n"]))
	# الفائز: من بقي له جيش، وعند التعادل يفوز صاحب النسبة الأعلى من الباقين، والمدافع يفوز عند التساوي
	var ra := _sum(a_left) / maxf(_sum(att_units), 1.0)
	var rd := _sum(d_left) / maxf(_sum(def_units), 1.0)
	var att_win := not retreated and (_sum(d_left) < 0.5 or (_sum(a_left) >= 0.5 and ra > rd * 1.15))
	return {"att_win": att_win, "rounds": rounds, "att_left": a_left, "att_loss": a_loss,
			"def_left": d_left, "def_loss": d_loss, "log": lines, "retreated": retreated}
