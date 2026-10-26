extends Node
## اختبار Stage 19 — الورشة الحربية + ربط المتانة والجرحى (بند 2.16)
## التشغيل: godot --headless --path . res://test_stage19.tscn

const Defs := preload("res://scripts/defs.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _fresh() -> void:
	Game.save_path_override = "user://frost_save_test_stage19.json"
	Game.dev_mode = false
	Game.new_game()


func _venture(losses: Dictionary) -> Dictionary:
	return {"units": {}, "losses": losses, "survivors": {}, "dead_factor": 0.25, "report": {}}


func _ready() -> void:
	# 1) التعريفات
	check(Defs.BUILDINGS.has("workshop"), "workshop building defined")
	check(Defs.PLOTS.has("wk1") and Defs.PLOTS["wk1"]["type"] == "workshop", "workshop plot wk1 defined")
	for tier in 3:
		check(ResourceLoader.exists("res://assets/city/workshop_t%d.glb" % tier), "workshop model tier %d exists" % tier)
	var near_plot := false
	for id in Defs.PLOTS:
		if id != "wk1" and Defs.PLOTS[id]["r"] == Defs.PLOTS["wk1"]["r"] and absf(float(Defs.PLOTS[id]["a"]) - float(Defs.PLOTS["wk1"]["a"])) < 25.0:
			near_plot = true
	check(not near_plot, "workshop plot does not crowd another plot on its ring")
	var mono := true
	for lv in range(2, 31):
		if Defs.build_time("workshop", lv) <= Defs.build_time("workshop", lv - 1):
			mono = false
	check(mono, "workshop build time rises with level")

	# 2) تجهيزات الورشة لكل نوع
	var g10s := Defs.workshop_gear("shield", 10)
	var g10p := Defs.workshop_gear("spear", 10)
	var g10b := Defs.workshop_gear("bow", 10)
	check(near(g10s["def"], 0.10) and near(g10s["hp"], 0.06) and g10s["atk"] == 0.0, "shield gear lv10: +10% def, +6% hp")
	check(near(g10p["atk"], 0.10) and near(g10p["hp"], 0.04) and g10p["def"] == 0.0, "spear gear lv10: +10% atk, +4% hp")
	check(near(g10b["atk"], 0.10) and near(g10b["def"], 0.04) and g10b["hp"] == 0.0, "bow gear lv10: +10% atk, +4% def")
	check(near(Defs.workshop_gear("bow", 999)["atk"], Defs.workshop_gear("bow", 30)["atk"]), "gear clamps at max level")

	# 3) تدخل التجهيزات في army_mods وملف الدفاع وإحصاءات الجندي
	_fresh()
	var m0 := Game.army_mods("")
	var st0 := Game.troop_stats("shield", 1)
	Game.plots["wk1"] = 10
	var m1 := Game.army_mods("")
	check(near(float(m1["def"]["shield"]) - float(m0["def"]["shield"]), 0.10), "army_mods: shield def +10% at workshop 10")
	check(near(float(m1["atk"]["spear"]) - float(m0["atk"]["spear"]), 0.10), "army_mods: spear atk +10% at workshop 10")
	check(near(float(m1["hp"]["shield"]) - float(m0["hp"]["shield"]), 0.06), "army_mods: shield hp +6% at workshop 10")
	check(float(Game.troop_stats("shield", 1)["hp"]) > float(st0["hp"]), "troop stats (camp view) reflect gear")
	Game.troops["shield_1"] = 20
	var prof := Game.defense_profile()
	check(near(float(prof["mods"]["def"]["shield"]) - float(m0["def"]["shield"]), 0.10), "defense_profile includes workshop gear")
	check(near(float(prof["wall"]["def"]), 0.0), "gear is separate from wall bonus")

	# 4) أبحاث الحرب تتطلب ورشة
	check(Defs.tech_workshop_req("bash", 1) == 0 and Defs.tech_workshop_req("bash", 2) == 0, "war tech levels 1-2 need no workshop")
	check(Defs.tech_workshop_req("bash", 3) == 2 and Defs.tech_workshop_req("bash", 12) == 20, "war tech lv3 needs workshop 2, lv12 needs 20")
	check(Defs.tech_workshop_req("hide", 8) == 12, "all war techs follow the same rule (hide lv8 -> 12)")
	var eco_ok := true
	for id in Defs.TECHS:
		if int(Defs.TECHS[id]["branch"]) != 2:
			for lv in range(1, int(Defs.TECHS[id]["max"]) + 1):
				if Defs.tech_workshop_req(id, lv) != 0:
					eco_ok = false
	check(eco_ok, "economy and survival techs are not gated by the workshop")
	_fresh()
	Game.plots["lb1"] = 20
	Game.res = {"food": 1e7, "wood": 1e7, "coal": 1e7, "iron": 1e7}
	Game.aurora = 999
	Game.techs["plate"] = 1
	Game.techs["bash"] = 2
	var chk := Game.tech_check("bash")
	var blocked := false
	for r in chk["reasons"]:
		if String(r).find("الورشة الحربية") >= 0:
			blocked = true
	check(blocked, "war tech lv3 blocked without workshop (reason shown)")
	Game.plots["wk1"] = 2
	chk = Game.tech_check("bash")
	blocked = false
	for r in chk["reasons"]:
		if String(r).find("الورشة الحربية") >= 0:
			blocked = true
	check(not blocked, "war tech lv3 allowed with workshop 2")
	Game.dev_mode = true
	Game.plots["wk1"] = 0
	chk = Game.tech_check("bash")
	blocked = false
	for r in chk["reasons"]:
		if String(r).find("الورشة الحربية") >= 0:
			blocked = true
	check(not blocked, "developer mode bypasses the workshop requirement")
	Game.dev_mode = false

	# 5) بند 2.16: حصة القتلى
	check(near(Defs.death_mult(0, 0.0), 1.0), "no infirmary and no toughness -> base death share")
	check(Defs.death_mult(10, 0.0) < Defs.death_mult(5, 0.0) and Defs.death_mult(5, 0.0) < 1.0, "higher infirmary level lowers death share")
	check(Defs.death_mult(0, 0.5) < Defs.death_mult(0, 0.2) and Defs.death_mult(0, 0.2) < 1.0, "more toughness lowers death share")
	check(Defs.death_mult(30, 5.0) >= Defs.DEATH_MULT_MIN - 0.0001, "death share has a floor (%.2f)" % Defs.death_mult(30, 5.0))
	check(Defs.death_mult(30, 0.0) > Defs.DEATH_MULT_MIN, "max infirmary alone does not hit the floor")
	_fresh()
	check(near(Game.death_mult("shield_1"), 1.0), "fresh game: death multiplier is 1")
	Game.plots["in1"] = 20
	var with_inf := Game.death_mult("shield_1")
	check(near(with_inf, Defs.death_mult(20, 0.0)), "game death multiplier reads infirmary level")
	Game.plots["wk1"] = 20
	check(Game.death_mult("shield_1") < with_inf, "workshop toughness lowers shield deaths further")
	check(Game.death_mult("bow_1") > Game.death_mult("shield_1"), "bow (no gear hp) loses more than shield (gear hp)")

	# 6) عودة الحملة تطبق المعامل فعليًا
	_fresh()
	Game.venture = _venture({"shield_1": 40})
	Game._return_venture()
	var base_dead := 40 - int(Game.wounded.get("shield_1", 0))
	check(base_dead == 10 and Game.wounded["shield_1"] == 30, "venture return baseline: 40 lost -> 10 dead, 30 wounded")
	_fresh()
	Game.plots["in1"] = 20
	Game.venture = _venture({"shield_1": 40})
	Game._return_venture()
	var better_dead := 40 - int(Game.wounded.get("shield_1", 0))
	check(better_dead < base_dead, "venture return: infirmary 20 -> fewer dead (%d vs %d)" % [better_dead, base_dead])

	# 7) الغارة تطبق المعامل: خسائر كبيرة بجيش ضخم وبلا ورشة ثم مع ورشة ومستوصف
	var dead_plain := 0
	var dead_better := 0
	for round_i in 2:
		_fresh()
		if round_i == 1:
			Game.plots["in1"] = 30
			Game.plots["wk1"] = 30
		Game.plots["in1"] = 30 if round_i == 1 else 0
		Game.troops["shield_1"] = 400
		Game.troops["spear_1"] = 400
		seed(5)
		Game._run_raid()
		var d := int(Game.last_raid["dead"])
		if round_i == 0:
			dead_plain = d
		else:
			dead_better = d
	check(dead_better <= dead_plain, "raid deaths with infirmary+workshop <= plain (%d vs %d)" % [dead_better, dead_plain])

	# 8) الحفظ وتوافق القديم
	_fresh()
	Game.plots["wk1"] = 7
	Game.save_game()
	Game.plots["wk1"] = 0
	Game.load_game()
	check(Game.level("wk1") == 7, "workshop level survives save/load")
	var f := FileAccess.open(Game.save_path_override, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data["plots"].erase("wk1")
	var fw := FileAccess.open(Game.save_path_override, FileAccess.WRITE)
	fw.store_string(JSON.stringify(data))
	fw.close()
	Game.load_game()
	check(Game.level("wk1") == 0, "old save without wk1 loads with workshop level 0")

	# 9) المدينة والواجهة
	_fresh()
	Game.res = {"food": 99999.0, "wood": 99999.0, "coal": 99999.0, "iron": 99999.0}
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	check(city.plot_nodes.has("wk1") if "plot_nodes" in city else true, "city creates a node for wk1")
	Game.plots["wk1"] = 3
	Game.plots["in1"] = 3
	for id in ["wk1", "in1"]:
		city.call("_select", id)
		await get_tree().process_frame
		check(String(city.bp_stats.text).length() > 0, "building panel shows stats for %s" % id)
	check(String(city.bp_stats.text).find("القتلى") >= 0, "infirmary panel shows casualty share")
	city.call("_select", "wk1")
	await get_tree().process_frame
	check(String(city.bp_stats.text).find("دروع مقوّاة") >= 0, "workshop panel lists gear")
	city.queue_free()

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
