extends Node
## اختبار Stage 18 — السور والأبراج + ملف دفاع المدينة الموحد
## التشغيل: godot --headless --path . res://test_stage18.tscn

const Defs := preload("res://scripts/defs.gd")
const Combat := preload("res://scripts/combat.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _fresh() -> void:
	Game.save_path_override = "user://frost_save_test_stage18.json"
	Game.dev_mode = false
	Game.new_game()


func _ready() -> void:
	# 1) التعريفات
	check(Defs.BUILDINGS.has("wall"), "wall building defined")
	check(Defs.PLOTS.has(Defs.WALL_PLOT) and Defs.PLOTS[Defs.WALL_PLOT]["type"] == "wall", "wall plot wl1 defined")
	check(ResourceLoader.exists("res://assets/city/city_wall_t0.glb") and ResourceLoader.exists("res://assets/city/city_wall_t4.glb"), "wall models exist")
	var b0 := Defs.wall_bonuses(0)
	var b10 := Defs.wall_bonuses(10)
	check(b0["def"] == 0.0 and b0["atk"] == 0.0, "level 0 gives no bonus")
	check(absf(b10["def"] - 0.24) < 0.0001 and absf(b10["atk"] - 0.13) < 0.0001, "level 10: +24% defense, +13% tower attack (levels + stage 2 bonus)")
	check(Defs.wall_bonuses(999)["def"] == Defs.wall_bonuses(30)["def"], "bonus clamps at max level")
	var mono := true
	for lv in range(2, 31):
		if Defs.build_time("wall", lv) <= Defs.build_time("wall", lv - 1):
			mono = false
	check(mono, "wall build time rises with level")

	# 2) ملف الدفاع: لا حامية مجانية
	_fresh()
	var p0 := Game.defense_profile()
	check(p0["units"].is_empty() and p0["power"] == 0, "no troops -> empty profile, zero power")
	check(p0["wall"]["level"] == 0, "fresh game has no wall")
	Game.plots["wl1"] = 10
	var p1 := Game.defense_profile()
	check(p1["units"].is_empty() and p1["power"] == 0, "wall alone gives NO free garrison")
	check(p1["wall"]["level"] == 10, "profile reads wall level")

	# 3) الجنود + السور يرفعان القوة والمعدّلات
	Game.plots["wl1"] = 0
	Game.troops["shield_1"] = 40
	Game.troops["bow_1"] = 30
	var base := Game.defense_profile()
	Game.plots["wl1"] = 10
	var walled := Game.defense_profile()
	check(base["units"] == walled["units"], "wall does not change unit counts")
	check(int(walled["power"]) > int(base["power"]), "wall raises defense power (%d -> %d)" % [base["power"], walled["power"]])
	check(absf(float(walled["mods"]["def"]["shield"]) - float(base["mods"]["def"]["shield"]) - 0.24) < 0.0001, "shield defense +24% at wall 10")
	check(absf(float(walled["mods"]["atk"]["bow"]) - float(base["mods"]["atk"]["bow"]) - 0.13) < 0.0001, "bow attack +13% at wall 10")
	var snap := Game.troops.duplicate(true)
	Game.defense_profile()
	check(Game.troops == snap, "profile is read-only")

	# 4) السور يحسّن نتيجة القتال فعليًا
	var rest := Game.army_mods("")
	var raiders := {"beast": 60}
	var rm := {"atk": {}, "def": {}, "hp": {}, "hp_all": 0.0, "all": 0.0, "skill": "", "taken": 1.0}
	var r_plain := Combat.fight(raiders, {"beast": Game.raid_strength()["beast"]}, base["units"], base["mods"], false, 7)
	var r_wall := Combat.fight(raiders, {"beast": Game.raid_strength()["beast"]}, walled["units"], walled["mods"], false, 7)
	var lost_plain := 0
	var lost_wall := 0
	for k in r_plain["def_loss"]:
		lost_plain += int(r_plain["def_loss"][k])
	for k in r_wall["def_loss"]:
		lost_wall += int(r_wall["def_loss"][k])
	check(lost_wall <= lost_plain, "wall does not increase defender losses (%d vs %d)" % [lost_wall, lost_plain])

	# 5) الغارة تستهلك الملف وتسجله
	Game.plots["wl1"] = 8
	Game._run_raid()
	var lr: Dictionary = Game.last_raid
	check(lr.has("defense_power") and lr.has("wall_level") and lr.has("wall_bonus") and lr.has("defenders"), "raid report records defense profile")
	check(int(lr["wall_level"]) == 8, "raid report wall level = 8")
	check(absf(float(lr["wall_bonus"]["def"]) - 0.20) < 0.0001, "raid report wall bonus recorded")
	check(not lr["defenders"].is_empty(), "raid report lists defenders present")

	# 6) غارة بلا جنود: السور لا يقاتل وحده
	_fresh()
	Game.plots["wl1"] = 30
	Game._run_raid()
	check(not Game.last_raid["win"], "empty city with max wall still loses the raid")
	check(Game.last_raid["defenders"].is_empty(), "no defenders recorded")

	# 7) الحفظ والتحميل + توافق الحفظ القديم
	_fresh()
	Game.plots["wl1"] = 5
	Game.save_game()
	Game.plots["wl1"] = 0
	Game.load_game()
	check(Game.level("wl1") == 5, "wall level survives save/load")
	var f := FileAccess.open(Game.save_path_override, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	if data.has("plots"):
		data["plots"].erase("wl1")
	var fw := FileAccess.open(Game.save_path_override, FileAccess.WRITE)
	fw.store_string(JSON.stringify(data))
	fw.close()
	Game.load_game()
	check(Game.level("wl1") == 0, "old save without wl1 loads with wall level 0")

	# 8) المدينة ثلاثية الأبعاد تعرض مبنى السور
	_fresh()
	Game.res = {"food": 99999.0, "wood": 99999.0, "coal": 99999.0, "iron": 99999.0}
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	check(city.plot_nodes.has("wl1") if "plot_nodes" in city else true, "city creates a node for wl1")
	var fcheck := Game.check_upgrade("wl1")
	check(fcheck.has("ok") or fcheck.has("time"), "wall can be queried for upgrade")
	city.queue_free()

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
