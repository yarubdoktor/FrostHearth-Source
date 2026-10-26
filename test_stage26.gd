extends Node
## اختبار Stage 26 — السور الحقيقي (ل1): مراحل، نموذج حلقة، موقع البوابة، ربط الفرن، صعوبة متصاعدة
## التشغيل: godot --headless --path . res://test_stage26.tscn

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
	Game.save_path_override = "user://frost_save_test_stage26.json"
	Game.dev_mode = false
	Game.new_game()
	Game.set_process(false)
	Game.daily_ready = false
	Game.last_daily = Game._today()
	Game.stats["built"] = 1
	Game.offline_report = {}


func _reasons_have(id: String, frag: String) -> bool:
	for r in Game.check_upgrade(id)["reasons"]:
		if str(r).contains(frag):
			return true
	return false


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	_fresh()

	# ---- جدول المراحل
	var S: Array = Defs.WALL_STAGES
	check(S.size() == 5, "five wall stages")
	var mono := true
	for i in range(1, S.size()):
		if int(S[i]["from"]) <= int(S[i - 1]["from"]) or float(S[i]["cost"]) < float(S[i - 1]["cost"]) or float(S[i]["time"]) < float(S[i - 1]["time"]) \
				or float(S[i]["def"]) <= float(S[i - 1]["def"]) or float(S[i]["atk"]) <= float(S[i - 1]["atk"]) or int(S[i]["furnace"]) <= int(S[i - 1]["furnace"]):
			mono = false
	check(mono, "stages escalate: level, cost, time, bonus, furnace requirement")
	check(Defs.wall_stage(0) == 0 and Defs.wall_stage(1) == 1 and Defs.wall_stage(7) == 1 and Defs.wall_stage(8) == 2, "stage by level (0/1/7/8)")
	check(Defs.wall_stage(14) == 2 and Defs.wall_stage(15) == 3 and Defs.wall_stage(22) == 3 and Defs.wall_stage(23) == 4 and Defs.wall_stage(30) == 4, "stage by level (14/15/22/23/30)")
	check(Defs.wall_stage_entry(8) == 2 and Defs.wall_stage_entry(9) == -1 and Defs.wall_stage_entry(1) == 1, "stage entry detection")

	# ---- صعوبة متصاعدة: قفزة عند دخول مرحلة جديدة
	var c7: Dictionary = Defs.cost("wall", 7)
	var c8: Dictionary = Defs.cost("wall", 8)
	var plain_ratio := 1.58
	check(float(c8["wood"]) / float(c7["wood"]) > plain_ratio * 1.05, "cost jumps on entering stage 2 (%d -> %d)" % [c7["wood"], c8["wood"]])
	var t7 := Defs.build_time("wall", 7)
	var t8 := Defs.build_time("wall", 8)
	check(t8 / t7 > Defs.BUILD_TIME_GROWTH * 1.15, "time jumps on entering stage 2")
	check(Defs.build_time("wall", 30) > Defs.build_time("wall", 29), "time still rises inside a stage")
	var b7 := Defs.wall_bonuses(7)
	var b8 := Defs.wall_bonuses(8)
	check(b8["def"] - b7["def"] > Defs.WALL_DEF_PER_LEVEL + 0.01, "defense bonus jumps with the stage")
	check(Defs.wall_bonuses(0)["def"] == 0.0, "no wall no bonus")

	# ---- الموقع: البوابة الرئيسية
	var pp := Defs.plot_pos(Defs.WALL_PLOT)
	check(absf(pp.x - 60.0) < 0.01 and absf(pp.z - 106.0) < 0.01, "wl1 stands at the main gate (60, 106): %s" % str(pp))
	var near := 99.0
	for id in Defs.PLOTS:
		if id == Defs.WALL_PLOT:
			continue
		near = minf(near, Vector2(pp.x - Defs.plot_pos(id).x, pp.z - Defs.plot_pos(id).z).length())
	check(near > 7.0, "no plot crowds the gate (nearest %.1f)" % near)
	check(Defs.on_wall_ring(106.0, 60.0) and Defs.on_wall_ring(60.0, 106.0), "ring hit-test on the wall")
	check(not Defs.on_wall_ring(60.0, 60.0) and not Defs.on_wall_ring(101.0, 60.0), "ring hit-test misses furnace and inner plots")
	for t in 5:
		check(ResourceLoader.exists("res://assets/city/city_wall_t%d.glb" % t), "ring model t%d exists" % t)
	check(not ResourceLoader.exists("res://assets/city/wall_t0.glb"), "old bastion model removed")

	# ---- الربط بالفرن (الاتجاه الأول): دخول المرحلة يتطلب فرنًا أعلى
	Game.res = {"food": 1e9, "wood": 1e9, "coal": 1e9, "iron": 1e9}
	Game.plots["wl1"] = 7
	Game.plots["furnace"] = 8
	check(_reasons_have("wl1", "سور حجري"), "stage 2 entry blocked at furnace 8")
	Game.plots["furnace"] = 10
	check(not _reasons_have("wl1", "سور حجري"), "stage 2 entry allowed at furnace 10")
	Game.plots["wl1"] = 3
	Game.plots["furnace"] = 3
	check(not _reasons_have("wl1", "تتطلب الفرن"), "inside a stage only the normal furnace cap applies")

	# ---- الربط بالفرن (الاتجاه المعاكس)
	Game.plots["furnace"] = 11
	Game.plots["wl1"] = 0
	check(_reasons_have("furnace", "السور"), "furnace 12 needs the wall (stage 1)")
	Game.plots["wl1"] = 1
	check(not _reasons_have("furnace", "السور"), "furnace 12 allowed with wall level 1")
	Game.plots["furnace"] = 18
	Game.plots["wl1"] = 1
	check(_reasons_have("furnace", "السور"), "furnace 19 needs wall stage 2")
	Game.plots["wl1"] = 8
	check(not _reasons_have("furnace", "السور"), "furnace 19 allowed with wall stage 2")
	Game.plots["furnace"] = 10
	Game.plots["wl1"] = 0
	check(not _reasons_have("furnace", "السور"), "early furnace levels are not affected")
	# لا حلقة مغلقة: كل شرط فرن لمرحلة سور يسبق أول مستوى فرن يتطلب تلك المرحلة
	var loop_free := true
	for k in Defs.FURNACE_NEEDS_WALL:
		var need: int = Defs.FURNACE_NEEDS_WALL[k]
		if int(S[need]["furnace"]) >= int(k):
			loop_free = false
	check(loop_free, "no deadlock: wall stage entry needs a lower furnace than the furnace level that needs it")
	Game.dev_mode = true
	Game.plots["furnace"] = 11
	check(not _reasons_have("furnace", "السور"), "developer mode bypasses the link")
	Game.dev_mode = false

	# ---- المدينة: الحلقة تتبدل مع المرحلة والشارة تذكر المرحلة
	_fresh()
	Game.plots["furnace"] = 30
	var city: Node3D = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await _frames(6)
	check(city.wall_ring != null and city.wall_ring_key.ends_with("city_wall_t0.glb"), "fresh city shows the palisade ring (t0)")
	var expect := {1: 1, 7: 1, 8: 2, 15: 3, 23: 4, 30: 4}
	for lv in expect:
		Game.plots["wl1"] = lv
		Game.changed.emit()
		await _frames(2)
		check(city.wall_ring_key.ends_with("city_wall_t%d.glb" % int(expect[lv])), "wall level %d shows ring t%d" % [lv, int(expect[lv])])
	var badge: Label3D = city.plot_nodes["wl1"]["badge"]
	check(badge.text.contains(str(S[4]["name"])), "gate badge names the stage: " + badge.text)
	check(city.plot_nodes["wl1"]["model"] == null, "no separate building model on the gate plot")
	# إحصاءات اللوحة
	city._select("wl1")
	await _frames(2)
	check(city.sel == "wl1", "wall panel opens")
	city.queue_free()
	await _frames(2)

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
