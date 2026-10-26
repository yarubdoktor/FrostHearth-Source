extends Node
## اختبار Stage 21 — المستودع الحربي: حجم المسيرة العسكرية + مؤن الحملات
## التشغيل: godot --headless --path . res://test_stage21.tscn

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
	Game.save_path_override = "user://frost_save_test_stage21.json"
	Game.dev_mode = false
	Game.new_game()
	Game.set_process(false)


func _on_toast(msg: String) -> void:
	toasts.append(msg)


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	Game.toast.connect(_on_toast)
	# 1) التعريفات
	check(Defs.BUILDINGS.has("war_depot") and Defs.BUILDINGS["war_depot"]["name"] == "المستودع الحربي", "war depot building defined")
	check(Defs.PLOTS.has("wd1") and Defs.PLOTS["wd1"]["type"] == "war_depot", "war depot plot wd1 defined")
	check(int(Defs.PLOTS["wd1"]["unlock"]) == 7, "war depot unlocks at furnace 7")
	var a_wd := float(Defs.PLOTS["wd1"]["a"])
	var near_ok := true
	for id in Defs.PLOTS:
		if id == "wd1":
			continue
		var p: Dictionary = Defs.PLOTS[id]
		if absf(float(p["r"]) - float(Defs.PLOTS["wd1"]["r"])) < 1.0:
			var d := absf(fposmod(float(p["a"]) - a_wd + 180.0, 360.0) - 180.0)
			if d < 25.0:
				near_ok = false
	check(near_ok, "wd1 does not crowd neighbouring plots")
	check(absf(fposmod(a_wd - 90.0 + 180.0, 360.0) - 180.0) > 20.0, "wd1 is away from the main gate (south, 90 deg)")
	for t in range(3):
		check(FileAccess.file_exists("res://assets/city/war_depot_t%d.glb" % t), "war_depot_t%d.glb exists" % t)

	# 2) المعادلات
	check(Defs.march_capacity(0) == 60, "capacity without depot is 60")
	check(Defs.march_capacity(1) == 90 and Defs.march_capacity(10) == 360, "capacity grows 30 per level")
	check(Defs.march_capacity(30) == 960, "capacity at max level 960")
	check(Defs.march_capacity(99) == Defs.march_capacity(30), "capacity clamps at max level")
	check(Defs.supply_discount(0) == 0.0 and absf(Defs.supply_discount(10) - 0.15) < 0.0001, "supply discount 1.5% per level")
	check(Defs.supply_discount(30) <= 0.5 + 0.0001, "supply discount capped at 50%")
	check(Defs.supply_cost(0, 0) == 0, "zero troops need no supplies")
	check(Defs.supply_cost(50, 0) == 100, "50 troops cost 100 food without depot")
	check(Defs.supply_cost(50, 10) < Defs.supply_cost(50, 0), "depot lowers supply cost")
	check(Defs.supply_cost(1, 30) >= 1, "supply cost at least 1")

	# 3) فحص المسيرة داخل اللعبة
	_fresh()
	Game.res = {"food": 5000.0, "wood": 999.0, "coal": 999.0, "iron": 999.0}
	check(Game.march_capacity() == 60, "new game capacity is 60")
	var c1 := Game.venture_check({"shield_1": 40, "bow_1": 20})
	check(c1["ok"] and c1["total"] == 60 and c1["cost"] == 120, "60 troops pass at the base capacity, cost 120")
	var c2 := Game.venture_check({"shield_1": 61})
	check(not c2["ok"] and String(c2["reason"]).find("المستودع") >= 0, "61 troops rejected with a depot hint")
	check(not Game.venture_check({})["ok"], "empty march rejected")
	Game.res["food"] = 50.0
	check(not Game.venture_check({"shield_1": 30})["ok"], "insufficient food rejects the march")
	Game.res["food"] = 5000.0
	Game.plots["wd1"] = 5
	check(Game.march_capacity() == 210, "capacity follows depot level")

	# 4) start_venture: السعة والمؤن
	_fresh()
	Game.res = {"food": 5000.0, "wood": 999.0, "coal": 999.0, "iron": 999.0}
	if Game.vent.is_empty():
		Game.vent = {"x": 10, "y": 10, "captured": false}
	Game.troops["shield_1"] = 300
	Game.troops["bow_1"] = 300
	toasts.clear()
	check(not Game.start_venture({"shield_1": 100}), "venture over capacity refused")
	check(Game.troops["shield_1"] == 300 and Game.venture.is_empty() and Game.res["food"] == 5000.0, "refused venture changes nothing")
	check(toasts.size() > 0 and String(toasts[-1]).find("60") >= 0, "refusal explains the allowed size")
	Game.plots["wd1"] = 4   # سعة 180، خصم 6%
	var cost := Game.venture_supply_cost(100)
	check(cost == int(ceil(100.0 * 2.0 * 0.94)), "supply cost uses depot discount (188)")
	var ok := Game.start_venture({"shield_1": 100})
	check(ok, "venture within capacity accepted")
	check(absf(float(Game.res["food"]) - (5000.0 - cost)) < 0.01, "supplies are deducted at launch")
	check(int(Game.venture.get("supplies", -1)) == cost, "venture records its supplies")
	check(Game.troops["shield_1"] == 200, "troops are reserved")
	# الحفظ والتحميل
	Game.save_game()
	Game.venture = {}
	Game.load_game()
	check(int(Game.venture.get("supplies", -1)) == cost, "supplies survive save and load")

	# 5) نقص الطعام يمنع الإرسال
	_fresh()
	Game.res = {"food": 10.0, "wood": 0.0, "coal": 0.0, "iron": 0.0}
	Game.troops["shield_1"] = 50
	toasts.clear()
	check(not Game.start_venture({"shield_1": 30}), "venture without food refused")
	check(toasts.size() > 0 and String(toasts[-1]).find("المؤن") >= 0, "toast mentions supplies")

	# 6) وضع المطوّر يتجاوز القيود
	_fresh()
	Game.dev_mode = true
	Game.res = {"food": 0.0, "wood": 0.0, "coal": 0.0, "iron": 0.0}
	Game.troops["shield_1"] = 500
	check(Game.venture_check({"shield_1": 400})["ok"], "dev mode bypasses capacity and supplies")
	Game.dev_mode = false

	# 7) الحفظ
	_fresh()
	Game.set_process(false)
	Game.plots["wd1"] = 3
	Game.save_game()
	Game.plots["wd1"] = 0
	Game.load_game()
	check(Game.level("wd1") == 3, "depot level persists")

	# 8) واجهة الخريطة: ملخص الحجم والمؤن وتعطيل الإرسال
	_fresh()
	Game.res = {"food": 5000.0, "wood": 0.0, "coal": 0.0, "iron": 0.0}
	Game.troops["shield_1"] = 300
	var map: Node3D = load("res://world_map.tscn").instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame
	map._open_vent_window()
	await get_tree().process_frame
	check(map.vent_summary != null and map.vent_summary.text.find("60") >= 0, "venture window shows the capacity")
	map.vent_spins["shield_1"].value = 40
	check(map.vent_summary.text.find("40 / 60") >= 0 and map.vent_summary.text.find("80") >= 0, "summary shows size and supplies (40 / 60, 80 food)")
	check(not map.vent_send_btn.disabled, "send enabled within capacity")
	map.vent_spins["shield_1"].value = 100
	check(map.vent_send_btn.disabled, "send disabled over capacity")
	check(map.vent_summary.text.find("المستودع") >= 0, "summary explains how to raise the cap")
	map.vent_spins["shield_1"].value = 0
	check(map.vent_send_btn.disabled, "send disabled with no troops chosen")
	map.queue_free()

	# 9) واجهة المدينة: لوحة المستودع
	_fresh()
	Game.res = {"food": 99999.0, "wood": 99999.0, "coal": 99999.0, "iron": 99999.0}
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.plots["wd1"] = 3
	city.call("_select", "wd1")
	await get_tree().process_frame
	var txt := String(city.bp_stats.text)
	check(txt.find("حجم المسيرة") >= 0 and txt.find("150") >= 0 and txt.find("180") >= 0, "depot panel shows capacity 150 -> 180")
	check(txt.find("خصم مؤن") >= 0, "depot panel shows supply discount")
	city.queue_free()

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
