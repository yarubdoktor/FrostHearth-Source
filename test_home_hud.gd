extends Node
## اختبار الشاشة الرئيسية الجديدة (2ب) — من داخل مشهد المدينة الفعلي

const UI := preload("res://scripts/ui_kit.gd")
## التشغيل: godot --headless --path . res://test_home_hud.tscn

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


func _ready() -> void:
	Game.save_path_override = "user://frost_save_test_home_hud.json"
	Game.dev_mode = false
	Game.new_game()
	var city: Node = (load("res://city.tscn") as PackedScene).instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) كل عناصر الشاشة موجودة
	check(city.res_chips.size() == 4 and city.gem_label != null and city.aurora_label != null, "resource chips + gems + aurora exist")
	check(city.temp_label != null and city.power_label != null and city.pop_label != null and city.trust_label != null, "temperature, power, population, trust chips exist")
	check(city.avatar_btn != null, "profile avatar button exists")
	var avatar_style: StyleBox = city.avatar_btn.get_theme_stylebox("normal")
	check(avatar_style is StyleBoxTexture, "primary buttons use the nine-slice gradient skin")
	var panel_style := UI.style(Color(0.04, 0.08, 0.14, 0.9))
	check(panel_style.anti_aliasing and panel_style.shadow_size >= 9, "shared panels use anti-aliased edges and deeper elevation")
	check(city.task_btn != null and city.task_title != null, "task strip exists")
	check(city.dev_btn != null and not city.dev_btn.visible, "dev button exists and hidden by default")
	check(city.builder_rows.size() == Game.MAX_BUILDERS, "builder rows match max builders (%d)" % city.builder_rows.size())
	check(city.march_rows.size() == 3, "3 march rows (2 map squads + military venture)")

	# 2) شريط التنقل: خمسة أزرار (الأبحاث من المختبر فقط — Stage 23)
	var keys := ["map", "army", "decision", "hero", "task"]
	var all_nav := true
	for k in keys:
		if not city.side_btns.has(k):
			all_nav = false
	check(all_nav, "bottom navigation has 5 tabs")
	check(not city.side_btns.has("research"), "research tab removed from the bottom bar")

	# 3) النصوص تتحدث
	Game.res["food"] = 12345.0
	Game.gems = 77
	Game.changed.emit()
	await get_tree().process_frame
	check((city.res_chips["food"] as Label).text == "12K", "food chip shows value (%s)" % (city.res_chips["food"] as Label).text)
	check(city.gem_label.text == "77", "gem chip shows value")

	# 4) طابور الزحف: لا فرق ← 0/3 والصفوف مخفية
	check(city.march_head.text == "زحف 0/3", "march header empty (%s)" % city.march_head.text)
	var any_visible := false
	for r in city.march_rows:
		if (r["panel"] as Control).visible:
			any_visible = true
	check(not any_visible, "no march rows visible when idle")

	# 5) فرقة جمع واحدة تظهر بصف وعدّاد
	var t := Game.now()
	Game.marches.append({"kind": "res", "t": "wood", "l": 1, "name": "", "fx": 0.0, "fy": 0.0, "tx": 1.0, "ty": 1.0,
		"start": t, "arrive": t + 30.0, "leave": t + 60.0, "back": t + 90.0})
	Game.changed.emit()
	await get_tree().process_frame
	check(city.march_head.text == "زحف 1/3", "march header counts one squad (%s)" % city.march_head.text)
	check((city.march_rows[0]["panel"] as Control).visible and not (city.march_rows[1]["panel"] as Control).visible, "first row visible only")
	check((city.march_rows[0]["label"] as Label).text.find("خشب") >= 0, "row names the resource (%s)" % (city.march_rows[0]["label"] as Label).text)
	Game.marches.clear()

	# 6) الأزرار تعمل: المهام تفتح نافذة، والأفاتار يفتح الملف الشخصي ومنه الإعدادات
	(city.side_btns["task"] as Button).pressed.emit()
	await get_tree().process_frame
	check(city.modal_layer.get_child_count() > 0, "task tab opens a window")
	for c in city.modal_layer.get_children():
		c.queue_free()
	await get_tree().process_frame
	city.avatar_btn.pressed.emit()
	await get_tree().process_frame
	var btns: Array = []
	_buttons(city.modal_layer, btns)
	var gear: Button = null
	for b in btns:
		if (b as Button).text == "الإعدادات":
			gear = b
	check(gear != null, "avatar opens the profile (settings button inside it)")
	if gear != null:
		gear.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	btns = []
	_buttons(city.modal_layer, btns)
	var has_audio := false
	for b in btns:
		if (b as Button).text == "الصوت":
			has_audio = true
	check(has_audio, "settings reachable from the profile (audio button found)")

	print("---- home_hud: %d checks, %d failures" % [checks, failures])
	if failures == 0:
		print("ALL PASSED")
	get_tree().quit(1 if failures > 0 else 0)
