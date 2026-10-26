extends RefCounted
## Stage 18 — ملف دفاع المدينة الموحد (بند 3.1). منطق نقي للقراءة فقط: لا يعدّل حالة اللعبة.
## يجمع: الجنود الحاضرين + أبحاثهم + قائد الدفاع + السور والأبراج. كل غارة تستهلكه (بند 3.2).
## لا حامية مجانية: بلا جنود حاضرين لا يقاتل السور وحده.

const Defs := preload("res://scripts/defs.gd")


static func present_units(g) -> Dictionary:
	var army := {}
	for k in g.troops:
		if int(g.troops[k]) > 0:
			army[k] = int(g.troops[k])
	return army


static func wall_level(g) -> int:
	return g.max_level_of("wall")


static func profile(g) -> Dictionary:
	var units := present_units(g)
	var lv := wall_level(g)
	var wb := Defs.wall_bonuses(lv)
	# أبحاث الدفاع (ل3): تُضاف إلى مكافأة السور نفسها وتعمل فقط في الدفاع
	wb["def"] = float(wb["def"]) + g.bonus("wall_def")
	wb["atk"] = float(wb["atk"]) + g.bonus("tower_atk")
	var whp: float = g.bonus("wall_hp")
	var mods: Dictionary = g.army_mods(g.defender)
	for tp in Defs.TROOP_ORDER:
		mods["def"][tp] = float(mods["def"].get(tp, 0.0)) + float(wb["def"])
		mods["atk"][tp] = float(mods["atk"].get(tp, 0.0)) + float(wb["atk"])
		mods["hp"][tp] = float(mods["hp"].get(tp, 0.0)) + whp
	var base := 0.0
	var gear_weight := 0.0
	for k in units:
		var parts: PackedStringArray = String(k).split("_")
		var unit_power: float = int(units[k]) * Defs.troop_power(parts[0], int(parts[1]))
		base += unit_power
		var crafted: Dictionary = g.GearRules.bonuses(g.equipment, parts[0])
		gear_weight += unit_power * (float(crafted["atk"]) + float(crafted["def"]) + 0.5 * float(crafted["hp"]) + float(crafted["damage"]))
	return {
		"units": units,
		"mods": mods,
		"storm": g.storm_active(),
		"hero": g.defender,
		"wall": {"level": lv, "def": float(wb["def"]), "atk": float(wb["atk"]), "hp": whp},
		"troops": g.troop_total(),
		"power": int(round(base * (1.0 + float(wb["def"]) + float(wb["atk"]) + 0.5 * whp) + gear_weight)),
	}
