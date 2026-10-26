extends Node
## اختبار واجهة نافذة الصوت — من داخل مشهد المدينة الفعلي (الإعدادات والمنزلقات)
## التشغيل: godot --headless --path . res://test_audio_ui.tscn

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
	for c in n.get_children():
		found.append_array(_walk(c, kind))
	return found

func _ready() -> void:
	Game.save_path_override = "user://frost_save_test_audio_ui.json"
	Game.new_game()
	Sound.cfg_path_override = "user://audio_test_ui.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://audio_test_ui.cfg"))

	var city_scene: PackedScene = load("res://city.tscn")
	var city: Node = city_scene.instantiate()
	add_child(city)
	await get_tree().process_frame
	await get_tree().process_frame

	# 1) زر الصوت موجود في نافذة الإعدادات ويفتح نافذة الصوت
	city._show_settings()
	await get_tree().process_frame
	var audio_btns: Array = []
	for b in _walk(city.modal_layer, "Button"):
		if (b as Button).text == "الصوت":
			audio_btns.append(b)
	if audio_btns.size() != 1:
		fail("sound button missing from settings: %d" % audio_btns.size())
	else:
		print("PASS: settings has sound button")
		(audio_btns[0] as Button).pressed.emit()
		await get_tree().process_frame
		# 2) نافذة الصوت فيها منزلقان (موسيقى + مؤثرات)
		var sliders: Array = _walk(city.modal_layer, "Slider")
		if sliders.size() != 2:
			fail("expected 2 volume sliders, found %d" % sliders.size())
		else:
			print("PASS: audio window opens with 2 sliders")
			# 3) تحريك المنزلقات عبر الواجهة يغير قيم Sound فعلًا
			var music_s := sliders[0] as HSlider
			var sfx_s := sliders[1] as HSlider
			music_s.set_value(2.0)
			sfx_s.set_value(9.0)
			await get_tree().process_frame
			if absf(Sound.music_vol - 2.0) > 0.01:
				fail("music slider did not apply: %s" % Sound.music_vol)
			elif absf(Sound.sfx_vol - 9.0) > 0.01:
				fail("sfx slider did not apply: %s" % Sound.sfx_vol)
			elif not FileAccess.file_exists(ProjectSettings.globalize_path("user://audio_test_ui.cfg")):
				fail("audio cfg not saved from UI")
			else:
				print("PASS: audio window sliders apply and save")
		# 4) زر الإغلاق يغلق نافذة الصوت تحديدًا (وليس أي نافذة أخرى)
		if sliders.size() != 2:
			fail("cannot locate audio window without sliders")
		else:
			# نافذة الصوت = الجد المباشر لطفل modal_layer الذي يحوي المنزلقات
			var audio_win: Control = sliders[0] as Control
			while audio_win != null and audio_win.get_parent() != city.modal_layer:
				audio_win = audio_win.get_parent()
			var n_before: int = city.modal_layer.get_child_count()
			var cbtn: Button = null
			for b in _walk(audio_win, "Button"):
				if (b as Button).text == "إغلاق":
					cbtn = b
			if cbtn == null:
				fail("close button missing inside audio window")
			else:
				cbtn.pressed.emit()
				await get_tree().process_frame
				if is_instance_valid(audio_win) or city.modal_layer.get_child_count() != n_before - 1:
					fail("audio window did not close (kept=%s, children %d→%d)" % [is_instance_valid(audio_win), n_before, city.modal_layer.get_child_count()])
				else:
					print("PASS: audio window closes with button")

	# 5) إعادة فتح النافذة تعرض القيم المحفوظة (لا تصفير عند الفتح)
	city._audio_window()
	await get_tree().process_frame
	var sliders2: Array = _walk(city.modal_layer, "Slider")
	if sliders2.size() == 2:
		var m2 := sliders2[0] as HSlider
		if absf(m2.value - 2.0) > 0.01:
			fail("music slider should show saved value: %s" % m2.value)
		else:
			print("PASS: audio window remembers saved values")
	for b in _walk(city.modal_layer, "Button"):
		if (b as Button).text == "إغلاق":
			(b as Button).pressed.emit()
			break

	# تنظيف
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frost_save_test_audio_ui.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://audio_test_ui.cfg"))
	Sound.cfg_path_override = ""
	Sound.set_music_vol(8.0)
	Sound.set_sfx_vol(8.0)
	print("ALL AUDIO UI TESTS PASSED" if ok else "SOME AUDIO UI TESTS FAILED")
	get_tree().quit(0 if ok else 1)
