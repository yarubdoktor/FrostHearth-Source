extends "res://scripts/game/state/state_core.gd"
## الطبقة 2/6 — الجيش: أعداد الجنود والثكنات والمعسكر والقوة والتعديلات وحساب التدريب (قراءة وحساب فقط).


func troop_total() -> int:
	var n := 0
	for k in troops:
		n += int(troops[k])
	return n


func wounded_total() -> int:
	var n := 0
	for k in wounded:
		n += int(wounded[k])
	return n


func wounded_cap() -> int:
	var c := 50
	for id in Defs.PLOTS:
		if Defs.PLOTS[id]["type"] == "infirmary":
			c += 40 * level(id)
	return c


func barracks_level(tp: String) -> int:
	## مستوى ثكنة نوع الجنود tp
	return level(str(Defs.BARRACKS_PLOT[tp]))


func max_tier_of(tp: String) -> int:
	var b := barracks_level(tp)
	var t := 0
	for i in range(1, 5):
		if b >= Defs.TIER_BARRACKS[i]:
			t = i
	return t


func max_tier() -> int:
	## أعلى رتبة يمكن تدريبها في أي ثكنة
	var t := 0
	for tp in Defs.TROOP_ORDER:
		t = maxi(t, max_tier_of(tp))
	return t


func train_batch_of(tp: String) -> int:
	var b := Defs.train_batch(barracks_level(tp))
	return 0 if b <= 0 else b + int(bonus("train_cap"))


func train_batch() -> int:
	var m := 0
	for tp in Defs.TROOP_ORDER:
		m = maxi(m, train_batch_of(tp))
	return m


func camp_level() -> int:
	return level("ba1")


func army_cap() -> int:
	return Defs.camp_capacity(camp_level())


func army_away() -> int:
	## جنود المسيرة العسكرية الخارجة (لا يشاركون في الدفاع حتى يعودوا)
	var n := 0
	if not venture.is_empty():
		for k in venture.get("units", {}):
			n += int(venture["units"][k])
	return n


func training_total() -> int:
	var n := 0
	for tp in train:
		n += int(train[tp].get("n", 0))
	return n


func army_count() -> int:
	## ما يشغل سعة المعسكر: الجنود الحاضرون + قيد التدريب + في مهمة
	return troop_total() + training_total() + army_away()


func has_military() -> bool:
	if camp_level() > 0:
		return true
	for tp in Defs.TROOP_ORDER:
		if barracks_level(tp) > 0:
			return true
	return false


func heroes_owned() -> int:
	var n := 0
	for id in heroes:
		if heroes[id]["owned"]:
			n += 1
	return n


func hero_cap() -> int:
	return clampi(max_level_of("hero_hall") * 5, 0, 50)


func power() -> float:
	var p := 0.0
	for k in troops:
		var parts: PackedStringArray = String(k).split("_")
		p += int(troops[k]) * Defs.troop_power(parts[0], int(parts[1]))
	for id in Defs.PLOTS:
		p += level(id) * 12.0
	for id in heroes:
		if heroes[id]["owned"]:
			p += Defs.hero_power(int(heroes[id]["lv"]), int(heroes[id]["stars"]))
	for id in techs:
		p += int(techs[id]) * 20.0
	for tp in Defs.TROOP_ORDER:
		p += float(GearRules.bonuses(equipment, tp)["power"])
	return p


func army_mods(hero_id: String) -> Dictionary:
	## المرحلة 2: لكل نوع جنود هجوم ودفاع ومتانة (صحة) من الأبحاث، ثم يُضاف تعزيز البطل لنوعه
	var m := {"atk": {"shield": bonus("atk_shield"), "spear": bonus("atk_spear"), "bow": bonus("atk_bow")},
			"def": {"shield": bonus("def_shield"), "spear": bonus("def_spear"), "bow": bonus("def_bow")},
			"hp": {"shield": bonus("hp_shield"), "spear": bonus("hp_spear"), "bow": bonus("hp_bow")},
			"hp_all": bonus("hp_all"), "all": 0.0, "skill": "", "taken": 1.0, "damage": {}}
	for tp in Defs.TROOP_ORDER:
		var crafted := GearRules.bonuses(equipment, tp)
		for effect in ["atk", "def", "hp"]:
			m[effect][tp] = float(m[effect][tp]) + float(crafted[effect])
		m["damage"][tp] = float(crafted["damage"])
	var wk := max_level_of("workshop")
	if wk > 0:
		for tp in Defs.TROOP_ORDER:
			var gear := Defs.workshop_gear(tp, wk)
			m["atk"][tp] = float(m["atk"][tp]) + float(gear["atk"])
			m["def"][tp] = float(m["def"][tp]) + float(gear["def"])
			m["hp"][tp] = float(m["hp"][tp]) + float(gear["hp"])
	if hero_id != "" and heroes.has(hero_id) and heroes[hero_id]["owned"]:
		var h: Dictionary = heroes[hero_id]
		var tp: String = Defs.HEROES[hero_id]["troop"]
		var b := Defs.hero_bonus(int(h["lv"]), int(h["stars"]))
		m["atk"][tp] = float(m["atk"][tp]) + b
		m["def"][tp] = float(m["def"][tp]) + b
		m["hp"][tp] = float(m["hp"][tp]) + b
		m["skill"] = hero_id
		if hero_id == "salma":
			m["all"] = 0.06
		if hero_id == "reem":
			m["taken"] = 0.85
	return m


func death_mult(key: String) -> float:
	## بند 2.16: من يموت من الجنود الخارجين من المعركة؟ المستوصف والمتانة (أبحاث + ورشة + قائد) تخفضان نسبة القتلى
	var tp := String(key).split("_")[0]
	var mods := army_mods(defender)
	var hp_bonus := float(mods["hp"].get(tp, 0.0)) + float(mods["hp_all"])
	return Defs.death_mult(max_level_of("infirmary"), hp_bonus)


func gear_level(tp: String, slot: String) -> int:
	return Gear.level(self, tp, slot)


func gear_job(tp: String, slot: String) -> Dictionary:
	return Gear.job(self, tp, slot)


func gear_check(tp: String, slot: String) -> Dictionary:
	return Gear.check(self, tp, slot)


func troop_stats(tp: String, tier: int) -> Dictionary:
	## القيم الفعلية لجندي من هذا النوع والرتبة بعد الأبحاث (بدون بطل وبدون عاصفة) — للعرض في المعسكر
	var td: Dictionary = Defs.TROOPS[tp]
	var m := Defs.tier_mult(tier)
	var mods := army_mods("")
	return {"atk": float(td["atk"]) * m * (1.0 + float(mods["atk"][tp])),
			"def": float(td["def"]) * m * (1.0 + float(mods["def"][tp])),
			"hp": float(td["hp"]) * m * (1.0 + float(mods["hp"][tp]) + float(mods["hp_all"])),
			"damage": float(mods["damage"].get(tp, 0.0))}


# ---------------------------------------------------------------- التدريب
func train_time(tp: String, tier: int, n: int) -> float:
	## زمن تدريب n جنديًا: يطول مع الرتبة والعدد، ويقصر بمستوى الثكنة والأبحاث والبطل
	var speed := Defs.barracks_speed(barracks_level(tp)) * (1.0 + bonus("train_speed"))
	return Defs.troop_time(tp, tier, n) / speed


func train_check(tp: String, tier: int, n: int) -> Dictionary:
	var reasons: Array[String] = []
	var bname: String = Defs.BUILDINGS[Defs.BARRACKS_TYPE[tp]]["name"]
	if not dev_mode:   # المطور: تجاوز اشتراط الثكنة والرتبة والسعة
		if barracks_level(tp) <= 0:
			reasons.append("ابنِ %s أولًا" % bname)
		elif tier > max_tier_of(tp):
			reasons.append("الرتبة تتطلب %s بالمستوى %d" % [bname, Defs.TIER_BARRACKS[tier]])
		if camp_level() <= 0:
			reasons.append("ابنِ المعسكر أولًا ليتسع للجنود")
		elif army_count() + n > army_cap():
			reasons.append("سعة المعسكر ممتلئة (%d / %d) — طوّر المعسكر" % [army_count(), army_cap()])
		if n > train_batch_of(tp):
			reasons.append("أكبر دفعة في هذه الثكنة %d" % train_batch_of(tp))
	if train.has(tp):
		reasons.append("الثكنة مشغولة بدفعة أخرى")
	if n <= 0:
		reasons.append("اختر عددًا")
	var c := Defs.troop_cost(tp, tier, n)
	var missing := {}
	for r in c:
		if res[r] < c[r]:
			missing[r] = c[r] - res[r]
	if dev_mode:
		missing = {}
	var time := train_time(tp, tier, n)
	return {"ok": reasons.is_empty() and missing.is_empty(), "reasons": reasons, "missing": missing, "cost": c, "time": time}


func _train_tp(tp: String) -> String:
	## توافق: بلا نوع ← أول طابور نشط
	if tp != "":
		return tp
	for k in train:
		return String(k)
	return ""


func train_next_end() -> float:
	## أقرب موعد انتهاء بين طوابير التدريب (للشريط الجانبي) أو -1
	var e := -1.0
	for tp in train:
		var v := float(train[tp]["end"])
		if e < 0.0 or v < e:
			e = v
	return e


func defense_profile() -> Dictionary:
	## لقطة دفاع للقراءة فقط: الجيش الحاضر + الأبحاث + القائد + السور.
	return CityDefense.profile(self)
