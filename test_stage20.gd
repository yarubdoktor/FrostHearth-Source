extends Node
## اختبار Stage 20 — برج الاستطلاع: كشف الخريطة + إنذار الغارات + تقدير حجمها
## التشغيل: godot --headless --path . res://test_stage20.tscn

const Defs := preload("res://scripts/defs.gd")

var checks := 0
var failures := 0
var toasts: Array[String] = []


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _fresh() -> void:
	Game.save_path_override = "user://frost_save_test_stage20.json"
	Game.dev_mode = false
	Game.new_game()


func _explored_count() -> int:
	var n := 0
	for b in Game.explored:
		if b > 0:
			n += 1
	return n


func _on_toast(msg: String) -> void:
	toasts.append(msg)


func _ready() -> void:
	# 1) التعريفات
	check(Defs.BUILDINGS.has("scout_tower"), "scout tower building defined")
	check(Defs.PLOTS.has("sk1") and Defs.PLOTS["sk1"]["type"] == "scout_tower", "scout tower plot sk1 defined")
	for tier in 3:
		check(ResourceLoader.exists("res://assets/city/scout_tower_t%d.glb" % tier), "scout tower model tier %d exists" % tier)
	var crowded := false
	for id in Defs.PLOTS:
		if id != "sk1" and Defs.PLOTS[id]["r"] == Defs.PLOTS["sk1"]["r"] and absf(float(Defs.PLOTS[id]["a"]) - float(Defs.PLOTS["sk1"]["a"])) < 25.0:
			crowded = true
	check(not crowded, "scout plot does not crowd another plot on its ring")
	var mono := true
	for lv in range(2, 31):
		if Defs.build_time("scout_tower", lv) <= Defs.build_time("scout_tower", lv - 1):
			mono = false
	check(mono, "scout tower build time rises with level")
	check(Defs.scout_vision(0) == Defs.FOG_REVEAL_HOME, "vision at level 0 equals the base home radius")
	check(Defs.scout_vision(10) == Defs.FOG_REVEAL_HOME + 80.0, "vision at level 10 = base + 80")
	check(Defs.scout_vision(999) == Defs.scout_vision(30), "vision clamps at max level")
	check(Defs.raid_warning_lead(0) == 90.0, "no tower keeps the original 90 s warning")
	check(Defs.raid_warning_lead(10) == 290.0 and Defs.raid_warning_lead(30) == 690.0, "warning lead grows 20 s per level")
	check(Defs.forecast_error(1) > Defs.forecast_error(6) and Defs.forecast_error(6) > 0.0, "forecast error shrinks with level")
	check(Defs.forecast_error(13) == 0.0 and Defs.forecast_error(30) == 0.0, "forecast is exact from level 13")

	# 2) كشف الخريطة
	_fresh()
	var base_cells := _explored_count()
	Game.recompute()
	check(_explored_count() == base_cells, "no tower: recompute reveals nothing new")
	Game.plots["sk1"] = 10
	Game.recompute()
	var c10 := _explored_count()
	check(c10 > base_cells, "tower 10 reveals more map (%d -> %d cells)" % [base_cells, c10])
	var far := Vector2(Game.home) + Vector2(125, 0)
	check(Game.is_explored(int(far.x), int(far.y)), "a point 125 tiles from home is revealed at tower 10")
	Game.recompute()
	check(_explored_count() == c10, "revealing is idempotent at the same level")
	Game.plots["sk1"] = 20
	Game.recompute()
	check(_explored_count() > c10, "higher tower level reveals even more")
	Game.plots["sk1"] = 0
	Game.recompute()
	check(Game.is_explored(int(far.x), int(far.y)), "revealed area is never hidden again")

	# 3) الإنذار
	_fresh()
	Game.raid_next = Game.now() + 200.0
	check(Game.raid_soon() < 0.0, "no tower: no warning at 200 s before the raid")
	Game.raid_next = Game.now() + 60.0
	check(Game.raid_soon() > 0.0, "no tower: warning inside 90 s")
	Game.plots["sk1"] = 10
	Game.raid_next = Game.now() + 200.0
	check(Game.raid_soon() > 0.0, "tower 10: warning already at 200 s")
	Game.raid_next = Game.now() + 400.0
	check(Game.raid_soon() < 0.0, "tower 10: no warning at 400 s (lead = 290 s)")

	# 4) التقدير
	_fresh()
	check(not Game.raid_forecast()["active"], "no tower: no forecast")
	Game.plots["sk1"] = 1
	check(not Game.raid_forecast()["active"], "tower without a scheduled raid: no forecast")
	Game.raid_next = Game.now() + 500.0
	var f1 := Game.raid_forecast()
	var real_n := int(Game.raid_strength()["n"])
	check(f1["active"] and f1["lo"] <= real_n and f1["hi"] >= real_n and f1["lo"] < f1["hi"], "tower 1: a range that contains the real count (%d–%d, real %d)" % [f1["lo"], f1["hi"], real_n])
	check(not f1["exact"] and not f1["storm_known"], "tower 1: inexact, weather unknown")
	Game.plots["sk1"] = 13
	var f12 := Game.raid_forecast()
	check(f12["exact"] and f12["lo"] == real_n and f12["hi"] == real_n, "tower 13: exact count")
	check(f12["storm_known"], "tower 13: weather is reported")
	var snapshot := Game.raid_next
	Game.raid_forecast()
	check(Game.raid_next == snapshot, "forecast is read-only")
	var prev_range := 0
	for lv in [1, 4, 8, 12]:
		Game.plots["sk1"] = lv
		var rr: Dictionary = Game.raid_forecast()
		var w := int(rr["hi"]) - int(rr["lo"])
		check(prev_range == 0 or w <= prev_range, "forecast range narrows or stays at level %d (width %d)" % [lv, w])
		prev_range = w

	# 5) الإشعار مرة واحدة لكل غارة
	_fresh()
	toasts.clear()
	Game.toast.connect(_on_toast)
	Game.plots["sk1"] = 5
	Game.raid_next = Game.now() + 150.0
	Game._simulate_stage2(1.0, Game.now())
	Game._simulate_stage2(1.0, Game.now())
	var warns := 0
	for t in toasts:
		if t.find("برج الاستطلاع") >= 0:
			warns += 1
	check(warns == 1, "warning toast fires exactly once per raid (%d)" % warns)
	Game.raid_next = Game.now() + 1000.0
	Game._simulate_stage2(1.0, Game.now())
	Game.raid_next = Game.now() + 150.0
	Game._simulate_stage2(1.0, Game.now())
	warns = 0
	for t in toasts:
		if t.find("برج الاستطلاع") >= 0:
			warns += 1
	check(warns == 2, "warning re-arms for the next raid (%d)" % warns)
	Game.toast.disconnect(_on_toast)
	_fresh()
	toasts.clear()
	Game.toast.connect(_on_toast)
	Game.raid_next = Game.now() + 60.0
	Game._simulate_stage2(1.0, Game.now())
	var any_scout := false
	for t in toasts:
		if t.find("برج الاستطلاع") >= 0:
			any_scout = true
	check(not any_scout, "no tower: no tower warning toast")
	Game.toast.disconnect(_on_toast)

	# 6) الحفظ والتحميل وتوافق القديم
	_fresh()
	Game.plots["sk1"] = 15
	Game.recompute()
	var cells := _explored_count()
	Game.save_game()
	Game.plots["sk1"] = 0
	Game.load_game()
	check(Game.level("sk1") == 15, "tower level survives save/load")
	check(_explored_count() >= cells, "explored area survives save/load")
	var f := FileAccess.open(Game.save_path_override, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	data["plots"].erase("sk1")
	var fw := FileAccess.open(Game.save_path_override, FileAccess.WRITE)
	fw.store_string(JSON.stringify(data))
	fw.close()
	Game.load_game()
	check(Game.level("sk1") == 0, "old save without sk1 loads with tower level 0")

	# 7) المدينة والواجهة
	_fresh()
	Game.res = {"food": 99999.0, "wood": 99999.0, "coal": 99999.0, "iron": 99999.0}
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	check(city.plot_nodes.has("sk1") if "plot_nodes" in city else true, "city creates a node for sk1")
	Game.plots["sk1"] = 3
	Game.raid_next = Game.now() + 500.0
	city.call("_select", "sk1")
	await get_tree().process_frame
	var txt := String(city.bp_stats.text)
	check(txt.find("نصف قطر الكشف") >= 0 and txt.find("مدة إنذار") >= 0 and txt.find("دقة تقدير") >= 0, "tower panel shows vision, warning and accuracy")
	check(txt.find("ذئب") >= 0, "tower panel shows the upcoming raid forecast")
	Game.changed.emit()
	await get_tree().process_frame
	check(String(city.raid_label.text).find("ذئب") >= 0, "HUD raid label shows the forecast when a tower exists")
	Game.plots["sk1"] = 0
	Game.changed.emit()
	await get_tree().process_frame
	check(String(city.raid_label.text).find("ذئب") < 0, "HUD raid label has no forecast without a tower")
	city.queue_free()

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
