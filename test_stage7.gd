extends Node
## اختبارات حزمة الصوت — المنطق والنواقل والإعدادات وقاعدة صمت الغياب
## التشغيل: godot --headless --path . -s test_stage7.gd

const SM := preload("res://scripts/sound_manager.gd")
const UI := preload("res://scripts/ui_kit.gd")

var ok := true

func fail(why: String) -> void:
	print("FAIL: " + why)
	ok = false

func _ready() -> void:
	var test_cfg := "user://audio_test_cfg.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_cfg))

	# 1) كل الأصوات تُحمَّل كمصادر صوت سليمة
	var names := ["click", "collect", "build", "march", "victory", "defeat", "alert", "storm", "wind", "music"]
	for n in names:
		var s: AudioStream = Sound._streams.get(n)
		if s == null:
			fail("stream missing: " + n)
		elif s.get_length() <= 0.0:
			fail("stream empty: " + n)
	if ok:
		print("PASS: all 10 audio streams loaded")

	# 2) النواقل الثلاثة موجودة وتصب في Master
	for bus_name in ["Music", "Ambience", "SFX"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			fail("bus missing: " + bus_name)
		elif AudioServer.get_bus_send(idx) != "Master":
			fail("bus send wrong: " + bus_name)
	if ok:
		print("PASS: Music/Ambience/SFX buses exist")

	# 3) الموسيقى والرياح تعملان كحلقتين، والمجموعة 4 قنوات + قناة إنذار
	if not Sound._music.playing or Sound._music.stream == null:
		fail("music loop not playing")
	elif not Sound._wind.playing or Sound._wind.stream == null:
		fail("wind loop not playing")
	elif Sound._pool.size() != 4:
		fail("sfx pool size: %d" % Sound._pool.size())
	elif Sound._alert_p == Sound._pool[0]:
		fail("alert channel should be dedicated")
	elif Sound.get_child_count() > 8:
		fail("too many audio nodes (leak?)")
	if ok:
		print("PASS: loops playing, 4-channel pool + alert channel")

	# 4) التشغيل الأساسي: مؤثر معروف يشغّل، ومجهول لا يكسر شيئًا
	var before: int = Sound.play_count
	Sound.play("click")
	if Sound.play_count != before + 1 or Sound.last_played != "click":
		fail("play() did not register")
	Sound.play("nonexistent")
	if Sound.play_count != before + 1:
		fail("unknown sound should be ignored")
	if ok:
		print("PASS: play() works and unknown sounds ignored")

	# 5) قاعدة صمت الغياب: أثناء _offline لا صوت إطلاقًا
	before = Sound.play_count
	Game._offline = true
	Game.building_done.emit("sh1")
	Game.march_done.emit({})
	Game.venture_done.emit({"win": true})
	Game.raid_happened.emit({"win": true})
	Game.storm_changed.emit(true)
	if Sound.play_count != before:
		fail("sounds played during offline catch-up")
	Game._offline = false
	# والآن نفس الأحداث تشغّل الأصوات
	Game.building_done.emit("sh1")
	if Sound.last_played != "build":
		fail("building_done should play build sound")
	Game.venture_done.emit({"win": true})
	if Sound.last_played != "victory":
		fail("venture win should play victory")
	Game.venture_done.emit({"win": false})
	if Sound.last_played != "defeat":
		fail("venture loss should play defeat")
	Game.raid_happened.emit({"win": true})
	if Sound.last_played != "alert":
		fail("raid should play alert")
	Game.storm_changed.emit(true)
	if Sound.last_played != "storm":
		fail("storm should play storm warning")
	if ok:
		print("PASS: offline silence + live event sounds")

	# 6) شدة الرياح تتبع العاصفة (ضمن مستوى المستخدم — لا تلغيه)
	Game.storm_changed.emit(false)   # توحيد نقطة البداية: هدوء
	var calm_db: float = Sound._wind.volume_db
	Game.storm_changed.emit(true)
	if Sound._wind.volume_db <= calm_db:
		fail("wind should get louder in storm")
	Game.storm_changed.emit(false)
	if absf(Sound._wind.volume_db - calm_db) > 0.001:
		fail("wind level changed without storm change")
	if ok:
		print("PASS: wind intensity follows storm")

	# 7) الإعدادات تُحفظ وتُقرأ — ومسار الاختبار لا يمس ملف اللاعب
	Sound.cfg_path_override = test_cfg
	Sound.set_music_vol(3.0)
	Sound.set_sfx_vol(7.0)
	if not FileAccess.file_exists(ProjectSettings.globalize_path(test_cfg)):
		fail("audio cfg not saved")
	else:
		# نسخة جديدة تقرأ نفس القيم من نفس الملف
		var s2: Node = SM.new()
		s2.cfg_path_override = test_cfg
		s2._load_cfg()
		if absf(s2.music_vol - 3.0) > 0.01 or absf(s2.sfx_vol - 7.0) > 0.01:
			fail("cfg values not reloaded: %s/%s" % [s2.music_vol, s2.sfx_vol])
		s2.free()
	if ok:
		print("PASS: audio settings persist through ConfigFile")

	# 8) ملف تالف أو قيم شاذة → القيم الافتراضية أو تقييد سليم
	var s3: Node = SM.new()
	s3.cfg_path_override = "user://audio_test_bad.cfg"
	var bf := FileAccess.open(ProjectSettings.globalize_path("user://audio_test_bad.cfg"), FileAccess.WRITE)
	bf.store_string("not a config file at all {{{")
	bf.close()
	s3._load_cfg()
	if absf(s3.music_vol - 8.0) > 0.01 or absf(s3.sfx_vol - 8.0) > 0.01:
		fail("corrupt cfg should fall back to defaults")
	s3.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://audio_test_bad.cfg"))
	if ok:
		print("PASS: corrupt config falls back to defaults")

	# 9) الموسيقى: 0 توقفها فعلًا والعودة تعيدها
	Sound.set_music_vol(0.0)
	if Sound._music.playing:
		fail("music should stop at volume 0")
	Sound.set_music_vol(5.0)
	if not Sound._music.playing:
		fail("music should restart when volume > 0")
	if ok:
		print("PASS: music stops at 0 and restarts")

	# 10) زر الواجهة يشغّل نقرة — من مساعد الأزرار المشترك نفسه
	before = Sound.play_count
	var b: Button = UI.button("اختبار", func(): pass)
	b.pressed.emit()
	if Sound.play_count != before + 1 or Sound.last_played != "click":
		fail("UI.button does not play click")
	b.free()
	if ok:
		print("PASS: UI.button plays click sound")

	# 11) لعبة جديدة لا تمس إعدادات الصوت (استقلال تام عن حفظ اللعبة)
	Game.save_path_override = "user://frost_save_test_audio.json"
	Game.new_game()
	if absf(Sound.music_vol - 5.0) > 0.01:
		fail("new game must not touch audio settings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://frost_save_test_audio.json"))
	# تنظيف ملف اختبار الإعدادات
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_cfg))
	Sound.cfg_path_override = ""
	Sound.set_music_vol(8.0)
	Sound.set_sfx_vol(8.0)
	if ok:
		print("PASS: audio settings independent from game save")

	print("ALL STAGE7 AUDIO TESTS PASSED" if ok else "SOME STAGE7 AUDIO TESTS FAILED")
	get_tree().quit(0 if ok else 1)
