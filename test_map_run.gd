extends Node
## اختبار مشهد الخريطة — المرحلة 3 (يُشغَّل مع تحميل Game التلقائي)
## التشغيل: godot --headless --path . res://test_map_run.tscn

var ok := true

func fail(why: String) -> void:
	print("FAIL: " + why)
	ok = false

func _ready() -> void:
	Game.save_path_override = "user://frost_save_test_map.json"
	Game.new_game()   # بيئة اختبار نظيفة: المنفث غير محتل ولا مسيرة جارية
	var map_scene: PackedScene = load("res://world_map.tscn")
	var map: Node3D = map_scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	var vx := float(Game.vent["x"])
	var vz := float(Game.vent["y"])

	# 0) بلاطة المنفث كانت خالية قبل التسجيل: لا كيان آخر على بعد خانتين في بيانات الخريطة
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_data.json"))
	var too_close := false
	if typeof(data) == TYPE_DICTIONARY:
		for list_name in ["cities", "resources", "beasts", "landmarks"]:
			for e in data.get(list_name, []):
				if absf(float(e["x"]) - vx) < 2.0 and absf(float(e["y"]) - vz) < 2.0:
					too_close = true
	if too_close:
		fail("vent tile overlaps another entity in map data")

	# 1) المنفث ظاهر ومسجل في شبكة التحديد
	if map.vent_node == null or map.vent_label == null:
		fail("vent nodes missing")
	var vtile: Vector2i = Vector2i(int(vx), int(vz))
	if not map.lookup.has(vtile):
		fail("vent tile not registered")
	elif String(map.lookup[vtile]["kind"]) != "vent":
		fail("vent tile kind wrong")
	# 2) ارتفاع المنفث من التضاريس فعلاً (وليس القيمة الاحتياطية)
	var vy: float = map._terrain_height_at(vx + 0.5, vz + 0.5)
	if not map._scan_found:
		fail("terrain sampling fell back to default height")
	elif vy < -5.0 or vy > 60.0:
		fail("vent height suspicious: %f" % vy)
	# 3) لوحة تحديد المنفث
	map._select(map.lookup[vtile])
	if not map.panel.visible or map.p_title.text.find("المنفث") < 0:
		fail("vent panel title wrong")
	# 4) نافذة الجنود بلا جنود
	Game.troops = {}
	map._open_vent_window()
	if map.vent_win == null:
		fail("vent window did not open")
	else:
		map._close_vent_window()
	# 5) نافذة الجنود مع كل الأنواع الـ12: تمرير محدود الارتفاع والنافذة لا تتجاوز الشاشة
	Game.troops = {}
	for tp in ["shield", "spear", "bow"]:
		for t in range(1, 5):
			Game.troops["%s_%d" % [tp, t]] = 5
	map._open_vent_window()
	if map.vent_spins.size() != 12:
		fail("spin count %d" % map.vent_spins.size())
	await get_tree().process_frame
	await get_tree().process_frame
	if map.vent_win != null and map.vent_win.size.y > 640:
		fail("troop window exceeds screen height: %d" % int(map.vent_win.size.y))
	map._close_vent_window()
	# 6) إرسال فعلي من الواجهة + ثبات رسم المسيرة (لا يُهدم كل إطار)
	Game.troops = {"shield_1": 20, "bow_2": 10}
	map._open_vent_window()
	map.vent_spins["shield_1"].value = 15
	map._send_venture()
	if Game.venture.is_empty() or int(Game.troops["shield_1"]) != 5:
		fail("venture not started from UI")
	map._sync_marches()
	var id1: int = (map.march_vis["venture"]["troop"] as MeshInstance3D).get_instance_id()
	map._sync_marches()
	if (map.march_vis["venture"]["troop"] as MeshInstance3D).get_instance_id() != id1:
		fail("venture visualization churns every frame")
	# 7) المعركة بتوقيت الوصول ثم العودة
	Game.venture["arrive"] = Game.now() - 1.0
	Game.venture["back"] = Game.now() + 30.0
	Game._simulate(0.5, Game.now())
	if not bool(Game.venture.get("resolved", false)):
		fail("battle not resolved at arrival")
	elif not Game.vent["captured"]:
		fail("vent not captured")
	elif int(Game.troops["shield_1"]) != 5:
		fail("survivors returned before back time")
	Game.venture["back"] = Game.now() - 1.0
	Game._simulate(0.5, Game.now())
	if int(Game.troops.get("shield_1", 0)) <= 5:
		fail("survivors not returned")
	# 8) تنظيف رسم المسيرة بعد العودة
	map._sync_marches()
	if map.march_vis.has("venture"):
		fail("venture visualization not cleaned up after return")
	# 9) تنظيف ملف الحفظ الاختباري
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frost_save_test_map.json"))
	print("ALL MAP TESTS PASSED" if ok else "SOME MAP TESTS FAILED")
	get_tree().quit(0 if ok else 1)
