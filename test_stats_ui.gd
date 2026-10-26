extends Node
## اختبار واجهة شاشة الإحصائيات — من داخل مشهد المدينة الفعلي
## التشغيل: godot --headless --path . res://test_stats_ui.tscn

var ok := true

func fail(why: String) -> void:
	print("FAIL: " + why)
	ok = false

func _walk(n: Node, kind: String) -> Array:
	var found: Array = []
	if kind == "Button" and n is Button:
		found.append(n)
	elif kind == "Slider" and n is Slider:
		found.append(n)
	elif kind == "Label" and n is Label:
		found.append(n)
	for c in n.get_children():
		found.append_array(_walk(c, kind))
	return found

func _labels_with(txt: String, root: Node) -> Array:
	var out: Array = []
	for l in _walk(root, "Label"):
		if txt in (l as Label).text:
			out.append(l)
	return out

func _ready() -> void:
	Game.save_path_override = "user://frost_save_test_stats_ui.json"
	Game.new_game()
	Game.troops["shield_1"] = 15
	Game.wounded["shield_1"] = 2
	Game.holds["stronghold_1"] = "stronghold"

	var city_scene: PackedScene = load("res://city.tscn")
	var city: Node = city_scene.instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) زر الإحصائيات موجود في الإعدادات ويفتح النافذة
	city._show_settings()
	await get_tree().process_frame
	var stats_btns: Array = []
	for b in _walk(city.modal_layer, "Button"):
		if (b as Button).text == "الإحصائيات":
			stats_btns.append(b)
	if stats_btns.size() != 1:
		fail("stats button missing from settings: %d" % stats_btns.size())
	else:
		print("PASS: settings has stats button")
		(stats_btns[0] as Button).pressed.emit()
		await get_tree().process_frame
		await get_tree().create_timer(0.1).timeout
		# 2) النافذة تعرض الأقسام والقيم الصحيحة لحالة معروفة
		var win: Control = null
		for l in _walk(city.modal_layer, "Label"):
			if (l as Label).text == "الإحصائيات":
				win = (l as Label).get_parent().get_parent().get_parent()
		if win == null:
			fail("stats window did not open")
		else:
			var sections := ["المدينة", "الاقتصاد الآن", "الجيش", "الخريطة والسيطرة", "الإنجاز التراكمي"]
			var all_sections := true
			for sec in sections:
				if _labels_with(sec, win).is_empty():
					fail("section missing: " + sec)
					all_sections = false
			if all_sections:
				print("PASS: all 5 sections shown")
			if _labels_with("الجنود: 15", win).is_empty():
				fail("troops value not displayed (expected الجنود: 15)")
			elif _labels_with("الجرحى: 2/", win).is_empty():
				fail("wounded value not displayed")
			elif _labels_with("معاقل: 1/4", win).is_empty():
				fail("stronghold count not displayed")
			else:
				print("PASS: known values displayed correctly")
			# 3) القيم تتحدث حيًّا كل ثانية ما دامت النافذة مفتوحة
			Game.troops["shield_1"] = 25
			await get_tree().create_timer(2.6).timeout
			if _labels_with("الجنود: 25", win).is_empty():
				fail("live refresh did not update troops to 25")
			else:
				print("PASS: live refresh updates values")
			# 3.5) موضع التمرير لا يقفز أثناء دورات التحديث الحي
			var scroll: ScrollContainer = null
			var stack2: Array = [win]
			while not stack2.is_empty():
				var n2: Node = stack2.pop_back()
				if n2 is ScrollContainer:
					scroll = n2
				stack2.append_array(n2.get_children())
			if scroll == null:
				fail("scroll container missing in stats window")
			else:
				var bar := scroll.get_v_scroll_bar()
				scroll.scroll_vertical = int(bar.max_value)
				await get_tree().process_frame
				await get_tree().process_frame
				var v_at_bottom: int = scroll.scroll_vertical
				await get_tree().create_timer(3.2).timeout   # ثلاث دورات تحديث أو أكثر
				if scroll.scroll_vertical < v_at_bottom - 2:
					fail("scroll position jumped during refresh (%d → %d)" % [v_at_bottom, scroll.scroll_vertical])
				else:
					# آخر سطر لا يزال ظاهرًا داخل منطقة العرض
					var last_ok := false
					for l in _walk(win, "Label"):
						if "أبحاث مكتملة" in (l as Label).text:
							var lrect: Rect2 = (l as Label).get_global_rect()
							var srect: Rect2 = scroll.get_global_rect()
							last_ok = lrect.intersects(srect, true)
					if not last_ok:
						fail("last line not visible after refreshes at bottom")
					else:
						print("PASS: scroll position stable during refresh")
			# 4) زر الإغلاق يحرر نافذة الإحصائيات نفسها تحديدًا
			var n_before: int = city.modal_layer.get_child_count()
			var cbtn: Button = null
			for b in _walk(win, "Button"):
				if (b as Button).text == "إغلاق":
					cbtn = b
			if cbtn == null:
				fail("close button missing inside stats window")
			else:
				cbtn.pressed.emit()
				await get_tree().process_frame
				if is_instance_valid(win) or city.modal_layer.get_child_count() != n_before - 1:
					fail("stats window did not close (kept=%s, children %d→%d)" % [is_instance_valid(win), n_before, city.modal_layer.get_child_count()])
				else:
					print("PASS: stats window closes with button")
	# 5) فتح النافذة لا يغيّر الحفظ (اللقطة للقراءة فقط عبر الواجهة)
	# نجمّد المحاكاة حتى لا يتقدم العالم بين الحفظين فيفسد المقارنة
	get_tree().paused = true
	Game.save_game()
	var f := FileAccess.open(Game._save_path(), FileAccess.READ)
	var before: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	before.erase("time")
	city._stats_window()
	await get_tree().process_frame
	city._stats_window()   # فتح مرة ثانية فوق الأولى
	await get_tree().process_frame
	for d in city.modal_layer.get_children():
		d.queue_free()
	await get_tree().process_frame
	Game.save_game()
	f = FileAccess.open(Game._save_path(), FileAccess.READ)
	var after: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	after.erase("time")
	get_tree().paused = false
	if after != before:
		fail("opening stats window changed the save")
	else:
		print("PASS: opening stats window does not change save")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game._save_path()))
	if ok:
		print("ALL STATS UI TESTS PASSED")
	get_tree().quit(0 if ok else 1)
