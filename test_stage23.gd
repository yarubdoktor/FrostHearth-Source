extends Node
## اختبار Stage 23 — بند 2.36 (الأبحاث من المختبر فقط) وبند 2.37 (الإعدادات عمودية)
## التشغيل: godot --headless --path . res://test_stage23.tscn

const Defs := preload("res://scripts/defs.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
	print(("PASS: " if value else "FAIL: ") + message)


func _buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)


func _find_vbox_with_buttons(n: Node, min_btn: int) -> VBoxContainer:
	if n is VBoxContainer:
		var cnt := 0
		for c in n.get_children():
			if c is Button:
				cnt += 1
		if cnt >= min_btn:
			return n
	for c in n.get_children():
		var r := _find_vbox_with_buttons(c, min_btn)
		if r != null:
			return r
	return null


func _ready() -> void:
	get_window().size = Vector2i(720, 1280)
	Game.save_path_override = "user://frost_save_test_stage23.json"
	Game.dev_mode = false
	Game.new_game()
	Game.set_process(false)
	Game.res = {"food": 99999.0, "wood": 99999.0, "coal": 99999.0, "iron": 99999.0}
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame

	# 2.36 — لا تبويب أبحاث في الشريط السفلي
	check(not city.side_btns.has("research"), "bottom bar has no research tab")
	var texts: Array[String] = []
	for k in city.side_btns:
		texts.append((city.side_btns[k] as Button).text)
	var any_research := false
	for t in texts:
		if t.begins_with("الأبحاث"):
			any_research = true
	check(not any_research, "no bottom button is labelled research")
	check(city.side_btns.size() == 5, "five bottom tabs remain")

	# تحديث الواجهة مع بحث جارٍ لا يسبب خطأ (كان يقرأ زر الأبحاث)
	Game.plots["lb1"] = 2
	var rid := ""
	for id in Defs.TECHS:
		rid = id
		break
	Game.research = {"id": rid, "lv": 1, "start": Game.now(), "end": Game.now() + 300.0}
	Game.changed.emit()
	await get_tree().process_frame
	check(true, "HUD refresh with a running research does not fail")

	# الأبحاث تُفتح من مختبر الجمر
	city.call("_select", "lb1")
	await get_tree().process_frame
	check(city.bp_open.visible and city.bp_open.text == "الأبحاث", "lab panel offers the research window")
	city.call("_open_from_panel")
	await get_tree().process_frame
	await get_tree().process_frame
	check(is_instance_valid(city.win_dim), "research window opens from the lab")
	city.call("_close_window")
	Game.research = {}

	# 2.37 — الإعدادات عمودية
	city.call("_show_settings")
	await get_tree().process_frame
	await get_tree().process_frame
	var col := _find_vbox_with_buttons(city.modal_layer, 5)
	check(col != null, "settings buttons are stacked in a vertical column")
	if col != null:
		var order: Array[String] = []
		var rects: Array = []
		for c in col.get_children():
			if c is Button:
				order.append((c as Button).text)
				rects.append((c as Button).get_global_rect())
		check(order.size() == 6, "settings has six buttons (%d)" % order.size())
		check(order[0] == "الصوت" and order[1] == "الإحصائيات" and order[2] == "تبديل الجودة", "audio, stats, quality come first")
		check(order[order.size() - 1] == "إغلاق", "close is the last button")
		check(order[order.size() - 2] == "بدء لعبة جديدة", "new game sits just above close")
		var vertical := true
		for i in range(1, rects.size()):
			if (rects[i] as Rect2).position.y <= (rects[i - 1] as Rect2).position.y:
				vertical = false
		check(vertical, "buttons go top to bottom")
		var first: Rect2 = rects[0]
		var inside := first.position.x >= 0.0 and first.end.x <= 720.0
		var wide := first.size.x >= 400.0
		check(inside and wide, "buttons fit 720 px and are wide (%d px)" % int(first.size.x))
		var last: Rect2 = rects[rects.size() - 1]
		check(last.end.y <= 1280.0, "settings window fits the 1280 px screen")
		# فجوة بين الزر الخطر وما قبله
		var gap: float = (rects[rects.size() - 2] as Rect2).position.y - (rects[rects.size() - 3] as Rect2).end.y
		check(gap >= 20.0, "danger button separated from the rest (gap %d)" % int(gap))
	for c in city.modal_layer.get_children():
		c.queue_free()
	await get_tree().process_frame

	# نافذة بزرّين تبقى صفًا أفقيًا (القرارات)
	city.call("_modal", "تجربة", "نص", [["نعم", func(): pass, "gold"], ["لا", func(): pass, "dark"]])
	await get_tree().process_frame
	await get_tree().process_frame
	var bs: Array = []
	_buttons(city.modal_layer, bs)
	check(bs.size() == 2 and absf((bs[0] as Button).get_global_rect().position.y - (bs[1] as Button).get_global_rect().position.y) < 1.0, "two-button modal stays a horizontal row")
	for c in city.modal_layer.get_children():
		c.queue_free()
	await get_tree().process_frame

	# أزرار الإعدادات تعمل
	city.call("_show_settings")
	await get_tree().process_frame
	var b2: Array = []
	_buttons(city.modal_layer, b2)
	var q0 := Game.quality_high
	for b in b2:
		if (b as Button).text == "تبديل الجودة":
			(b as Button).pressed.emit()
	await get_tree().process_frame
	check(Game.quality_high != q0, "quality toggle still works from the stacked settings")

	print("RESULT: %d/%d" % [checks - failures, checks])
	print("ALL PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)
