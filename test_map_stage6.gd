extends Node
## اختبار واجهة الخريطة — تعميق الخريطة: ضباب الحرب والمعاقل والتشكيلات
## التشغيل: godot --headless --path . res://test_map_stage6.tscn

var ok := true

func fail(why: String) -> void:
	print("FAIL: " + why)
	ok = false

func _ready() -> void:
	Game.save_path_override = "user://frost_save_test_map6.json"
	Game.new_game()   # بيئة اختبار نظيفة
	var map_scene: PackedScene = load("res://world_map.tscn")
	var map: Node3D = map_scene.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	# 0) طائرة الضباب موجودة فوق الخريطة بنسيج الكشف
	var fog_plane: MeshInstance3D = null
	for c in map.get_children():
		if c is MeshInstance3D and absf(c.position.x - 600.0) < 0.1 and absf(c.position.y - 4.5) < 0.1:
			fog_plane = c
			break
	if fog_plane == null or map.fog_tex == null:
		fail("fog plane/texture missing")
	if map.holds_label == null or map.holds_label.text.find("معاقل: 0/4") < 0:
		fail("holds label missing or wrong: %s" % map.holds_label.text if map.holds_label != null else "null")

	# 1) المنفث مخفي قبل الكشف (بعيد عن دائرة البيت) ويظهر بعد الكشف
	var vx := float(Game.vent["x"])
	var vz := float(Game.vent["y"])
	if Game.is_explored(int(vx), int(vz)):
		fail("vent should start unexplored")
	if map.vent_node.visible:
		fail("vent node should be hidden under fog")
	Game.reveal_at(vx, vz, 30.0)   # يجب أن يبثّ إشارة fog_changed فتُحدَّث الواجهة
	if not map.vent_node.visible:
		fail("vent node not shown after reveal")

	# 2) لوحات المناطق مخفية تحت الضباب حتى الكشف
	var hidden_lm := 0
	for fl in map.fog_labels:
		if not (fl["label"] as Label3D).visible:
			hidden_lm += 1
	if hidden_lm < 5:
		fail("labels should start hidden under fog (%d hidden only)" % hidden_lm)
	Game.reveal_at(670.0, 670.0, 30.0)   # منطقة المعقل
	var st_tile: Vector2i = Vector2i(670, 670)
	if not map.lookup.has(st_tile) or String(map.lookup[st_tile].get("kind", "")) != "lm":
		fail("stronghold_1 tile not registered")
	elif (map.lookup[st_tile]["n"] as String).is_empty():
		fail("stronghold name missing")

	# 3) لمس منطقة مجهولة: لا تسريب تفاصيل + إرسال استطلاع من الواجهة
	Game.marches = []
	map._on_tap(Vector3(300.5, 0.0, 300.5), Vector2.ZERO)
	if not map.panel.visible:
		fail("unknown tap did not open panel")
	elif map.p_title.text.find("منطقة غير مستكشفة") < 0:
		fail("unknown tap title wrong: %s" % map.p_title.text)
	elif map.p_action.text != "إرسال استطلاع":
		fail("unknown tap action wrong: %s" % map.p_action.text)
	else:
		map.p_action.pressed.emit()   # ضغط حقيقي على الزر → _on_action → _send_scout
		await get_tree().process_frame
		if Game.marches.is_empty():
			fail("scout not sent from UI")
		else:
			var sm: Dictionary = Game.marches.back()
			if String(sm.get("kind", "")) != "scout" or int(sm.get("tx", -1)) != 300:
				fail("scout march wrong: %s" % str(sm.get("kind")))
		if map.panel.visible:
			fail("panel should close after sending scout")

	# 4) نقل المدينة يُرفض في المناطق غير المستكشفة
	var home_before: Vector2i = Game.home
	map._move_home({"kind": "empty", "x": 300, "y": 300, "pos": Vector3(300.5, 0.0, 300.5)})
	if Game.home != home_before:
		fail("move_home should be rejected in unexplored area")

	# 5) اختيار معقل → نافذة الفرقة العسكرية مع هدف المعقل + أزرار التشكيل الثلاثة
	Game.troops = {"shield_1": 30, "bow_2": 10}
	Game.marches = []
	map._on_tap(Vector3(670.71, 0.0, 670.71), Vector2.ZERO)
	if not map.panel.visible or map.p_title.text != String(map.lookup[st_tile]["n"]):
		fail("stronghold panel title wrong: %s" % map.p_title.text)
	elif map.p_sub.text.find("يحرسه حرّاس") < 0:
		fail("stronghold sub wrong: %s" % map.p_sub.text)
	elif map.p_action.text != "أرسل فرقة عسكرية":
		fail("stronghold action wrong: %s" % map.p_action.text)
	else:
		map.p_action.pressed.emit()   # يفتح نافذة الفرقة نحو المعقل
		await get_tree().process_frame
		if map.vent_win == null:
			fail("venture window did not open for stronghold")
		else:
			if map.venture_target.get("kind", "") != "hold" or String(map.venture_target.get("id", "")) != "stronghold_1":
				fail("venture target not the stronghold: %s" % str(map.venture_target))
			if map._formation_btns.size() != 3:
				fail("formation buttons count: %d" % map._formation_btns.size())
			# ضغط زر التشكيل الهجومي عبر الواجهة
			(map._formation_btns["aggressive"] as Button).pressed.emit()
			if map.venture_formation != "aggressive":
				fail("formation pick did not register")
			# إرسال فعلي من الواجهة
			map.vent_spins["shield_1"].value = 25
			map._send_venture()
			if Game.venture.is_empty():
				fail("venture to stronghold not started")
			else:
				if Game.venture.get("target", {}).get("id", "") != "stronghold_1":
					fail("venture target wrong in Game state")
				if String(Game.venture.get("formation", "")) != "aggressive":
					fail("venture formation not saved")
				if int(Game.troops["shield_1"]) != 5:
					fail("troops not deducted on send")
			if map.vent_win != null:
				fail("venture window should close after send")

	# 6) نافذة الفرقة بنصوص عربية طويلة و12 نوع جنود: لا تتجاوز ارتفاع الشاشة
	Game.venture = {}
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
		fail("venture window exceeds screen height: %d" % int(map.vent_win.size.y))
	if map.vent_win != null:
		# النافذة متمركزة فعلًا ولا تغطي أزرار التنقل السفلية
		var bottom: float = map.vent_win.position.y + map.vent_win.size.y
		if bottom > map.ui.size.y - 54.0:
			fail("venture window overlaps bottom nav: bottom=%.0f ui=%.0f" % [bottom, map.ui.size.y])
	map._close_vent_window()

	# 7) المعقل المحتل يظهر «تحت سيطرتك» ولا يفتح نافذة إرسال جديدة
	Game.holds["stronghold_1"] = "stronghold"
	map._on_tap(Vector3(670.71, 0.0, 670.71), Vector2.ZERO)
	if map.p_sub.text.find("تحت سيطرتك") < 0 or map.p_action.text != "تفاصيل":
		fail("captured stronghold display wrong: %s / %s" % [map.p_sub.text, map.p_action.text])
	else:
		map.p_action.pressed.emit()
		await get_tree().process_frame
		if map.vent_win != null:
			fail("captured stronghold should not open venture window")

	# 8) تنظيف ملف الحفظ الاختباري
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frost_save_test_map6.json"))
	print("ALL STAGE6 MAP TESTS PASSED" if ok else "SOME STAGE6 MAP TESTS FAILED")
	get_tree().quit(0 if ok else 1)
