extends Node
## اختبار Stage 27 — أبحاث الدفاع المرتبطة بالسور (ل3)
## التشغيل: godot --headless --path . res://test_stage27.tscn

const Defs := preload("res://scripts/defs.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fresh() -> void:
	Game.save_path_override = "user://frost_save_test_stage27.json"
	Game.dev_mode = false
	Game.new_game()
	Game.set_process(false)
	Game.daily_ready = false
	Game.last_daily = Game._today()
	Game.stats["built"] = 1
	Game.offline_report = {}
	Game.res = {"food": 1e9, "wood": 1e9, "coal": 1e9, "iron": 1e9}
	Game.aurora = 100000


func _why(id: String, frag: String) -> bool:
	for r in Game.tech_check(id)["reasons"]:
		if str(r).contains(frag):
			return true
	return false


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	_fresh()

	# ---- التعريف
	check(Defs.BRANCHES.size() == 4 and Defs.BRANCHES[3] == "الدفاع", "fourth branch: defense")
	var ids: Array[String] = []
	for id in Defs.TECHS:
		if int(Defs.TECHS[id]["branch"]) == 3:
			ids.append(id)
	check(ids.size() == 5, "five defense researches")
	var effs := {}
	for id in ids:
		effs[Defs.TECHS[id]["eff"]] = true
		check(Defs.EFF_NAMES.has(Defs.TECHS[id]["eff"]), "effect name exists: " + id)
		var rq: String = Defs.TECHS[id]["req"]
		check(rq == "" or Defs.TECHS.has(rq), "valid prerequisite: " + id)
	check(effs.has("wall_def") and effs.has("tower_atk") and effs.has("wall_hp"), "covers wall defense, tower attack and durability")
	check(Game.techs.has("gatehouse") and int(Game.techs["gatehouse"]) == 0, "new game has the new researches at 0")

	# ---- الاشتراط بمرحلة السور
	check(Defs.tech_wall_req("bulwark", 1) == 1 and Defs.tech_wall_req("bulwark", 3) == 1, "levels 1-3 need wall stage 1")
	check(Defs.tech_wall_req("bulwark", 4) == 2 and Defs.tech_wall_req("bulwark", 7) == 3 and Defs.tech_wall_req("bulwark", 12) == 4, "levels 4/7/12 need stages 2/3/4")
	check(Defs.tech_wall_req("saw", 5) == 0, "other branches are not tied to the wall")
	Game.plots["furnace"] = 30
	Game.plots["lb1"] = 0
	check(_why("bulwark", "السور"), "research blocked without a wall")
	Game.plots["wl1"] = 1
	check(not _why("bulwark", "السور"), "level 1 allowed with wall stage 1")
	Game.techs["bulwark"] = 3
	check(_why("bulwark", "السور"), "level 4 needs stage 2")
	Game.plots["wl1"] = 8
	check(not _why("bulwark", "السور"), "level 4 allowed with wall stage 2")
	Game.dev_mode = true
	Game.plots["wl1"] = 0
	check(not _why("bulwark", "السور"), "developer mode bypasses the wall requirement")
	Game.dev_mode = false
	Game.techs["bulwark"] = 0

	# ---- سلسلة البحث والمختبر
	Game.plots["wl1"] = 30
	check(_why("mortar", "ملاط") == false and _why("mortar", "تحصين الأساسات"), "mortar needs bulwark first")

	# ---- الأثر على ملف الدفاع (دفاع فقط)
	Game.plots["lb1"] = 30
	Game.plots["wl1"] = 8
	Game.troops["shield_1"] = 40
	var base := Game.defense_profile()
	Game.techs["bulwark"] = 5
	Game.techs["ballista"] = 4
	Game.techs["mortar"] = 3
	var boosted := Game.defense_profile()
	check(absf(float(boosted["mods"]["def"]["shield"]) - float(base["mods"]["def"]["shield"]) - 0.05) < 0.0001, "bulwark 5 = +5% defense")
	check(absf(float(boosted["mods"]["atk"]["bow"]) - float(base["mods"]["atk"]["bow"]) - 0.04) < 0.0001, "ballista 4 = +4% tower attack")
	check(absf(float(boosted["mods"]["hp"]["spear"]) - float(base["mods"]["hp"]["spear"]) - 0.06) < 0.0001, "mortar 3 = +6% durability")
	check(int(boosted["power"]) > int(base["power"]), "defense power rises (%d -> %d)" % [base["power"], boosted["power"]])
	check(absf(float(boosted["wall"]["def"]) - float(base["wall"]["def"]) - 0.05) < 0.0001, "profile wall block includes research")
	# لا أثر في الهجوم (الجيش المُرسل)
	var am: Dictionary = Game.army_mods("")
	check(absf(float(am["def"]["shield"]) - float(base["mods"]["def"]["shield"]) + float(Defs.wall_bonuses(8)["def"])) < 0.0001, "research does not leak into attack mods")
	Game.techs["bulwark"] = 0
	Game.techs["ballista"] = 0
	Game.techs["mortar"] = 0

	# ---- بدء بحث وإكماله
	Game.plots["wl1"] = 1
	var ok := Game.start_research("bulwark")
	check(ok and Game.research.get("id", "") == "bulwark", "defense research starts")
	Game.research["end"] = Game.now() - 1.0
	Game._simulate_stage2(0.1, Game.now())
	check(int(Game.techs["bulwark"]) == 1 and Game.research.is_empty(), "defense research completes")

	# ---- الحفظ والتحميل
	Game.research = {}
	Game.techs["firearrow"] = 2
	Game.save_game()
	Game.techs["firearrow"] = 0
	Game.load_game()
	check(int(Game.techs["firearrow"]) == 2, "defense research level survives save/load")
	# حفظ قديم بلا الأبحاث الجديدة
	Game.techs.erase("gatehouse")
	Game.save_game()
	var f := FileAccess.open(Game.save_path_override, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data["techs"].erase("gatehouse")
	data["techs"].erase("bulwark")
	f = FileAccess.open(Game.save_path_override, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	Game.load_game()
	check(int(Game.techs.get("gatehouse", -1)) == 0, "old save loads new researches at 0")

	# ---- النافذة: أربعة تبويبات والدفاع يعرض أبحاثه
	_fresh()
	Game.plots["furnace"] = 10
	Game.plots["lb1"] = 5
	var city: Node3D = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await _frames(6)
	city.tech_branch = 3
	city._show_research()
	await _frames(3)
	var names := 0
	for n in city.get_tree().root.find_children("*", "Label", true, false):
		if (n as Label).text.begins_with("تحصين الأساسات"):
			names += 1
	check(names >= 1, "defense tab lists its researches")
	city.queue_free()
	await _frames(2)

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
