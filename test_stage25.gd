extends Node
## اختبار Stage 25 — تنظيم الواجهة: عداد القوة في المدينة + هيكل واجهة الخريطة الخارجية
## التشغيل: godot --headless --path . res://test_stage25.tscn

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


func _find(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var r := _find(c, nm)
		if r != null:
			return r
	return null


func _fresh() -> void:
	Game.save_path_override = "user://frost_save_test_stage25.json"
	Game.dev_mode = false
	Game.new_game()
	Game.set_process(false)
	Game.daily_ready = false
	Game.last_daily = Game._today()
	Game.stats["built"] = 1
	Game.offline_report = {}


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	_fresh()
	Game.res = {"food": 8000.0, "wood": 12000.0, "coal": 3500.0, "iron": 900.0}

	# ---- المدينة: عداد القوة شريط عريض تحت الصورة الشخصية
	var city: Node3D = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await _frames(6)
	Game.changed.emit()
	await _frames(2)
	var bar := _find(city, "PowerBar") as Control
	check(bar != null, "city has a PowerBar")
	check(city.power_label != null and bar.is_ancestor_of(city.power_label), "power_label lives inside the bar")
	check(city.power_label.text == Defs.fmt(Game.power()), "power value shown")
	var av: Control = city.avatar_btn
	var br := bar.get_global_rect()
	var ar := av.get_global_rect()
	check(br.size.x >= 200.0, "power bar is wide (>= 200px): %d" % int(br.size.x))
	check(br.position.y >= ar.end.y - 2.0 and br.position.y - ar.end.y < 30.0, "bar sits directly under the avatar row")
	check(absf(br.end.x - ar.end.x) <= 24.0, "bar is right-aligned with the avatar")
	check(br.position.x >= 0.0 and br.end.x <= 720.0, "bar fits the 720 px width")
	var head: Control = city.march_head
	check(head != null and not br.intersects(head.get_global_rect().grow(-1.0)), "bar does not overlap the march queue")
	var temp_r: Rect2 = city.temp_chip.get_global_rect()
	check(not br.intersects(temp_r), "bar does not overlap the temperature chip")
	city.queue_free()
	await _frames(3)

	# ---- الخريطة: هيكل منظم
	var map: Node3D = (load("res://world_map.tscn") as PackedScene).instantiate()
	add_child(map)
	await _frames(8)
	Game.changed.emit()
	await _frames(2)
	var mbar := _find(map, "PowerBar") as Control
	check(mbar != null and map.power_label != null, "map has the same PowerBar")
	check(map.power_label.text == Defs.fmt(Game.power()), "map power value matches")
	for r in ["food", "wood", "coal", "iron", "gems"]:
		check(map.res_chips.has(r), "map top bar has chip " + r)
	check(map.res_chips["food"].text == Defs.fmt(Game.res["food"]), "map food chip shows the stock")
	var top := _find(map, "MapTop") as Control
	var tr := top.get_global_rect()
	check(tr.position.x >= 0.0 and tr.end.x <= 720.0, "top bar fits 720 px")
	var mbr := mbar.get_global_rect()
	check(mbr.end.x <= 720.0 and mbr.position.y >= 40.0, "map power bar below the resource strip and inside the screen")

	# شريط التنقل: خمسة أزرار متساوية العرض ومرئية بالكامل
	check(map.nav_btns.size() == 5, "five navigation buttons")
	var w0 := -1.0
	var equal := true
	var inside := true
	var rects: Array[Rect2] = []
	for k in map.nav_btns:
		var b: Button = map.nav_btns[k]
		var rc := b.get_global_rect()
		rects.append(rc)
		if w0 < 0.0:
			w0 = rc.size.x
		if absf(rc.size.x - w0) > 1.5:
			equal = false
		if rc.position.x < 0.0 or rc.end.x > 720.0 or rc.end.y > 1280.0:
			inside = false
	check(equal, "nav buttons have equal width")
	check(inside, "nav buttons are fully visible (no clipping)")
	var overlap := false
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].grow(-1.0).intersects(rects[j].grow(-1.0)):
				overlap = true
	check(not overlap, "nav buttons do not overlap each other")
	check(map.nav_btns["enter"].get_global_rect().end.x > 700.0, "enter-city is the right-most button")

	# الأعمدة: بطاقة الحالة يسارًا ولوحة الفرق يمينًا بلا تراكب
	var card := _find(map, "MapStatusCard") as Control
	var march_panel := _find(map, "MarchStatusPanel") as Control
	check(card != null and march_panel != null, "status card and march panel exist")
	check(not card.get_global_rect().intersects(march_panel.get_global_rect()), "status card and march panel do not overlap")
	check(not mbr.intersects(card.get_global_rect()) and not mbr.intersects(march_panel.get_global_rect()), "power bar does not overlap the columns")
	check(march_panel.get_global_rect().end.x <= 720.0, "march panel inside width")

	# صفيحة الأدوات
	check(not map.tools_sheet.visible, "tools sheet hidden at start")
	map.nav_btns["tools"].pressed.emit()
	await _frames(3)
	check(map.tools_sheet.visible, "tools button opens the sheet")
	var sr: Rect2 = map.tools_sheet.get_global_rect()
	check(sr.end.y <= map.nav_btns["tools"].get_global_rect().position.y + 1.0, "tools sheet sits above the nav bar")
	check(sr.position.x >= 0.0 and sr.end.x <= 720.0, "tools sheet fits the width")
	map.nav_btns["tools"].pressed.emit()
	await _frames(2)
	check(not map.tools_sheet.visible, "tools button toggles the sheet closed")
	map.nav_btns["tools"].pressed.emit()
	await _frames(2)
	map.biome_button.pressed.emit()
	await _frames(2)
	check(not map.tools_sheet.visible, "using a tool closes the sheet")

	# المعلومات السفلية تغلق الصفيحة
	map.nav_btns["tools"].pressed.emit()
	await _frames(2)
	map._select({"kind": "res", "t": "food", "l": 3, "pos": Vector3(10, 0, 10), "x": 10, "y": 10})
	await _frames(2)
	check(map.panel.visible and not map.tools_sheet.visible, "opening the info panel closes the tools sheet")

	# لوحة المعلومات فوق شريط التنقل
	var nav_top: float = map.nav_btns["enter"].get_global_rect().position.y
	check(map.panel.get_global_rect().end.y <= nav_top + 1.0 or not map.panel.visible, "info panel never covers the nav bar %s %s" % [map.panel.get_global_rect(), nav_top])

	# تحديث الموارد
	Game.res["food"] = 1234.0
	map._refresh_stock()
	check(map.res_chips["food"].text == Defs.fmt(1234.0), "refresh updates the food chip")

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
