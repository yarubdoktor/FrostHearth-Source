extends Node
## اختبارات المرحلة 14 (الموازنة 2أ) — منحنيات زمنية طويلة، أبحاث حربية لكل نوع جنود، متانة، وتكلفة تسريع متدرجة
## التشغيل: godot --headless --path . res://test_stage14.tscn

const D := preload("res://scripts/defs.gd")
var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _fresh() -> void:
	Game.dev_mode = false
	Game.new_game()
	for r in Game.res:
		Game.res[r] = 100000000.0
	Game.gems = 100000


func _ready() -> void:
	Game.save_path_override = "user://frost_stage14_%s_test_only.json" % DisplayServer.get_name()
	Game.set_process(false)
	var H := 3600.0
	var DAY := 86400.0

	# 1) منحنى زمن البناء: ثوانٍ ← دقائق ← ساعات ← أيام ← أشهر
	check(D.build_time("furnace", 5) < 120.0, "furnace lv5 under 2 minutes (%s)" % D.fmt_time(D.build_time("furnace", 5)))
	check(D.build_time("furnace", 10) > 600.0 and D.build_time("furnace", 10) < 1800.0, "furnace lv10 between 10 and 30 minutes (%s)" % D.fmt_time(D.build_time("furnace", 10)))
	check(D.build_time("furnace", 15) > H and D.build_time("furnace", 15) < 6.0 * H, "furnace lv15 is hours (%s)" % D.fmt_time(D.build_time("furnace", 15)))
	check(D.build_time("furnace", 20) > 12.0 * H and D.build_time("furnace", 20) < 2.0 * DAY, "furnace lv20 about a day (%s)" % D.fmt_time(D.build_time("furnace", 20)))
	check(D.build_time("furnace", 25) > 3.0 * DAY and D.build_time("furnace", 25) < 15.0 * DAY, "furnace lv25 is days (%s)" % D.fmt_time(D.build_time("furnace", 25)))
	check(D.build_time("furnace", 30) > 60.0 * DAY, "furnace lv30 is months (%s)" % D.fmt_time(D.build_time("furnace", 30)))
	var mono := true
	var months_all := true
	for tp in D.BUILDINGS:
		for lv in range(2, int(D.BUILDINGS[tp]["max"]) + 1):
			if D.build_time(tp, lv) <= D.build_time(tp, lv - 1):
				mono = false
		if D.build_time(tp, int(D.BUILDINGS[tp]["max"])) < 20.0 * DAY:
			months_all = false
	check(mono, "build time strictly increases with level for every building")
	check(months_all, "every building's top level takes at least 20 days")

	# 2) الزمن الفعلي في الواجهة يحترم روافع البناء
	_fresh()
	var t_plain: float = Game.check_upgrade("furnace")["time"]
	check(absf(t_plain - D.build_time("furnace", Game.level("furnace") + 1)) < 0.01, "upgrade time equals defs time without bonuses")
	Game.techs["crane"] = 5
	var t_crane: float = Game.check_upgrade("furnace")["time"]
	check(absf(t_crane - D.build_time("furnace", Game.level("furnace") + 1) / 1.2) < 0.01, "crane research shortens build time by +20%")

	# 3) أزمنة الأبحاث
	var all_short := true
	var all_long := true
	var tmono := true
	for id in D.TECHS:
		if D.tech_time(id, 1) > 120.0:
			all_short = false
		if D.tech_time(id, 8) < H:
			all_long = false
		for lv in range(2, int(D.TECHS[id]["max"]) + 1):
			if D.tech_time(id, lv) <= D.tech_time(id, lv - 1):
				tmono = false
	check(all_short, "every research level 1 takes at most 2 minutes")
	check(all_long, "every research level 8 takes at least 1 hour")
	check(tmono, "research time strictly increases with level")
	check(D.tech_time("saw", 12) > 12.0 * H, "saw lv12 takes more than 12 hours (%s)" % D.fmt_time(D.tech_time("saw", 12)))
	check(D.tech_time("crane", 15) > 3.0 * DAY, "crane lv15 takes days (%s)" % D.fmt_time(D.tech_time("crane", 15)))

	# 4) سقوف الأبحاث ممكنة فعلًا (مستوى المختبر المطلوب ≤ 30)
	var lab_ok := true
	for id in D.TECHS:
		if D.tech_lab_req(id, int(D.TECHS[id]["max"])) > 30:
			lab_ok = false
	check(lab_ok, "every research max level is reachable with lab level 30")

	# 5) الأبحاث الحربية الجديدة: كل نوع جنود له هجوم ودفاع ومتانة
	check(D.TECHS.size() == 27, "27 researches now (%d)" % D.TECHS.size())
	var effs := {}
	for id in D.TECHS:
		effs[D.TECHS[id]["eff"]] = true
		if D.TECHS[id]["req"] != "":
			if not D.TECHS.has(D.TECHS[id]["req"]):
				check(false, "research %s requires an unknown research" % id)
	for tp in D.TROOP_ORDER:
		for kind in ["atk", "def", "hp"]:
			check(effs.has("%s_%s" % [kind, tp]), "a research affects %s of %s" % [kind, tp])
	var names_ok := true
	for id in D.TECHS:
		if not D.EFF_NAMES.has(D.TECHS[id]["eff"]):
			names_ok = false
	check(names_ok, "every research effect has a display name")

	# 6) سلسلة البحث والفتح
	_fresh()
	Game.plots["lb1"] = 3
	var c := Game.tech_check("bash")
	check(not c["ok"], "bash refused without plate")
	Game.techs["plate"] = 1
	c = Game.tech_check("bash")
	check(c["ok"], "bash allowed after plate with lab 3")
	check(absf(float(c["time"]) - D.tech_time("bash", 1)) < 0.01, "research time equals defs time")
	check(Game.start_research("bash") and not Game.research.is_empty(), "research starts")
	check(absf(float(Game.research["end"]) - float(Game.research["start"]) - D.tech_time("bash", 1)) < 0.01, "queued research duration matches")

	# 7) ربط الأبحاث بالجنود (army_mods)
	_fresh()
	var m0: Dictionary = Game.army_mods("")
	check(float(m0["atk"]["shield"]) == 0.0 and float(m0["hp"]["bow"]) == 0.0, "no research -> zero mods")
	Game.techs["bash"] = 3
	Game.techs["chain"] = 2
	Game.techs["endure"] = 4
	Game.techs["ironwall"] = 1
	Game.techs["banner"] = 2
	var m1: Dictionary = Game.army_mods("")
	check(absf(float(m1["atk"]["shield"]) - 0.12) < 0.0001, "bash lv3 -> shield attack +12%")
	check(absf(float(m1["def"]["spear"]) - 0.08) < 0.0001, "chain lv2 -> spear defense +8%")
	check(absf(float(m1["hp"]["bow"]) - 0.16) < 0.0001, "endure lv4 -> bow durability +16%")
	check(absf(float(m1["hp"]["shield"]) - 0.04) < 0.0001, "ironwall lv1 -> shield durability +4%")
	check(absf(float(m1["hp_all"]) - 0.08) < 0.0001, "banner lv2 -> all durability +8%")
	check(float(m1["atk"]["spear"]) == 0.0 and float(m1["def"]["bow"]) == 0.0, "unrelated stats untouched")

	# 8) البطل يُضاف فوق الأبحاث ولا يمحوها (كان يستبدل الصحة)
	Game.heroes["reem"]["owned"] = true
	Game.heroes["reem"]["lv"] = 1
	Game.heroes["reem"]["stars"] = 0
	Game.techs["ironwall"] = 2
	var hb := D.hero_bonus(1, 0)
	var m2: Dictionary = Game.army_mods("reem")
	check(absf(float(m2["hp"]["shield"]) - (0.08 + hb)) < 0.0001, "hero durability bonus stacks on research")
	check(absf(float(m2["atk"]["shield"]) - (0.12 + hb)) < 0.0001, "hero attack bonus stacks on research")

	# 9) العرض الفعلي لقيم الجندي
	_fresh()
	Game.techs["bash"] = 5
	Game.techs["ironwall"] = 5
	var st: Dictionary = Game.troop_stats("shield", 1)
	check(absf(float(st["atk"]) - 8.0 * 1.2) < 0.001, "troop_stats attack includes research (%.2f)" % float(st["atk"]))
	check(absf(float(st["hp"]) - 30.0 * 1.2) < 0.001, "troop_stats health includes research (%.2f)" % float(st["hp"]))
	var st2: Dictionary = Game.troop_stats("shield", 2)
	check(float(st2["atk"]) > float(st["atk"]) and float(st2["hp"]) > float(st["hp"]), "higher tier is stronger")

	# 10) أثر المتانة في المعركة: نفس الجيش بمتانة أعلى يخسر أقل
	var units := {"shield_1": 40}
	var foe := {"spear_1": 40}
	var base_mods := {"atk": {"shield": 0.0, "spear": 0.0, "bow": 0.0}, "def": {"shield": 0.0, "spear": 0.0, "bow": 0.0},
		"hp": {"shield": 0.0, "spear": 0.0, "bow": 0.0}, "hp_all": 0.0, "all": 0.0, "skill": "", "taken": 1.0}
	var tough_mods: Dictionary = base_mods.duplicate(true)
	tough_mods["hp"]["shield"] = 0.5
	var Cmb := preload("res://scripts/combat.gd")
	var r_base: Dictionary = Cmb.fight(units, base_mods, foe, base_mods, false, 4242)
	var r_tough: Dictionary = Cmb.fight(units, tough_mods, foe, base_mods, false, 4242)
	var left_base := 0.0
	var left_tough := 0.0
	for k in r_base.get("att_left", {}):
		left_base += float(r_base["att_left"][k])
	for k in r_tough.get("att_left", {}):
		left_tough += float(r_tough["att_left"][k])
	check(left_tough >= left_base, "tougher army keeps at least as many soldiers (%.1f vs %.1f)" % [left_tough, left_base])

	# 11) زمن التدريب: الرتبة ×3 للجندي الواحد، والتكلفة ×1.7
	var tr1 := D.troop_time("shield", 1, 10)
	var tr2 := D.troop_time("shield", 2, 10)
	check(absf(tr2 / tr1 - 3.0) < 0.001, "each tier takes 3x longer per soldier")
	check(absf(D.troop_time("bow", 1, 20) / D.troop_time("bow", 1, 10) - 2.0) < 0.001, "double batch doubles time")
	var elite := D.troop_time("bow", 4, 320) / (D.barracks_speed(30))
	check(elite > H, "320 elite archers at barracks lv30 still take over an hour (%s)" % D.fmt_time(elite))
	check(D.troop_cost("shield", 2, 10)["food"] > D.troop_cost("shield", 1, 10)["food"] * 1.5, "tier cost still rises clearly (x2.2 since stage 17)")
	check(D.troop_time("shield", 1, 20) <= 120.0, "first-tier starter batch is quick (%s)" % D.fmt_time(D.troop_time("shield", 1, 20)))

	# 12) تكلفة التسريع بالجواهر
	check(D.speedup_gems(600.0) == 10 and D.speedup_gems(3600.0) == 60, "first hour costs 1 gem per minute")
	check(D.speedup_gems(DAY) > 60 and D.speedup_gems(DAY) < int(DAY / 60.0), "one day is cheaper than linear")
	check(D.speedup_gems(30.0 * DAY) < int(30.0 * DAY / 60.0) / 3, "a month is far cheaper than linear")
	var gmono := true
	var prev := 0
	for s in [10.0, 600.0, 3600.0, 7200.0, DAY, 3.0 * DAY, 30.0 * DAY, 90.0 * DAY]:
		var g := D.speedup_gems(s)
		if g < prev:
			gmono = false
		prev = g
	check(gmono, "speedup cost never decreases with time")
	check(Game.gems_for_time(100.0) == 0, "free speedup threshold still applies")
	check(Game.gems_for_time(600.0) == 10, "game gem cost matches defs for short times")

	# 13) تنسيق الزمن
	check(D.fmt_time(90.0) == "01:30", "fmt 90s")
	check(D.fmt_time(2.0 * DAY + 3.0 * H).find("ي") >= 0, "fmt days has day mark")
	check(D.fmt_time(75.0 * DAY).find("شهر") >= 0, "fmt months has month word (%s)" % D.fmt_time(75.0 * DAY))

	# 14) حفظ قديم بلا الأبحاث الجديدة يُحمَّل بقيم صفر
	_fresh()
	Game.techs["saw"] = 4
	Game.save_game()
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game._save_path()))
	for id in ["bash", "ironwall", "chain", "vigor", "hide", "endure"]:
		d["techs"].erase(id)
	var f := FileAccess.open(Game._save_path(), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	check(Game.load_game(), "old save without new researches loads")
	check(int(Game.techs["saw"]) == 4 and int(Game.techs["bash"]) == 0 and int(Game.techs["endure"]) == 0, "old research kept, new ones start at 0")

	print("---- stage14: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("ALL PASSED")
	get_tree().quit(1 if failures > 0 else 0)
